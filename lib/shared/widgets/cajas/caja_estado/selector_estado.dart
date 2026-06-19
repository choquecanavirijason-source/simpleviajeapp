import 'package:flutter/material.dart';

class StatusOption {
  final String value; // "aprobado" | "en_revision" | "rechazado"
  final String label; // "Aprobado" | "En revisión" | "Rechazado"
  final Color color;
  final IconData icon;
  const StatusOption({
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
  });
}

class SelectorEstadoSimple extends StatefulWidget {
  const SelectorEstadoSimple({
    super.key,
    this.initialValue, // ej. "en_revision"
    this.onChanged, // callback con la opción elegida
    this.title = 'Estado del documento',
    this.useBottomSheet = true, // si false, usa popup anclado
    this.dense = false,
  });

  final String? initialValue;
  final ValueChanged<StatusOption>? onChanged;
  final String title;
  final bool useBottomSheet;
  final bool dense;

  /// Opciones por defecto internas
  static const List<StatusOption> defaultOptions = [
    StatusOption(
      value: 'aprobado',
      label: 'Aprobado',
      color: Colors.green,
      icon: Icons.check_circle_rounded,
    ),
    StatusOption(
      value: 'en_revision',
      label: 'En revisión',
      color: Colors.amber,
      icon: Icons.pending_actions_rounded,
    ),
    StatusOption(
      value: 'rechazado',
      label: 'Rechazado',
      color: Colors.red,
      icon: Icons.cancel_rounded,
    ),
  ];

  @override
  State<SelectorEstadoSimple> createState() => _SelectorEstadoSimpleState();
}

class _SelectorEstadoSimpleState extends State<SelectorEstadoSimple> {
  late StatusOption _selected;

  @override
  void initState() {
    super.initState();
    _selected =
        _findByValue(widget.initialValue) ??
        SelectorEstadoSimple.defaultOptions[1]; // por defecto: En revisión
  }

  StatusOption? _findByValue(String? v) {
    if (v == null) return null;
    try {
      return SelectorEstadoSimple.defaultOptions.firstWhere(
        (o) => o.value == v,
      );
    } catch (_) {
      return null;
    }
  }

  void _pick(StatusOption opt) {
    setState(() => _selected = opt);
    widget.onChanged?.call(opt);
  }

  Future<void> _openPicker() async {
    if (widget.useBottomSheet) {
      final picked = await showModalBottomSheet<StatusOption>(
        context: context,
        isScrollControlled: false,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          final cs = Theme.of(ctx).colorScheme;
          return SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  height: 4,
                  width: 36,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant.withOpacity(.7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.title,
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                ...SelectorEstadoSimple.defaultOptions.map((opt) {
                  final selected = opt.value == _selected.value;
                  return ListTile(
                    leading: Icon(opt.icon, color: opt.color),
                    title: Text(opt.label),
                    trailing: selected
                        ? Icon(Icons.check_circle, color: opt.color)
                        : null,
                    onTap: () => Navigator.of(ctx).pop(opt),
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );
      if (picked != null) _pick(picked);
    } else {
      final box = context.findRenderObject() as RenderBox?;
      final overlay =
          Overlay.of(context).context.findRenderObject() as RenderBox?;
      if (box == null || overlay == null) return;

      final position = RelativeRect.fromRect(
        Rect.fromPoints(
          box.localToGlobal(Offset.zero, ancestor: overlay),
          box.localToGlobal(
            box.size.bottomRight(Offset.zero),
            ancestor: overlay,
          ),
        ),
        Offset.zero & overlay.size,
      );

      final picked = await showMenu<StatusOption>(
        context: context,
        position: position,
        items: SelectorEstadoSimple.defaultOptions.map((opt) {
          final selected = opt.value == _selected.value;
          return PopupMenuItem<StatusOption>(
            value: opt,
            child: Row(
              children: [
                Icon(opt.icon, color: opt.color, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(opt.label)),
                if (selected) Icon(Icons.check, color: opt.color, size: 18),
              ],
            ),
          );
        }).toList(),
      );
      if (picked != null) _pick(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: cs.onSurface,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: widget.dense ? 6 : 8),
            child: Text(widget.title, style: titleStyle),
          ),
        Material(
          color: cs.surfaceContainerHighest.withOpacity(.35),
          shape: StadiumBorder(side: BorderSide(color: _selected.color)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: _openPicker,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_selected.icon, size: 18, color: _selected.color),
                  const SizedBox(width: 8),
                  Text(
                    _selected.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.expand_more, size: 18, color: cs.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/* Ejemplo de uso:
import 'package:buses2/shared/widgets/cajas/caja_estado/selector_estado.dart';
...
SelectorEstadoSimple(
  initialValue: 'en_revision', // opcional; por defecto “en_revision”
  onChanged: (opt) => debugPrint('Nuevo estado: ${opt.value}'), // opcional
  // useBottomSheet: true, // (default) abre un bottom sheet con las opciones
  // useBottomSheet: false, // usa popup anclado al chip
),
*/
