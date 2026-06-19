import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Actualiza el estado de una orden a `cancelado`.
/// - Si pasas [ordenId], actualiza ese doc directamente.
/// - Si no pasas [ordenId], busca la **última** orden con `estado == 'pedido'`
///   y la actualiza. Si no encuentra ninguna, devuelve false.
/// - [programado] => usa `ordenesProgramados` si es `true`, caso contrario `ordenes`.
Future<bool> actualizarEstadoOrden({
  String? ordenId,
  bool programado = false,
  String nuevoEstado = 'cancelado',
  String motivo = 'usuario',
}) async {
  try {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (kDebugMode) debugPrint('🟥 actualizarEstadoOrden: UID null');
      return false;
    }

    final colName = programado ? 'ordenesProgramados' : 'ordenes';
    final colRef = FirebaseFirestore.instance
        .collection('ordenesPasajeros')
        .doc(uid)
        .collection(colName);

    DocumentReference<Map<String, dynamic>>? targetRef;

    if (ordenId != null && ordenId.isNotEmpty) {
      // Actualizamos por ID directo
      targetRef = colRef.doc(ordenId);
    } else {
      // Buscamos la última orden con estado = pedido

      // 1) Intento con índice: where + orderBy(createdAt)
      QuerySnapshot<Map<String, dynamic>>? snap;
      try {
        snap = await colRef
            .where('estado', isEqualTo: 'pedido')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();

        if (snap.docs.isNotEmpty) {
          targetRef = snap.docs.first.reference;
        }
      } on FirebaseException catch (e) {
        // Si falta índice, hacemos un fallback
        if (kDebugMode)
          debugPrint('🟠 Falta índice createdAt+where. Fallback. $e');
      }

      // 2) Fallback: orderBy(createdAt) y filtrar en memoria
      if (targetRef == null) {
        try {
          final fb = await colRef
              .orderBy('createdAt', descending: true)
              .limit(5)
              .get();

          for (final d in fb.docs) {
            final data = d.data();
            if (data['estado'] == 'pedido') {
              targetRef = d.reference;
              break;
            }
          }
        } catch (e) {
          if (kDebugMode) debugPrint('🟠 Fallback createdAt-only falló: $e');
        }
      }

      // 3) Último fallback: usar timestampLocal si tu colección no tiene createdAt
      if (targetRef == null) {
        try {
          final fb2 = await colRef
              .orderBy('timestampLocal', descending: true)
              .limit(5)
              .get();

          for (final d in fb2.docs) {
            final data = d.data();
            if (data['estado'] == 'pedido') {
              targetRef = d.reference;
              break;
            }
          }
        } catch (e) {
          if (kDebugMode) debugPrint('🟥 Fallback timestampLocal falló: $e');
        }
      }
    }

    if (targetRef == null) {
      if (kDebugMode)
        debugPrint(
          '🟥 actualizarEstadoOrden: no se encontró orden en estado "pedido".',
        );
      return false;
    }

    await targetRef.update({
      'estado': nuevoEstado,
      'canceladoPor': motivo, // 'usuario', 'sistema', etc.
    });

    if (kDebugMode)
      debugPrint('✅ actualizarEstadoOrden OK → ${targetRef.path}');
    return true;
  } catch (e, st) {
    if (kDebugMode) debugPrint('🟥 actualizarEstadoOrden ERROR: $e\n$st');
    return false;
  }
}
