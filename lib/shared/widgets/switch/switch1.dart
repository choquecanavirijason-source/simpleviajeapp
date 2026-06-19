import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum Estado3 { ocupado, libre, suspendido }

class Switch1 extends StatefulWidget {
  const Switch1({
    super.key,
    // Controlado
    this.value,
    this.onChanged,
    // No controlado
    this.initialValue = Estado3.libre,

    // Visual
    this.height = 44,
    this.width, // si no se pasa, se calcula por contenido
    this.duration = const Duration(milliseconds: 220),
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.padding = const EdgeInsets.all(4),

    // Etiquetas
    this.labelOcupado = 'Ocupado',
    this.labelLibre = 'Libre',
    this.labelSuspendido = 'Suspendido',

    // Colores
    this.colorOcupado,
    this.colorLibre,
    this.colorSuspendido,
    this.textColorSelected,
    this.textColorUnselected,
    this.unselectedBgColor,
    this.borderColor,

    // Íconos (opcionales)
    this.iconOcupado = Icons.do_not_disturb_alt_rounded,
    this.iconLibre = Icons.check_circle_rounded,
    this.iconSuspendido = Icons.pause_circle_rounded,

    // Suspender
    this.onTapSuspendido,
    this.suspendidoTapSetsTo,
  });

  // Controlado
  final Estado3? value;
  final ValueChanged<Estado3>? onChanged;

  // No controlado
  final Estado3 initialValue;

  // Visual
  final double height;
  final double? width;
  final Duration duration;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;

  // Etiquetas
  final String labelOcupado;
  final String labelLibre;
  final String labelSuspendido;

  // Colores
  final Color? colorOcupado;
  final Color? colorLibre;
  final Color? colorSuspendido;
  final Color? textColorSelected;
  final Color? textColorUnselected;
  final Color? unselectedBgColor;
  final Color? borderColor;

  // Íconos
  final IconData? iconOcupado;
  final IconData? iconLibre;
  final IconData? iconSuspendido;

  // Suspender
  final VoidCallback? onTapSuspendido;
  final Estado3? suspendidoTapSetsTo;

  @override
  State<Switch1> createState() => _Switch1State();
}

class _Switch1State extends State<Switch1> {
  late Estado3 _value;
  bool get _isControlled => widget.value != null;

  @override
  void initState() {
    super.initState();
    _value = widget.value ?? widget.initialValue;
  }

