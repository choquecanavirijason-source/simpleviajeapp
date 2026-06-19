// lib/core/services/user_empresa/firebase_adapters.dart
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'ports.dart';
import 'estado.dart';
import 'empresa_model.dart';

class FirebaseEmpresaAdapter implements EmpresaPort {
  final fs.FirebaseFirestore _db;
  FirebaseEmpresaAdapter({fs.FirebaseFirestore? db})
    : _db = db ?? fs.FirebaseFirestore.instance;

  @override
  Future<bool> hasEmpresa(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    final data = snap.data();
    final empresa = data?['empresa'];
    return empresa is Map && empresa.isNotEmpty;
  }

  @override
  Future<RemotoEmpresaEstado> estadoRemoto(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    final data = snap.data();
    final empresa = data?['empresa'];
    final valor = (empresa is Map) ? empresa['estado'] : null;
    return parseRemotoEstado(valor);
  }

  @override
  Stream<RemotoEmpresaEstado> watchEstadoRemoto(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      final data = snap.data();
      final empresa = data?['empresa'];
      final valor = (empresa is Map) ? empresa['estado'] : null;
      return parseRemotoEstado(valor);
    });
  }

  @override
  Future<Empresa?> getEmpresa(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    final data = snap.data();
    final empresa = data?['empresa'];
    if (empresa is Map<String, dynamic>) {
      return Empresa.fromMap(empresa);
    }
    return null;
  }

  @override
  Future<void> updateEmpresaPartial(
    String uid,
    Map<String, dynamic> partial,
  ) async {
    // Usamos set(..., merge:true) para no romper si el doc no existe.
    await _db
        .collection('users')
        .doc(uid)
        .set(partial, fs.SetOptions(merge: true));
  }
}
