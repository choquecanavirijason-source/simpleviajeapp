import 'dart:math';

String generarCodigoEmpresa({
  int longitud = 6, // 👈 cantidad de caracteres aleatorios (default: 6)
  String? prefijo, // 👈 opcional, si es null no se usa
}) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final random = Random.secure();

  // Genera la parte aleatoria
  final randomPart = List.generate(
    longitud,
    (_) => chars[random.nextInt(chars.length)],
  ).join();

  // Retorna con o sin prefijo
  if (prefijo != null && prefijo.isNotEmpty) {
    return "$prefijo$randomPart";
  }
  return randomPart;
}

/* Ejemplo de uso:
final codigoAcceso = generarCodigoEmpresa(
  prefijo: "YaAps", // opcional
  longitud: 6
);
print(codigoAcceso); // Ejemplo: YaAps4G7H2K
*/

/*Detalles
- 4 caracteres -> 1.67 millones de conbinaciones
- 5 caracteres -> 60.4 millones de combinaciones
- 6 caracteres -> 2.17 mil millones de combinaciones
- 7 caracteres -> 78.3 mil millones de combinaciones
- 8 caracteres -> 2.82 billones de combinaciones
- 9 caracteres -> 101.5 billones de combinaciones
- 10 caracteres -> 3.65 trillones de combinaciones
- 11 caracteres -> 131.4 trillones de combinaciones
- 12 caracteres -> 4.72 cuatrillones de combinaciones
*/
