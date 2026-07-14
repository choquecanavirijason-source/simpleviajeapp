import 'package:flutter/material.dart';
import 'package:buses2/shared/theme/app_colors.dart';
import 'package:buses2/shared/theme/app_radius.dart';

enum PillStatusType { success, warning, error, info, neutral }

/// Badge de estado en forma de píldora, con fondo pastel suave y texto
/// del color de acento correspondiente (estilo "Modern Clean Light UI").
class PillStatusBadge extends StatelessWidget {
  const PillStatusBadge({
    super.key,
    required this.label,
    this.type = PillStatusType.neutral,
    this.icon,
  });

  final String label;
  final PillStatusType type;
  final IconData? icon;

  _PillColors get _colors {
    switch (type) {
      case PillStatusType.success:
        return _PillColors(
          background: const Color(0xFFE0F5EF),
          foreground: AppColors.success,
        );
      case PillStatusType.warning:
        return _PillColors(
          background: const Color(0xFFFFF3D9),
          foreground: const Color(0xFFB5790A),
        );
      case PillStatusType.error:
        return _PillColors(
          background: const Color(0xFFFCE4E4),
          foreground: const Color(0xFFC0392B),
        );
      case PillStatusType.info:
        return _PillColors(
          background: const Color(0xFFE7ECF6),
          foreground: AppColors.navy,
        );
      case PillStatusType.neutral:
        return _PillColors(
          background: const Color(0xFFF1F2F4),
          foreground: const Color(0xFF5B5F66),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: colors.foreground),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: colors.foreground,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PillColors {
  const _PillColors({required this.background, required this.foreground});
  final Color background;
  final Color foreground;
}
