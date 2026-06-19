import 'package:flutter/material.dart';

class Casillas extends StatelessWidget {
  const Casillas({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showTopDivider = true,
    this.showBottomDivider = true,
  });

  final String? title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showTopDivider;
  final bool showBottomDivider;

  /// Helper para un ícono dentro de círculo azul
  static Widget blueCircleIcon(
    IconData icon, {
    double radius = 16,
    double size = 18,
    Color backgroundColor = Colors.blue,
    Color iconColor = Colors.white,
  }) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: Icon(icon, size: size, color: iconColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    if (showTopDivider) {
      children.add(const Divider(height: 1, thickness: 0.8));
    }

    children.add(
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        dense: true,
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        minVerticalPadding: 0,
        minLeadingWidth: 0,
        leading: leading,
        title: (title != null)
            ? Text(
                title!,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
        subtitle: (subtitle != null)
            ? Text(
                subtitle!,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              )
            : null,
        trailing: trailing,
        onTap: onTap,
      ),
    );

    if (showBottomDivider) {
      children.add(const Divider(height: 1, thickness: 0.8));
    }

    return Column(mainAxisSize: MainAxisSize.min, children: children);
  }
}

/* Ejemplo de uso:
Casillas(
  title: 'Teléfono',
  subtitle: '78945612',
  leading: Casillas.blueCircleIcon(Icons.phone), // círculo azul + icono
  trailing: const Icon(Icons.edit, size: 18),
  onTap: () {},

  // opcionales (por defecto true):
  showTopDivider: true, // línea arriba
  showBottomDivider: false, // sin línea abajo
),
*/
