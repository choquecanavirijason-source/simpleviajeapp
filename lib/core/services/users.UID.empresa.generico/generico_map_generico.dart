// crea map genericos dentro de users<uid>empresa><tarifas> {...}
import 'package:flutter/widgets.dart';

/// Utilidades para construir y validar el mapa genérico de tarifas.
class TarifasMapBuilder {
  /// Crea un Map<String, dynamic> a partir de un mapa de controllers.
  /// - Convierte a double cuando puede.
  /// - Si [ignoreEmpty] es true, omite claves con texto vacío.
  static Map<String, dynamic> fromControllers(
    Map<String, TextEditingController> ctrls, {
    bool ignoreEmpty = true,
  }) {
    final out = <String, dynamic>{};
    ctrls.forEach((key, ctrl) {
      final txt = ctrl.text.trim();
      if (ignoreEmpty && txt.isEmpty) return;
      final asNum = double.tryParse(txt);
      out[key] = asNum ?? txt;
    });
    return out;
  }

  /// Devuelve las claves requeridas que faltan en el mapa.
  static List<String> missingKeys(
    Map<String, dynamic> map,
    Iterable<String> requiredKeys,
  ) => requiredKeys.where((k) => !map.containsKey(k)).toList();

  /// Devuelve las claves (de las requeridas) cuyo valor no es numérico.
  static List<String> nonNumericKeys(
    Map<String, dynamic> map,
    Iterable<String> numericKeys,
  ) => numericKeys.where((k) => map.containsKey(k) && map[k] is! num).toList();
}

/* Ejemplo de uso:

late final Map<String, TextEditingController> _ctrls;

late final TextEditingController _baseFareCtrl; // tarifa base (Bs)
late final TextEditingController _perKmCtrl;    // Bs por km extra

void initState() {
  super.initState();
  _baseFareCtrl = TextEditingController();
  _perKmCtrl    = TextEditingController();

  _ctrls = {
    'baseFare': _baseFareCtrl,
    'baseKm': _baseKmCtrl,
    'perKm': _perKmCtrl,
    'perMinute': _perMinCtrl,
    'nightSurchargePct': _nightPctCtrl,
    // si mañana agregas otro input, lo pones aquí: 'newKey': _newCtrl,
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

void _guardar() async {
  
  // Construir el mapa desde los inputs
  final tarifas = TarifasMapBuilder.fromControllers(_ctrls);

}
*/
