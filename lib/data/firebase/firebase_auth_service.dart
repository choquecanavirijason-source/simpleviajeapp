library auth_service; //🡆 para comentarios
/// Usando clase abstracta AuthService de core/services/auth_service.dart'
/// Si desea cambiar de proveedor (ej. de firebase a Supabase), solo modifique este archivo.
/// Se debe respetar la interfaz AuthService con sus métodos:
/// - signInWithGoogle()
/// - signOut()
/// - onAuthStateChanged

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:buses2/shared/services/auth_service.dart';

class FirebaseAuthService implements AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _gsi = GoogleSignIn.instance;

  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    // Android:
    // - Si tu google-services.json tiene un OAuth client web (client_type: 3),
    //   NO necesitas pasar nada aquí.
    // - Si no, pasa serverClientId con el client id web.
    await _gsi.initialize(
      // clientId: 'com.tuapp.ios-client-id.apps.googleusercontent.com', // iOS/macOS si corresponde
      // serverClientId: 'xxxx-xxxxxxxxxxxx.apps.googleusercontent.com', // Android si no usas google-services.json con client web
    ); // :contentReference[oaicite:4]{index=4}

    _initialized = true;
  }

  @override
  Future<void> signInWithGoogle() async {
    await _ensureInitialized();

    // (Opcional) Para forzar el selector de cuentas, cierra sesión previa:
    await _gsi.signOut();

    // Intenta “silencioso”; si no hay sesión previa, abre el flujo interactivo:
    final GoogleSignInAccount user =
        (await _gsi.attemptLightweightAuthentication()) ??
        await _gsi.authenticate(); // :contentReference[oaicite:5]{index=5}

    // En v7, authentication -> solo idToken (lo que Firebase necesita)
    final String? idToken = (await user.authentication)
        .idToken; // :contentReference[oaicite:6]{index=6}
    if (idToken == null) {
      throw StateError('Google no devolvió idToken');
    }

    final credential = GoogleAuthProvider.credential(
      idToken: idToken,
    ); // :contentReference[oaicite:7]{index=7}
    await _auth.signInWithCredential(credential);
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
