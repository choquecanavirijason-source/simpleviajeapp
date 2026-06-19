import 'package:flutter/material.dart';

// Ajusta el import según tu paquete real
import 'package:buses2/shared/widgets/botones/boton_small.dart' show BotonSmall;

/// Modal genérico:
/// - Header azul (título izq, equis der)
/// - Body inyectable
/// - Footer: opcional "Cancelar" + botones que envíes desde el page (BotonSmall)
class AppModal extends StatelessWidget {
  const AppModal({
    super.key,
    required this.title,
    required this.body,
    this.showCancel = false,
    this.cancelText = 'Cancelar',
    this.onCancel,
    this.headerColor,
    this.closeIcon = Icons.close,
    this.maxBodyHeightFactor = 0.7,
    this.footerButtons = const <Widget>[], // 👈 botones extras desde el page
  });

  final String title;
  final Widget body;

  // Cancelar opcional
  final bool showCancel;
  final String cancelText;
  final VoidCallback? onCancel;

  // Estilo
  final Color? headerColor;
  final IconData closeIcon;
  final double maxBodyHeightFactor;

  /// Botones extras (p.ej., BotonSmall) puestos desde el page.
  /// Sugerencia: pasa instancias de BotonSmall.
  final List<Widget> footerButtons;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final headerBg = headerColor ?? cs.primary;

    final header = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 0, 0),
      decoration: BoxDecoration(
        color: headerBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: cs.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Cerrar',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(closeIcon, color: cs.onPrimary),
          ),
        ],
      ),
    );

    final bodyArea = ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * maxBodyHeightFactor,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: body,
      ),
    );

    final hasFooter = showCancel || footerButtons.isNotEmpty;

    final footer = hasFooter
        ? Padding(
            padding: const EdgeInsets.fromLTRB(
              10,
              10,
              10,
              10,
            ), // izq, arr, der, ab
            child: Row(
              children: [
                if (showCancel)
                  BotonSmall.cancel(
                    label: cancelText,
                    onPressed:
                        onCancel ?? () => Navigator.of(context).maybePop(),
                  ),
                if (showCancel) const Spacer(),
                if (!showCancel)
                  const Spacer(), // mantiene botones a la derecha
                // Botones extra del page alineados a la derecha
                Wrap(spacing: 8, runSpacing: 8, children: footerButtons),
              ],
            ),
          )
        : const SizedBox.shrink();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: cs.surface,
      elevation: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          header,
          Divider(
            height: 1,
            thickness: 1,
            color: cs.outlineVariant.withOpacity(0.5),
          ),
          bodyArea,
          if (hasFooter)
            Divider(
              height: 1,
              thickness: 1,
              color: cs.outlineVariant.withOpacity(0.5),
            ),
          footer,
        ],
      ),
    );
  }
}

/// Helper para mostrar el modal.
Future<T?> showAppModal<T>(
  BuildContext context, {
  required String title,
  required Widget body,
  bool showCancel = false,
  String cancelText = 'Cancelar',
  VoidCallback? onCancel,
  Color? headerColor,
  IconData closeIcon = Icons.close,
  bool barrierDismissible = true,
  double maxBodyHeightFactor = 0.7,
  List<Widget> footerButtons = const <Widget>[], // 👈 ahora aceptamos botones
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => AppModal(
      title: title,
      body: body,
      showCancel: showCancel,
      cancelText: cancelText,
      onCancel: onCancel,
      headerColor: headerColor,
      closeIcon: closeIcon,
      maxBodyHeightFactor: maxBodyHeightFactor,
      footerButtons: footerButtons,
    ),
  );
}

/* Ejemplo de uso:
void _abrirModalEjemplo() {
  showAppModal(
    context,
    title: 'Editar perfil',
    body: const Text('Contenido libre del modal...'),
    showCancel: true, // muestra botón Cancelar
    footerButtons: [
      BotonSmall(
        label: 'Guardar',
        icon: Icons.save,
        onPressed: () {
          // lógica de guardado
          Navigator.of(context).pop();
        },
      ),
      BotonSmall(
        label: 'Otro',
        onPressed: () {},
      ),
    ],
  );
}
*/
