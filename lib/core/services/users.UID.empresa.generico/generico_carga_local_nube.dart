// lib/features/home_empresa_features/tarifas/services/tarifas_carga_local_nube.dart
// Orquestador: primero LOCAL; si no hay datos, NUBE. Compatible con mapa genérico de controllers.

import 'package:flutter/widgets.dart';
import 'package:buses2/core/services/users.UID.empresa.generico/generico_carga_local.dart';
import 'package:buses2/core/services/users.UID.empresa.generico/generico_carga_nube.dart';

class TarifasCargaLocalNubeService {
  /// Prefiere LOCAL; si no hay datos locales, trae desde la NUBE.
  /// Solo escribe en los controllers de las claves presentes.
  static Future<void> fillControllersPreferLocalElseCloudByKeys({
    required Map<String, TextEditingController> ctrls,
  }) async {
    final localMap = await TarifasCargaLocalService.fetchTarifasMapOnce();
    if (localMap != null && localMap.isNotEmpty) {
      await TarifasCargaLocalService.fillControllersByKeys(ctrls: ctrls);
      return;
    }
    await TarifasCargaNubeService.fillControllersByKeys(ctrls: ctrls);
  }

  /// Wrapper legacy (por si en algún sitio aún llamas con 5 controllers fijos).
  static Future<void> fillControllersPreferLocalElseCloud({
    required TextEditingController baseFareCtrl,
    required TextEditingController baseKmCtrl,
    required TextEditingController perKmCtrl,
    required TextEditingController perMinCtrl,
    required TextEditingController nightPctCtrl,
  }) async {
    final ctrls = <String, TextEditingController>{
      'baseFare': baseFareCtrl,
      'baseKm': baseKmCtrl,
      'perKm': perKmCtrl,
      'perMinute': perMinCtrl,
      'nightSurchargePct': nightPctCtrl,
    };
    await fillControllersPreferLocalElseCloudByKeys(ctrls: ctrls);
  }
}

/* Ejemplo de uso:
void initState() {
  super.initState();
  _baseFareCtrl = TextEditingController();
  _baseKmCtrl   = TextEditingController();
  _perKmCtrl    = TextEditingController();
  _perMinCtrl   = TextEditingController();
  _nightPctCtrl = TextEditingController();

  WidgetsBinding.instance.addPostFrameCallback((_) {
    TarifasCargaLocalNubeService.fillControllersPreferLocalElseCloud(
      baseFareCtrl: _baseFareCtrl,
      baseKmCtrl: _baseKmCtrl,
      perKmCtrl: _perKmCtrl,
      perMinCtrl: _perMinCtrl,
      nightPctCtrl: _nightPctCtrl,
    );
  });
}
*/
