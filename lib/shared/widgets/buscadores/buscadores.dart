import 'package:flutter/material.dart';

export 'logica_buscar.dart'; // para poder importar solo "buscadores.dart" y tener la lógica

// v. 1.0.0

/// Configuración de un campo del buscador (reutilizable para cualquier app)
class BuscadorField {
  const BuscadorField({
    this.label = '', // opcional; si está vacío no se muestra
    this.placeholder = '',
    this.icon = Icons.search,
    this.iconContainerColor = const Color(0xFF4CAF50),
    this.controller,
    this.onChanged,
    this.onTap,

    // Interactividad avanzada:
    this.focusNode,
    this.showMapOnFocus = false, // muestra botón "Mapa" cuando hay foco
    this.mapLabel = 'Mapa',
    this.onMapPressed,
    this.trailingGap = 6, // separación entre X ↔ Mapa
    // Tamaños/espaciados visuales:
    this.iconSize = 26, // tamaño del ícono dentro de la pastilla
    this.iconBoxSize = 52, // tamaño de la pastilla de ícono (alto del field)
    this.iconRadius = 16, // radios de la pastilla de ícono
    this.tileVerticalPadding =
        10, // padding vertical del field (aumenta altura)
  });

  // Contenido
  final String label;
  final String placeholder;
  final IconData icon;
  final Color iconContainerColor;

  // Control
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;

  // Interactividad
  final FocusNode? focusNode;
  final bool showMapOnFocus;
  final String mapLabel;
  final VoidCallback? onMapPressed;
  final double trailingGap;

  // Apariencia
  final double iconSize;
  final double iconBoxSize;
  final double iconRadius;
  final double tileVerticalPadding;
}

/// Contenedor de uno o más campos tipo “buscador”
class Buscador extends StatelessWidget {
  const Buscador({
    super.key,
    required this.fields, // 1..N campos
    this.cardColor = Colors.white,
    this.elevation = 4,
    this.radius = 16,
    this.horizontalPadding = 2,
    this.verticalPadding = 2,
    this.itemSpacing = 4, // separación label ↔ input cuando HAY label
    this.showDividers = true,
  }) : assert(fields.length >= 1);

  final List<BuscadorField> fields;
  final Color cardColor;
  final double elevation;
  final double radius;
  final double horizontalPadding;
  final double verticalPadding;
  final double itemSpacing;
  final bool showDividers;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: elevation,
      borderRadius: BorderRadius.circular(radius),
      color: cardColor,
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius)),
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < fields.length; i++) ...[
              LabelInputTile(
                label: fields[i].label,
                placeholder: fields[i].placeholder,
                icon: fields[i].icon,
                iconContainerColor: fields[i].iconContainerColor,
                controller: fields[i].controller,
                onChanged: fields[i].onChanged,
                onTap: fields[i].onTap,
                spacingBetweenLabelAndInput: itemSpacing,

                // Interactividad
                focusNode: fields[i].focusNode,
                showMapOnFocus: fields[i].showMapOnFocus,
                mapLabel: fields[i].mapLabel,
                onMapPressed: fields[i].onMapPressed,
                trailingGap: fields[i].trailingGap,

                // Apariencia
                iconSize: fields[i].iconSize,
                iconBoxSize: fields[i].iconBoxSize,
                iconRadius: fields[i].iconRadius,
                tileVerticalPadding: fields[i].tileVerticalPadding,
              ),
              if (showDividers && i != fields.length - 1)
                const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }
}

/// Fila con bloque de ícono + (opcional) etiqueta arriba + input debajo.
/// Integra:
///  • Botón “Mapa” (solo si el campo tiene foco y showMapOnFocus=true)
///  • Ícono “X” (solo si hay texto; limpia el campo)
class LabelInputTile extends StatefulWidget {
  const LabelInputTile({
    super.key,
    required this.icon,
    required this.iconContainerColor,
    this.label = '',
    this.placeholder = '',
    this.controller,
    this.onChanged,
    this.onTap,

    // Apariencia
    this.iconSize = 26,
    this.iconBoxSize = 52,
    this.iconRadius = 16,
    this.spacingBetweenLabelAndInput = 8,
    this.tileVerticalPadding = 10,

    // Interactividad
    this.focusNode,
    this.showMapOnFocus = false,
    this.mapLabel = 'Mapa',
    this.onMapPressed,
    this.trailingGap = 6,
  });

