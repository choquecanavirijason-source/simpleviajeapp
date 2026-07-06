import 'package:flutter/material.dart';
import 'package:buses2/shared/widgets/inputs/input_number.dart';
import 'package:buses2/shared/widgets/cajas/caja_contenedora/caja_contenedora.dart';
import 'package:buses2/shared/widgets/botones/boton.dart';

/// Tarjeta reutilizable de "Tramo":
/// - Título opcional arriba
/// - Dos NumberInput2 en 2 columnas
/// - Botón eliminar en el rincón derecho, centrado verticalmente, fondo gris circular
enum TramoMode { inputs, horas }

class TramoRowCard extends StatelessWidget {
  // ===== Fábrica: modo INPUTS (controllers vienen de la page) =====
  factory TramoRowCard.inputs({
    Key? key,
    String? title,
    required NumberEditingController leftController,
    required NumberEditingController rightController,
    required VoidCallback onRemove,
    String leftLabel = 'Desde (km)',
    String rightLabel = 'Precio (USD)',
    String leftPlaceholder = '0.00',
    String rightPlaceholder = '0.00',
    IconData leftIcon = Icons.straighten,
    IconData rightIcon = Icons.attach_money,
    bool allowDecimalLeft = true,
    bool allowDecimalRight = true,
    int decimalPlacesLeft = 2,
    int decimalPlacesRight = 2,
    Color backgroundColor = Colors.white,
    Color? borderColor,
    double borderRadius = 12,
  }) {
    return TramoRowCard._(
      key: key,
      mode: TramoMode.inputs,
      title: title,
      onRemove: onRemove,
      // inputs
      leftController: leftController,
      rightController: rightController,
      leftLabel: leftLabel,
      rightLabel: rightLabel,
      leftPlaceholder: leftPlaceholder,
      rightPlaceholder: rightPlaceholder,
      leftIcon: leftIcon,
      rightIcon: rightIcon,
      allowDecimalLeft: allowDecimalLeft,
      allowDecimalRight: allowDecimalRight,
      decimalPlacesLeft: decimalPlacesLeft,
      decimalPlacesRight: decimalPlacesRight,
      // ui
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      borderRadius: borderRadius,
    );
  }

  // ===== Fábrica: modo HORAS =====
  factory TramoRowCard.horas({
    Key? key,
    String? title,
    required VoidCallback onRemove,
    required TimeOfDay desde,
    required TimeOfDay hasta,
    ValueChanged<TimeOfDay>? onDesdeChanged,
    ValueChanged<TimeOfDay>? onHastaChanged,
    String labelDesde = 'Desde',
    String labelHasta = 'Hasta',
    Color backgroundColor = Colors.white,
    Color? borderColor,
    double borderRadius = 12,
  }) {
    return TramoRowCard._(
      key: key,
      mode: TramoMode.horas,
      title: title,
      onRemove: onRemove,
      // horas
      desde: desde,
      hasta: hasta,
      onDesdeChanged: onDesdeChanged,
      onHastaChanged: onHastaChanged,
      labelDesde: labelDesde,
      labelHasta: labelHasta,
      // ui
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      borderRadius: borderRadius,
    );
  }

  const TramoRowCard._({
    super.key,
    required this.mode,
    this.title,
    required this.onRemove,

    // inputs
    this.leftController,
    this.rightController,
    this.leftLabel = 'Campo A',
    this.rightLabel = 'Campo B',
    this.leftPlaceholder = '0.00',
    this.rightPlaceholder = '0.00',
    this.leftIcon = Icons.straighten,
    this.rightIcon = Icons.attach_money,
    this.allowDecimalLeft = true,
    this.allowDecimalRight = true,
    this.decimalPlacesLeft = 2,
    this.decimalPlacesRight = 2,

    // horas
    this.desde,
    this.hasta,
    this.onDesdeChanged,
    this.onHastaChanged,
    this.labelDesde = 'Desde',
    this.labelHasta = 'Hasta',

    // ui
    this.backgroundColor = Colors.white,
    this.borderColor,
    this.borderRadius = 12,
  });

