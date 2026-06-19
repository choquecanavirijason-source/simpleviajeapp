import 'package:flutter/material.dart';

class AppBars {
  /// AppBar con botón de retroceso y título
  static AppBar backWithTitle(String title) {
    return AppBar(leading: const BackButton(), title: Text(title));
  }

  /// AppBar solo con botón atrás (sin título)
  static AppBar backOnly() {
    return AppBar(leading: const BackButton());
  }
}
