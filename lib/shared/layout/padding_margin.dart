//* import 'package:buses2/shared/layout/padding_margin.dart';

import 'package:flutter/material.dart';

//* Ejemplo de uso:
//* padding: AppSpacing.container,
//* margin: AppSpacing.allMargin,

// horizontal 🡆 --
// vertical 🡆 |
class AppSpacing {
  // Padding
  static const EdgeInsets container = EdgeInsets.symmetric(
    horizontal: 15.0,
    vertical: 0.0,
  );
  static const EdgeInsets paddingABCD = EdgeInsets.symmetric(
    horizontal: 7.0,
    vertical: 7.0,
  );

  // Margin                                              --               |
  static const EdgeInsets mAll = EdgeInsets.symmetric(
    horizontal: 6.0,
    vertical: 7.0,
  );
}

// TIPOS DE PADDING
// padding: EdgeInsets.all(16), // Igual en todos lados
// padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
// padding: EdgeInsets.only(left: 10, top: 20, right: 10), // izq, arr, der, aba
// padding: EdgeInsets.fromLTRB(10, 20, 30, 40),
// padding: EdgeInsets.zero, // Sin padding

// TIPOS DE MARGIN
// margin: EdgeInsets.all(16), // Igual en todos lados
// margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
// margin: EdgeInsets.only(left: 10, top: 20, right: 10), // izq, arr, der, aba
// margin: EdgeInsets.only(left: 10, top: 20, right: 10),
// margin: EdgeInsets.zero, // Sin padding
