// lib/core/services/users.UID.generico/save_local_nube.dart
//
// Guarda PRIMERO en la NUBE (users/<uid>.<sectionName> = {...})
// y, si fue exitoso, TAMBIÉN guarda en LOCAL (SharedPreferences)
// bajo la clave users.<uid>.<sectionName>.
//
// Uso 100% genérico: la page pasa sectionName y el map.

import 'package:flutter/foundation.dart';
import 'package:buses2/core/services/users.UID.generico/save_nube.dart';
import 'package:buses2/core/services/users.UID.generico/save_local.dart';

class SaveLocalNubeGenericoService {
  /// Devuelve true si se guardó con éxito en la NUBE (y se intentó local).
  /// Por defecto, si falla la nube, NO guarda local (mismo comportamiento que tu patrón de tarifas).
  static Future<bool> saveSectionMap({
    required String sectionName,
    required Map<String, dynamic> map,
    bool saveLocalIfCloudFails =
        false, // si quieres fallback local aunque falle la nube
  }) async {
    debugPrint('⬆️ Guardando "$sectionName" en la NUBE (genérico)...');

    try {
      // 1) NUBE
      await SaveBilleteraNube.guardar(data: map, nombreCampo: sectionName);
      debugPrint('✅ NUBE OK para "$sectionName". 💾 Guardando en LOCAL...');

      // 2) LOCAL
      await SaveLocalGenerico.saveSectionMap(
        sectionName: sectionName,
        map: map,
      );
      debugPrint('✅ LOCAL OK para "$sectionName".');

      return true;
    } catch (e, st) {
      debugPrint('❌ Error guardando "$sectionName" en NUBE: $e\n$st');

      if (saveLocalIfCloudFails) {
        debugPrint('↩️ Guardando en LOCAL pese a fallo de NUBE...');
        try {
          await SaveLocalGenerico.saveSectionMap(
            sectionName: sectionName,
            map: map,
          );
          debugPrint('✅ LOCAL OK (fallback) para "$sectionName".');
        } catch (e2, st2) {
          debugPrint('❌ También falló LOCAL: $e2\n$st2');
        }
      }

      return false;
    }
  }
}

/* Ejemplo de uso:
void _guardar() async {

  try {
    // Construye el mapa genérico desde los inputs
    final data = MapGenericoBuilder.fromControllers(_ctrls);

    // Guarda 1) nube y 2) local
    await SaveLocalNubeGenericoService.saveSectionMap(
      sectionName: sectionName, // 'billetera' (la page manda)
      map: data,
      // saveLocalIfCloudFails: true, // <- habilítalo si quieres fallback local cuando falle nube
    );

    // Guarda en <uid>.generico = { ... }
    /*
    await SaveBilleteraNube.guardar(
      data: data,
      nombreCampo: sectionName,
    );
    */

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Billetera guardada')),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al guardar: $e')),
    );
  }

}
*/
