import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:buses2/shared/widgets/botones/boton.dart';
import 'package:buses2/shared/widgets/botones/boton_desactivado.dart';

class TarifaControlCard extends StatefulWidget {
  final String servicio;
  final double precioRecomendado;

  /// MODO CONTROLADO: si provees [valor], el padre controla el estado.
  /// MODO NO CONTROLADO: deja [valor] en null y pasa [initialValue].
  final num? valor;
  final num initialValue;

  /// Notifica cada cambio (en ambos modos)
  final ValueChanged<num>? onChanged;

  // Opcionales
  final num step;
  final num min;
  final num max;
  final String moneda;
  final bool compacto;
  final Color? accentColor;
  final bool? boton;
  final VoidCallback? onBotonPressed;
  final String botonLabel;
  // ⬇️ NUEVOS (habilitar/deshabilitar + íconos del botón)
  final bool? botonHabilitado; // null o false => desactivado visualmente
  final IconData? botonIconoIzq;
  final IconData? botonIconoDer;

  const TarifaControlCard({
    super.key,
    required this.servicio,
    required this.precioRecomendado,
    this.valor, // ← si lo usas, es modo controlado
    this.initialValue = 0, // ← se usa si [valor] es null
    this.onChanged,
    this.step = 1,
    this.min = 0,
    this.max = 9999,
    this.moneda = 'ARS',
    this.compacto = false,
    this.accentColor,
    this.boton,
    this.onBotonPressed,
    this.botonLabel = 'Continuar',
    this.botonHabilitado,
    this.botonIconoIzq,
    this.botonIconoDer,
  });

  @override
  State<TarifaControlCard> createState() => _TarifaControlCardState();
}

class _TarifaControlCardState extends State<TarifaControlCard> {
  late num _value; // solo se usa en modo NO controlado

  bool get _isControlled => widget.valor != null;
  num get _current => _isControlled ? widget.valor! : _value;

  @override
  void initState() {
    super.initState();
    _value = _clamp(widget.valor ?? widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant TarifaControlCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isControlled && widget.valor != oldWidget.valor) {
      _value = _clamp(widget.valor!);
    }
    if (!_isControlled &&
        (widget.min != oldWidget.min || widget.max != oldWidget.max)) {
      _value = _clamp(_value);
    }
  }

  num _clamp(num v) {
    if (v < widget.min) return widget.min;
    if (v > widget.max) return widget.max;
    return v;
  }

  void _set(num v) {
    final next = _clamp(v);
    if (!_isControlled) setState(() => _value = next);
    widget.onChanged?.call(next);
  }

  void _dec() => _set(_current - widget.step);
  void _inc() => _set(_current + widget.step);

  Future<void> _editarTarifa() async {
    final controller = TextEditingController(text: _formatNum(_current));
    final result = await showDialog<num>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Editar tarifa'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              prefixText: '${widget.moneda} ',
              hintText: 'Ingresa un valor',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            TextButton(
              child: const Text('Guardar'),
              onPressed: () {
                final raw = controller.text.trim().replaceAll(',', '.');
                final parsed = num.tryParse(raw);
                if (parsed == null) return; // no cerrar si no es número
                final clamped = _clamp(parsed);
                Navigator.pop<num>(ctx, clamped);
              },
            ),
          ],
        );
      },
    );
    if (result != null) _set(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1F2225) : Colors.white;
    final border = isDark ? Colors.white10 : const Color(0xFFE8E8E8);
    final subtle = theme.textTheme.bodySmall?.color?.withOpacity(0.70);

    final btnSize = widget.compacto ? 40.0 : 48.0;
    final fontMain = widget.compacto ? 22.0 : 26.0;
    final fontNum = widget.compacto ? 20.0 : 22.0;

    final Color c = widget.accentColor ?? theme.colorScheme.primary;

    final canDec = (_current - widget.step) >= widget.min;
    final canInc = (_current + widget.step) <= widget.max;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado
          Row(
            children: [
              Icon(Icons.local_offer_rounded, size: 18, color: c),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.servicio,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: fontMain,
                    height: 1.05,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Precio recomendado: ${widget.moneda} ${widget.precioRecomendado.toStringAsFixed(2)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: subtle,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),

          // Control [-]  [CAJA EDITABLE]  [+]
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _RoundIconButton(
                icon: Icons.remove_rounded,
                size: btnSize,
                color: c,
                onTap: canDec ? _dec : null,
              ),

              // === CAJA EDITABLE ===
              InkWell(
                onTap: _editarTarifa,
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      constraints: const BoxConstraints(minWidth: 140),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c, width: 1.5),
                        color: c.withOpacity(0.06),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${widget.moneda} ${_formatNum(_current)}',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              fontSize: fontNum,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Lápiz en esquina superior derecha
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.10),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(2),
                        child: Icon(Icons.edit, size: 16, color: c),
                      ),
                    ),
                  ],
                ),
              ),

              _RoundIconButton(
                icon: Icons.add_rounded,
                size: btnSize,
                color: c,
                onTap: canInc ? _inc : null,
              ),
            ],
          ),
          if (widget.boton == true) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child:
                  (widget.botonHabilitado == true &&
                      widget.onBotonPressed != null)
                  ? Boton1(
                      label: widget.botonLabel,
                      color: BotonColor.color2,
                      borde: BotonBorde.borde1,
                      iconoIzquierdo: widget.botonIconoIzq ?? Icons.upload_file,
                      iconoDerecho: widget.botonIconoDer ?? Icons.upload_file,
                      onPressed: widget.onBotonPressed,
                    )
                  : BotonDesactivado(
                      label: widget.botonLabel,
                      iconoIzquierdo: widget.botonIconoIzq ?? Icons.upload_file,
                      iconoDerecho: widget.botonIconoDer ?? Icons.upload_file,
                    ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatNum(num n) =>
      n % 1 == 0 ? n.toInt().toString() : n.toStringAsFixed(2);
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback? onTap;
  final Color color;

  const _RoundIconButton({
    required this.icon,
    required this.size,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final bg = enabled ? color.withOpacity(0.10) : color.withOpacity(0.06);
    final ic = enabled ? color : color.withOpacity(0.45);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: ic.withOpacity(0.20), width: 1),
          ),
          child: Icon(icon, color: ic, size: size * 0.55),
        ),
      ),
    );
  }
}

/* Ejemplo de uso:
TarifaControlCard(
  servicio: 'Taxi',            // 'Taxi', 'Moto taxi', etc.
  precioRecomendado: 12.5,      // recomendado
  //valor: 10, 
  valor: _tarifa,                      // valor actual
  moneda: 'ARS',
  step: 1,                              // o 0.5 si quieres decimales
  min: 0,
  max: 999,
  accentColor: Colors.red,
  onChanged: (v) => setState(() => _tarifa = v),
),
*/

//import 'package:flutter/foundation.dart';

class TarifaController extends ValueNotifier<num> {
  num min;
  num max;
  num step;

  TarifaController(num initial, {this.min = 0, this.max = 9999, this.step = 1})
    : super(initial);

  void inc() {
    final next = value + step;
    if (next <= max) value = next;
  }

  void dec() {
    final next = value - step;
    if (next >= min) value = next;
  }

  void setValue(num v) {
    if (v < min) v = min;
    if (v > max) v = max;
    value = v;
  }

  void configure({num? min, num? max, num? step}) {
    if (min != null) this.min = min;
    if (max != null) this.max = max;
    if (step != null) this.step = step;
    // Asegura que el valor actual siga dentro del rango
    setValue(value);
  }
}
