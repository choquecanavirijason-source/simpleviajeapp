import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:buses2/core/services/notification/notification_service.dart';

class PassengerOffersListenerService {
  PassengerOffersListenerService._();
  static final PassengerOffersListenerService instance =
      PassengerOffersListenerService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Listeners principales de la lista de pedidos
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ordenesNormalSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _ordenesProgramadoSub;

  // AHORA: Un mapa para manejar múltiples suscripciones de ofertas simultáneas
  // Key: Path del documento de la orden
  // Value: La suscripción a la subcolección de ofertas de esa orden
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _activeOfferSubscriptions = {};

  // Cache local de precios ofertados por path de documento de oferta,
  // para distinguir cambios reales del taxista de cambios internos
  // (como la contraoferta del pasajero que solo toca otros campos).
  final Map<String, double> _lastOfferPriceByPath = {};

  /// Inicia la cadena de listeners, solo si el usuario está en modo PASAJERO.
  Future<void> startListening() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    final mode = await _resolveUserMode();
    if (mode != 'pasajero') {
      await stopListening();
      if (kDebugMode) {
        debugPrint(
          'PassengerOffersListener: modo "$mode" ≠ pasajero, no se escuchan ofertas',
        );
      }
      return;
    }

    if (kDebugMode) {
      debugPrint(
        'PassengerOffersListener: iniciando escucha MULTIPLE para pasajero $uid',
      );
    }

