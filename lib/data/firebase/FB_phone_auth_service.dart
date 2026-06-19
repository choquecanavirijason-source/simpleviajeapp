import 'package:firebase_auth/firebase_auth.dart';
import '../../shared/services/phone_auth_service.dart';

class FirebasePhoneAuthService implements PhoneAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Future<void> sendPhoneCode(
    String phoneNumber, {
    required Function(String) onCodeSent,
    required Function(FirebaseAuthException) onFailed,
  }) async {
    print('📞 Enviando código a: $phoneNumber');

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 120),
      verificationCompleted: (PhoneAuthCredential credential) async {
        print('✅ Autenticación automática completada');
        await FirebaseAuth.instance.signInWithCredential(credential);
        //Modular.to.pushNamed('/home');
      },
      verificationFailed: (error) {
        print('❌ Falló el envío del código: ${error.message}');
        onFailed(error);
      },
      codeSent: (verificationId, _) {
        print('✅ Código enviado con ID: $verificationId');
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (_) {
        print('⏰ Tiempo agotado para autocompletado del código');
      },
    );
  }

  @override
  Future<void> verifySmsCode(String verificationId, String smsCode) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    await _auth.signInWithCredential(credential);
  }
}
