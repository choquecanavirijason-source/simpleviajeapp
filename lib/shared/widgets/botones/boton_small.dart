import 'package:flutter/material.dart';

/// Alineación horizontal del botón dentro de su contenedor padre.
enum BotonSmallAlignment { left, center, right }

/// Paletas propias (3 colores).
enum BotonSmallColor { color1, color2, color3 }

/// Bordes propios (3 variantes).
enum BotonSmallBorde { borde1, borde2, borde3 }

class BotonSmall extends StatelessWidget {
  const BotonSmall({
    super.key,
    this.label,
    this.icon,
    this.onPressed,
    this.color = BotonSmallColor.color1,
    this.borde = BotonSmallBorde.borde1,
    this.innerPadding = const EdgeInsets.fromLTRB(1, 5, 1, 5),
    this.alignment = BotonSmallAlignment.center,
    this.edgePadding = 0,
  });

  /// Texto opcional. Si es null/vacío y hay [icon], se muestra solo el icono.
  final String? label;

  /// Icono opcional. Si hay [label] e [icon], se muestran ambos.
  final IconData? icon;

  final VoidCallback? onPressed;
  final BotonSmallColor color;
  final BotonSmallBorde borde;

  /// Padding interno extra (muy pequeño por defecto).
  final EdgeInsets innerPadding;

  /// Alineación horizontal dentro del espacio disponible.
  final BotonSmallAlignment alignment;

  /// Separación opcional desde el borde (izq/der) según [alignment].
  final double edgePadding;

  // ---- Constructor de conveniencia para "Cancelar" ----
  factory BotonSmall.cancel({
    Key? key,
    String label = 'Cancelar',
    VoidCallback? onPressed,
    EdgeInsets innerPadding = const EdgeInsets.fromLTRB(1, 5, 1, 5),
    BotonSmallAlignment alignment = BotonSmallAlignment.left,
    double edgePadding = 0,
  }) {
    return BotonSmall(
      key: key,
      label: label,
      onPressed: onPressed,
      color: BotonSmallColor.color2, // azul
      borde: BotonSmallBorde.borde1, // pill
      innerPadding: innerPadding,
      alignment: alignment,
      edgePadding: edgePadding,
    );
  }

  Color _bgColor() {
    switch (color) {
      case BotonSmallColor.color1:
        return Colors.green;
      case BotonSmallColor.color2:
        return Colors.blue;
      case BotonSmallColor.color3:
        return Colors.red;
    }
  }

  OutlinedBorder _shape() {
    switch (borde) {
      case BotonSmallBorde.borde1:
        return RoundedRectangleBorder(borderRadius: BorderRadius.circular(50));
      case BotonSmallBorde.borde2:
        return RoundedRectangleBorder(borderRadius: BorderRadius.circular(13));
      case BotonSmallBorde.borde3:
        return RoundedRectangleBorder(borderRadius: BorderRadius.circular(0));
    }
  }

  EdgeInsets _paddingForContent() {
    final hasText = (label != null && label!.trim().isNotEmpty);
    final hasIcon = icon != null;

    if (hasIcon && !hasText) {
      // Solo icono → muy compacto
      return const EdgeInsets.all(8);
    }
    // Texto (con o sin icono)
    return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
  }

  EdgeInsets _mergePadding(EdgeInsets a, EdgeInsets b) {
    return EdgeInsets.fromLTRB(
      a.left + b.left,
      a.top + b.top,
      a.right + b.right,
      a.bottom + b.bottom,
    );
  }

  AlignmentGeometry _toAlignment() {
    switch (alignment) {
      case BotonSmallAlignment.left:
        return Alignment.centerLeft;
      case BotonSmallAlignment.right:
        return Alignment.centerRight;
      case BotonSmallAlignment.center:
        return Alignment.center;
    }
  }

  EdgeInsets _edgeInset() {
    switch (alignment) {
      case BotonSmallAlignment.left:
        return EdgeInsets.only(left: edgePadding);
      case BotonSmallAlignment.right:
        return EdgeInsets.only(right: edgePadding);
      case BotonSmallAlignment.center:
        return EdgeInsets.symmetric(horizontal: edgePadding);
    }
  }

  @override
  Widget build(BuildContext context) {
    const textColor = Colors.white;
    final bg = _bgColor();
    final shape = _shape();

    final hasText = (label != null && label!.trim().isNotEmpty);
    final hasIcon = icon != null;

    Widget child;
    if (hasIcon && hasText) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label!,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    } else if (hasIcon) {
      child = const Icon(
        Icons.cloud_upload,
        size: 18,
        color: textColor,
      ).copyWith(icon); // helper simple para mantener tamaño/color
    } else {
      child = Text(
        (label ?? '').isEmpty ? ' ' : label!,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final borderRadius = (shape is RoundedRectangleBorder)
        ? shape.borderRadius
        : BorderRadius.zero;
    final effectivePadding = _mergePadding(_paddingForContent(), innerPadding);

    final button = Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: const [
          BoxShadow(
            color: Color.fromARGB(120, 0, 0, 0),
            blurRadius: 1.5,
            offset: Offset(0, 1.8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: textColor,
          shape: shape,
          padding: effectivePadding,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(0, 0),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        ),
        child: child,
      ),
    );

    // Controla la ubicación horizontal
    return Align(
      alignment: _toAlignment(),
      child: Padding(padding: _edgeInset(), child: button),
    );
  }
}

extension on Widget {
  /// Mini helper para clonar el Icon manteniendo estilo cuando cambiamos solo el `icon`.
  Widget copyWith(IconData? newIcon) {
    if (this is! Icon || newIcon == null) return this;
    final i = this as Icon;
    return Icon(newIcon, size: i.size, color: i.color);
  }
}

/* Ejemplo de uso:
BotonSmall(
  label: 'Enviar',
  icon: Icons.send,
  color: BotonSmallColor.color1,
  borde: BotonSmallBorde.borde2,
  alignment: BotonSmallAlignment.right, // left, center, right
  onPressed: () {},
),

// Cancelar (factory)
BotonSmall.cancel(
  onPressed: () => Navigator.of(context).pop(),
),
*/
