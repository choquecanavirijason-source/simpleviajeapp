// lib/core/services/cuenta_user/firebase_adapter.dart
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'ports.dart';

class FirebaseUserAccountAdapter implements UserAccountPort {
  final fb.FirebaseAuth _auth;
  FirebaseUserAccountAdapter({fb.FirebaseAuth? auth})
    : _auth = auth ?? fb.FirebaseAuth.instance;

  @override
  Future<Account?> current() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    await user.reload();
    final u = _auth.currentUser!;
    return Account(
      uid: u.uid,
      email: u.email,
      phone: u.phoneNumber,
      displayName: u.displayName,
      providers: u.providerData.map((p) => p.providerId).toList(),
    );
  }
}
