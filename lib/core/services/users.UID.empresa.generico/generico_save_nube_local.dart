// lib/features/home_empresa_features/tarifas/services/tarifas_save_nube_local.dart
// Guarda en Firestore y, si fue exitoso, también en almacenamiento local.

import 'package:flutter/foundation.dart';
import 'package:buses2/core/services/users.UID.empresa.generico/generico_save_nube.dart';
import 'package:buses2/core/services/users.UID.empresa.generico/generico_save_local.dart';

class TarifasSaveNubeLocalService {
  /// GENÉRICO: guarda empresa.<sectionName> = map en la NUBE y, si OK, también en LOCAL.
  static Future<bool> saveSectionMap({
    required String sectionName,
    required Map<String, dynamic> map,
  }) async {
    debugPrint('⬆️ Guardando $sectionName en la NUBE (map genérico)...');

    final cloudOk = await TarifasService.saveSectionMap(
      sectionName: sectionName,
      map: map,
    );

    if (cloudOk) {
      debugPrint(
        '✅ $sectionName guardado en la NUBE. 💾 Guardando en LOCAL...',
      );
      // HOY: el local aún guarda bajo la clave fija 'empresa.tarifas'.
      // Si más adelante genericizas el local, cámbialo a un saveSectionMapLocal(sectionName, map).
      await TarifasSaveLocalService.saveTarifasMap(map);
      debugPrint('✅ LOCAL OK.');
    } else {
      debugPrint(
        '❌ Error guardando $sectionName en la NUBE. No se guarda en LOCAL.',
      );
    }

    return cloudOk;
  }

  /// Compat: atajo específico para "tarifas"
  static Future<bool> saveTarifasMap(Map<String, dynamic> tarifas) {
    return saveSectionMap(sectionName: 'tarifas', map: tarifas);
  }
}

/* Ejemplo de uso:
  // Guardar 1ro en NUBE y, si OK, también en LOCAL
  final ok = await TarifasSaveNubeLocalService.saveSectionMap(
    sectionName: sectionName, // 'tarifas'
    map: tarifas,
  );
*/
