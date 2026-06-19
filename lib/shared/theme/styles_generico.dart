import 'package:flutter/material.dart';
import 'package:buses2/shared/theme/app_colors.dart';

// Estilo para cursor parpadeante
const Widget blinkingCursor = SizedBox(
  width: 2,
  height: 20,
  child: ColoredBox(color: AppColors.cursor),
);

const EdgeInsets blinkingCursorMargin = EdgeInsets.only(left: 2);

// (Ejemplo) Estilo para punto parpadeante
const Widget blinkingDot = SizedBox(
  width: 6,
  height: 6,
  child: DecoratedBox(
    decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
  ),
);
