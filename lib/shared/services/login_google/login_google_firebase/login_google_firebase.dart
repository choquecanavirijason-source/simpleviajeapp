library firebase_auth_service;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;

import '../login_google_service.dart';

class FirebaseLoginService implements LoginService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // v7: singleton
  final gsi.GoogleSignIn _gsi = gsi.GoogleSignIn.instance;

  @override
  Future<void> signInWithGoogle({
    String collectionRoot = 'users',
    String nombreMap = 'perfil', // default 'perfil'
  }) async {
    await _gsi.initialize();

    await _gsi.signOut();
    final gsi.GoogleSignInAccount user = await _gsi.authenticate();
    final gsi.GoogleSignInAuthentication tokens = await user.authentication;

    final credential = GoogleAuthProvider.credential(idToken: tokens.idToken);
    final UserCredential cred = await _auth.signInWithCredential(credential);

    await _ensureUserDoc(cred.user, collectionRoot, nombreMap);

    await _ensureEmpresaParaUsuario(cred.user!.uid); //
  }

  Future<void> _ensureUserDoc(User? user, String root, String nombreMap) async {
    if (user == null) return;

    final ref = _db.collection(root).doc(user.uid);
    final snap = await ref.get();

    // datos que sí pueden actualizarse en cada login
    final base = {
      'email': user.email,
      'name': user.displayName,
      'photoUrl': user.photoURL,
      'provider': 'google',
      'ultimoLogin': FieldValue.serverTimestamp(),
    };

    // si el map (p.ej. perfilUser) aún NO tiene createdAt, lo agregamos una sola vez
    bool hasCreatedAt = false;
    if (snap.exists) {
      dynamic cur = snap.data();
      for (final part in nombreMap.split('.')) {
        if (cur is Map<String, dynamic> && cur.containsKey(part)) {
          cur = cur[part];
        } else {
          cur = null;
          break;
        }
      }
      if (cur is Map<String, dynamic>) {
        hasCreatedAt = cur['createdAt'] != null;
      }
    }
    if (!hasCreatedAt) {
      base['createdAt'] = FieldValue.serverTimestamp();
    }

    // construir el mapa anidado correctamente
    final nestedMap = _buildNestedMap(nombreMap, base);

    // merge para no pisar otros campos
    await ref.set(nestedMap, SetOptions(merge: true));
  }

  Future<void> _ensureEmpresaParaUsuario(String uid) async {
    // Paso 2: lo implementamos a continuación.
    // Por ahora lo dejamos vacío para que compile.
  }

  /// Convierte "perfil" o "taxista.datosLaborales" + { ...data } en map anidado
  Map<String, dynamic> _buildNestedMap(
    String path,
    Map<String, dynamic> value,
  ) {
    final parts = path.split('.');
    Map<String, dynamic> result = value;
    for (final part in parts.reversed) {
      result = {part: result};
    }
    return result;
  }

  @override
  Future<void> signOut() async {
    await _gsi.signOut();
    await _auth.signOut();
  }

  @override
  Stream<UserAuth?> get onAuthStateChanged => _auth.authStateChanges().map(
    (u) => u == null
        ? null
        : UserAuth(uid: u.uid, email: u.email, displayName: u.displayName),
  );

  @override
  UserAuth? get currentUser {
    final u = _auth.currentUser;
    return u == null
        ? null
        : UserAuth(uid: u.uid, email: u.email, displayName: u.displayName);
  }
}