  // Contenido
  final String label;
  final String placeholder;
  final IconData icon;
  final Color iconContainerColor;

  // Control
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;

  // Apariencia
  final double iconSize;
  final double iconBoxSize;
  final double iconRadius;
  final double spacingBetweenLabelAndInput;
  final double tileVerticalPadding;

  // Interactividad
  final FocusNode? focusNode;
  final bool showMapOnFocus;
  final String mapLabel;
  final VoidCallback? onMapPressed;
  final double trailingGap;

  @override
  State<LabelInputTile> createState() => _LabelInputTileState();
}

class _LabelInputTileState extends State<LabelInputTile> {
  late final TextEditingController _ctrl =
      widget.controller ?? TextEditingController();
  late final FocusNode _focus = widget.focusNode ?? FocusNode();

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_tick);
    _focus.addListener(_tick);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_tick);
    _focus.removeListener(_tick);
    if (widget.controller == null) _ctrl.dispose();
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  // ⬇️ NUEVO: pedir foco al tocar en cualquier parte del tile
  void _requestFocus() {
    FocusScope.of(context).requestFocus(_focus);
  }

  @override
  Widget build(BuildContext context) {
    final hasLabel = widget.label.trim().isNotEmpty;
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: Colors.grey[600],
      fontWeight: FontWeight.w600,
    );

    final hasText = _ctrl.text.isNotEmpty;
    final isFocused = _focus.hasFocus;

    return GestureDetector(
      behavior: HitTestBehavior.opaque, // toda el área es tocable
      onTap: _requestFocus, // al tocar, enfoca y abre teclado
      child: Padding(
        // aumenta/disminuye la altura “táctil”
        padding: EdgeInsets.symmetric(vertical: widget.tileVerticalPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Ícono a la izquierda (pastilla)
            Container(
              width: widget.iconBoxSize,
              height: widget.iconBoxSize,
              decoration: BoxDecoration(
                color: widget.iconContainerColor,
                borderRadius: BorderRadius.circular(widget.iconRadius),
              ),
              child: Icon(
                widget.icon,
                color: Colors.white,
                size: widget.iconSize,
              ),
            ),
            const SizedBox(width: 12),

            // Columna con label + input + acciones
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasLabel) Text(widget.label, style: labelStyle),
                  if (hasLabel)
                    SizedBox(height: widget.spacingBetweenLabelAndInput),

                  Row(
                    children: [
                      // TextField expandible
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          focusNode: _focus,
                          readOnly: widget.onTap != null,
                          onTap: widget.onTap,
                          onChanged: widget.onChanged,
                          decoration: InputDecoration(
                            hintText: widget.placeholder,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                          ),
                          style: const TextStyle(fontSize: 16, height: 1.2),
                        ),
                      ),

                      // X para limpiar (solo si hay texto)
                      if (hasText)
                        IconButton(
                          tooltip: 'Borrar',
                          onPressed: () {
                            _ctrl.clear();
                            widget.onChanged?.call('');
                            _requestFocus(); // mantener teclado abierto tras borrar
                          },
                          icon: Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: Colors.grey.shade700,
                          ),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),

                      // Separación pequeña entre X y Mapa (cuando ambos aparecen)
                      if (hasText && widget.showMapOnFocus && isFocused)
                        SizedBox(width: widget.trailingGap),

                      // Botón "Mapa" (solo si el campo está enfocado y está habilitado)
                      if (widget.showMapOnFocus && isFocused)
                        _MapaChip(
                          label: widget.mapLabel,
                          onTap: widget.onMapPressed,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón “Mapa” estilo chip/pastilla
class _MapaChip extends StatelessWidget {
  const _MapaChip({required this.onTap, this.label = 'Mapa'});

  final VoidCallback? onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
    );
  }
}

