import 'package:flutter/material.dart';
import 'package:buses2/features/auth/widgets/phone_input_reusable.dart';
import 'package:buses2/shared/widgets/teclado_numerico.dart';
import 'package:buses2/shared/utils/teclado_numerico_utils.dart';
import 'package:buses2/shared/utils/tecla_number_retraso.dart'; //Teclado rapido
import 'package:buses2/shared/widgets/custom_app_bars.dart';
import 'widgets/img_avatar.dart';
import 'package:buses2/shared/widgets/inputs.dart';
//here
import 'package:firebase_auth/firebase_auth.dart';
import 'widgets/confirm_user_button.dart';

class GoogleLoginPage extends StatefulWidget {
  const GoogleLoginPage({Key? key}) : super(key: key);

  @override
  State<GoogleLoginPage> createState() => _GoogleLoginPageState();
}

class _GoogleLoginPageState extends State<GoogleLoginPage> {
  final FocusNode nameFocusNode = FocusNode();
  final FocusNode emailFocusNode = FocusNode();
  final FocusNode phoneFocusNode = FocusNode();

  late PhoneNumberInputController phoneNumberController;
  late TextEditingController emailController;
  late TextEditingController nameController;
  bool showNumericKeyboard = false;

  @override
  void initState() {
    super.initState();

    emailController = TextEditingController();
    nameController = TextEditingController();

    // Obtené el usuario actual desde Firebase
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      print('✅ Usuario autenticado: ${user.email}');
      print('✅ Usuario autenticado: ${user.displayName}');
      emailController.text = user.email ?? '';
      nameController.text = user.displayName ?? '';
    }

    print('GoogleLoginPage precargada (initState)');
    // Evita el retraso de teclado numerico. core/utils/tecla_number_retraso.dart';
    phoneNumberController = PhoneNumberInputController(
      phoneNumber: '',
      onChanged: (newPhoneNumber) {
        setState(() {
          // Actualiza estado local para refrescar UI
        });
      },
      textController: TextEditingController(),
    );

    // Escucha cambios de foco para mostrar u ocultar teclado personalizado
    nameFocusNode.addListener(_handleFocusChange);
    emailFocusNode.addListener(_handleFocusChange);
    phoneFocusNode.addListener(() {
      setState(() {
        showNumericKeyboard = phoneFocusNode.hasFocus;
      });
    });
  }

  void _handleFocusChange() {
    setState(() {
      showNumericKeyboard = phoneFocusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    phoneNumberController.textController?.dispose();
    nameFocusNode.dispose();
    emailFocusNode.dispose();
    phoneFocusNode.dispose();
    emailController.dispose();
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textController = phoneNumberController.textController!;

    return Scaffold(
      appBar: AppBars.backWithTitle('Confirma tu información'),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const ImgAvatar(),

              // Casilla nombre 🡆 core/widgets/inputs.dart';
              InputNombre(focusNode: nameFocusNode, controller: nameController),

              // Casilla Email 🡆 core/widgets/inputs.dart';
              InputEmail(controller: emailController),

              // Casilla Phone 🡆 core/widgets/inputs.dart';
              GestureDetector(
                onTap: () {
                  FocusScope.of(context).requestFocus(phoneFocusNode);
                },
                child: PhoneNumberField(
                  controller: textController,
                  focusNode: phoneFocusNode,
                  readOnly: true,
                  // showCursor: true, // Opcional: por defecto es true
                  onChanged: (value) {
                    /*Sincronización controlada por controlador ya*/
                  },
                  onCountryChanged: (code) {},
                ),
              ),

              const SizedBox(height: 32),
              // Boton Confirmar Datos 🡆 widgets/confirm_user_button.dart
              ConfirmUserButton(phoneNumber: phoneNumberController.phoneNumber),

              // Pedir OTP Boton 🡇🡇🡇
              // SendCodeButton(
              //   phoneNumber: phoneNumberController.phoneNumber,
              //   isTesting: AppConfig.skipOtpSend, // ✅ usa config centralizada
              // ),
              // Pedir OTP Boton 🡅🡅🡅
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: showNumericKeyboard
          ? NumericKeyboard(
              onKeyTap: (key) => phoneNumberController.onKeyTap(
                key,
                modificarNumeroTelefonico,
              ),
            )
          : null,
    );
  }
}
