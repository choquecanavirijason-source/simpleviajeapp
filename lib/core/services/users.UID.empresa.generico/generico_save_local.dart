// lib/features/home_empresa_features/tarifas/services/tarifas_save_local.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TarifasSaveLocalService {
  static const String _kPrefsTarifasKey = 'empresa.tarifas';

  static Future<bool> saveTarifasMap(Map<String, dynamic> tarifas) async {
    debugPrint('💾 Guardando tarifas en LOCAL (map genérico)...');
    try {
      final payload = {...tarifas, 'savedAt': DateTime.now().toIso8601String()};
      final prefs = await SharedPreferences.getInstance();
      final ok = await prefs.setString(_kPrefsTarifasKey, jsonEncode(payload));
      debugPrint(
        ok
            ? '✅ Tarifas guardadas en LOCAL'
            : '❌ Error guardando tarifas localmente',
      );
      return ok;
    } catch (e) {
      debugPrint('❌ Error guardando tarifas localmente: $e');
      return false;
    }
  }
}

/* Ejemplo de uso:
late final Map<String, TextEditingController> _ctrls; // Aumentar si agregas más inputs

late final TextEditingController _baseFareCtrl; // tarifa base (Bs) (solo de ejemplo)
late final TextEditingController _perKmCtrl;    // Bs por km extra (solo de ejemplo)

void initState() {
  super.initState();
  _baseFareCtrl = TextEditingController();
  _perKmCtrl    = TextEditingController();

  // Sube datos a la NUBE (Firestore)
  WidgetsBinding.instance.addPostFrameCallback((_) {
    TarifasCargaLocalNubeService.fillControllersPreferLocalElseCloud(
      baseFareCtrl: _baseFareCtrl,
      perKmCtrl: _perKmCtrl,
    );
  });
}

void dispose() {
  _baseFareCtrl.dispose();
  _perKmCtrl.dispose();
  super.dispose();
}

void _guardar() async {

  // Guardar en local
  final ok = await TarifasSaveLocalService.saveTarifasMap(tarifas);
  if (ok) {
    // Éxito
  } else {
    // Error
  }
}
*/