/* Ejemplo de uso:  [Sebas]
body: Column(
  children: [

Padding(
  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
  child: Buscador(
    fields: const [
      BuscadorField(
        label: 'Buscar Cliente',
        placeholder: 'Buscar Cliente',
        icon: Icons.search,
        iconContainerColor: Color(0xFF2a5298),
      ),
      BuscadorField(
        label: 'Buscar Carnet',
        placeholder: 'Buscar Carnet',
        icon: Icons.badge,
        iconContainerColor: Color(0xFF2a5298),
      ),
    ],
  ),
),
*/

/* Buscador funcionando internamente
final _searchCtrl = TextEditingController(); //🔔
final List<Map<String, dynamic>> base = [ //🔔 base lista


  @override
  void dispose() {
    _searchCtrl.dispose(); //🔔
    super.dispose();
  }

final lista = filtrarMapasPorCampos(
  base,
  query,
  campos: ['cliente', 'telefono', 'carnet', 'estadoTexto', 'creadoPor'],
); //🔔
...
Padding(
  padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
  child: Buscador(
    fields: [
      BuscadorField(
        placeholder: 'Buscar Cliente, ej: "María", "61234567", "LP"',
        icon: Icons.search,
        iconContainerColor: const Color(0xFF2a5298),
        controller: _searchCtrl, //🔔
        onChanged: (_) => setState(() {}), //🔔
      ),
    ],
  ),
),
*/

/* Ejemplo de uso:
body: Column(
  children: [

Padding(
  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
  child: Buscador(
    fields: const [
      BuscadorField(
        label: 'Buscar Cliente',
        placeholder: 'Buscar Cliente',
        icon: Icons.search,
        iconContainerColor: Color(0xFF2a5298),
      ),
      BuscadorField(
        label: 'Buscar Carnet',
        placeholder: 'Buscar Carnet',
        icon: Icons.badge,
        iconContainerColor: Color(0xFF2a5298),
      ),
    ],
  ),
),
*/

/* Buscador funcionando internamente
final _searchCtrl = TextEditingController(); //🔔
final List<Map<String, dynamic>> base = [ //🔔 base lista


  @override
  void dispose() {
    _searchCtrl.dispose(); //🔔
    super.dispose();
  }

final lista = filtrarMapasPorCampos(
  base,
  query,
  campos: ['cliente', 'telefono', 'carnet', 'estadoTexto', 'creadoPor'],
); //🔔
...
Padding(
  padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
  child: Buscador(
    fields: [
      BuscadorField(
        placeholder: 'Buscar Cliente, ej: "María", "61234567", "LP"',
        icon: Icons.search,
        iconContainerColor: const Color(0xFF2a5298),
        controller: _searchCtrl, //🔔
        onChanged: (_) => setState(() {}), //🔔
      ),
    ],
  ),
),
*/

/*
BuscadorField(
                        label: 'Punto de partida',
                        placeholder: '¿Desde dónde?',
                        icon: Icons.near_me,
                        iconContainerColor: const Color.fromARGB(
                          255,
                          0,
                          195,
                          255,
                        ),
                        controller: _origenCtrl,
                        focusNode: _origenFocus,
                        showMapOnFocus: true,
                        mapLabel: 'Mapa',
                        onMapPressed: () async {
                          FocusScope.of(context).unfocus();
                          final result = await Cargando.run(
                            context,
                            message: 'Redirigiendo al mapa...',
                            task: () async {
                              // ← aquí abrimos el mapa en modo ORIGEN
                              return await MiUbicacion.abrirMapaOrigen(
                                context,
                                tituloPaso1: 'Marcar dirección',
                              );
                            },
                          );

                          // ⬇️ Guarda dirección y coordenadas si el mapa devolvió un Map
                          if (result is Map) {
                            setState(() {
                              _origenCtrl.text =
                                  (result['direccion'] as String?) ??
                                  _origenCtrl.text;
                              _origenLat = (result['lat'] as num?)?.toDouble();
                              _origenLng = (result['lng'] as num?)?.toDouble();
                            });
                          } else if (result is String && result.isNotEmpty) {
                            // Compat: si solo devolvió el texto
                            setState(() {
                              _origenCtrl.text = result;
                              // _origenLat/_origenLng quedan como estaban (por ejemplo, GPS).
                            });
                          }
                        },
                        onChanged: (_) => setState(() {}),
                      ),
*/
