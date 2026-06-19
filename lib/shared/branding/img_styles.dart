import 'package:flutter/material.dart';

class ImageStyles {
  // Esquinas redondeadas para las imágenes
  static Widget img1(BuildContext context, String assetPath) {
    final size = MediaQuery.of(context).size;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(
        assetPath,
        width: size.width * 0.6,
        height: size.height * 0.25,
        fit: BoxFit.cover,
      ),
    );
  }

  // Estilo cuadrado
  static Widget img2(BuildContext context, String assetPath) {
    final size = MediaQuery.of(context).size;

    return Image.asset(
      assetPath,
      width: size.width * 0.6,
      height: size.height * 0.25,
      fit: BoxFit.contain,
    );
  }

  // Estilo Redondo
  static Widget img3(BuildContext context, String assetPath) {
    final size = MediaQuery.of(context).size;

    final width = size.width * 0.6;
    final height = size.height * 0.25;
    final dimension = width < height ? width : height;

    return ClipRRect(
      borderRadius: BorderRadius.circular(dimension / 2),
      child: Image.asset(
        assetPath,
        width: dimension,
        height: dimension,
        fit: BoxFit.cover,
      ),
    );
  }
}
