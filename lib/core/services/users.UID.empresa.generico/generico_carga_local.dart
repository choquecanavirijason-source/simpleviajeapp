// lib/features/home_empresa_features/tarifas/services/tarifas_carga_local.dart
// Carga EXCLUSIVAMENTE desde el almacenamiento local (SharedPreferences)
// y rellena los TextEditingController. No toca la nube ni depende de otros servicios.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kPrefsTarifasKey = 'empresa.tarifas';

class _LocalTariffValues {
  final double? baseFare;
  final double? baseKm;
  final double? perKm;
  final double? perMinute;
  final double? nightSurchargePct;

  const _LocalTariffValues({
    this.baseFare,
    this.baseKm,
    this.perKm,
    this.perMinute,
    this.nightSurchargePct,
  });

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  factory _LocalTariffValues.fromMap(Map<String, dynamic> map) {
    return _LocalTariffValues(
      baseFare: _LocalTariffValues._toDouble(map['baseFare']),
      baseKm: _LocalTariffValues._toDouble(map['baseKm']),
      perKm: _LocalTariffValues._toDouble(map['perKm']),
      perMinute: _LocalTariffValues._toDouble(map['perMinute']),
      nightSurchargePct: _LocalTariffValues._toDouble(map['nightSurchargePct']),
    );
  }

  bool get isEmpty =>
      baseFare == null &&
      baseKm == null &&
      perKm == null &&
      perMinute == null &&
      nightSurchargePct == null;
}

class TarifasCargaLocalService {
  // ---------- helpers ----------
  static String _fmt(dynamic value) {
    if (value == null) return '';
    if (value is num) {
      final s = value.toString();
      return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
    }
    return value.toString();
  }

  static Map<String, dynamic>? _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  // ---------- API ----------
  /// Lee SOLO del almacenamiento local y devuelve el mapa crudo (o null).
  static Future<Map<String, dynamic>?> readRaw() async {
    debugPrint('📥 Cargando tarifas desde LOCAL...');
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kPrefsTarifasKey);
    if (s == null) {
      debugPrint('⚠️ No hay tarifas locales guardadas');
      return null;
    }
    try {
      final decoded = jsonDecode(s);
      final map = _asMap(decoded);
      if (map != null) {
        debugPrint('✅ Tarifas cargadas desde LOCAL (map genérico)');
        return map;
      }
    } catch (e) {
      debugPrint('❌ Error leyendo tarifas locales: $e');
    }
    return null;
  }

  /// Alias semántico por consistencia con el servicio de nube.
  static Future<Map<String, dynamic>?> fetchTarifasMapOnce() => readRaw();

  /// Devuelve las tarifas SOLO locales como objeto (o null si no hay).
  static Future<_LocalTariffValues?> fetchOnce() async {
    final raw = await readRaw();
    if (raw == null) return null;
    final v = _LocalTariffValues.fromMap(raw);
    return v.isEmpty ? null : v;
  }

  /// Versión genérica: rellena controllers a partir de las claves del mapa local.
  /// Solo escribe si la clave existe y su valor no es null.
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

/* Se usa así (ejemplo):

  @override
  void initState() {
    super.initState();
    _baseFareCtrl = TextEditingController();
    _baseKmCtrl   = TextEditingController();
    _perKmCtrl    = TextEditingController();
    _perMinCtrl   = TextEditingController();
    _nightPctCtrl = TextEditingController();

    // Cargar valores de local y rellenar inputs:
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await TarifasCargaLocalService.fillControllersByKeys(ctrls: _ctrls);
    });
  }
*/
