// lib/core/services/user_empresa/ports.dart
import 'estado.dart';
import 'empresa_model.dart';

abstract class EmpresaPort {
  Future<bool> hasEmpresa(String uid);

  /// Lee una sola vez el estado remoto.
  Future<RemotoEmpresaEstado> estadoRemoto(String uid);

  /// Escucha cambios en tiempo real del estado remoto.
  Stream<RemotoEmpresaEstado> watchEstadoRemoto(String uid);

  Future<Empresa?> getEmpresa(String uid);

  //
  Future<void> updateEmpresaPartial(String uid, Map<String, dynamic> partial);
}
