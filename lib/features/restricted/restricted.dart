// lib/features/common/pages/unauthorized_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:buses2/shared/widgets/app_bar/app_bar.dart';

class UnauthorizedPage extends StatelessWidget {
  const UnauthorizedPage({super.key});

  Future<bool> _goHome() async {
    Modular.to.navigate('/home'); // ajusta si tu ruta home es otra
    return false; // evita el pop normal
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return WillPopScope(
      onWillPop: _goHome, // captura back del sistema → /home
      child: Scaffold(
        appBar: AppBar1(
          titleSize: TitleSize.big,
          titulo: 'Usuario No Autorizado',
          subtitulo: 'por favor contacta a la empresa',
          backgroundColor: Colors.green,
          systemOverlayIsLight: true,
          textColor: Colors.white,
          hasShadow: false,
          leftAction: LeftAction.back,
          iconoIzquierda: Icons.arrow_back,
          // Si tu AppBar1 tiene un callback para el botón izquierdo, úsalo:
          onTapIzquierda:
              _goHome, // ⬅️ si tu AppBar1 no lo tiene, puedes quitar esta línea
          // Alternativa si tu AppBar1 usa 'onBack' en lugar de 'onTapIzquierda':
          // onBack: _goHome,
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                cs.primary.withOpacity(0.06),
                cs.secondary.withOpacity(0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, size: 64, color: cs.primary),
              const SizedBox(height: 16),
              Text(
                'Usted no está autorizado para entrar a esta página',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  letterSpacing: -0.2,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
