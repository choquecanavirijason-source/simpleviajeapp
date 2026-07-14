import 'package:flutter/foundation.dart';

/// Notifica si hay un [Drawer] abierto en la pantalla actual, para que
/// elementos flotantes (como el bottom nav) puedan ocultarse mientras
/// tanto y no choquen visualmente con él.
class DrawerVisibility {
  DrawerVisibility._();

  static final ValueNotifier<bool> isOpen = ValueNotifier<bool>(false);
}
