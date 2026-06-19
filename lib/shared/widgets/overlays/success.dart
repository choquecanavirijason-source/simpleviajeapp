// lib/features/home_empresa_features/pantalla_generica/widgets/success_overlay.dart
import 'package:flutter/material.dart';

/// Overlay de éxito.
/// Uso rápido:
///   await SuccessOverlay.flash(context, message: 'Guardado con éxito');
///
/// También puedes usar show()/hide() manualmente si lo prefieres.
class SuccessOverlay {
  static bool _isShowing = false;
  static BuildContext? _overlayContext;

  static void show(
    BuildContext context, {
    String message = 'Guardado con éxito',
  }) {
    if (_isShowing) return;
    _isShowing = true;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'success',
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, a1, a2) {
        _overlayContext = ctx;
        return Center(child: _SuccessCard(message: message));
      },
    );
  }

  static void hide() {
    if (!_isShowing) return;
    if (_overlayContext != null) {
      Navigator.of(_overlayContext!).pop();
    }
    _overlayContext = null;
    _isShowing = false;
  }

  /// Muestra el overlay y lo cierra solo después de [duration].
  static Future<void> flash(
    BuildContext context, {
    String message = 'Guardado con éxito',
    Duration duration = const Duration(seconds: 2),
  }) async {
    show(context, message: message);
    await Future.delayed(duration);
    hide();
  }
}

class _SuccessCard extends StatelessWidget {
  const _SuccessCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                blurRadius: 20,
                color: Colors.black26,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF22C55E), // verde
                ),
                child: const Icon(Icons.check, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/*Uso:
SuccessOverlay.flash(context, message: 'Guardado con éxito');
*/
