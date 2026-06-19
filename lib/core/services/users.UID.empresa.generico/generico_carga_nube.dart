// lib/features/home_empresa_features/tarifas/services/tarifas_carga_nube.dart
// Carga EXCLUSIVAMENTE desde Firestore y rellena controllers.
// Compatible con el enfoque de Map genérico (sin depender de otros servicios).

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:buses2/shared/services/cuenta_user/cuenta_user.dart';

class TarifasCargaNubeService {
  // ---------- helpers ----------
  static Future<String?> _uid() async {
    final acc = await Modular.get<UserAccountService>().current();
    return acc?.uid;
  }

  static Map<String, dynamic>? _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  static String _fmt(dynamic value) {
    if (value == null) return '';
    if (value is num) {
      final s = value.toString();
      return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
    }
    return value.toString();
  }

  // ---------- API ----------
  /// Devuelve SOLO el mapa de tarifas desde la nube:
  /// /users/<uid> { empresa: { tarifas: {...} } }
  /// Retorna null si no hay tarifas.
  static Future<Map<String, dynamic>?> fetchTarifasMapOnce() async {
    debugPrint('☁️ Cargando tarifas desde la NUBE (map genérico)...');
    final uid = await _uid();
    if (uid == null) {
      debugPrint('⚠️ No hay UID para cargar tarifas de la nube');
      return null;
    }

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    final data = _asMap(snap.data());
    final empresa = _asMap(data?['empresa']);
    final tarifas = _asMap(empresa?['tarifas']);

    if (tarifas == null || tarifas.isEmpty) {
      debugPrint('⚠️ No hay tarifas en la NUBE');
      return null;
    }

    debugPrint('✅ Tarifas cargadas desde la NUBE (map genérico)');
    return tarifas;
  }

  /// Versión genérica: rellena controllers a partir de las claves del mapa.
  /// Solo escribe si la clave existe en el mapa y su valor no es null.
  static Future<void> fillControllersByKeys({
    required Map<String, TextEditingController> ctrls,
  }) async {
    final tarifas = await fetchTarifasMapOnce();
    if (tarifas == null) return;

    for (final entry in ctrls.entries) {
      final key = entry.key;
      if (!tarifas.containsKey(key)) continue;
      final value = tarifas[key];
      if (value == null) continue;
      entry.value.text = _fmt(value);
    }
  }
}

/* Ejemplo de uso:

  @override
  void initState() async {
    super.initState();
    _baseFareCtrl = TextEditingController();
    _baseKmCtrl   = TextEditingController();
    _perKmCtrl    = TextEditingController();
    _perMinCtrl   = TextEditingController();
    _nightPctCtrl = TextEditingController();

    // Carga 1ro de local; si no hay, de la nube y rellena inputs:
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      TarifasCargaLocalNubeService.fillControllersPreferLocalElseCloudByKeys(ctrls: _ctrls);
    });
  }
*/
