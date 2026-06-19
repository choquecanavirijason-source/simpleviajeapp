import 'package:flutter/material.dart';

class CajaFechaIniFin extends StatefulWidget {
  final DateTime? fechaIni;
  final DateTime? fechaFin;
  final ValueChanged<DateTime?>? onFechaIniChanged;
  final ValueChanged<DateTime?>? onFechaFinChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const CajaFechaIniFin({
    Key? key,
    this.fechaIni,
    this.fechaFin,
    this.onFechaIniChanged,
    this.onFechaFinChanged,
    this.firstDate,
    this.lastDate,
  }) : super(key: key);

  @override
  State<CajaFechaIniFin> createState() => _CajaFechaIniFinState();
}

class _CajaFechaIniFinState extends State<CajaFechaIniFin> {
  DateTime? _ini;
  DateTime? _fin;

  @override
  void initState() {
    super.initState();
    _ini = widget.fechaIni;
    _fin = widget.fechaFin;
  }

  Future<void> _pickIni() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _ini ?? _fin ?? now,
      firstDate: widget.firstDate ?? DateTime(2000),
      lastDate: widget.lastDate ?? now,
    );
    if (selected != null) {
      setState(() {
        _ini = selected;
        if (_fin != null && _ini!.isAfter(_fin!)) _fin = _ini;
      });
      widget.onFechaIniChanged?.call(_ini);
      widget.onFechaFinChanged?.call(_fin);
    }
  }

  Future<void> _pickFin() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _fin ?? _ini ?? now,
      firstDate: widget.firstDate ?? DateTime(2000),
      lastDate: widget.lastDate ?? now,
    );
    if (selected != null) {
      setState(() {
        _fin = selected;
        if (_ini != null && _fin!.isBefore(_ini!)) _ini = _fin;
      });
      widget.onFechaFinChanged?.call(_fin);
      widget.onFechaIniChanged?.call(_ini);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ButtonStyle style = ElevatedButton.styleFrom(
      padding: EdgeInsets.zero, // sin padding interno
      fixedSize: const Size(85, 27), // altura *exacta* 24 px
      tapTargetSize: MaterialTapTargetSize.shrinkWrap, // sin inflar a 40/48 px
      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),

      backgroundColor: Colors.white.withOpacity(0.14),
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.white.withOpacity(0.28)),
      ),
      textStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: .3,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Caja para la fecha inicial
        ElevatedButton(
          onPressed: _pickIni,
          style: style,
          child: const Text('Fecha in'),
        ),
        const SizedBox(height: 8),
        // Caja para la fecha final
        ElevatedButton(
          onPressed: _pickFin,
          style: style,
          child: const Text('Fecha fin'),
        ),
      ],
    );
  }
}
