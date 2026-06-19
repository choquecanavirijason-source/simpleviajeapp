// import 'package:buses2/core/services/user_empresa/empresa.dart';
export 'ports.dart';
export 'empresa_service.dart';
export 'firebase_adapters.dart' show FirebaseEmpresaAdapter;
export 'estado.dart';

/* Ejemplo de uso:
final empresa = await EmpresaService().getEmpresa(uid);

print(empresa.email);          // "michaelfloresrojas31@gmail.com"
print(empresa.nombreEmpresa);  // "Pil"
print(empresa.telefono);       // "62369713"
print(empresa.saldo);          // 75
*/
