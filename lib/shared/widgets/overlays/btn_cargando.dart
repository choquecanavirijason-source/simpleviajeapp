import 'package:flutter/material.dart';

/// Devuelve null cuando [loading] es true; útil para pasar a onPressed.
VoidCallback? disableOnLoading(bool loading, VoidCallback? cb) =>
    loading ? null : cb;

/// Mantengo helpers por si los usas en otros lados:
String busyLabel(
  bool loading,
  String idle, {
  String working = 'Guardando...',
}) => loading ? working : idle;
IconData? hideIconWhenLoading(bool loading, IconData? icon) =>
    loading ? null : icon;

/// Tipos de borde del overlay (igual semántica que tu BotonBorde).
enum BtnBorde { borde1, borde2, borde3 }

double _radiusFor(BtnBorde b) {
  switch (b) {
    case BtnBorde.borde1:
      return 50; // pill
    case BtnBorde.borde2:
      return 12; // radio 12
    case BtnBorde.borde3:
      return 0; // cuadrado
  }
}

/// Overlay “cargando”
/// - NO recorta la sombra del child
/// - Fondo gris SÓLIDO por defecto
/// - Muestra spinner + texto configurables ENCIMA del botón
class Btn_Cargando extends StatelessWidget {
  const Btn_Cargando({
    super.key,
    required this.loading,
    required this.child,
    this.borde = BtnBorde.borde1,
    this.overlayColor = Colors.grey,
    this.spinnerColor = Colors.white,
    this.strokeWidth = 2,
    this.indicatorSize = 20,
    this.workingLabel = 'Guardando...',
    this.showWorkingLabel = true,
    this.textStyle,
    this.gap = 10,
    this.overlayOpacity = 1.0, // sólido por defecto
  });

  final bool loading;
  final Widget child;

  // Apariencia
  final BtnBorde borde;
  final Color overlayColor;
  final double overlayOpacity;
  final Color spinnerColor;
  final double strokeWidth;
  final double indicatorSize;

  // Contenido del overlay
  final String workingLabel;
  final bool showWorkingLabel;
  final TextStyle? textStyle;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final radius = _radiusFor(borde);

    return Stack(
      clipBehavior: Clip.none, // no corta la sombra del botón
      fit: StackFit.passthrough,
      children: [
        // El botón original (bloqueado cuando loading)
        AbsorbPointer(absorbing: loading, child: child),

        if (loading) ...[
          // Capa sólida con el borde elegido
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: overlayColor.withOpacity(overlayOpacity),
                  borderRadius: BorderRadius.circular(radius),
                ),
              ),
            ),
          ),
          // Spinner + Texto arriba de la capa
          Positioned.fill(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: indicatorSize,
                    height: indicatorSize,
                    child: CircularProgressIndicator(
                      strokeWidth: strokeWidth,
                      valueColor: AlwaysStoppedAnimation<Color>(spinnerColor),
                    ),
                  ),
                  if (showWorkingLabel) ...[
                    SizedBox(width: gap),
                    Text(
                      workingLabel,
                      style:
                          textStyle ??
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/* Ejemplo de uso:
import 'package:buses2/shared/widgets/overlays/btn_cargando.dart';
...
bool _loading = false; // tu estado real

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      // TODO: tu lógica async real
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos guardados')),
      );
      // Modular.to.navigate('/home');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

Btn_Cargando(
  loading: _loading,
  borde: BtnBorde.borde1,               // borde1 (pill) | borde2 (12) | borde3 (cuadrado)
  workingLabel: 'Ingresando...',        // 👈 texto que quieres ver mientras carga
  overlayColor: Colors.grey,            // sólido
  spinnerColor: Colors.white,           // visible sobre gris
  child: Boton1(
    label: 'Iniciar sesión',            // el botón mantiene su label original
    iconoIzquierdo: Icons.login,        // puedes no ocultarlo: el overlay lo tapa
    color: BotonColor.color1,
    borde: BotonBorde.borde1,
    alineacion: BotonAlineacion.centrado,
    gap: 8,
    onPressed: disableOnLoading(_loading, _submit), // 👈 evita doble click
  ),
),
*/
