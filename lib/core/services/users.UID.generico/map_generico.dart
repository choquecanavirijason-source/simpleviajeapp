// lib/core/services/users.UID.generico/map_generico.dart
import 'package:flutter/widgets.dart';

/// Construye y valida mapas a partir de controllers.
/// Úsalo para guardar en Firestore sin tocar otros archivos.
class MapGenericoBuilder {
  /// Crea un mapa desde los controllers.
  /// - Si [ignoreEmpty] es true, omite claves con texto vacío.
  /// - Intenta parsear números (coma o punto) si [parseNumbers] es true.
  static Map<String, dynamic> fromControllers(
    Map<String, TextEditingController> ctrls, {
    bool ignoreEmpty = true,
    bool parseNumbers = true,
  }) {
    final out = <String, dynamic>{};
    ctrls.forEach((key, c) {
      final txt = c.text.trim();
      if (ignoreEmpty && txt.isEmpty) return;

      if (parseNumbers) {
        final normalized = txt.replaceAll(',', '.');
        final asNum = double.tryParse(normalized);
        out[key] = asNum ?? txt;
      } else {
        out[key] = txt;
      }
    });
    return out;
  }

  /// Claves requeridas que faltan en el mapa.
  static List<String> missingKeys(
    Map<String, dynamic> map,
    Iterable<String> requiredKeys,
  ) => requiredKeys.where((k) => !map.containsKey(k)).toList();

  /// Claves (de las requeridas) cuyo valor no es numérico.
  static List<String> nonNumericKeys(
    Map<String, dynamic> map,
    Iterable<String> numericKeys,
  ) => numericKeys.where((k) => map.containsKey(k) && map[k] is! num).toList();
}

/* Ejemplo de uso:
late final Map<String, TextEditingController> _ctrls; // Controladores de texto para los campos

void initState() {
  super.initState();
  _baseFareCtrl = NumberEditingController(allowDecimal: true, decimalPlaces: 2);
  _baseKmCtrl   = NumberEditingController(allowDecimal: true, decimalPlaces: 2);

  _ctrls = {
    'baseFare': _baseFareCtrl,
    'baseKm'  : _baseKmCtrl,
    // 👉 mañana agregas: 'waitingFee': _waitingFeeCtrl,
  };
}

--- antes ---
void dispose() {
  _baseFareCtrl.dispose();
  _perKmCtrl.dispose();
  super.dispose();
}

--- despues ---
void dispose() {
  for (final c in _ctrls.values) {
    c.dispose();
  }
  super.dispose();
}

---

void _guardar() async {
  
  // Construir el mapa desde los inputs
  final tarifas = TarifasMapBuilder.fromControllers(_ctrls);

}
*/
