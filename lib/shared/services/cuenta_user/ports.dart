// lib/core/services/cuenta_user/ports.dart
class Account {
  final String uid;
  final String? email;
  final String? phone;
  final String? displayName;
  final List<String> providers;

  const Account({
    required this.uid,
    this.email,
    this.phone,
    this.displayName,
    this.providers = const [],
  });

  @override
  String toString() =>
      'Account(uid=$uid, email=$email, phone=$phone, name=$displayName, providers=$providers)';
}

/// Puerto independiente del backend
abstract class UserAccountPort {
  Future<Account?> current();
}

/// Helper para imprimir en consola
void logAccount(Account? a) {
  if (a == null) {
    // ignore: avoid_print
    print('[Account] null (no autenticado)');
    return;
  }
  // ignore: avoid_print
  print('======== Cuenta actual ========');
  print('[uid]      ${a.uid}');
  print('[email]    ${a.email ?? "-"}');
  print('[phone]    ${a.phone ?? "-"}');
  print('[name]     ${a.displayName ?? "-"}');
  print('[providers] ${a.providers.join(", ")}');
  print('================================');
}