  @override
  void didUpdateWidget(covariant Switch1 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isControlled) _value = widget.value!;
  }

  void _setValue(Estado3 v) {
    HapticFeedback.selectionClick();
    if (_isControlled) {
      widget.onChanged?.call(v);
    } else {
      setState(() => _value = v);
      widget.onChanged?.call(v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color ocupadoBg = widget.colorOcupado ?? Colors.red;
    final Color libreBg = widget.colorLibre ?? Colors.green;
    final Color suspendidoBg =
        widget.colorSuspendido ?? theme.colorScheme.secondaryContainer;

    final Color selectedFg = widget.textColorSelected ?? Colors.white;
    final Color unselectedFg =
        widget.textColorUnselected ??
        (theme.brightness == Brightness.dark ? Colors.white70 : Colors.black87);

    final Color baseBg = widget.unselectedBgColor ?? theme.colorScheme.surface;
    final Color borde = widget.borderColor ?? theme.colorScheme.outlineVariant;

    final textStyle = theme.textTheme.labelLarge?.copyWith(fontSize: 14);

    final double height = widget.height;
    final double minWidth = 220; // tamaño mínimo agradable
    final double width = widget.width ?? minWidth;

    // ----- Modo SUSPENDIDO -----
    if (_value == Estado3.suspendido) {
      return Semantics(
        label: 'Estado: ${widget.labelSuspendido}',
        button: true,
        child: ConstrainedBox(
          constraints: BoxConstraints.tightFor(height: height, width: width),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: baseBg,
              borderRadius: widget.borderRadius,
              border: Border.all(color: borde, width: 1),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: widget.borderRadius,
                onTap: () {
                  widget.onTapSuspendido?.call();
                  if (widget.suspendidoTapSetsTo != null) {
                    _setValue(widget.suspendidoTapSetsTo!);
                  }
                },
                child: AnimatedContainer(
                  duration: widget.duration,
                  margin: widget.padding,
                  decoration: BoxDecoration(
                    color: suspendidoBg,
                    borderRadius: BorderRadius.circular(height),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _Label(
                      icon: widget.iconSuspendido,
                      text: widget.labelSuspendido,
                      color: selectedFg,
                      style: textStyle,
                      bold: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // ----- Modo OCUPADO/LIBRE (segmented) -----
    final bool isOcupado = _value == Estado3.ocupado;

    return Semantics(
      label: 'Estado: ${isOcupado ? widget.labelOcupado : widget.labelLibre}',
      button: true,
      child: ConstrainedBox(
        constraints: BoxConstraints.tightFor(height: height, width: width),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: baseBg,
            borderRadius: widget.borderRadius,
            border: Border.all(color: borde, width: 1),
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              final double segmentWidth =
                  (c.maxWidth - widget.padding.horizontal) / 2;

              return Stack(
                children: [
                  // Thumb deslizante
                  AnimatedAlign(
                    alignment: isOcupado
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    duration: widget.duration,
                    curve: Curves.easeOutCubic,
                    child: Padding(
                      padding: widget.padding,
                      child: Container(
                        width: segmentWidth,
                        height: c.maxHeight - widget.padding.vertical,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(height),
                          // Gradiente sutil según estado
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isOcupado
                                ? [
                                    (widget.colorOcupado ?? Colors.red)
                                        .withOpacity(.95),
                                    (widget.colorOcupado ?? Colors.red)
                                        .withOpacity(.75),
                                  ]
                                : [
                                    (widget.colorLibre ?? Colors.green)
                                        .withOpacity(.95),
                                    (widget.colorLibre ?? Colors.green)
                                        .withOpacity(.75),
                                  ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.10),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Contenido tocheable
                  Row(
                    children: [
                      _SegmentButton(
                        width: segmentWidth,
                        height: c.maxHeight,
                        onTap: () => _setValue(Estado3.ocupado),
                        child: _Label(
                          icon: widget.iconOcupado,
                          text: widget.labelOcupado,
                          color: isOcupado ? selectedFg : unselectedFg,
                          style: textStyle,
                          bold: isOcupado,
                        ),
                      ),
                      _SegmentButton(
                        width: segmentWidth,
                        height: c.maxHeight,
                        onTap: () => _setValue(Estado3.libre),
                        child: _Label(
                          icon: widget.iconLibre,
                          text: widget.labelLibre,
                          color: !isOcupado ? selectedFg : unselectedFg,
                          style: textStyle,
                          bold: !isOcupado,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Botón de cada segmento (maneja ripple y focus)
class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.width,
    required this.height,
    required this.onTap,
    required this.child,
  });

  final double width;
  final double height;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(height),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// Etiqueta con icono opcional
class _Label extends StatelessWidget {
  const _Label({
    required this.text,
    required this.color,
    required this.style,
    this.icon,
    this.bold = false,
  });

  final String text;
  final Color color;
  final TextStyle? style;
  final IconData? icon;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final textWidget = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: (style ?? const TextStyle()).copyWith(
        color: color,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
        letterSpacing: .2,
      ),
    );

    if (icon == null) return textWidget;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        textWidget,
      ],
    );
  }
}

/*
Switch1(
  initialValue: Estado3.libre, // libre ocupado o suspendido
  onChanged: (v) {
    // opcional: reaccionas al cambio
  },
  onTapSuspendido: () {
    // por ejemplo: setState(() => estado = Estado3.libre);
  },

  // Personalización opcional:
  colorOcupado: Colors.red.shade300,
  colorLibre: Colors.green.shade300,
  colorSuspendido: Colors.blueGrey.shade200,
  textColorSelected: Colors.black87,
  unselectedBgColor: Theme.of(context).colorScheme.surface,
  borderColor: Theme.of(context).colorScheme.outlineVariant,
  onTapSuspendido: () => Estado3.libre,
),
*/
