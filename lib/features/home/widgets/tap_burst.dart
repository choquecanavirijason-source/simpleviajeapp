// lib/shared/utils/tap_burst.dart
import 'package:flutter/foundation.dart';

/// Detecta una ráfaga de taps (p.ej., 4 taps en 3s).
/// Uso:
/// final gate = TapBurst(tapsRequired: 4, window: Duration(seconds: 3));
/// onTap: if (gate.registerTap()) { /* trigger secreto */ }
class TapBurst {
  TapBurst({
    this.tapsRequired = 4, //cantidad de taps
    this.window = const Duration(
      seconds: 3,
    ), // limite de tiempo para hacerlo en segungos
  }) : assert(tapsRequired > 0);

  final int tapsRequired;
  final Duration window;

  int _count = 0;
  DateTime? _start;

  /// Registra un tap y retorna `true` cuando se alcanza el umbral
  /// dentro de la ventana de tiempo.
  bool registerTap() {
    final now = DateTime.now();

    if (_start == null || now.difference(_start!) > window) {
      // reinicia ventana
      _start = now;
      _count = 1;
      return false;
    } else {
      _count += 1;
      if (kDebugMode) {
        // debug opcional
        // print('TapBurst: $_count/$tapsRequired en ${now.difference(_start!).inMilliseconds}ms');
      }
      if (_count >= tapsRequired) {
        reset();
        return true;
      }
      return false;
    }
  }

  void reset() {
    _count = 0;
    _start = null;
  }
}
