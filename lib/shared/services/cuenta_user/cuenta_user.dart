// import 'package:buses2/core/services/cuenta_user/cuenta_user.dart';
export 'ports.dart';
export 'user_account_service.dart';
export 'firebase_adapters.dart' show FirebaseUserAccountAdapter;
// export 'supabase_adapter.dart' show SupabaseUserAccountAdapter;

/* Se usa asi:
app_module.dart:
import 'package:buses2/core/services/cuenta_user/cuenta_user.dart';
...
i.addSingleton<UserAccountService>(() => UserAccountService(FirebaseUserAccountAdapter()));

Boton nombre_archivo_usara.dart:
import 'package:buses2/core/services/cuenta_user/cuenta_user.dart';
...
void _onSave() async {
  // 1) Validar inputs
  final result = _controller.buildResult(); // { id, data, files }

  // 2) Lee cual es el usuario actual
  final accountSvc = Modular.get<UserAccountService>();
  await accountSvc.logCurrent();

  // 3) Si todo ok, regresar datos
  if (mounted) Modular.to.pop(result);
}
*/
