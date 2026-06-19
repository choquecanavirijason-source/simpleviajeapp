import 'package:flutter/material.dart';
import 'package:buses2/shared/widgets/app_bar/app_bar.dart';
import 'package:buses2/features/home/controller/home_controller.dart';
import 'package:buses2/shared/localization/all_texts.dart';

class AppBars {
  static PreferredSizeWidget navbarUbicacion({
    required BuildContext context,
    required HomeController controller,
    required VoidCallback onStateUpdate,
    required String direccion,
  }) => AppBar1(
    titulo: direccion,
    subtitulo: AllTexts.tuUbicacion,
    iconoIzquierda: Icons.menu,
    iconoDerecha: Icons.directions_car,
    onTapIzquierda: () => Scaffold.of(context).openDrawer(),
    onTapDerecha: () {
      // Ícono del carro sin funcionalidad especial
    },
  );
}
