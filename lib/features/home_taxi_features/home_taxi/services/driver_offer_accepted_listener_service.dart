import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:buses2/core/services/notification/notification_service.dart';

/// Listener de ofertas para el TAXISTA.
///
/// - Usa collectionGroup('ofertas') filtrando por uidTaxista == uid actual.
/// - Mantiene el último estado conocido de cada oferta.
/// - Cuando una oferta pasa de otro estado a 'aceptado',
///   dispara una notificación local para el conductor.
class DriverOfferAcceptedListenerService {
  DriverOfferAcceptedListenerService._();
  static final DriverOfferAcceptedListenerService instance =
      DriverOfferAcceptedListenerService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ofertasSub;

  bool _isListening = false;

  /// cachea el último estado normalizado por path del documento
  final Map<String, String> _lastEstadoByOffer = {};

  /// Inicia el listener solo si el usuario está en modo TAXISTA.
  Future<void> startListening() async {
    // Evitar crear múltiples listeners para el mismo usuario
    if (_ofertasSub != null && _isListening) {
      if (kDebugMode) {
        debugPrint(
          'DriverOfferAcceptedListener: ya existe un listener activo, no se reinicia',
        );
      }
      return;
    }

    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    final mode = await _resolveUserMode();
    debugPrint('DriverOfferAcceptedListener: modo actual: $mode');
    if (mode != 'taxista') {
      await stopListening();
      if (kDebugMode) {
        debugPrint(
          'DriverOfferAcceptedListener: modo "$mode" ≠ taxista, no se escuchan ofertas',
        );
      }
      return;
    }

    if (kDebugMode) {
      debugPrint(
        'DriverOfferAcceptedListener: iniciando escucha para taxista $uid',
      );
    }

    _ofertasSub?.cancel();

    // Escuchamos solo ofertas del taxista en estados activos
    // (pendiente / aceptado) para reducir lecturas innecesarias.
    final query = _db
        .collectionGroup('ofertas')
        .where('uidTaxista', isEqualTo: uid)
        .where('estado', whereIn: ['pendiente', 'aceptado']);

    _ofertasSub = query.snapshots().listen(
      (snapshot) async {
        debugPrint('DriverOfferAcceptedListener: oferta snapshot recibida');
        final modeNow = await _resolveUserMode();
        debugPrint('modo actual: $modeNow');
        if (modeNow != 'taxista') {
          return;
        }

        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.removed) continue;

          await _handleOfferChange(change.doc);
        }
      },
      onError: (e) {
        if (kDebugMode) {
          debugPrint('DriverOfferAcceptedListener: error en ofertas: $e');
        }
      },
    );

    _isListening = true;
  }

  Future<void> _handleOfferChange(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();

    final rawEstado = (data != null && data['estado'] is String)
        ? data['estado'] as String
        : '';
    final estadoNorm = rawEstado.trim().toLowerCase();
    if (estadoNorm.isEmpty) return;

    final key = doc.reference.path;
    final prev = _lastEstadoByOffer[key];

    // Actualizamos cache siempre
    _lastEstadoByOffer[key] = estadoNorm;

    // Primera vez que lo vemos → no notificar (estado histórico).
    if (prev == null) return;

    final wasAccepted = prev == 'aceptado';
    final isAccepted = estadoNorm == 'aceptado';
    if (!isAccepted || wasAccepted) return;

    // Obtenemos la ruta del doc de la orden: padre de la subcolección 'ofertas'
    final ordenRef = doc.reference.parent.parent;
    if (ordenRef == null) return;
    final rutaDoc = ordenRef.path;

    // Detectamos si la orden es normal o programada según la ruta
    // Ej: 'ordenesPasajeros/{uid}/ordenes/{id}' vs 'ordenesPasajeros/{uid}/ordenesProgramados/{id}'
    final segments = rutaDoc.split('/');
    final esProgramado = segments.contains('ordenesProgramados');

    if (kDebugMode) {
      debugPrint(
        'DriverOfferAcceptedListener: oferta aceptada (${doc.id}) para orden $rutaDoc',
      );
    }

    await NotificationService().showDriverOfferAcceptedNotification(
      rutaDocOrden: rutaDoc,
      esProgramado: esProgramado,
    );
  }

  /// Detiene el listener.
  Future<void> stopListening() async {
    await _ofertasSub?.cancel();
    _ofertasSub = null;
    _isListening = false;
    _lastEstadoByOffer.clear();
    if (kDebugMode) {
      debugPrint('DriverOfferAcceptedListener: listener detenido');
    }
  }

  /// Retorna 'taxista' o 'pasajero' (por defecto 'pasajero').
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
        debugPrint(
          'DriverOfferAcceptedListener: error resolviendo modo de usuario: $e',
        );
      }
      return 'pasajero';
    }
  }
}
