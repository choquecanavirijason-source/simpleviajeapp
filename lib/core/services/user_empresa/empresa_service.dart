// lib/core/services/user_empresa/empresa_service.dart
import 'ports.dart';
import 'estado.dart';
import 'empresa_model.dart';

class EmpresaService {
  final EmpresaPort port;
  const EmpresaService(this.port);

  Future<bool> hasEmpresa(String uid) => port.hasEmpresa(uid);

  Future<RemotoEmpresaEstado> estadoRemoto(String uid) =>
      port.estadoRemoto(uid);
  Stream<RemotoEmpresaEstado> watchEstadoRemoto(String uid) =>
      port.watchEstadoRemoto(uid);
  Future<Empresa?> getEmpresa(String uid) => port.getEmpresa(uid);

  Future<void> updateEmpresaPartial(String uid, Map<String, dynamic> partial) =>
      port.updateEmpresaPartial(uid, partial);
}
