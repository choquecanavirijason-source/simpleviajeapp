library auth_service;

class UserAuth {
  final String uid;
  final String? email;
  final String? displayName;

  UserAuth({required this.uid, this.email, this.displayName});
}

abstract class LoginService {
  Future<void> signInWithGoogle({
    String collectionRoot = 'users',
    String nombreMap = 'perfil', // ✅ agregar aquí
  });
  Future<void> signOut();
  Stream<UserAuth?> get onAuthStateChanged;
  UserAuth? get currentUser;
}

/*
import 'package:prestamos1/shared/services/auth_service.dart';
...
final auth = Modular.get<LoginService>(); // Login Google
...
onPressed: () async {
  await auth.signInWithGoogle(
    collectionRoot: 'hola',
    nombreMap: 'Perfil.datos',
  ); // 👉 abre el selector nativo de cuentas
  Modular.to.pushNamed('/google-login');
},
*/

/* Reglas Firebase
// Firestore Rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Aplica a cualquier colección raíz y documento {uid}
    match /{root}/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
*/

/* Cerrar sesión
import 'package:prestamos1/shared/services/login_google/login_google_service.dart';
...
@override
Widget build(BuildContext context) {
  final auth = Modular.get<LoginService>();
  ...
onPressed: () async {
  try {
    // Cierra el Drawer primero (para evitar UI "rota")
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    // Cierra sesión (Google + Firebase)
    await auth.signOut();

    // Navega al login y limpia el historial
    Modular.to.pushNamedAndRemoveUntil('/login', (_) => false);
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No se pudo cerrar sesión: $e')),
    );
  }
},
*/
