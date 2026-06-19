// lib/core/services/users.UID.generico/carga_local_nube.dart
//
// Orquestador: intenta cargar PRIMERO desde LOCAL; si no hay datos, desde la NUBE.
// Compatible con el enfoque de Mapa genérico (clave -> controller).

import 'package:flutter/widgets.dart';
import 'package:buses2/core/services/users.UID.generico/carga_local.dart';
import 'package:buses2/core/services/users.UID.generico/carga_nube.dart';

class CargaLocalNubeGenericoService {
  /// Prefiere LOCAL; si no hay datos locales, trae desde la NUBE.
  /// Solo escribe en los controllers de las claves presentes.
  static Future<void> fillControllersPreferLocalElseCloudByKeys({
    required String sectionName, // p.ej. 'billetera', 'suscripcion', etc.
    required Map<String, TextEditingController> ctrls,
  }) async {
    final localMap = await CargaLocalGenerico.loadSectionMap(
      sectionName: sectionName,
    );
    if (localMap != null && localMap.isNotEmpty) {
      await CargaLocalGenerico.fillControllersByKeys(
        sectionName: sectionName,
        ctrls: ctrls,
      );
      return;
    }

    await UserCampoCargaNubeService.fillControllersByKeys(
      nombreCampo: sectionName,
      ctrls: ctrls,
    );
  }
}

/* Ejemplo de uso:
void initState() {
  super.initState();
  _baseFareCtrl = NumberEditingController(allowDecimal: true, decimalPlaces: 2);
  _baseKmCtrl   = NumberEditingController(allowDecimal: true, decimalPlaces: 2);

  _ctrls = {
    'baseFare': _baseFareCtrl,
    'baseKm'  : _baseKmCtrl,
    // 👉 mañana agregas: 'waitingFee': _waitingFeeCtrl,
  };

  // Local -> si no hay, Nube (igual que en Tarifas)
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await CargaLocalNubeGenericoService.fillControllersPreferLocalElseCloudByKeys(
      sectionName: sectionName, // la page manda
      ctrls: _ctrls,            // tu mapa clave -> controller
    );
  });
}
*/
