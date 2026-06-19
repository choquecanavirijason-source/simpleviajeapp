// lib/shared/utils/delay_retraso.dart
import 'dart:async';

/// 🕒 Utilidad global para aplicar retrasos controlados.
/// Ideal para pruebas, simulaciones o sincronización con animaciones.
class DelayRetraso {
  /// Espera [delayMs] milisegundos antes de continuar.
  static Future<void> ejecutar({int delayMs = 0}) async {
    if (delayMs <= 0) return;
    await Future.delayed(Duration(milliseconds: delayMs));
  }

  /// Versión alternativa usando [Duration].
  static Future<void> esperar({Duration? duracion}) async {
    if (duracion == null || duracion.inMilliseconds <= 0) return;
    await Future.delayed(duracion);
  }
}
