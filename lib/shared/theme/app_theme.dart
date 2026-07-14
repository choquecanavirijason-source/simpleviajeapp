import 'package:flutter/material.dart';
import 'package:buses2/shared/theme/app_colors.dart';

// Temas y estilos Globales
// Si no pones estilos a algo, por defecto usara estos estilos.
// En app_widget.dart se define el estilo global "theme: AppTheme.lightTheme,"

class AppTheme {
  static ThemeData get lightTheme => ThemeData(
    //** */
    useMaterial3: false, // Decide si usar Material Design 3 (aquí no se usa)
    brightness: Brightness
        .light, // Define que el tema es claro (los colores base se ajustan a tema claro)
    primaryColor: AppColors.primary, // Aplica a botones, barras, etc.
    scaffoldBackgroundColor:
        AppColors.background, // Fondo global Modern Clean Light UI (#F8F9FA)
    //** AppBar Global */
    appBarTheme: AppBarTheme(
      // Tema para todas las AppBars de la app
      backgroundColor: AppColors.appBar, // Color de fondo del (AppBar)
      foregroundColor:
          AppColors.arrowBack, // Color para iconos y textos dentro del AppBar
      centerTitle: true, // Centra el título en la AppBar
      elevation: 0, // Sombra o profundidad del AppBar
      titleTextStyle: TextStyle(
        // Estilo del texto del título del AppBar
        fontSize: 22, // Tamaño del título
        fontWeight: FontWeight.w600, // Grosor de la fuente
        color: AppColors.textAppBar, // Color del texto
      ),
    ),

    //** Botones Globales*/
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16), // Altura del botón
        backgroundColor: AppColors.botonGlobal, // Fondo
        foregroundColor: AppColors.botonGlobalTexto, // Texto e íconos
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50), // Bordes muy redondeados
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),

    // ✅ TextFields (Inputs)
    inputDecorationTheme: InputDecorationTheme(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ), // Espaciado interno horizontal y vertical
      // Borde general del campo (cuando no está enfocado ni deshabilitado)
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), // Bordes redondeados
        borderSide: BorderSide(color: AppColors.borderColor), // Color del borde
      ),

      // Borde cuando el campo está habilitado pero no enfocado
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), // Mismo borde redondeado
        borderSide: BorderSide(
          color: AppColors.borderColor,
        ), // Mismo color gris
      ),

      // Borde cuando el campo está enfocado (activo)
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), // Mismo borde redondeado
        borderSide: BorderSide(
          color: AppColors.bordeEnfocado,
          width: 2,
        ), // Borde más grueso y con color primario
      ),

      // Estilo del texto que aparece como etiqueta (labelText)
      labelStyle: TextStyle(
        color: AppColors.parrafoGlobal, // Color definido en tu tema
        fontSize: 16, // Tamaño de la etiqueta
      ),
    ),

    //**Titulos y Parrafos Globales */
    textTheme: TextTheme(
      // Tema general para textos de la app
      bodyLarge: TextStyle(
        fontSize: 16,
        color: AppColors.parrafoGlobal,
      ), // Estilo para texto normal (párrafos)
      titleLarge: TextStyle(
        fontSize: 20,
        color: AppColors.tituloGlobal,
        fontWeight: FontWeight.bold,
      ), // Estilo para títulos grandes
    ),
  );
}
