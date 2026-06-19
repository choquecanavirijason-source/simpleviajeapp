import 'package:flutter/material.dart';
import 'modal_code/code_delibery_modal.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:buses2/shared/services/phone_auth_service.dart';

class SendCodeButton extends StatelessWidget {
  final String phoneNumber;
  final bool isTesting; // 👈 testeo llevar a la siguiente pantalla.

  const SendCodeButton({
    super.key,
    required this.phoneNumber,
    this.isTesting = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          // 🟢 Se obtiene el número ingresado y se eliminan espacios extras
          final phone = phoneNumber.trim();
          final fullPhone = '+591$phone';

          if (phone.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Por favor ingresa tu número')),
            );
            return;
          }

          // 👇 testeo llevar a la siguiente pantalla.
          if (isTesting) {
            Modular.to.pushNamed(
              '/verify-code',
              arguments: {
                'phone': fullPhone,
                'verificationId': 'dummy-verification-id', // Valor ficticio
              },
            );
            return;
          }

          final phoneAuth = Modular.get<PhoneAuthService>();

          try {
            await phoneAuth.sendPhoneCode(
              fullPhone,
              onCodeSent: (verificationId) {
                // ✅ Una vez enviado, redirigimos y pasamos el verificationId también si querés
                Modular.to.pushNamed(
                  '/verify-code',
                  arguments: {
                    'phone': fullPhone,
                    'verificationId': verificationId,
                  },
                );
              },
              onFailed: (error) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al enviar código: ${error.message}'),
                  ),
                );
              },
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ocurrió un error inesperado')),
            );
          }
        },
        child: const Text('Enviar código'),
      ),
    );
  }
}
