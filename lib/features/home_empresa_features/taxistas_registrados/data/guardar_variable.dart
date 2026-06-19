// lib/shared/state/guardar_variable.dart
import 'package:flutter/foundation.dart';

/// Store simple y global para variables compartidas.
/// En este caso, guardamos el uid del taxista seleccionado/logueado.
class GuardarVariable {
  GuardarVariable._();
  static final GuardarVariable instance = GuardarVariable._();

  final ValueNotifier<String?> _uidTaxista = ValueNotifier<String?>(null);

  /// Setter
  void setUidTaxista(String? uid) {
    _uidTaxista.value = (uid == null || uid.isEmpty) ? null : uid;
  }

  /// Getter sincrónico
  String? get uidTaxista => _uidTaxista.value;

  /// Notifier para reaccionar en UI
  ValueListenable<String?> get uidTaxistaListenable => _uidTaxista;
}
