import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserRegistrationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ¿Existe /users/<uid> ?
  Future<bool> userAlreadyExists(String uid) async {
    final snap = await _firestore.collection('users').doc(uid).get();
    return snap.exists;
  }

  // Crea/actualiza /users/<UID> (ID del doc = UID)
  Future<void> registerNewUser(String phone) async {
    final user = _auth.currentUser!;
    final userRef = _firestore.collection('users').doc(user.uid);

    await userRef.set({
      'email': user.email,
      'name': user.displayName,
      'phone': phone,
      'createdAt': FieldValue.serverTimestamp(),
      // 'originalUid': user.uid, // opcional; el ID del doc ya es el UID
    }, SetOptions(merge: true));
  }
}

/*
class UserRegistrationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // verificar si un usuario ya existe
  Future<bool> userAlreadyExists(String uid) async {
    final existingQuery = await _firestore
        .collection('users')
        .where('originalUid', isEqualTo: uid)
        .limit(1)
        .get();
    return existingQuery.docs.isNotEmpty;
  }

  // 🡇 🡆 /users/3-TIpXeLTo1NMcjoVoaPOEs4nfeaZ2
  Future<void> registerNewUser(String phone) async {
    final user = _auth.currentUser!;
    final counterRef = _firestore.collection('counters').doc('users');

    await _firestore.runTransaction((transaction) async {
      // --- ENUMERAR: Obtener y actualizar contador global ---
      final counterSnapshot = await transaction.get(counterRef);
      int currentCount = counterSnapshot.exists ? counterSnapshot.get('count') as int : 0;
      int newCount = currentCount + 1;

      transaction.set(counterRef, {'count': newCount});
      // --- GUARDAR: Crear ID personalizado y guardar datos de usuario ---
      final customId = '$newCount-${user.uid}'; // n+1 + UID
      final userRef = _firestore.collection('users').doc(customId);

      transaction.set(userRef, {
        'email': user.email,
        'name': user.displayName,
        'phone': phone,
        'originalUid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
*/
