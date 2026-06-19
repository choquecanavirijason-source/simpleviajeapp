import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:buses2/core/services/notification/notification_service.dart';

/// Listener exclusivo para CONTRAOFERTAS
/// Regla:
/// - estado == pendiente
/// - cambia precioOfrecido
/// - cambia updatedAt
class DriverOfferCounterOfferListenerService {
  DriverOfferCounterOfferListenerService._();
  static final DriverOfferCounterOfferListenerService instance =
      DriverOfferCounterOfferListenerService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ofertasSub;

  bool _isListening = false;

  /// Cache por oferta
  final Map<String, _CounterCache> _cache = {};

  Future<void> startListening() async {
    if (_isListening) {
      debugPrint('CounterOfferListener: ya existe listener activo');
      return;
    }

    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    final mode = await _resolveUserMode();
    debugPrint('CounterOfferListener: modo actual = $mode');

    if (mode != 'taxista') {
      await stopListening();
      debugPrint('CounterOfferListener: no taxista, listener detenido');
      return;
    }

    debugPrint('CounterOfferListener: iniciando escucha para taxista $uid');

    _ofertasSub?.cancel();
    _cache.clear();

    final query = _db
        .collectionGroup('ofertas')
        .where('uidTaxista', isEqualTo: uid)
        .where('estado', isEqualTo: 'pendiente');

    bool isFirstLoad = true;

    _ofertasSub = query.snapshots().listen(
      (snapshot) async {
        // Ignorar la primera carga para no spamear notificaciones
        if (isFirstLoad) {
          isFirstLoad = false;
          debugPrint('CounterOfferListener: primera carga ignorada');
          return;
        }

        debugPrint('CounterOfferListener: snapshot recibido ');

        final modeNow = await _resolveUserMode();
        if (modeNow != 'taxista') {
          debugPrint('CounterOfferListener: modo cambió a $modeNow, ignorando');
          return;
        }

        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.removed) {
            final path = change.doc.reference.path;
            _cache.remove(path);
            debugPrint('CounterOfferListener: oferta removida $path');
            continue;
          }

          await _handleOfferChange(change.doc);
        }
      },
      onError: (e) {
        debugPrint('CounterOfferListener: ERROR en listener: $e');
      },
    );

    _isListening = true;
  }

  Future<void> _handleOfferChange(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    if (data == null) return;

    final estado = data['estado']?.toString().trim().toLowerCase();
    if (estado != 'pendiente') return;

    final tarifa = data['tarifa'] as Map<String, dynamic>?;
    final precio = double.tryParse(tarifa?['precioOfrecido']?.toString() ?? '');
    final updatedAt = data['updatedAt'];

    final path = doc.reference.path;

    debugPrint(
      'CounterOfferChange [$path] estado=$estado '
      'precio=$precio updatedAt=$updatedAt',
    );

    if (precio == null || precio <= 0 || updatedAt == null) {
      debugPrint('CounterOfferChange: datos incompletos, se ignora');
      return;
    }

    final prev = _cache[path];

    // Actualizamos cache siempre
    _cache[path] = _CounterCache(precio: precio, updatedAt: updatedAt);

    // Si no había cache previo y ya pasamos la primera carga,
    // consideramos esto como la primera contraoferta para esta oferta.
    if (prev == null) {
      debugPrint(
        'CounterOfferChange: contraoferta inicial detectada (sin valor previo en cache)',
      );
    } else {
      final precioCambio = prev.precio != precio;
      final updatedCambio = prev.updatedAt != updatedAt;

      if (!precioCambio || !updatedCambio) {
        debugPrint(
          'CounterOfferChange: no es contraoferta real '
          '(precioCambio=$precioCambio, updatedCambio=$updatedCambio)',
        );
        return;
      }
    }

    final ordenRef = doc.reference.parent.parent;
    if (ordenRef == null) return;

    final rutaOrden = ordenRef.path;
    final esProgramado = rutaOrden.contains('ordenesProgramados');

    debugPrint(
      'CounterOfferChange: CONTRAOFERTA DETECTADA '
      '${prev?.precio} → $precio | orden=$rutaOrden',
    );

    await NotificationService().showNewOfferNotification(
      rutaDocOrden: rutaOrden,
      titulo: esProgramado
          ? '¡Contraoferta en viaje programado!'
          : '¡Nueva contraoferta del pasajero!',
      cuerpo: 'El pasajero actualizó la tarifa a $precio. Toca para ver.',
    );
  }

  Future<void> stopListening() async {
    await _ofertasSub?.cancel();
    _ofertasSub = null;
    _isListening = false;
    _cache.clear();

    debugPrint('CounterOfferListener: listener detenido');
  }

  Future<String> _resolveUserMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('modo')?.toLowerCase() ?? 'pasajero';
    } catch (_) {
      return 'pasajero';
    }
  }
}

/// Cache interno
class _CounterCache {
  final double precio;
  final dynamic updatedAt;

  _CounterCache({required this.precio, required this.updatedAt});
}
