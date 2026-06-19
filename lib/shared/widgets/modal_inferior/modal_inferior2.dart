import 'package:flutter/material.dart';

/// [V.2.0.1]
/// Modal inferior deslizable, no se cierra
/// Cuando quieres que aparesca un modal por defecto al abrir la page,

typedef ModalInferiorContentBuilder =
    Widget Function(BuildContext context, ScrollController scrollController);

/// Comportamiento con rebote y estiramiento para el overscroll.
class _BouncyStretchBehavior extends ScrollBehavior {
  const _BouncyStretchBehavior({this.enableStretch = true});

  final bool enableStretch;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // Siempre “bounciness”, incluso si el contenido es menor al viewport.
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (!enableStretch) return child;
    return StretchingOverscrollIndicator(
      axisDirection: details.direction,
      child: child,
    );
  }
}

class ModalInferior2 extends StatelessWidget {
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;

  final ModalInferiorContentBuilder builder;
  final DraggableScrollableController? controller;

  // Estilos opcionales
  final bool showHandle;
  final EdgeInsetsGeometry handlePadding;
  final Color backgroundColor;
  final double topRadius;
  final EdgeInsetsGeometry? contentPadding;
  final List<BoxShadow>? boxShadow;

  /// Elimina padding que algunos scrollables heredan de MediaQuery.
  final bool removeTopMediaPadding;
  final bool removeBottomMediaPadding;

  /// 🔧 Nuevo: controla el rebote/estiramiento por defecto.
  final bool enableBouncing; // activa BouncingScrollPhysics
  final bool enableStretchOverscroll; // usa StretchingOverscrollIndicator
  final ScrollBehavior?
  scrollBehaviorOverride; // por si quieres inyectar otro behavior

  const ModalInferior2({
    super.key,
    required this.initialChildSize,
    required this.minChildSize,
    required this.maxChildSize,
    required this.builder,
    this.controller,
    this.showHandle = true,
    this.handlePadding = const EdgeInsets.symmetric(vertical: 8),
    this.backgroundColor = Colors.white,
    this.topRadius = 16,
    this.contentPadding,
    this.boxShadow,
    this.removeTopMediaPadding = true,
    this.removeBottomMediaPadding = false,

    // 🔧 Nuevos defaults
    this.enableBouncing = true,
    this.enableStretchOverscroll = true,
    this.scrollBehaviorOverride,
  }) : assert(
         0.0 <= minChildSize &&
             0.0 <= initialChildSize &&
             0.0 <= maxChildSize &&
             minChildSize <= maxChildSize &&
             maxChildSize <= 1.0,
         'Asegúrate de que 0 <= min, initial, max <= 1.0 y min <= max',
       );

  @override
  Widget build(BuildContext context) {
    final double effectiveInitial = initialChildSize.clamp(
      minChildSize,
      maxChildSize,
    );

    final ScrollBehavior behavior =
        scrollBehaviorOverride ??
        (enableBouncing
            ? _BouncyStretchBehavior(enableStretch: enableStretchOverscroll)
            : const ScrollBehavior());

    return DraggableScrollableSheet(
      controller: controller,
      initialChildSize: effectiveInitial,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      builder: (context, scrollController) {
        final inner = Padding(
          padding: contentPadding ?? EdgeInsets.zero,
          child: builder(context, scrollController),
        );

        return Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(topRadius),
            ),
            boxShadow:
                boxShadow ??
                const [
                  BoxShadow(
                    blurRadius: 12,
                    offset: Offset(0, -2),
                    color: Colors.black26,
                  ),
                ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showHandle)
                Padding(
                  padding: handlePadding,
                  child: const SizedBox(
                    height: 4,
                    width: 40,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.all(Radius.circular(2)),
                      ),
                    ),
                  ),
                ),

              // 👇 Todo lo que esté adentro hereda el rebote/estiramiento
              Expanded(
                child: ScrollConfiguration(
                  behavior: behavior,
                  // 👇 Hace que cualquier ListView/CustomScrollView sin controller
                  // use automáticamente el controller del sheet.
                  child: PrimaryScrollController(
                    controller: scrollController,
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: removeTopMediaPadding,
                      removeBottom: removeBottomMediaPadding,
                      child: inner,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/* Ejemplo de uso:
import 'package:buses2/shared/widgets/modal_inferior/modal_inferior2.dart';
...
final DraggableScrollableController _sheetCtrl = DraggableScrollableController();
...
body: Stack(
  children: [
    // 2) "Modal" inferior que aparece al abrir, deslizable y NO descartable
    Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: ModalInferior2(
          // Aquí decides los tamaños desde la page:
          controller: _sheetCtrl, // tiene controller para controlar con botones su tamano
          initialChildSize: 0.25, // aparece abierto al 25%
          minChildSize: 0.18,     // no baja más de aquí (no se “cierra”)
          maxChildSize: 0.25,     // puedes expandir casi a pantalla completa
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              children: const [
                Text(
                  'Modal inferior (no descartable)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  'Desliza hacia arriba/abajo. El mapa sigue siendo interactivo '
                  'en las zonas no cubiertas por este panel.',
                ),
                SizedBox(height: 16),
                // ... tu contenido
              ],
            );
          },
        ),
      ),
    ),
  ],
),
*/
