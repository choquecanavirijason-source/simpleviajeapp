import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:buses2/shared/services/user_registro_service.dart';
import '../../validators/input_phonevalidators.dart';

class ConfirmUserButton extends StatelessWidget {
  final String phoneNumber;

  const ConfirmUserButton({Key? key, required this.phoneNumber})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          final user = FirebaseAuth.instance.currentUser;
          final phone = phoneNumber;

          // Validators ../../validators/input_phonevalidators.dart
          final phoneError = validateBolivianPhone(phone);
          if (phoneError != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('⚠️ $phoneError')));
            return;
          }

          if (user != null && phone.isNotEmpty) {
            final service = UserRegistrationService();
            final exists = await service.userAlreadyExists(
              user.uid,
            ); // verify user existe

            if (exists) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('⚠️ Usuario ya está registrado')),
              );
              Modular.to.pushNamed('/home');
              return;
            }

            try {
              await service.registerNewUser(phone); // n+1 + UID
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Usuario guardado con ID numerado'),
                ),
              );
              Modular.to.pushNamed('/home');
            } catch (e) {
              print('❌ Error al guardar número: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('❌ Error al guardar número')),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('⚠️ Faltan datos para guardar')),
            );
          }
        },
        child: const Text('Confirmar datos'),
      ),
    );
  }
}
