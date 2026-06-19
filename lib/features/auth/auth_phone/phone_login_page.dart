import 'package:flutter/material.dart';
import 'widgets/phone_title_section.dart';
import 'widgets/input_section.dart';
import '../widgets/send_code_button_reusable.dart';
import 'package:buses2/shared/widgets/teclado_numerico.dart';
import 'package:buses2/shared/utils/teclado_numerico_utils.dart';
import 'package:buses2/shared/utils/tecla_number_retraso.dart'; // teclado rapido
import 'package:buses2/shared/widgets/custom_app_bars.dart';
import 'package:buses2/shared/config/app_config.dart';

class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({super.key});

  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> {
  late PhoneNumberInputController phoneNumberController;

  @override
  void initState() {
    super.initState();
    print('🔁 PhoneLoginPage precargada (initState)');
    // Evita el retraso de teclado numerico. core/utils/tecla_number_retraso.dart';
    phoneNumberController = PhoneNumberInputController(
      phoneNumber: '',
      onChanged: (newPhoneNumber) {
        setState(() {
          // Actualiza el estado local para redibujar UI rápido
          phoneNumberController.phoneNumber = newPhoneNumber;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBars.backOnly(),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titulo y Parrafo
            // 'widgets/phone_title_section.dart'; Ubicaion logica
            const PhoneTitleSection(),
            const SizedBox(height: 32),

            // Input del número con código
            // 'widgets/input_section.dart'; Ubicaion logica
            InputSection(
              phoneNumber: phoneNumberController.phoneNumber,
              onTap: () {
                // para la logica adicional
              },
            ),

            const Spacer(),
            // Boton enviar codigo
            // '../widgets/send_code_button_reusable.dart'; Ubicaion logica
            SendCodeButton(
              phoneNumber: phoneNumberController.phoneNumber,
              isTesting: AppConfig.skipOtpSend, // ✅ usa config centralizada
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: NumericKeyboard(
        onKeyTap: (key) {
          phoneNumberController.onKeyTap(key, modificarNumeroTelefonico);
        },
      ),
    );
  }
}
