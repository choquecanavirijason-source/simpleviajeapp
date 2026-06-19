// lib/core/services/users.UID.generico/carga_local.dart
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Lee mapas por usuario y sección desde el almacenamiento local.
/// Clave usada: users.<uid>.<sectionName> (igual que en save_local.dart)
class CargaLocalGenerico {
  CargaLocalGenerico._();

  static final _auth = FirebaseAuth.instance;

  // ----------------- API -----------------

  /// Devuelve el mapa guardado localmente para la sección o null si no existe.
  static Future<Map<String, dynamic>?> loadSectionMap({
    required String sectionName,
  }) async {
    print('📥 [LOCAL] Cargando sección "$sectionName"...');
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      print('❌ [LOCAL] Usuario no autenticado.');
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final key = _key(uid, sectionName);
    final str = prefs.getString(key);
    if (str == null) {
      print('⚠️ [LOCAL] No hay datos para sección "$sectionName".');
      return null;
    }

    final decoded = jsonDecode(str);
    final map = _asMap(decoded);

    print(
      '✅ [LOCAL] Sección "$sectionName" cargada. (${map?.length ?? 0} claves)',
    );
    // ⬇️ Print bonito con todos los valores que llegaron
    print('🧾 [LOCAL] Datos "$sectionName":\n${_pretty(map)}');

    return map;
  }

  /// Rellena los controllers (clave -> controller) con lo guardado localmente.
  /// Sólo escribe si la clave existe y su valor no es null.
  static Future<void> fillControllersByKeys({
    required String sectionName,
    required Map<String, TextEditingController> ctrls,
  }) async {
    print('🖊️ [LOCAL] Rellenando controllers para sección "$sectionName"...');
    final map = await loadSectionMap(sectionName: sectionName);
    if (map == null || map.isEmpty) {
      print('⚠️ [LOCAL] Nada que rellenar en controllers.');
      return;
    }

    for (final entry in ctrls.entries) {
      final k = entry.key;
      if (!map.containsKey(k)) continue;
      final v = map[k];
      if (v == null) continue;
      entry.value.text = _fmt(
        v,
      ); // sirve con TextEditingController y NumberEditingController
      print('🖊️ [LOCAL] Controller "$k" ← "$v".');
    }
  }

  // ----------------- helpers -----------------

  static String _key(String uid, String sectionName) =>
      'users.$uid.$sectionName';

  static Map<String, dynamic>? _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  static String _fmt(dynamic value) {
    if (value == null) return '';
    if (value is num) {
      final s = value.toString();
      // Evita ".0" si es entero
      return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
    }
    return value.toString();
  }

  static String _pretty(Map<String, dynamic>? m) {
    if (m == null) return '(null)';
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(m);
  }
}

/* Ejemplo de uso:

void initState() {
  super.initState();
  _baseFareCtrl = NumberEditingController(allowDecimal: true, decimalPlaces: 2);
  _baseKmCtrl   = NumberEditingController(allowDecimal: true, decimalPlaces: 2);

  // Cargar datos desde LOCAL y llenar los campos
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await CargaLocalGenerico.fillControllersByKeys(
      sectionName: sectionName, // 'billetera'
      ctrls: _ctrls,
    );
  });
}
*/
