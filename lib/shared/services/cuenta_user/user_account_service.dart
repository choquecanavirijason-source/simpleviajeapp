// lib/core/services/cuenta_user/user_account_service.dart
import 'ports.dart';

/// Fachada mínima y reusable para la UI
class UserAccountService {
  final UserAccountPort _port;
  const UserAccountService(this._port);

  Future<Account?> current() => _port.current();

  Future<Account?> logCurrent() async {
    final acc = await _port.current();
    logAccount(acc);
    return acc;
  }
}