    _listenPedidos(uid);
  }

  /// Detiene TODOS los listeners activos (ordenes + todas las ofertas).
  Future<void> stopListening() async {
    await _ordenesNormalSub?.cancel();
    await _ordenesProgramadoSub?.cancel();

    // Cancelamos todas las suscripciones de ofertas activas
    for (final sub in _activeOfferSubscriptions.values) {
      await sub.cancel();
    }
    _activeOfferSubscriptions.clear();

    _ordenesNormalSub = null;
    _ordenesProgramadoSub = null;

    if (kDebugMode) {
      debugPrint('PassengerOffersListener: listeners detenidos');
    }
  }

  void _listenPedidos(String uid) {
    _ordenesNormalSub?.cancel();
    _ordenesProgramadoSub?.cancel();

    // Stream 1: Órdenes Normales
    final streamNormal = _db
        .collection('ordenesPasajeros')
        .doc(uid)
        .collection('ordenes')
        .where('estado', isEqualTo: 'pedido')
        .snapshots();

    // Stream 2: Órdenes Programadas
    final streamProgramado = _db
        .collection('ordenesPasajeros')
        .doc(uid)
        .collection('ordenesProgramados')
        .where('estado', isEqualTo: 'pedido')
        .snapshots();

    QuerySnapshot<Map<String, dynamic>>? lastNormalSnap;
    QuerySnapshot<Map<String, dynamic>>? lastProgramadoSnap;

    // Esta función se llama cada vez que CUALQUIERA de las dos listas cambia
    void sincronizarListeners() {
      final normalDocs = lastNormalSnap?.docs ?? const [];
      final programadoDocs = lastProgramadoSnap?.docs ?? const [];

      // 1. Obtenemos una lista de todos los PATHS que deberían estar activos
      final Set<String> activeOrderPaths = {};

      for (var doc in normalDocs) activeOrderPaths.add(doc.reference.path);
      for (var doc in programadoDocs) activeOrderPaths.add(doc.reference.path);

      // 2. ELIMINAR STALE: Cancelamos listeners de órdenes que ya no existen o cambiaron de estado
      // Iteramos sobre una copia de las llaves para poder modificar el mapa
      final currentSubscribedPaths = _activeOfferSubscriptions.keys.toList();

      for (final path in currentSubscribedPaths) {
        if (!activeOrderPaths.contains(path)) {
          // La orden ya no está activa, cancelamos su listener de ofertas
          _activeOfferSubscriptions[path]?.cancel();
          _activeOfferSubscriptions.remove(path);
          if (kDebugMode) debugPrint('Dejando de escuchar ofertas para: $path');
        }
      }

      // 3. AGREGAR NUEVOS: Iniciamos listeners para órdenes nuevas que aun no escuchamos
      for (final path in activeOrderPaths) {
        if (!_activeOfferSubscriptions.containsKey(path)) {
          if (kDebugMode)
            debugPrint('Iniciando escucha de ofertas para: $path');
          _startListeningToOrder(path);
        }
      }
    }

    _ordenesNormalSub = streamNormal.listen((snapshot) {
      lastNormalSnap = snapshot;
      sincronizarListeners();
    });

    _ordenesProgramadoSub = streamProgramado.listen((snapshot) {
      lastProgramadoSnap = snapshot;
      sincronizarListeners();
    });
  }

  // Crea un listener dedicado para una orden específica y lo guarda en el mapa
  void _startListeningToOrder(String orderPath) {
    final ref = _db
        .doc(orderPath)
        .collection('ofertas')
        .where('estado', isEqualTo: 'pendiente');

    // Usamos una variable local para controlar la carga inicial DE ESTA suscripción específica
    bool isFirstLoad = true;

    final subscription = ref.snapshots().listen((snapshot) async {
      // Ignoramos la primera carga de datos (snapshots existentes) para no spamear
      if (isFirstLoad) {
        isFirstLoad = false;
        return;
      }

      final esProgramado = orderPath.contains('ordenesProgramados');

      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added ||
            change.type == DocumentChangeType.modified) {
          final data = change.doc.data();
          final esNuevo = change.type == DocumentChangeType.added;

          // Usamos un pequeño cache para saber si realmente cambió
          // el precio ofertado del taxista. Las contraofertas del
          // pasajero actualizan otros campos (como tarifa.precioOfrecido)
          // y no deberían generar notificación aquí.
          final path = change.doc.reference.path;
          final rawPrecio =
              data?['precioOfertado'] ??
              data?['precioOfrecido'] ??
              data?['precioRecomendado'];

          double? precioActual;
          if (rawPrecio is num) {
            precioActual = rawPrecio.toDouble();
          } else if (rawPrecio != null) {
            precioActual = double.tryParse(rawPrecio.toString());
          }

          if (precioActual == null) {
            continue;
          }

          final previo = _lastOfferPriceByPath[path];
          _lastOfferPriceByPath[path] = precioActual;

          // Si es una modificación y el precio no cambió, la ignoramos:
          if (!esNuevo &&
              previo != null &&
              (previo - precioActual).abs() < 1e-6) {
            if (kDebugMode) {
              debugPrint(
                'PassengerOffersListener: cambio en $path sin variación de precioOfertado, se ignora',
              );
            }
            continue;
          }

          final titulo = esNuevo
              ? (esProgramado
                    ? '¡Nueva oferta para tu viaje programado!'
                    : '¡Nueva oferta para tu viaje!')
              : (esProgramado
                    ? 'Precio actualizado en tu viaje programado'
                    : 'Precio actualizado en tu viaje');

          final cuerpo = esProgramado
              ? "${data?['nombre']} ofrece su servicio por ${data?['precioOfertado']} en tu viaje programado."
              : "${data?['nombre']} ofrece su servicio por ${data?['precioOfertado']} en tu viaje.";

          await NotificationService().showNewOfferNotification(
            rutaDocOrden:
                orderPath, // Importante: pasamos el path de ESTA orden
            titulo: titulo,
            cuerpo: cuerpo,
          );
        }
      }
    }, onError: (e) => debugPrint('Error escuchando ofertas en $orderPath: $e'));

    // Guardamos la suscripción en el mapa
    _activeOfferSubscriptions[orderPath] = subscription;
  }

  Future<String> _resolveUserMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('modo');
      if (cached != null && cached.isNotEmpty) {
        return cached.toLowerCase() == 'taxista' ? 'taxista' : 'pasajero';
      }
      return 'pasajero';
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error resolviendo modo: $e');
      }
      return 'pasajero';
    }
  }
}
