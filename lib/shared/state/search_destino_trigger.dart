import 'package:flutter/foundation.dart';

/// Señal para abrir el modal "¿A dónde vamos?" desde fuera de la página
/// de viajes (ej. el botón central del nav flotante, que vive en el shell
/// que envuelve el `RouterOutlet`).
class SearchDestinoTrigger {
  SearchDestinoTrigger._();

  static final ValueNotifier<int> ping = ValueNotifier<int>(0);

  static void fire() => ping.value++;
}
