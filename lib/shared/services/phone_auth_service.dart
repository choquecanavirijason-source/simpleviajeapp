library phone_auth_service;

import 'package:firebase_auth/firebase_auth.dart';

abstract class PhoneAuthService {
  Future<void> sendPhoneCode(
    String phoneNumber, {
    required Function(String verificationId) onCodeSent,
    required Function(FirebaseAuthException error) onFailed,
  });

  Future<void> verifySmsCode(String verificationId, String smsCode);
}
