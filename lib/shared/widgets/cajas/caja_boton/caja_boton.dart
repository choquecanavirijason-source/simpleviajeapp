import 'package:flutter/material.dart';

class CajaBoton extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? leftIcon;
  final IconData? rightIcon;
  final Color? rightIconColor;
  final VoidCallback onTap;
  final TextAlign textAlign;
  final CrossAxisAlignment columnAlignment;

  /// Estado por texto:
  ///   - ocultar: null | "" | "no mostrar" | "sin imagen"
  ///   - pendiente: "pendiente" | "en revisión" | "en revision" | "pendiente o en revision" (etc.)
  ///   - aprobado: "aprobado" | "aprovado"
  ///   - rechazado: "rechazado"
  final String? estado;

  // Alto fijo definido aquí (ajústalo si quieres otro valor)
  static const double _fixedHeight = 70;

  const CajaBoton({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.leftIcon,
    this.rightIcon,
    this.rightIconColor,
    this.textAlign = TextAlign.center,
    this.columnAlignment = CrossAxisAlignment.center,
    this.estado, // <- NUEVO: reemplaza badgeState
  });

  // Normaliza el texto para comparar (minúsculas y sin acentos comunes)
  String _normalize(String? s) {
    if (s == null) return "";
    var t = s.trim().toLowerCase();
    const map = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ä': 'a',
      'ë': 'e',
      'ï': 'i',
      'ö': 'o',
      'ü': 'u',
    };
    map.forEach((k, v) => t = t.replaceAll(k, v));
    return t;
  }

  /// Badge dinámico según `estado`
  Widget? get _badgeDerecha {
    final n = _normalize(estado);

    // Ocultar badge si no hay valor o si es "no mostrar" / "sin imagen"
    final isHide = n.isEmpty || n == "no mostrar" || n == "sin imagen";
    if (isHide) return null;

    // Pendiente / En revisión (acepta varias formas)
    final isPending =
        n == "pendiente" ||
        n == "en revision" ||
        n.contains("pendiente") ||
        n.contains("revision");

    if (isPending) {
      return _buildBadge(
        "En revisión",
        Colors.amber.shade300,
        Colors.amber.shade700,
        Colors.black87,
      );
    }

    // Aprobado (incluye "aprovado")
    if (n == "aprobado" || n == "aprovado") {
      return _buildBadge(
        "Aprobado",
        Colors.green.shade400,
        Colors.green.shade700,
        Colors.white,
      );
    }

    // Rechazado
    if (n == "rechazado") {
      return _buildBadge(
        "Rechazado",
        Colors.red.shade400,
        Colors.red.shade700,
        Colors.white,
      );
    }

    // Cualquier otro valor → no mostrar (ajústalo si prefieres mostrarlo neutro)
    return null;
  }

  Widget _buildBadge(String text, Color bg, Color border, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: _fixedHeight,
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blueGrey.shade200),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            // ─── Icono izquierdo ───
            if (leftIcon != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(leftIcon, color: Colors.blueGrey),
              ),

            // ─── Título / subtítulo ───
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: columnAlignment,
                children: [
                  Text(
                    title,
                    textAlign: textAlign,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.blueGrey,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      textAlign: textAlign,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ─── Columna derecha: icono + badge debajo ───
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (rightIcon != null)
                  Icon(rightIcon, color: rightIconColor ?? Colors.blueGrey)
                else
                  const SizedBox(height: 24),

                if (_badgeDerecha != null) ...[
                  const SizedBox(height: 6),
                  _badgeDerecha!,
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/* Uso:
CajaBoton(
  title: "Documento",
  subtitle: "Subtítulo",
  rightIcon: Icons.check_circle,
  rightIconColor: Colors.green,
  textAlign: TextAlign.start,
  columnAlignment: CrossAxisAlignment.start,
  estado: "Pendiente o en revisión", // ← ahora por texto
  onTap: () {},
);

Otros ejemplos válidos:
  estado: null                        // no muestra badge
  estado: "no mostrar"                // no muestra badge
  estado: "sin imagen"                // no muestra badge
  estado: "pendiente"                 // En revisión — icono: Icons.hourglass_top — color: Colors.amber
  estado: "pendiente o en revisión"   // En revisión — icono: Icons.hourglass_top — color: Colors.amber
  estado: "en revisión"               // En revisión — icono: Icons.hourglass_top — color: Colors.amber
  estado: "aprobado"                  // Aprobado    — icono: Icons.check_circle   — color: Colors.green
  estado: "rechazado"                 // Rechazado   — icono: Icons.cancel         — color: Colors.red
*/
