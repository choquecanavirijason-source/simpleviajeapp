// import 'package:buses2/shared/widgets/overlays/cargando.dart';
import 'package:flutter/material.dart';

class Cargando {
  static bool _isShowing = false;
  static BuildContext? _overlayContext;

  static void show(BuildContext context, {String message = 'Cargando...'}) {
    if (_isShowing) return;
    _isShowing = true;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'loading',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (ctx, a1, a2) {
        _overlayContext = ctx;
        return WillPopScope(
          onWillPop: () async => false, // bloquear back
          child: Center(child: _LoadingCard(message: message)),
        );
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
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 220, maxWidth: 280),
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
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(width: 14),
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

/* Uso:
import 'package:buses2/shared/widgets/overlays/cargando.dart';
...
onPressed: () {
  FocusScope.of(context).unfocus(); // Oculta el teclado si está abierto
  // Mostrar overlay
  Cargando.show(context, message: "Guardando...");

  // Cerrar overlay después de 3 segundos
  Future.delayed(const Duration(seconds: 3), () {
    Cargando.hide();
  });
},
*/
