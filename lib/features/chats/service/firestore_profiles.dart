import 'package:cloud_firestore/cloud_firestore.dart';

final _fs = FirebaseFirestore.instance;

/// Trae nombre y foto desde 'pasajeros/{uid}.perfil'
Future<Map<String, String>> getPassengerPublic(String uid) async {
  final snap = await _fs.collection('pasajeros').doc(uid).get();
  final perfil = (snap.data()?['perfil'] ?? {}) as Map<String, dynamic>;
  final name = (perfil['name'] ?? 'Usuario').toString();
  final photo = (perfil['photoUrl'] ?? '').toString(); // tu campo es photoUrl
  return {'name': name, 'photoUrl': photo};
}

/// Busca el UID por email dentro de 'pasajeros.perfil.email'
Future<String?> findUidByPassengerEmail(String email) async {
  final q = await _fs
      .collection('pasajeros')
      .where('perfil.email', isEqualTo: email)
      .limit(1)
      .get();
  if (q.docs.isEmpty) return null;
  return q.docs.first.id; // id del doc = UID
}
