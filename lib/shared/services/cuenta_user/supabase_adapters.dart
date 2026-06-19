// supabase_adapters.dart
/*
// lib/core/services/cuenta_user/supabase_adapter.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ports.dart';

class SupabaseUserAccountAdapter implements UserAccountPort {
  final SupabaseClient _sb;
  SupabaseUserAccountAdapter({SupabaseClient? client})
      : _sb = client ?? Supabase.instance.client;

  @override
  Future<Account?> current() async {
    final user = _sb.auth.currentUser;
    if (user == null) return null;
    return Account(
      uid: user.id,
      email: user.email,
      phone: user.phone,
      displayName: user.userMetadata?['name'] as String?,
      providers: [user.appMetadata?['provider']?.toString() ?? 'supabase'],
    );
  }
}
*/
