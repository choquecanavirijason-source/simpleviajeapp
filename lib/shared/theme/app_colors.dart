// import 'package:buses2/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class AppColors {
  // Colorimetria App
  static const Color primary = Color(0xFF008080); // Verde azulado
  static const Color secondary = Color(0xFF004D4D); // Verde más oscuro

  // Para los bordes
  static const Color borderColor = Colors.grey;
  static const Color borderColorRed = Colors.red;
  // Para la sombra
  static const Color sombra = Colors.black45;

  // *** INPUTS *** //
  // Para los fondo inputs
  static const Color fondoInput = Colors.white;
  // inputs desabilitados
  static const Color fondoInputDisable = Color(0xFFF0F0F0);
  static const Color textInputDisable = Colors.black54;

  // *** CAJAS *** //
  // fondo cajas
  static const Color fondoCaja1 = Colors.white;

  // *** TEXTOS *** //
  // Texto Global
  static const Color tituloGlobal = Colors.black;
  static const Color parrafoGlobal = Colors.black87;
  static const Color subtitulo = Colors.grey;

  // Placeholder
  static const Color placeholder = Colors.black54;
  // *** TEXTOS *** //

  // *** BOTONES *** //
  // Boton por Defecto Global
  static const Color botonGlobal = Colors.green;
  static const Color botonGlobalTexto = Colors.white;

  // Botón Google
  static const Color botonGoogle = Colors.white;
  static const Color botonGoogleTexto = Colors.black;

  // Botón Facebook
  static const Color botonFacebook = Color(0xFF1877F2);
  static const Color botonFacebookTexto = Colors.white;

  // Botón estilo Blue Grey (por ejemplo para SMS)
  static const Color botonBlueGrey = Colors.blueGrey;
  static const Color botonBlueGreyText = Colors.white;
  // *** BOTONES *** //

  // ***🡇🡇🡇 APPBARS 🡇🡇🡇*** //
  // AppBar Global
  static const Color appBar = Colors.white;
  static const Color arrowBack = Colors.black;
  static const Color textAppBar = Colors.black;

  // AppBar Home
  static const Color fondoAppBarHome = Color(0xFF008080);
  static const Color iconMenu = Colors.white;
  static const Color fondoCampoGps = Color.fromRGBO(
    255,
    0,
    0,
    0.15,
  ); // rojo con 15% de opacidad
  static const Color iconGps = Colors.grey;
  // Linea vertical |
  static final Color lineVertical = Colors.grey[400]!;
  // Iconos
  static final Color iconDestino = Color(0xFF008080); // bandera
  // ***🡅🡅🡅 APPBARS 🡅🡅🡅*** //

  // ***🡇🡇🡇 RADIOLINEA 🡇🡇🡇*** //
  // AppBar Global
  static const Color fondoRadiolinea = Colors.white;
  // ***🡅🡅🡅 RADIOLINEA 🡅🡅🡅*** //

  // Fondo Pantalla
  static const Color fondoPantalla = Colors.white;

  // Estabdares
  static const Color success = Color(0xFF4CAF50); // éxito
  static const Color warning = Color(0xFFFFC107); // advertencia
  static const Color error = Color(0xFFF44336); // error

  // *** ONBOARDING *** //
  static const Color oscureceImg = Color.fromRGBO(0, 0, 0, 0.5);
  // Texto Blanco Onboarding
  static const Color tituloOnboarding = Colors.white;
  static const Color parrafoOnboarding = Colors.white;

  // *** CURSOR *** //
  static const Color cursor = Colors.blue;

  // *** TEXTFIELDS INPUTS *** //
  // Input por Defecto Global
  static const Color bordeEnfocado = Color(0xFF008080); // primary

  // *** TECLADO NUMERICO *** //
  // Teclado
  static final Color fondoTeclado = Colors.grey[200]!;
  static const Color fondoTeclaEspecial = Color(
    0xFFEEEEEE,
  ); // ≈ Colors.grey[300]
  static const Color teclaPresioanda = Color(0xFFEEEEEE); // ≈ Colors.grey[300]
  static const Color fondoTecla = Colors.white;
}
