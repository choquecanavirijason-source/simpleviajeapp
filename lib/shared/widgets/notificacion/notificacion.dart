// import 'package:buses2/shared/widgets/notificacion/notificacion.dart';
import 'dart:ui';
import 'package:flutter/material.dart';

enum NotificationPosition { top, bottom }

void notificacion(
  BuildContext context, {
  required String title,
  String? subtitle,
  int seconds = 6,
  IconData icon = Icons.check_rounded,
  required Color color,
  NotificationPosition position =
      NotificationPosition.top, // ⬅️ por defecto arriba
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  if (overlay == null) {
    // Fallback raro: SnackBar sin top (solo por compatibilidad)
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
          elevation: 0,
          duration: Duration(seconds: seconds),
          backgroundColor: Colors.transparent,
          content: _NotificationBox(
            title: title,
            subtitle: subtitle,
            icon: icon,
            color: color,
            onClose: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ),
      );
    return;
  }

  final marginTop = const EdgeInsets.fromLTRB(16, 34, 16, 0); // baja ~48 px más
  final marginBottom = const EdgeInsets.fromLTRB(16, 0, 16, 90);

  OverlayEntry? entry;
  entry = OverlayEntry(
    builder: (ctx) => _NotificationOverlay(
      seconds: seconds,
      isTop: position == NotificationPosition.top, // ⬅️ anclaje
      margin: position == NotificationPosition.top ? marginTop : marginBottom,
      childBuilder: (onClose) => _NotificationBox(
        title: title,
        subtitle: subtitle,
        icon: icon,
        color: color,
        onClose: onClose,
      ),
      onRemove: () => entry?.remove(),
    ),
  );

  overlay.insert(entry);
}

class _NotificationOverlay extends StatefulWidget {
  const _NotificationOverlay({
    required this.childBuilder,
    required this.onRemove,
    required this.seconds,
    required this.isTop,
    this.margin = EdgeInsets.zero,
    super.key,
  });

  final Widget Function(VoidCallback onClose) childBuilder;
  final VoidCallback onRemove;
  final int seconds;
  final bool isTop; // ⬅️ nuevo
  final EdgeInsets margin;

  @override
  State<_NotificationOverlay> createState() => _NotificationOverlayState();
}

class _NotificationOverlayState extends State<_NotificationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(
      milliseconds: 1900,
    ), // ENTRADA lenta (desde arriba)
    reverseDuration: const Duration(milliseconds: 1900), // ⬅️ SALIDA más lenta
  );

  // Fade: visible casi desde el inicio al entrar; salida suave.
  late final Animation<double> _fade = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0.08, 1.0, curve: Curves.easeOut), // entrada
    reverseCurve: const Interval(0.00, 1.0, curve: Curves.easeIn), // salida
  );

  @override
  void initState() {
    super.initState();
    _ctrl.forward(); // ENTRADA
    _autoClose();
  }

  Future<void> _autoClose() async {
    await Future.delayed(Duration(seconds: widget.seconds));
    if (!mounted) return;
    await close();
  }

  Future<void> close() async {
    if (!mounted) return;
    await _ctrl.reverse(); // SALIDA (ahora dura 1100ms)
    if (mounted) widget.onRemove();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Entrada: desde muy arriba, desacelera al final
    // Salida: acelera al subir, pero con más tiempo para que no se sienta brusca.
    const Curve slideInCurve = Cubic(0.16, 0.90, 0.22, 1.0);
    const Curve slideOutCurve = Curves.easeInCubic;

    final Animation<Offset> slide =
        Tween<Offset>(
          begin: widget.isTop ? const Offset(0, -12.0) : const Offset(0, 12.0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _ctrl,
            curve: slideInCurve,
            reverseCurve: slideOutCurve,
          ),
        );

    return IgnorePointer(
      ignoring: false,
      child: SafeArea(
        top: widget.isTop,
        bottom: !widget.isTop,
        left: true,
        right: true,
        child: Align(
          alignment: widget.isTop
              ? Alignment.topCenter
              : Alignment.bottomCenter,
          child: Padding(
            padding: widget.margin,
            child: SlideTransition(
              position: slide,
              child: FadeTransition(
                opacity: _fade,
                child: widget.childBuilder(close),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ---------- Caja visual (tu estilo) ----------
class _NotificationBox extends StatelessWidget {
  const _NotificationBox({
    required this.title,
    required this.icon,
    required this.color,
    required this.onClose,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(16);

    Color tone(Color c, double delta) {
      final h = HSLColor.fromColor(c);
      final l = (h.lightness + delta).clamp(0.0, 1.0);
      return h.withLightness(l as double).toColor();
    }

    final fillStart = color; // base
    final fillEnd = tone(color, 0.12); // un poco más claro

    final glassA = Colors.white.withOpacity(0.25);
    final glassB = color.withOpacity(0.18);

    const textColor = Color(0xFFF7F7F7);
    final textSub = textColor.withOpacity(0.92);

    return Material(
      color: Colors.transparent,
      child: Container(
        // Borde con degradado y blur (glass SOLO en bordes)
        padding: const EdgeInsets.all(1.4), // grosor del borde
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [glassA, glassB, glassA],
            stops: const [0.0, 0.5, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.60),
              blurRadius: 3,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [fillStart, fillEnd],
                ),
              ),
              child: Row(
                children: [
                  // Icono
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: textColor, size: 20),
                  ),
                  const SizedBox(width: 12),

                  // Texto
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.1,
                            fontSize: 18,
                          ),
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: textSub,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  TextButton(
                    onPressed: onClose,
                    style: TextButton.styleFrom(
                      foregroundColor: textColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('OK'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* Ejemplo de uso:
import 'package:buses2/shared/widgets/notificacion/notificacion.dart';
...
notificacion(
  context,
  title: 'Nombre guardado',
  subtitle: 'Se actualizó tu perfil correctamente',
  seconds: 6,
  icon: Icons.check_rounded,
  color: Colors.green, // usa tu color
  // position: NotificationPosition.bottom, // notificacion abajo
);
*/
