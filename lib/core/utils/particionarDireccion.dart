/// Separa una descripción de Google Places en título y subtítulo.
/// Ejemplo: "Plaza 14 de Septiembre, Montero, Bolivia"
/// → { "titulo": "Plaza 14 de Septiembre", "subtitulo": "Montero, Bolivia" }

import 'package:flutter/foundation.dart';

/// Normaliza el nombre de un departamento/provincia removiendo prefijos
/// ("Departamento de", "Provincia de", "Province of") y sufijos ("Province"),
/// y compactando espacios.
///
/// Ej.: "Provincia de Buenos Aires"  → "Buenos Aires"
///      "Departamento de Cochabamba" → "Cochabamba"
///      "Buenos Aires Province"      → "Buenos Aires"
String normalizarDepartamento(String departamento) {
  return departamento
      .replaceAll(RegExp(r'^\s*Departamento de\s+', caseSensitive: false), '')
      .replaceAll(RegExp(r'^\s*Department of\s+', caseSensitive: false), '')
      .replaceAll(RegExp(r'^\s*Provincia de\s+', caseSensitive: false), '')
      .replaceAll(RegExp(r'^\s*Province of\s+', caseSensitive: false), '')
      .replaceAll(RegExp(r'^\s*Provincia\s+', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+Province\s*$', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

Map<String, String> direccionPorPartes(String description) {
  // 1. DIVISIÓN INTELIGENTE:
  // Usa una RegExp que detecta comas (,) o guiones (-)
  // Luego limpia espacios en blanco y quita elementos vacíos
  debugPrint('🏠 direccionPorPartes: procesando "$description"');

  final partes = description
      .split(RegExp(r'[,|-]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  String calle = '';
  String ciudad = '';
  String departamento = '';
  String pais = '';

  // 2. ASIGNACIÓN LÓGICA
  // Si recibimos "Punata - Cochabamba, Bolivia"
  // partes[0] = Punata
  // partes[1] = Cochabamba
  // partes[2] = Bolivia

  if (partes.isNotEmpty) calle = partes[0];

  if (partes.length == 2) {
    // Caso: "Punata, Bolivia" o "Punata - Cochabamba"
    ciudad = partes[1];
  } else if (partes.length == 3) {
    // Caso: "Punata - Cochabamba, Bolivia" -> Lo más común en Google Maps
    ciudad = partes[0]; // Opcional: podrías poner calle = partes[0]
    departamento = normalizarDepartamento(partes[1]);
    pais = partes[2];
  } else if (partes.length > 3) {
    // Caso completo con calle, ciudad, depto, pais
    ciudad = partes[1];
    departamento = normalizarDepartamento(partes[2]);
    pais = partes.sublist(3).join(', ');
  }

  // Compatibilidad con tu interfaz
  final titulo = calle;
  final subtitulo = [
    if (ciudad != calle) ciudad, // Evita repetir si son iguales
    departamento,
    pais,
  ].where((p) => p.isNotEmpty).join(', ');
  debugPrint(
    '🏠 direccionPorPartes: "$description" → titulo="$titulo", subtitulo="$subtitulo"',
  );
  return {
    'titulo': titulo,
    'subtitulo': subtitulo,
    'calle': calle,
    'ciudad': ciudad,
    'departamento': departamento,
    'pais': pais,
  };
}