  final TramoMode mode;
  final String? title;
  final VoidCallback onRemove;

  // Inputs
  final NumberEditingController? leftController;
  final NumberEditingController? rightController;
  final String leftLabel;
  final String rightLabel;
  final String leftPlaceholder;
  final String rightPlaceholder;
  final IconData leftIcon;
  final IconData rightIcon;
  final bool allowDecimalLeft;
  final bool allowDecimalRight;
  final int decimalPlacesLeft;
  final int decimalPlacesRight;

  // Horas
  final TimeOfDay? desde;
  final TimeOfDay? hasta;
  final ValueChanged<TimeOfDay>? onDesdeChanged;
  final ValueChanged<TimeOfDay>? onHastaChanged;
  final String labelDesde;
  final String labelHasta;

  // UI
  final Color backgroundColor;
  final Color? borderColor;
  final double borderRadius;

  bool get _showTitle => (title != null && title!.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    assert(
      mode == TramoMode.inputs
          ? (leftController != null && rightController != null)
          : (desde != null && hasta != null),
      'Parámetros obligatorios faltantes para el modo seleccionado.',
    );

    final bc = borderColor ?? Colors.grey.shade300;

    final Widget content = (mode == TramoMode.inputs)
        ? TramoInputsRow(
            leftController: leftController!,
            rightController: rightController!,
            leftLabel: leftLabel,
            rightLabel: rightLabel,
            leftPlaceholder: leftPlaceholder,
            rightPlaceholder: rightPlaceholder,
            leftIcon: leftIcon,
            rightIcon: rightIcon,
            allowDecimalLeft: allowDecimalLeft,
            allowDecimalRight: allowDecimalRight,
            decimalPlacesLeft: decimalPlacesLeft,
            decimalPlacesRight: decimalPlacesRight,
            gap: 12,
          )
        : FranjaHorariaRow(
            labelDesde: labelDesde,
            labelHasta: labelHasta,
            initialDesde: desde!,
            initialHasta: hasta!,
            onDesdeChanged: onDesdeChanged,
            onHastaChanged: onHastaChanged,
          );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: bc),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showTitle) ...[
            Text(title!, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(child: content),
              const SizedBox(width: 5),
              SizedBox(
                width: 33,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 18, 0, 0),
                  child: Material(
                    color: Colors.grey.shade300,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onRemove,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.delete_outline,
                          size: 22,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ====================== SECCIÓN MODULAR ===========================
class TramoSection extends StatefulWidget {
  // -------- FÁBRICA: INPUTS --------
  factory TramoSection.inputs({
    Key? key,
    required String boxTitle,
    required IconData boxIconTitle,
    required IconData boxIconRight,
    String? introText,
    String? emptyText,
    String addButtonLabel = 'Agregar tramo',
    String rowTitlePrefix = 'Tramo',
    // Config de inputs
    String leftLabel = 'Desde (km)',
    String rightLabel = 'Precio (USD)',
    String leftPlaceholder = '0.00',
    String rightPlaceholder = '0.00',
    IconData leftIcon = Icons.straighten,
    IconData rightIcon = Icons.attach_money,
    bool allowDecimalLeft = true,
    bool allowDecimalRight = true,
    int decimalPlacesLeft = 2,
    int decimalPlacesRight = 2,
    // ✅ tramos por defecto (solo inputs)
    List<(String left, String right)>? initialTramos,
    // Helpers
    Widget? helperTop,
    Widget? helperBottom,
    // Callback
    ValueChanged<List<(String left, String right)>>? onChange,
  }) {
    return TramoSection._(
      key: key,
      mode: TramoMode.inputs,
      boxTitle: boxTitle,
      boxIconTitle: boxIconTitle,
      boxIconRight: boxIconRight,
      introText: introText,
      emptyText: emptyText ?? 'No hay tramos. Toca "Agregar tramo".',
      addButtonLabel: addButtonLabel,
      rowTitlePrefix: rowTitlePrefix,
      // inputs
      leftLabel: leftLabel,
      rightLabel: rightLabel,
      leftPlaceholder: leftPlaceholder,
      rightPlaceholder: rightPlaceholder,
      leftIcon: leftIcon,
      rightIcon: rightIcon,
      allowDecimalLeft: allowDecimalLeft,
      allowDecimalRight: allowDecimalRight,
      decimalPlacesLeft: decimalPlacesLeft,
      decimalPlacesRight: decimalPlacesRight,
      // horas (no aplica)
      labelDesde: 'Desde',
      labelHasta: 'Hasta',
      // helpers
      helperTop: helperTop,
      helperBottom: helperBottom,
      // defaults & callback
      initialTramos: initialTramos,
      onChangeInputs: onChange,
    );
  }

  // -------- FÁBRICA: HORAS --------
  factory TramoSection.horas({
    Key? key,
    required String boxTitle,
    required IconData boxIconTitle,
    required IconData boxIconRight,
    String? introText,
    String? emptyText,
    String addButtonLabel = 'Agregar franja',
    String rowTitlePrefix = 'Hora Pico',
    String labelDesde = 'Desde',
    String labelHasta = 'Hasta',
    Widget? helperTop,
    Widget? helperBottom,
    // ✅ franjas por defecto (solo horas)
    List<({TimeOfDay desde, TimeOfDay hasta})>? initialFranjas,
    // Callback
    ValueChanged<List<({TimeOfDay desde, TimeOfDay hasta})>>? onChange,
  }) {
    return TramoSection._(
      key: key,
      mode: TramoMode.horas,
      boxTitle: boxTitle,
      boxIconTitle: boxIconTitle,
      boxIconRight: boxIconRight,
      introText: introText,
      emptyText: emptyText ?? 'No hay horas pico. Toca "Agregar franja".',
      addButtonLabel: addButtonLabel,
      rowTitlePrefix: rowTitlePrefix,
      // horas
      labelDesde: labelDesde,
      labelHasta: labelHasta,
      // inputs (no aplica)
      leftLabel: 'Campo A',
      rightLabel: 'Campo B',
      leftPlaceholder: '0.00',
      rightPlaceholder: '0.00',
      leftIcon: Icons.straighten,
      rightIcon: Icons.attach_money,
      allowDecimalLeft: true,
      allowDecimalRight: true,
      decimalPlacesLeft: 2,
      decimalPlacesRight: 2,
      // helpers
      helperTop: helperTop,
      helperBottom: helperBottom,
      // defaults & callback
      initialFranjas: initialFranjas,
      onChangeHoras: onChange,
    );
  }

  const TramoSection._({
    super.key,
    required this.mode,
    // CajaContenedora
    required this.boxTitle,
    required this.boxIconTitle,
    required this.boxIconRight,
    this.introText,
    required this.emptyText,
    required this.addButtonLabel,
    required this.rowTitlePrefix,
    // Inputs
    required this.leftLabel,
    required this.rightLabel,
    required this.leftPlaceholder,
    required this.rightPlaceholder,
    required this.leftIcon,
    required this.rightIcon,
    required this.allowDecimalLeft,
    required this.allowDecimalRight,
    required this.decimalPlacesLeft,
    required this.decimalPlacesRight,
    // Horas
    required this.labelDesde,
    required this.labelHasta,
    // Helpers
    this.helperTop,
    this.helperBottom,
    // Callbacks
    this.onChangeInputs,
    this.onChangeHoras,
    // Defaults opcionales
    this.initialFranjas, // solo HORAS
    this.initialTramos, // solo INPUTS
  });
  final TramoMode mode;
  // Caja
  final String boxTitle;
  final IconData boxIconTitle;
  final IconData boxIconRight;
  final String? introText;
  final String emptyText;
  final String addButtonLabel;
  final String rowTitlePrefix;

  // Inputs
  final String leftLabel;
  final String rightLabel;
  final String leftPlaceholder;
  final String rightPlaceholder;
  final IconData leftIcon;
  final IconData rightIcon;
  final bool allowDecimalLeft;
  final bool allowDecimalRight;
  final int decimalPlacesLeft;
  final int decimalPlacesRight;

  // Horas
  final String labelDesde;
  final String labelHasta;

  // Helpers
  final Widget? helperTop;
  final Widget? helperBottom;

  // Callbacks
  final ValueChanged<List<(String left, String right)>>? onChangeInputs;
  final ValueChanged<List<({TimeOfDay desde, TimeOfDay hasta})>>? onChangeHoras;

  // ✅ Defaults (opcionales)
  final List<({TimeOfDay desde, TimeOfDay hasta})>?
  initialFranjas; // solo para horas
  final List<(String left, String right)>? initialTramos;

  @override
  State<TramoSection> createState() => _TramoSectionState();
}

class _TramoCtrlsInternal {
  final NumberEditingController left;
  final NumberEditingController right;
  _TramoCtrlsInternal({
    required bool allowLeft,
    required int decLeft,
    required bool allowRight,
    required int decRight,
  }) : left = NumberEditingController(
         allowDecimal: allowLeft,
         decimalPlaces: decLeft,
       ),
       right = NumberEditingController(
         allowDecimal: allowRight,
         decimalPlaces: decRight,
       );
  void dispose() {
    left.dispose();
    right.dispose();
  }
}

class _TramoSectionState extends State<TramoSection> {
  // Lista interna según modo
  final List<_TramoCtrlsInternal> _tramos = []; // inputs
  final List<({TimeOfDay desde, TimeOfDay hasta})> _franjas = []; // horas

  @override
  void initState() {
    super.initState();
    // ✅ Defaults para HORAS
    if (widget.mode == TramoMode.horas && widget.initialFranjas != null) {
      _franjas.addAll(widget.initialFranjas!);
      WidgetsBinding.instance.addPostFrameCallback((_) => _emitChange());
    }
    // ✅ Defaults para INPUTS
    if (widget.mode == TramoMode.inputs && widget.initialTramos != null) {
      for (final (left, right) in widget.initialTramos!) {
        final ctrl = _TramoCtrlsInternal(
          allowLeft: widget.allowDecimalLeft,
          decLeft: widget.decimalPlacesLeft,
          allowRight: widget.allowDecimalRight,
          decRight: widget.decimalPlacesRight,
        );
        ctrl.left.text = left;
        ctrl.right.text = right;

        // 👉 importantísimo: escuchar cambios para emitir onChange al tipear
        ctrl.left.addListener(_emitChange);
        ctrl.right.addListener(_emitChange);

        _tramos.add(ctrl);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _emitChange());
    }
  }

  @override
  void dispose() {
    for (final t in _tramos) t.dispose();
    super.dispose();
  }

  void _emitChange() {
    if (widget.mode == TramoMode.inputs && widget.onChangeInputs != null) {
      widget.onChangeInputs!.call(
        _tramos.map((e) => (e.left.text, e.right.text)).toList(),
      );
    } else if (widget.mode == TramoMode.horas && widget.onChangeHoras != null) {
      widget.onChangeHoras!.call(List.of(_franjas));
    }
  }

  void _addItem() {
    setState(() {
      if (widget.mode == TramoMode.inputs) {
        final item = _TramoCtrlsInternal(
          allowLeft: widget.allowDecimalLeft,
          decLeft: widget.decimalPlacesLeft,
          allowRight: widget.allowDecimalRight,
          decRight: widget.decimalPlacesRight,
        );

        // 👉 escuchar cambios del usuario
        item.left.addListener(_emitChange);
        item.right.addListener(_emitChange);

        _tramos.add(item);
      } else {
        _franjas.add((
          desde: const TimeOfDay(hour: 12, minute: 0),
          hasta: const TimeOfDay(hour: 16, minute: 0),
        ));
      }
    });
    _emitChange();
  }

  void _removeItem(int index) {
    setState(() {
      if (widget.mode == TramoMode.inputs) {
        final removed = _tramos.removeAt(index);
        removed.dispose();
      } else {
        _franjas.removeAt(index);
      }
    });
    _emitChange();
  }

  @override
  Widget build(BuildContext context) {
    return CajaContenedora(
      titulo: widget.boxTitle,
      iconoTitulo: widget.boxIconTitle,
      tituloAlign: TituloAlign.center,
      iconoDerecha: widget.boxIconRight,
      padding: const EdgeInsets.all(16),
      borderRadius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.introText != null) ...[
            Text(
              widget.introText!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
          ],
          if (widget.helperTop != null) ...[
            widget.helperTop!,
            const SizedBox(height: 12),
          ],

          // ===== LISTA =====
          Builder(
            builder: (_) {
              final isEmpty = widget.mode == TramoMode.inputs
                  ? _tramos.isEmpty
                  : _franjas.isEmpty;
              if (isEmpty) {
                return Text(
                  widget.emptyText,
                  style: Theme.of(context).textTheme.bodyMedium,
                );
              }

              return Column(
                children: List.generate(
                  widget.mode == TramoMode.inputs
                      ? _tramos.length
                      : _franjas.length,
                  (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: (widget.mode == TramoMode.inputs)
                          ? TramoRowCard.inputs(
                              title: '${widget.rowTitlePrefix} ${index + 1}',
                              leftController: _tramos[index].left,
                              rightController: _tramos[index].right,
                              leftLabel: widget.leftLabel,
                              rightLabel: widget.rightLabel,
                              leftPlaceholder: widget.leftPlaceholder,
                              rightPlaceholder: widget.rightPlaceholder,
                              leftIcon: widget.leftIcon,
                              rightIcon: widget.rightIcon,
                              allowDecimalLeft: widget.allowDecimalLeft,
                              allowDecimalRight: widget.allowDecimalRight,
                              decimalPlacesLeft: widget.decimalPlacesLeft,
                              decimalPlacesRight: widget.decimalPlacesRight,
                              onRemove: () => _removeItem(index),
                            )
                          : TramoRowCard.horas(
                              title: '${widget.rowTitlePrefix} ${index + 1}',
                              desde: _franjas[index].desde,
                              hasta: _franjas[index].hasta,
                              labelDesde: widget.labelDesde,
                              labelHasta: widget.labelHasta,
                              onDesdeChanged: (t) {
                                setState(
                                  () => _franjas[index] = (
                                    desde: t,
                                    hasta: _franjas[index].hasta,
                                  ),
                                );
                                _emitChange();
                              },
                              onHastaChanged: (t) {
                                setState(
                                  () => _franjas[index] = (
                                    desde: _franjas[index].desde,
                                    hasta: t,
                                  ),
                                );
                                _emitChange();
                              },
                              onRemove: () => _removeItem(index),
                            ),
                    );
                  },
                ),
              );
            },
          ),

          const SizedBox(height: 10),

          // ===== Botón Agregar =====
          Boton1(
            label: widget.addButtonLabel,
            color: BotonColor.color1,
            borde: BotonBorde.borde1,
            iconoIzquierdo: Icons.add,
            iconoDerecho: Icons.add,
            onPressed: _addItem,
          ),

          if (widget.helperBottom != null) ...[
            const SizedBox(height: 8),
            const Divider(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 18),
                const SizedBox(width: 8),
                Expanded(child: widget.helperBottom!),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/* Ejemplo de uso:
TramoSection.inputs( // horas | inputs
  boxTitle: 'Tarifa Aeropuerto por distancia',
  boxIconTitle: Icons.flight_takeoff,
  boxIconRight: Icons.attach_money,
  introText: 'Configura el precio del traslado al aeropuerto por tramos de distancia. '
             'Ej.: ≤10 km → 40; >10 y ≤20 km → 60.',
  rowTitlePrefix: 'Tramo',
  leftLabel: 'Desde (km)',
  rightLabel: 'Precio (USD)',
  initialFranjas: _horasPicoDefault,
  leftPlaceholder: '0.00',
  rightPlaceholder: '0.00',
  helperTop: Text(
    'Consejo: ordena los tramos por km ascendente (10, 20, 30…). '
    'La validación y el cálculo real del tramo aplicable la puedes '
    'agregar luego con tu lógica.',
    style: Theme.of(context).textTheme.bodySmall,
  ),
  helperBottom: Text(
    'Ejemplos: 23:00–05:00 (cruza medianoche) y 12:01–16:00. '
    'La lógica del recargo la agregas aparte.',
    style: Theme.of(context).textTheme.bodySmall,
  ),
  // opcional: recibir lo que se va digitando
  onChange: (items) { // items para inputs | franjas para horas
    // items => List<(String left, String right)>
    // guarda en tu modelo si quieres
  },
),
*/

/*
TramoSection.inputs(
  boxTitle: 'Tarifa Aeropuerto por distancia',
  boxIconTitle: Icons.flight_takeoff,
  boxIconRight: Icons.attach_money,
  introText: 'Configura el precio del traslado al aeropuerto por tramos de distancia. '
             'Ej.: ≤10 km → 40; >10 y ≤20 km → 60.',
  rowTitlePrefix: 'Tramo',
  leftLabel: 'Desde (km)',
  rightLabel: 'Precio (ARS)',
  leftPlaceholder: '0.00',
  rightPlaceholder: '0.00',
  helperBottom: Text(
    'Consejo: ordena los tramos por km ascendente (10, 20, 30…). '
    'La validación y el cálculo real del tramo aplicable la puedes '
    'agregar luego con tu lógica.',
    style: Theme.of(context).textTheme.bodySmall,
  ),
  // opcional: recibir lo que se va digitando
  onChange: (items) {
    // items => List<(String left, String right)>
    // guarda en tu modelo si quieres
  },
),
*/

/*
final List<({TimeOfDay desde, TimeOfDay hasta})> _horasPicoDefault = [
  (desde: const TimeOfDay(hour: 7,  minute: 0),  hasta: const TimeOfDay(hour: 9,  minute: 0)),  // Mañana
  (desde: const TimeOfDay(hour: 12, minute: 0),  hasta: const TimeOfDay(hour: 14, minute: 0)),  // Mediodía
  (desde: const TimeOfDay(hour: 18, minute: 0),  hasta: const TimeOfDay(hour: 20, minute: 0)),  // Tarde
];
...
TramoSection.horas(
  boxTitle: 'Horas Pico',
  boxIconTitle: Icons.schedule,
  boxIconRight: Icons.trending_up,
  introText: 'Define las franjas horarias en las que se aplicará el recargo '
             'indicado en "Hora pico (extra)".',
  rowTitlePrefix: 'Hora Pico',
  labelDesde: 'Desde',
  labelHasta: 'Hasta',
  initialFranjas: _horasPicoDefault,
  helperBottom: Text(
    'Ejemplos: 23:00–05:00 (cruza medianoche) y 12:01–16:00. '
    'La lógica del recargo la agregas aparte.',
    style: Theme.of(context).textTheme.bodySmall,
  ),
  // opcional: recibir los cambios
  onChange: (franjas) {
    // franjas => List<({TimeOfDay desde, TimeOfDay hasta})>
  },
),
*/

//import 'package:flutter/material.dart';
//import 'package:buses2/shared/widgets/inputs/input_number.dart';

/// Solo la fila de 2 NumberInput2 (izq | der), reutilizable.
class TramoInputsRow extends StatelessWidget {
  const TramoInputsRow({
    super.key,
    required this.leftController,
    required this.rightController,
    this.leftLabel = 'Campo A',
    this.rightLabel = 'Campo B',
    this.leftPlaceholder = '0.00',
    this.rightPlaceholder = '0.00',
    this.leftIcon = Icons.straighten,
    this.rightIcon = Icons.attach_money,
    this.allowDecimalLeft = true,
    this.allowDecimalRight = true,
    this.decimalPlacesLeft = 2,
    this.decimalPlacesRight = 2,
    this.gap = 12,
  });

  final NumberEditingController leftController;
  final NumberEditingController rightController;

  final String leftLabel;
  final String rightLabel;
  final String leftPlaceholder;
  final String rightPlaceholder;
  final IconData leftIcon;
  final IconData rightIcon;
  final bool allowDecimalLeft;
  final bool allowDecimalRight;
  final int decimalPlacesLeft;
  final int decimalPlacesRight;

  /// espacio entre inputs
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: NumberInput2(
            controller: leftController,
            label: leftLabel,
            placeholder: leftPlaceholder,
            prefixIcon: leftIcon,
            allowDecimal: allowDecimalLeft,
            decimalPlaces: decimalPlacesLeft,
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          child: NumberInput2(
            controller: rightController,
            label: rightLabel,
            placeholder: rightPlaceholder,
            prefixIcon: rightIcon,
            allowDecimal: allowDecimalRight,
            decimalPlaces: decimalPlacesRight,
          ),
        ),
      ],
    );
  }
}

/// Fila reutilizable: [Desde HH:mm] | [Hasta HH:mm]
/// - Abre showTimePicker en 24h
/// - Emite cambios vía callbacks
class FranjaHorariaRow extends StatefulWidget {
  const FranjaHorariaRow({
    super.key,
    this.labelDesde = 'Desde',
    this.labelHasta = 'Hasta',
    this.initialDesde,
    this.initialHasta,
    this.onDesdeChanged,
    this.onHastaChanged,
    this.gap = 12,
    this.icon = Icons.access_time_filled,
  });

  final String labelDesde;
  final String labelHasta;
  final TimeOfDay? initialDesde;
  final TimeOfDay? initialHasta;
  final ValueChanged<TimeOfDay>? onDesdeChanged;
  final ValueChanged<TimeOfDay>? onHastaChanged;
  final double gap;
  final IconData icon;

  @override
  State<FranjaHorariaRow> createState() => _FranjaHorariaRowState();
}

class _FranjaHorariaRowState extends State<FranjaHorariaRow> {
  late TimeOfDay _desde =
      widget.initialDesde ?? const TimeOfDay(hour: 0, minute: 0);
  late TimeOfDay _hasta =
      widget.initialHasta ?? const TimeOfDay(hour: 0, minute: 0);

  Future<void> _pick({
    required bool isDesde,
    required TimeOfDay initial,
  }) async {
    final ctx = context;
    final picked = await showTimePicker(
      context: ctx,
      initialTime: initial,
      helpText: 'Seleccionar hora',
      initialEntryMode: TimePickerEntryMode.dial,
      builder: (context, child) {
        // Forzar 24h
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isDesde) {
          _desde = picked;
          widget.onDesdeChanged?.call(_desde);
        } else {
          _hasta = picked;
          widget.onHastaChanged?.call(_hasta);
        }
      });
    }
  }

  String _fmt(TimeOfDay t) {
    // Siempre 24h: HH:mm
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Widget _timeTile({
    required String label,
    required TimeOfDay value,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 20, color: Colors.blueAccent),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _fmt(value),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _timeTile(
          label: widget.labelDesde,
          value: _desde,
          onTap: () => _pick(isDesde: true, initial: _desde),
        ),
        SizedBox(width: widget.gap),
        _timeTile(
          label: widget.labelHasta,
          value: _hasta,
          onTap: () => _pick(isDesde: false, initial: _hasta),
        ),
      ],
    );
  }
}
