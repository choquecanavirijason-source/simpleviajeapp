import 'package:flutter/material.dart';
import 'package:buses2/shared/theme/app_colors.dart';

// Ejemplo de uso:
// decoration: borde1(backgroundColor: AppColors.fondoCampoGps),

// No tiene borde - esquina redondeado - sombreado
BoxDecoration borde1({required Color backgroundColor}) {
  return BoxDecoration(
    color: backgroundColor, // fondo del contenedor
    borderRadius: const BorderRadius.all(Radius.circular(12)),
    boxShadow: const [
      BoxShadow(color: AppColors.sombra, blurRadius: 3, offset: Offset(1, 1)),
    ],
  );
}

// tiene borde - esquina redona - sombreado
BoxDecoration borde2({required Color backgroundColor}) {
  return BoxDecoration(
    color: backgroundColor, // ← este es el fondo del contenedor
    borderRadius: BorderRadius.all(Radius.circular(50)), // Radio
    border: Border.all(
      color: AppColors.borderColor, // Puedes cambiar el color del borde
      width: 0.4, // Ancho del borde
    ),
    boxShadow: [
      BoxShadow(color: AppColors.sombra, blurRadius: 5, offset: Offset(2, 2)),
    ],
  );
}

// sin sombra, sin borde - con fondo y bordes redondeados
BoxDecoration borde3({required Color backgroundColor}) {
  return BoxDecoration(
    color: backgroundColor,
    borderRadius: BorderRadius.all(Radius.circular(16)),
  );
}

// sin sombra, con borde - con fondo y bordes redondeados
BoxDecoration borde4({required Color backgroundColor}) {
  return BoxDecoration(
    color: backgroundColor,
    borderRadius: BorderRadius.all(Radius.circular(0)), // esquinas rectas
    border: Border.all(
      color: Colors.black, // color del borde
      width: 1, // grosor del borde (1px)
    ),
  );
}

// tiene borde - esquina redona - sombreado
BoxDecoration borde5({required Color backgroundColor}) {
  return BoxDecoration(
    color: backgroundColor, // ← este es el fondo del contenedor
    borderRadius: BorderRadius.all(Radius.circular(50)), // Radio
    border: Border.all(
      color: AppColors.borderColor, // Puedes cambiar el color del borde
      width: 1, // Ancho del borde
    ),
    boxShadow: [
      BoxShadow(color: AppColors.sombra, blurRadius: 5, offset: Offset(2, 2)),
    ],
  );
}

/*
BoxDecoration(
  color: Colors.white,               // 🎨 Color de fondo
  border: Border.all(...),          // 🔲 Borde (líneas)
  borderRadius: BorderRadius.all(...), // 🟦 Bordes redondeados
  boxShadow: [...],                 // ☁️ Sombras
  image: DecorationImage(...),      // 🖼 Fondo con imagen
  gradient: LinearGradient(...),    // 🌈 Degradado
  shape: BoxShape.circle,           // ⭕ Círculo o rectángulo
)
*/
