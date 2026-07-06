import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Modelo simple para un destino reciente (normal o programado).
class DestinoReciente {
  final double? lat;
  final double? lng;
  final String? texto;
  final String? calle;
  final String? ciudad;
  final String? pais;
  final bool programado; // true => viene de ordenesProgramados
  final DateTime ts; // para ordenar por fecha

  const DestinoReciente({
    required this.lat,
    required this.lng,
    required this.texto,
    required this.calle,
    required this.ciudad,
    required this.pais,
    required this.programado,
    required this.ts,
  });
}

class RecientesRepo {
  RecientesRepo._();

  static DateTime _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) {
      final d = DateTime.tryParse(v);
      if (d != null) return d;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Lee 3 de `ordenes` + 2 de `ordenesProgramados`, mezcla por fecha desc y devuelve 5.
  static Future<List<DestinoReciente>> obtenerRecientes({
    required String uid,
  }) async {
    try {
      return await _obtenerRecientesInternal(uid: uid);
    } catch (e) {
      debugPrint('⚠️ RecientesRepo.obtenerRecientes error: $e');
      return [];
    }
  }

  static Future<List<DestinoReciente>> _obtenerRecientesInternal({
    required String uid,
  }) async {
    final fs = FirebaseFirestore.instance;

    // 3 últimos de ordenes
    final qOrdenes = await fs
        .collection('ordenesPasajeros')
        .doc(uid)
        .collection('ordenes')
        .orderBy('createdAt', descending: true)
        .limit(3)
        .get();

    // 2 últimos de ordenesProgramados
    final qProg = await fs
        .collection('ordenesPasajeros')
        .doc(uid)
        .collection('ordenesProgramados')
        .orderBy('createdAt', descending: true)
        .limit(2)
        .get();

    final out = <DestinoReciente>[];

    // Mapear colección "ordenes"
    for (final d in qOrdenes.docs) {
      final data = d.data();
      final destino = (data['destino'] as Map?)?.cast<String, dynamic>() ?? {};
      out.add(
        DestinoReciente(
          lat: (destino['lat'] as num?)?.toDouble(),
          lng: (destino['lng'] as num?)?.toDouble(),
          texto: destino['texto'] as String?,
          calle: destino['calle'] as String?,
          ciudad: destino['ciudad'] as String?,
          pais: destino['pais'] as String?,
          programado: false,
          ts: _toDate(data['createdAt'] ?? data['timestampLocal']),
        ),
      );
    }

    // Mapear colección "ordenesProgramados"
    for (final d in qProg.docs) {
      final data = d.data();
      final destino = (data['destino'] as Map?)?.cast<String, dynamic>() ?? {};
      out.add(
        DestinoReciente(
          lat: (destino['lat'] as num?)?.toDouble(),
          lng: (destino['lng'] as num?)?.toDouble(),
          texto: destino['texto'] as String?,
          calle: destino['calle'] as String?,
          ciudad: destino['ciudad'] as String?,
          pais: destino['pais'] as String?,
          programado: true,
          ts: _toDate(data['createdAt'] ?? data['timestampLocal']),
        ),
      );
    }

    // Ordenar desc por fecha y tomar 5
    out.sort((a, b) => b.ts.compareTo(a.ts));
    return out.take(5).toList();
  }
}
