// SOLO nube: trae Empresa desde servicio remoto usando UID actual
// lib/features/home_empresa_features/datos_empresa/empresa_cache_remote/empresa_remote/empresa_remote.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:buses2/core/services/user_empresa/empresa.dart';
import 'package:buses2/core/services/user_empresa/empresa_model.dart';
import 'package:buses2/shared/services/cuenta_user/cuenta_user.dart';

class EmpresaRemote {
  /// Si pasas [uidOverride], usa ese; si no, toma el UID del usuario actual.
  static Future<Empresa?> fetch({String? uidOverride}) async {
    try {
      final accountSvc = Modular.get<UserAccountService>();
      final acc = await accountSvc.current();
      final uid = uidOverride ?? acc?.uid ?? '';

      if (uid.isEmpty) {
        debugPrint('⚠️ EmpresaRemote.fetch: UID vacío');
        return null;
      }

      final empresaSvc = Modular.get<EmpresaService>();
      final empresa = await empresaSvc.getEmpresa(uid);
      debugPrint(
        '🔵 EmpresaRemote: datos recibidos uid=$uid -> ${empresa?.toMap()}',
      );
      return empresa;
    } catch (e, st) {
      debugPrint('❌ EmpresaRemote.fetch error: $e\n$st');
      return null;
    }
  }
}

/* Se puede usar así:

import 'package:buses2/features/home_empresa_features/datos_empresa/empresa_cache_remote/empresa_cache_remote.dart';

// Traer Empresa del usuario actual (UID desde UserAccountService):
final Empresa? e = await EmpresaRemote.fetch();

// Traer Empresa de un UID específico:
final Empresa? e2 = await EmpresaRemote.fetch(uidOverride: 'Xst8joeM7JNCHTo7LtPWoSFwOru2');

// En un State:
final e3 = await EmpresaRemote.fetch();
if (mounted) setState(() => _empresa = e3);
*/
