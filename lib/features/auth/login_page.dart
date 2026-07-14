import 'package:flutter/material.dart';

import 'widgets/logo_section.dart';
import 'widgets/image_section.dart';
import 'widgets/title_section.dart';
import 'widgets/buttons_section.dart';
import 'widgets/terminos_section.dart';

import 'package:buses2/features/auth/auth_phone/phone_login_page.dart'; //Precargar. Velocidad Botones
import 'package:buses2/features/auth/auth_google/google_login_page.dart'; //Precargar Velocidad Botones

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Control para mostrar o no las precargas
  bool _showPreloaders = true;

  @override
  void initState() {
    super.initState();

    // Después de construir el frame, "esconde" el preloader invisible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _showPreloaders = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 60),
                  const LogoSection(),
                  const SizedBox(height: 1),
                  const ImageSection(),
                  const SizedBox(height: 20),
                  const TitleSection(),
                  const SizedBox(height: 24),
                  const ButtonsSection(),
                  const Spacer(),
                  const TermsText(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Widget invisible para precargar páginas phone_login y google_login
          if (_showPreloaders)
            Opacity(
              opacity: 0,
              child: Column(
                children: const [PhoneLoginPage(), GoogleLoginPage()],
              ),
            ),
        ],
      ),
    );
  }
}
