import 'package:flutter/material.dart';

class ServiceTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  // 🎨 Personalización desde el page
  final Color? foregroundColor; // color del texto/ícono (normal)
  final Color? selectedForegroundColor; // color del texto/ícono (seleccionado)

  final Color? backgroundColor; // fondo normal
  final Color? selectedBackgroundColor; // fondo seleccionado

  final Color? borderColor; // borde normal
  final Color? selectedBorderColor; // borde seleccionado

  // Tamaños/espaciados
  final EdgeInsetsGeometry padding;
  final double radius;
  final double gap;
  final double iconSize;
  final TextStyle? textStyle;

  const ServiceTag({
    super.key,
    required this.icon,
    required this.label,
    this.selected = false,
    this.enabled = true,
    this.onTap,
    // Colores opcionales
    this.foregroundColor,
    this.selectedForegroundColor,
    this.backgroundColor,
    this.selectedBackgroundColor,
    this.borderColor,
    this.selectedBorderColor,
    // Layout
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.radius = 14,
    this.gap = 8,
    this.iconSize = 18,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Defaults del tema
    final Color defaultFg = theme.textTheme.bodyMedium?.color ?? Colors.black87;
    final Color defaultBorder = theme.brightness == Brightness.dark
        ? Colors.white12
        : Colors.black12;
    final Color defaultBg = theme.brightness == Brightness.dark
        ? const Color(0xFF181A1D)
        : Colors.white;
    final Color defaultAccent = theme.colorScheme.primary;

    // Resuelve colores por estado
    final Color fg = selected
        ? (selectedForegroundColor ?? defaultAccent)
        : (foregroundColor ?? defaultFg);

    final Color bg = selected
        ? (selectedBackgroundColor ?? defaultAccent.withOpacity(0.08))
        : (backgroundColor ?? defaultBg);

    final Color br = selected
        ? (selectedBorderColor ??
              (selectedForegroundColor ?? foregroundColor ?? defaultAccent))
        : (borderColor ?? defaultBorder);

    final text = (textStyle ?? theme.textTheme.labelLarge!).copyWith(
      fontWeight: FontWeight.w600,
      color: fg,
    );

    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: br, width: 1),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: br.withOpacity(0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: fg),
          SizedBox(width: gap),
          Text(label, style: text),
        ],
      ),
    );

    if (!enabled) return child;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: child,
      ),
    );
  }
}

/* Ejemplo de uso:
ServiceTag(
  icon: Icons.local_taxi,
  label: 'Taxi',
  selected: _selectedService == 'Taxi',
  onTap: () {
    setState(() {
      _selectedService = 'Taxi';
    });
  },
),
*/

/* Ejemplo de uso: VARIOS
Wrap(
  spacing: 10,
  runSpacing: 8,
  children: [
    ServiceTag(
      icon: Icons.local_taxi,
      label: 'Taxi',
      selected: true,
      selectedForegroundColor: Colors.orange,
      selectedBackgroundColor: Colors.orange.withOpacity(0.10),
      selectedBorderColor: Colors.orange,
      onTap: () {},
    ),
    ServiceTag(
      icon: Icons.motorcycle,
      label: 'Moto',
      foregroundColor: Colors.blueGrey,      // estado no seleccionado
      borderColor: Colors.blueGrey.withOpacity(0.35),
      onTap: () {},
    ),
    ServiceTag(
      icon: Icons.delivery_dining,
      label: 'Delivery',
      selected: false,
      foregroundColor: Colors.purple,
      borderColor: Colors.purple.withOpacity(0.35),
      onTap: () {},
    ),
  ],
);
*/
