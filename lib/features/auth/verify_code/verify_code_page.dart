import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'widgets/title_section.dart';
import 'widgets/code_input_section.dart';
import 'package:buses2/shared/widgets/teclado_numerico.dart';
import 'package:buses2/shared/utils/teclado_numerico_utils.dart';
import 'widgets/time_text.dart';
import 'package:buses2/shared/utils/cuenta_regresiva_utils.dart';
import 'package:buses2/shared/widgets/custom_app_bars.dart';
import 'package:buses2/shared/services/phone_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:buses2/shared/config/app_config.dart';

// --- Página de verificación ---
class VerifyCodePage extends StatefulWidget {
  const VerifyCodePage({Key? key}) : super(key: key);

  @override
  State<VerifyCodePage> createState() => _VerifyCodePageState();
}

class _VerifyCodePageState extends State<VerifyCodePage> {
  late final String phone;
  late final String verificationId;

  List<String> codeDigits = List.filled(6, ''); // 👈 6 inputs
  final CountdownController countdownController =
      CountdownController(); // cuenta regresiva

  @override
  void initState() {
    super.initState();

    // 📦 Recibir los argumentos de Modular
    final args = Modular.args.data as Map;
    phone = args['phone'] as String;
    verificationId = args['verificationId'] as String;

    countdownController.start(); // cuenta regresiva
  }

  @override
  void dispose() {
    countdownController.disposeTimer(); // cuenta regresiva
    super.dispose();
  }

  // Teclado numerico / Logica del boton Borrar y del Boton OK
  // Utils ubicado en /core/utils/teclado_numerico_utils.dart';
  void _onKeyTap(String key) async {
    final previousCodeDigits = List<String>.from(codeDigits);
    final changed = modificarCodigoOtp(codeDigits, key);

    if (changed) {
      setState(() {
        for (int i = 0; i < codeDigits.length; i++) {
          if (previousCodeDigits[i].isEmpty && codeDigits[i].isNotEmpty) {
            print('Casilla ${i + 1} completada con: ${codeDigits[i]}');
          }
        }
      });

      final isComplete = codeDigits.every((digit) => digit.isNotEmpty);
      if (!isComplete) return;

      final smsCode = codeDigits.join();
      print('✅ Código completo ingresado: $smsCode');
      print('📨 verificationId recibido: $verificationId');

      // 🧪 Si el modo test está activo, permite cualquier código lleno
      if (AppConfig.skipOtpVerification) {
        print('🧪 Modo test activo: acceso con cualquier código');
        Modular.to.pushNamed('/home');
        return;
      }

      try {
        final phoneAuthService = Modular.get<PhoneAuthService>();
        await phoneAuthService.verifySmsCode(verificationId, smsCode);

        print('🎉 Usuario autenticado correctamente');
        Modular.to.pushNamed('/home');
      } on FirebaseAuthException catch (e) {
        print('❌ Error al verificar código: ${e.message}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Código incorrecto. Intenta de nuevo.')),
        );
        setState(() {
          codeDigits = List.filled(6, '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBars.backOnly(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TitleSection(phone: phone), //Titulo y parrafo
                      const SizedBox(height: 32),
                      CodeInputSection(codeDigits: codeDigits), // 4 casillas
                      const SizedBox(height: 32),
                      AnimatedBuilder(
                        //Cuenta regresiva
                        animation: countdownController,
                        builder: (_, __) => TimeText(
                          secondsRemaining:
                              countdownController.secondsRemaining,
                          onResend: countdownController.start,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // Teclado numerico -> /core/widgets/teclado_numerico.dart';
      bottomNavigationBar: NumericKeyboard(onKeyTap: _onKeyTap),
    );
  }
}
