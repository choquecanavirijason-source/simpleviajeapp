import 'package:flutter/material.dart';
import 'package:buses2/shared/theme/app_colors.dart';
import 'package:buses2/shared/theme/app_radius.dart';
import 'package:buses2/shared/theme/app_shadows.dart';

/// Tarjeta base del estilo "Modern Clean Light UI": fondo blanco puro,
/// radio de borde muy pronunciado y sombra suave en vez de bordes sólidos.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: content,
      ),
    );
  }
}
