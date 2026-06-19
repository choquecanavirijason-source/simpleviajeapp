// lib/shared/widgets/modal_inferior/modal_inferior3.dart
import 'package:flutter/material.dart';

/// Modal inferior reutilizable (cascarón).
/// La page provee el contenido via [builder] y define alturas (min/initial/max).
class ModalInferior3 extends StatelessWidget {
  const ModalInferior3({
    Key? key,
    required this.builder,
    this.minChildSize = 0.30,
    this.initialChildSize = 0.45,
    this.maxChildSize = 0.90,
    this.contentPadding = const EdgeInsets.fromLTRB(0, 0, 0, 0),
    this.showHandle = true,
    this.backgroundColor = Colors.white,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(20)),
  }) : super(key: key);

  /// Contenido que se dibuja dentro del DraggableScrollableSheet.
  /// Recibes el [scrollController] para listas largas o SingleChildScrollView.
  final Widget Function(BuildContext context, ScrollController scrollController)
  builder;

  /// Alturas controladas desde la page
  final double minChildSize;
  final double initialChildSize;
  final double maxChildSize;

  /// Decoración opcional (no esencial para el cascarón)
  final EdgeInsets contentPadding;
  final bool showHandle;
  final Color backgroundColor;
  final BorderRadius borderRadius;

  /// Atajo estático para mostrar el modal desde cualquier lado.
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget Function(BuildContext, ScrollController) builder,
    double minChildSize = 0.30,
    double initialChildSize = 0.45,
    double maxChildSize = 0.90,
    EdgeInsets contentPadding = const EdgeInsets.fromLTRB(16, 10, 16, 16),
    bool showHandle = true,
    Color backgroundColor = Colors.white,
    BorderRadius borderRadius = const BorderRadius.vertical(
      top: Radius.circular(20),
    ),
    Color? barrierColor,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: barrierColor ?? Colors.black54,
      builder: (_) {
        return ModalInferior3(
          builder: builder,
          minChildSize: minChildSize,
          initialChildSize: initialChildSize,
          maxChildSize: maxChildSize,
          contentPadding: contentPadding,
          showHandle: showHandle,
          backgroundColor: backgroundColor,
          borderRadius: borderRadius,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: borderRadius,
        ),
        child: SafeArea(
          top: false,
          child: DraggableScrollableSheet(
            expand: false,
            minChildSize: minChildSize,
            initialChildSize: initialChildSize,
            maxChildSize: maxChildSize,
            builder: (context, scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                child: Padding(
                  padding: contentPadding,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showHandle)
                        Center(
                          child: Container(
                            width: 40,
                            height: 5,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.black12,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      // Aquí va el contenido que define la page
                      builder(context, scrollController),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/* Ejemplo de uso en una page:
  Future<void> _abrirModalDestino() async {
    final resultado = await ModalInferior3.show<Map<String, dynamic>>(
      context: context,
      minChildSize: 0.30,
      initialChildSize: 0.95,
      maxChildSize: 0.95,
      contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      builder: (ctx, sc) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿A dónde vas?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
...
onPressed: () async {
  await _abrirModalDestino();
}
*/
