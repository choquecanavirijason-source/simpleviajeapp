import 'package:flutter/material.dart';
import 'package:buses2/shared/theme/app_colors.dart';

class FloatingNavItem {
  const FloatingNavItem({required this.icon, this.label});
  final IconData icon;
  final String? label;
}

/// Bottom navigation oscura. Por defecto queda anclada de extremo a
/// extremo en la parte inferior del dispositivo (usar en el slot
/// `bottomNavigationBar` del Scaffold). Con [floating] en `true` se
/// convierte en una píldora con esquinas totalmente redondeadas, pensada
/// para usarse dentro de un `Stack`/`Positioned` con márgenes propios
/// (el llamador se encarga del `SafeArea`/margen inferior en ese caso).
/// El item seleccionado mantiene una cubierta circular mientras se
/// permanece en esa sección.
class FloatingBottomNav extends StatelessWidget {
  const FloatingBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.height = 64,
    this.floating = false,
    this.centerAction,
  });

  final List<FloatingNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final double height;
  final bool floating;

  /// Widget opcional con su propio espacio dedicado al centro de la fila
  /// (ej. un botón de búsqueda), distinto de los items normales.
  final Widget? centerAction;

  @override
  Widget build(BuildContext context) {
    final radius = floating
        ? const BorderRadius.all(Radius.circular(32))
        : const BorderRadius.vertical(top: Radius.circular(28));

    final children = <Widget>[
      for (var i = 0; i < items.length; i++)
        _NavItem(
          item: items[i],
          selected: i == currentIndex,
          onTap: () => onTap(i),
        ),
    ];
    if (centerAction != null) {
      children.insert(
        children.length ~/ 2,
        Expanded(child: Center(child: centerAction)),
      );
    }

    final row = Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: children,
    );

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.navyDark,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      // No flotante: el color llega hasta el borde real y solo el
      // contenido se acomoda con SafeArea. Flotante: el margen/SafeArea
      // lo maneja quien la posiciona (Positioned), así que aquí solo se
      // fija el alto.
      child: floating
          ? SizedBox(height: height, child: row)
          : SafeArea(
              top: false,
              child: SizedBox(height: height, child: row),
            ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final FloatingNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Ícono: navy sobre círculo blanco cuando está seleccionado, claro
    // semitransparente sobre la barra cuando no. El texto siempre queda
    // sobre la barra (fuera del círculo), así que se mantiene claro.
    final iconColor = selected
        ? AppColors.navyDark
        : AppColors.onNavy.withValues(alpha: 0.5);
    final textColor = selected
        ? AppColors.onNavy
        : AppColors.onNavy.withValues(alpha: 0.5);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? Colors.white : Colors.transparent,
                  ),
                  child: Icon(item.icon, color: iconColor, size: 18),
                ),
                if (item.label != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.label!,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
