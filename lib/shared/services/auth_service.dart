library auth_service; //🡆 para comentarios
/// Toda clase que implemente esta interfaz debe definir:
/// - signInWithGoogle(): iniciar sesión con Google.
/// - signOut(): cerrar sesión.
/// - onAuthStateChanged: notifica cambios en sesión (login/logout).

abstract class AuthService {
  Future<void> signInWithGoogle();
  Future<void> signOut();
  Stream<UserAuth?> get onAuthStateChanged;
  UserAuth? get currentUser;
}

/// Se usa asi:
/// await auth.signInWithGoogle(); iniciar sesion google
/// await auth.signOut(); cerrar sesion

// Clase que representa a un usuario autenticado.
class UserAuth {
  final String uid; // ID único Firebase para cada usuario.
  final String? email; // correo (puede ser nulo).
  final String? displayName; // nombre visible (puede ser nulo).

  UserAuth({required this.uid, this.email, this.displayName});
}
