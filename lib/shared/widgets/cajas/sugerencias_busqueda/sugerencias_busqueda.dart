import 'package:flutter/material.dart';

/// Modelo de cada sugerencia que VIENE desde la page.
class SugerenciaEntry {
  final String titulo; // texto principal
  final String? subtitulo; // texto secundario (opcional)
  final IconData leadingIcon; // icono izquierdo (obligatorio)
  final IconData trailingIcon; // icono derecho (obligatorio)
  final Color? leadingColor; // color icono izquierdo (opcional, PRIORIDAD)
  final Color? trailingColor; // color icono derecho (opcional)
  final String? placeId; // place_id obtener coordenas de Google (opcional)

  const SugerenciaEntry({
    required this.titulo,
    this.subtitulo,
    required this.leadingIcon,
    required this.trailingIcon,
    this.leadingColor,
    this.trailingColor,
    this.placeId,
  });
}

/// Lista compacta. Todo lo manda la page.
class SugerenciasBusqueda extends StatelessWidget {
  const SugerenciasBusqueda({
    super.key,
    required this.controller,
    required this.items,
    this.onUpdate,

    // ---- Densidad / tamaño ----
    this.mostrarSubtitulo = true,
    this.dense = false,
    this.showDivider = true,
    this.iconSize = 24,
    this.itemVerticalPadding = 10,
    this.leadingGap = 10,
    this.trailingGap = 6,

    // ---- NUEVO: color por defecto del icono izquierdo ----
    this.defaultLeadingColor,
  });

  final TextEditingController controller;
  final List<SugerenciaEntry> items;
  final Future<void> Function(SugerenciaEntry lugar)? onUpdate;

  // Densidad / tamaño
  final bool mostrarSubtitulo;
  final bool dense;
  final bool showDivider;
  final double iconSize;
  final double itemVerticalPadding;
  final double leadingGap;
  final double trailingGap;

  /// Color por defecto para TODOS los íconos izquierdos.
  /// Si un item trae `leadingColor`, ese tiene prioridad.
  final Color? defaultLeadingColor;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final double vPad = dense
        ? (itemVerticalPadding * 0.8)
        : itemVerticalPadding;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => showDivider
          ? Divider(
              height: 1,
              thickness: 0.7,
              indent: 40,
              color: theme.dividerColor.withOpacity(0.25),
            )
          : const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final it = items[i];
        final Color leftColor =
            it.leadingColor ?? defaultLeadingColor ?? theme.colorScheme.primary;

        return InkWell(
          onTap: () async {
            controller.text = it.titulo;
            if (onUpdate != null) {
              await onUpdate!(it);
            }
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: vPad),
            child: Row(
              children: [
                Icon(it.leadingIcon, size: iconSize, color: leftColor),
                SizedBox(width: leadingGap),

                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        it.titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      if (mostrarSubtitulo &&
                          (it.subtitulo?.isNotEmpty ?? false))
                        Text(
                          it.subtitulo!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color
                                ?.withOpacity(.65),
                          ),
                        ),
                    ],
                  ),
                ),

                SizedBox(width: trailingGap),

                Icon(
                  it.trailingIcon,
                  size: iconSize * 0.72,
                  color: it.trailingColor ?? theme.hintColor.withOpacity(.8),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/* Ejemplo de uso:
SugerenciasBusqueda(
  controller: _destinoController,
  onUpdate: (r) async {
    print('📍 Coordenadas ORIGEN:');
  },
  items: const [
    SugerenciaEntry(
      titulo: 'Plaza Principal',
      subtitulo: 'Cochabamba - Bolivia',
      leadingIcon: Icons.location_on,           // icono izquierdo
      trailingIcon: Icons.north_east,           // icono derecho
    ),
  ],

  // Ajustes de densidad / tamaño
  mostrarSubtitulo: true,   // o false si quieres aún menos alto
  dense: false,             // true = más compacto
  showDivider: true,        // separadores finos
  iconSize: 24,             // 22–24 cómodo, 20 compacto
  itemVerticalPadding: 10,  // sube/baja según lo quieras de alto
  leadingGap: 10,
  trailingGap: 6,
  defaultLeadingColor: Colors.red,
),
*/
