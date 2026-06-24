import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

import 'package:buses2/core/services/notification/notification_service.dart';
import 'package:buses2/features/home_taxi_features/home_taxi/services/ride_request_service.dart';

/// Servicio que encapsula el listener de órdenes normales (estado "pedido")
/// y aplica los filtros de:
///   - ubicación del taxista
///   - tipo de servicio del taxista
///   - estado libre/ocupado del taxista
///
/// Se expone un stream ya filtrado, y métodos para:
///   - startListening / stopListening (Firestore)
///   - updateLocation / updateServiceType / updateDisponibilidad
class OrderService {
  OrderService._();
  static final OrderService instance = OrderService._();
  factory OrderService() => instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Inputs reactivos ---
  final BehaviorSubject<Map<String, double>?> _ubicacionController =
      BehaviorSubject.seeded(null);
  final BehaviorSubject<String?> _servicioController = BehaviorSubject.seeded(
    null,
  );
  final BehaviorSubject<bool> _disponibleController = BehaviorSubject.seeded(
    false,
  );

  // --- Salida: Lista de órdenes para la UI (Normales) ---
  final BehaviorSubject<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _ordersController = BehaviorSubject.seeded(const []);

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> get ordersStream =>
      _ordersController.stream;

  // --- Suscripciones y Estado Interno ---
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _firestoreSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _firestoreScheduledSubscription;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _lastFirestoreDocs =
      const [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _lastScheduledDocs =
      const [];

  // Set para evitar notificaciones repetidas de la misma orden
  final Set<String> _notifiedOrderPaths = <String>{};

  // --- BANDERAS DE CONTROL (Para evitar notificaciones al iniciar) ---
  bool _firstLoadNormals = true;
  bool _firstLoadScheduled = true;

  /// Comienza a escuchar las órdenes en Firestore.
  void startListening() {
    if (_firestoreSubscription != null) {
      debugPrint('📡 OrderService: ya estaba escuchando (no-op)');
      return;
    }
    debugPrint('📡 OrderService: startListening() INICIADO');

    // Reseteamos
    _firstLoadNormals = true;
    _firstLoadScheduled = true;
    _notifiedOrderPaths.clear();

    // 1. Query Normales
    final query = _db
        .collectionGroup('ordenes')
        .where('estado', isEqualTo: 'pedido')
        .orderBy('createdAt', descending: true)
        .limit(20);

    _firestoreSubscription = query.snapshots().listen(
      (snapshot) {
        _lastFirestoreDocs = snapshot.docs;

        if (_firstLoadNormals) {
          for (var doc in snapshot.docs) {
            _notifiedOrderPaths.add(doc.reference.path);
          }
          debugPrint(
            'OrderService: Carga inicial Normales (${snapshot.docs.length} docs).',
          );
          _firstLoadNormals = false;
        }

        _recomputeAndEmit();
      },
      onError: (e) {
        debugPrint(
          '🟥 OrderService Firestore ERROR (normales): $e\n'
          '⚠️  Verificar: índice collectionGroup "ordenes" y reglas de Firestore.',
        );
      },
    );

    // 2. Query Programadas
    final scheduledQuery = _db
        .collectionGroup('ordenesProgramados')
        .where('estado', isEqualTo: 'pedido')
        .orderBy('createdAt', descending: true)
        .limit(20);

    _firestoreScheduledSubscription = scheduledQuery.snapshots().listen(
      (snapshot) {
        _lastScheduledDocs = snapshot.docs;

        if (_firstLoadScheduled) {
          for (var doc in snapshot.docs) {
            _notifiedOrderPaths.add(doc.reference.path);
          }
          debugPrint(
            'OrderService: Carga inicial Programadas (${snapshot.docs.length} docs).',
          );
          _firstLoadScheduled = false;
        }

        _recomputeAndEmit();
      },
      onError: (e) {
        debugPrint(
          '🟥 OrderService Firestore ERROR (programados): $e\n'
          '⚠️  Verificar: índice collectionGroup "ordenesProgramados" y reglas de Firestore.',
        );
      },
    );
  }

  /// Detiene la suscripción y limpia todo.
  Future<void> stopListening() async {
    await _firestoreSubscription?.cancel();
    _firestoreSubscription = null;
    await _firestoreScheduledSubscription?.cancel();
    _firestoreScheduledSubscription = null;

    _lastFirestoreDocs = const [];
    _lastScheduledDocs = const [];
    _ordersController.add(const []);

    _notifiedOrderPaths.clear();
    // Importante: Resetear banderas para la próxima vez que se llame a start
    _firstLoadNormals = true;
    _firstLoadScheduled = true;
  }

  // --- Métodos de actualización de estado del taxista ---

  void updateLocation(double lat, double lng) {
    _ubicacionController.add({'lat': lat, 'lng': lng});
    _recomputeAndEmit();
  }

  void markLocationUnavailable() {
    _ubicacionController.add(null);
    _recomputeAndEmit();
  }

  void updateServiceType(String? service) {
    _servicioController.add(service);
    _recomputeAndEmit();
  }

  void updateDisponibilidad(bool estaLibre) {
    _disponibleController.add(estaLibre);
    _recomputeAndEmit();
  }

  /// Lógica central: Filtra por distancia/servicio y gestiona notificaciones
  void _recomputeAndEmit() {
    final docsNormales = _lastFirestoreDocs;
    final docsProgramados = _lastScheduledDocs;
    final coords = _ubicacionController.valueOrNull;
    final servicioDriver = _servicioController.valueOrNull;
    final estaLibre = _disponibleController.valueOrNull ?? false;

    // Si no está libre o no hay GPS, limpiar y salir
    if (!estaLibre || coords == null) {
      if (kDebugMode) {
        debugPrint(
          '📡 OrderService: bloqueado – libre=$estaLibre, coords=${coords != null}',
        );
      }
      _ordersController.add(const []);
      return;
    }

    final driverLat = coords['lat']!;
    final driverLng = coords['lng']!;

    // Normaliza: minúsculas, sin espacios/underscores extra
    // Permite que "simple_uber" y "simple uber" coincidan
    final srvNormDriver =
        servicioDriver != null ? _normalize(servicioDriver) : null;

    // --- FUNCIÓN DE FILTRADO (Reutilizable) ---
    bool filtroGeneral(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final data = doc.data();

      // 1. Filtro de Servicio (solo si el conductor tiene servicio no vacío)
      if (srvNormDriver != null && srvNormDriver.isNotEmpty) {
        final ordenServicio = data['servicio']?.toString();
        final srvNormOrden = _normalize(ordenServicio);
        if (srvNormOrden != srvNormDriver) {
          if (kDebugMode) {
            debugPrint(
              '⏭️ OrderService: orden ${doc.id} filtrada por servicio '
              '"$ordenServicio" (norm:"$srvNormOrden") != "$servicioDriver" (norm:"$srvNormDriver")',
            );
          }
          return false;
        }
      }

      // 2. Filtro de Distancia
      final origen = data['origen'] as Map<String, dynamic>?;
      if (origen == null) {
        if (kDebugMode) {
          debugPrint('⏭️ OrderService: orden ${doc.id} sin campo "origen"');
        }
        return false;
      }

      final dynamic rawLat = origen['lat'];
      final dynamic rawLng = origen['lng'];

      final double? oLat = (rawLat is num)
          ? rawLat.toDouble()
          : double.tryParse(rawLat.toString());
      final double? oLng = (rawLng is num)
          ? rawLng.toDouble()
          : double.tryParse(rawLng.toString());

      if (oLat == null || oLng == null) {
        if (kDebugMode) {
          debugPrint(
            '⏭️ OrderService: orden ${doc.id} coordenadas origen inválidas',
          );
        }
        return false;
      }

      final distance = GeoUtils.calculateDistanceHaversine(
        lat1: driverLat,
        lon1: driverLng,
        lat2: oLat,
        lon2: oLng,
      );

      // Radio de 5 km (era 2 km — ampliado para reducir falsos negativos)
      if (distance > 5.0) {
        if (kDebugMode) {
          debugPrint(
            '⏭️ OrderService: orden ${doc.id} muy lejos (${distance.toStringAsFixed(1)} km)',
          );
        }
        return false;
      }
      return true;
    }

    // Aplicar filtros
    final filteredNormals = docsNormales.where(filtroGeneral).toList();
    final filteredScheduled = docsProgramados.where(filtroGeneral).toList();

    if (kDebugMode) {
      debugPrint(
        '📡 OrderService: ${docsNormales.length} normales → ${filteredNormals.length} pasaron filtros '
        '(servicio:"$servicioDriver", driver=${driverLat.toStringAsFixed(4)},${driverLng.toStringAsFixed(4)})',
      );
    }

    // --- LÓGICA DE NOTIFICACIÓN ---
    final List<QueryDocumentSnapshot> ordersToNotify = [];

    // A) Revisar Normales
    for (var doc in filteredNormals) {
      final path = doc.reference.path;
      // Si no ha sido vista/notificada antes
      if (!_notifiedOrderPaths.contains(path)) {
        _notifiedOrderPaths.add(path); // La marcamos como vista

        // Solo notificamos si NO es la carga inicial de este stream
        if (!_firstLoadNormals) {
          ordersToNotify.add(doc);
        }
      }
    }

    // B) Revisar Programadas
    for (var doc in filteredScheduled) {
      final path = doc.reference.path;
      // Si no ha sido vista/notificada antes
      if (!_notifiedOrderPaths.contains(path)) {
        _notifiedOrderPaths.add(path); // La marcamos como vista

        // Solo notificamos si NO es la carga inicial de este stream
        if (!_firstLoadScheduled) {
          ordersToNotify.add(doc);
        }
      }
    }

    // C) Disparar notificación si hay órdenes realmente nuevas
    if (ordersToNotify.isNotEmpty) {
      if (kDebugMode) {
        debugPrint(
          'OrderService: ${ordersToNotify.length} nuevas órdenes detectadas (post-carga inicial). Notificando.',
        );
      }

      final firstRutaDoc = ordersToNotify.first.reference.path;
      NotificationService().showNewNearbyOrdersForDriverNotification(
        count: ordersToNotify.length,
        rutaDocOrden: firstRutaDoc,
      );
    }

    // --- ACTUALIZAR UI ---
    // Emitimos las normales filtradas al Stream principal
    _ordersController.add(filteredNormals);
  }

  // Normaliza para comparar: minúsculas, sin espacios ni underscores
  // "simple_uber" y "simple uber" quedan iguales: "simpleuber"
  String _normalize(String? text) =>
      (text ?? '').toLowerCase().trim().replaceAll(RegExp(r'[\s_]+'), '');

  // Limpieza total
  Future<void> dispose() async {
    await stopListening();
    await _ubicacionController.close();
    await _servicioController.close();
    await _disponibleController.close();
    await _ordersController.close();
  }
}
