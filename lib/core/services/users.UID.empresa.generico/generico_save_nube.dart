import 'package:flutter/foundation.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:buses2/shared/services/cuenta_user/cuenta_user.dart';
import 'package:buses2/core/services/user_empresa/empresa.dart';

class TarifasService {
  /// GENÉRICO: guarda cualquier sección dentro de `empresa.<sectionName> = map`
  static Future<bool> saveSectionMap({
    required String sectionName,
    required Map<String, dynamic> map,
  }) async {
    try {
      final accountSvc = Modular.get<UserAccountService>();
      final acc = await accountSvc.current();
      final uid = acc?.uid ?? '';
      if (uid.isEmpty) {
        debugPrint('⚠️ UID vacío al guardar $sectionName');
        return false;
      }

      final empresaSvc = Modular.get<EmpresaService>();

      await empresaSvc.updateEmpresaPartial(uid, {
        'empresa': {
          sectionName: map, // <- guarda en empresa.<sectionName>
          'updatedAt': DateTime.now(),
        },
      });

      return true;
    } catch (e, st) {
      debugPrint('❌ Error guardando $sectionName: $e\n$st');
      return false;
    }
  }

  /// COMPATibilidad: wrapper específico para "tarifas"
  static Future<bool> saveTarifasMap(Map<String, dynamic> tarifas) {
    return saveSectionMap(sectionName: 'tarifas', map: tarifas);
  }
}

/* Ejemplo de uso:

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

  // Guardar en la NUBE
  final ok = await TarifasService.saveSectionMap(
    sectionName: sectionName,
    map: map,
  );
  if (ok) {
    // Éxito
  } else {
    // Error
  }
}
*/
