// calendar_es_modal.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart' as fl;
import 'package:table_calendar/table_calendar.dart';

/// DTO que devuelve el modal con la selección realizada
class ProgramacionSeleccion {
  final String mode; // 'range' | 'list' | 'single'
  final DateTime timeLocal; // fecha/hora local elegida (se usa la hora)
  final List<DateTime>?
  datesLocal; // solo si mode='list' o 'single' (días sin hora)
  final DateTime? rangeStartLocal; // solo si mode='range'
  final DateTime? rangeEndLocal; // solo si mode='range'

  ProgramacionSeleccion({
    required this.mode,
    required this.timeLocal,
    this.datesLocal,
    this.rangeStartLocal,
    this.rangeEndLocal,
  });

  // util: YYYY-MM-DD
  String _d(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // util: HH:mm (24h)
  String _t(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
    'mode': mode,
    'timeLocal': _t(timeLocal),
    'datesLocal': datesLocal?.map(_d).toList(),
    'range': (rangeStartLocal != null && rangeEndLocal != null)
        ? {'startLocal': _d(rangeStartLocal!), 'endLocal': _d(rangeEndLocal!)}
        : null,
  };
}

/// Muestra un modal (ES) para elegir FECHA y HORA (24h).
/// - Calendario: rango por long-press+drag, días sueltos por tap
/// - No permite fechas anteriores a HOY
Future<ProgramacionSeleccion?> showCalendarEsModal(
  BuildContext context, {
  DateTime? initialDate,
  DateTime? minDate,
  DateTime? maxDate,
  int minuteInterval = 5,
  Color primaryColor = const Color(0xFF22C55E), // Verde por defecto
  String title = 'Programar fecha y hora',
}) {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final init = _roundToInterval(initialDate ?? now, minuteInterval);

  // mínimo permitido = HOY 00:00 (a menos que pases algo mayor)
  final first = (minDate == null || minDate.isBefore(todayStart))
      ? todayStart
      : minDate;

  final last = maxDate ?? now.add(const Duration(days: 365 * 2));

  return showModalBottomSheet<ProgramacionSeleccion>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return Localizations(
        locale: const Locale('es'),
        delegates: [
          fl.GlobalMaterialLocalizations.delegate,
          fl.GlobalWidgetsLocalizations.delegate,
          fl.GlobalCupertinoLocalizations.delegate,
        ],
        child: _CalendarSheetEs(
          initial: init,
          minDate: first!,
          maxDate: last,
          minuteInterval: minuteInterval,
          primary: primaryColor,
          title: title,
        ),
      );
    },
  );
}

// ====== Widget interno ======
class _CalendarSheetEs extends StatefulWidget {
  final DateTime initial;
  final DateTime minDate;
  final DateTime maxDate;
  final int minuteInterval;
  final Color primary;
  final String title;

  const _CalendarSheetEs({
    required this.initial,
    required this.minDate,
    required this.maxDate,
    required this.minuteInterval,
    required this.primary,
    required this.title,
  });

  @override
  State<_CalendarSheetEs> createState() => _CalendarSheetEsState();
}

class _CalendarSheetEsState extends State<_CalendarSheetEs> {
  // Paleta fija
  static const kSurface = Color(0xFFF8FAFC);
  static const kCard = Colors.white;
  static const kBorder = Color(0xFFE2E8F0);
  static const kText = Color(0xFF0F172A);
  static const kSubtle = Color(0xFF475569);
  static const kSelectedGreen = Color(0xFF22C55E);
  static const kRangeFill = Color(0x2622C55E); // ~15% opacidad

  late DateTime _temp;

  // Multi-selección por TAP (días sueltos)
  final Set<int> _markedDays = <int>{};
  int _dayKey(DateTime d) =>
      DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
  bool _isMarked(DateTime d) => _markedDays.contains(_dayKey(d));

  // Rango
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  RangeSelectionMode _rangeMode = RangeSelectionMode.toggledOff;
  bool _draggingRange = false;

  // Mes/página enfocada del calendario
  late DateTime _focused;

  bool get _isRangeActive =>
      _rangeMode != RangeSelectionMode.toggledOff &&
      _rangeStart != null &&
      _rangeEnd != null;

  String _fmtFechaSolo(DateTime d) {
    const dias = [
      'lunes',
      'martes',
      'miércoles',
      'jueves',
      'viernes',
      'sábado',
      'domingo',
    ];
    const meses = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    final wd = dias[(d.weekday + 6) % 7];
    final m = meses[d.month - 1];
    return '$wd, ${d.day} de $m';
  }

  String _fmtHora(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  List<DateTime> _markedDatesSorted() {
    final list =
        _markedDays
            .map((ms) => DateTime.fromMillisecondsSinceEpoch(ms))
            .toList()
          ..sort((a, b) => a.compareTo(b));
    return list;
  }

  @override
  void initState() {
    super.initState();
    _temp = _enforceAll(widget.initial);
    _focused = DateTime(_temp.year, _temp.month, _temp.day);
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  // Validación mínima: solo límites absolutos
  DateTime _enforceAll(DateTime dt) {
    if (dt.isBefore(widget.minDate)) return widget.minDate;
    if (dt.isAfter(widget.maxDate)) return widget.maxDate;
    return dt;
  }

  void _apply(DateTime dt) {
    HapticFeedback.selectionClick();
    setState(
      () => _temp = _enforceAll(_roundToInterval(dt, widget.minuteInterval)),
    );
  }

  void _deactivateRange() {
    _draggingRange = false;
    _rangeMode = RangeSelectionMode.toggledOff;
    _rangeStart = null;
    _rangeEnd = null;
  }

  void _deactivateMarked() {
    _markedDays.clear();
  }
  /////// FUNCION PARA DES/HABILITAR BOTON ACEPTAR

  bool _isValidSelection() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Caso 1: Modo rango
    if (_isRangeActive) {
      final startDay = DateTime(
        _rangeStart!.year,
        _rangeStart!.month,
        _rangeStart!.day,
      );
      final endDay = DateTime(
        _rangeEnd!.year,
        _rangeEnd!.month,
        _rangeEnd!.day,
      );

      // Si el rango incluye hoy
      if (!startDay.isAfter(today) && !endDay.isBefore(today)) {
        // Y la hora elegida es anterior a ahora → inválido
        if (_temp.isBefore(now)) return false;
      }
    }
    // Caso 2: Modo lista (días sueltos)
    else if (_markedDays.isNotEmpty) {
      final markedDates = _markedDatesSorted();
      final hasToday = markedDates.any(
        (d) =>
            d.year == today.year &&
            d.month == today.month &&
            d.day == today.day,
      );

      if (hasToday && _temp.isBefore(now)) return false;
    }
    // Caso 3: Día único
    else {
      final selectedDay = DateTime(_temp.year, _temp.month, _temp.day);
      if (selectedDay.isAtSameMomentAs(today) && _temp.isBefore(now)) {
        return false;
      }
    }

    return true; // Todo OK
  }

  /////// FUNCION PARA DES/HABILITAR BOTON ACEPTAR\\\\\\\
  // Diálogo de confirmación (fondo blanco)
  Future<bool?> _showSummaryDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final marcados = _markedDatesSorted();

        final List<Widget> body = _isRangeActive
            ? <Widget>[
                _linea('de:', _fmtFechaSolo(_rangeStart!)),
                _linea('hasta:', _fmtFechaSolo(_rangeEnd!)),
                const SizedBox(height: 4),
                _linea('hora:', _fmtHora(_temp)),
              ]
            : (marcados.isNotEmpty
                  ? <Widget>[
                      const Text(
                        'los días:',
                        style: TextStyle(
                          color: kSubtle,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...marcados.map(
                        (d) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            _fmtFechaSolo(d),
                            style: const TextStyle(
                              color: kText,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _linea('hora:', _fmtHora(_temp)),
                    ]
                  : <Widget>[
                      _linea('fecha:', _fmtFechaSolo(_temp)),
                      _linea('hora:', _fmtHora(_temp)),
                    ]);

        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          title: Row(
            children: [
              Icon(Icons.event_available, color: widget.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Confirmar programación',
                  style: TextStyle(fontWeight: FontWeight.w800, color: kText),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: body,
              ),
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.black),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Editar'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isValidSelection()
                    ? kSelectedGreen
                    : Colors.grey.shade400,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.check),
              label: const Text('Confirmar'),
              onPressed: _isValidSelection()
                  ? () => Navigator.of(ctx).pop(true)
                  : null,
            ),
          ],
        );
      },
    );
  }

  ProgramacionSeleccion _buildSelection() {
    if (_isRangeActive) {
      return ProgramacionSeleccion(
        mode: 'range',
        timeLocal: _temp,
        rangeStartLocal: DateTime(
          _rangeStart!.year,
          _rangeStart!.month,
          _rangeStart!.day,
        ),
        rangeEndLocal: DateTime(
          _rangeEnd!.year,
          _rangeEnd!.month,
          _rangeEnd!.day,
        ),
      );
    }
    final marks = _markedDatesSorted();
    if (marks.isNotEmpty) {
      final onlyDays = marks
          .map((d) => DateTime(d.year, d.month, d.day))
          .toList(growable: false);
      return ProgramacionSeleccion(
        mode: 'list',
        timeLocal: _temp,
        datesLocal: onlyDays,
      );
    }
    final day = DateTime(_temp.year, _temp.month, _temp.day);
    return ProgramacionSeleccion(
      mode: 'single',
      timeLocal: _temp,
      datesLocal: [day],
    );
  }

  Widget _linea(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              etiqueta,
              style: const TextStyle(
                color: kSubtle,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(color: kText, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final height = media.size.height * 0.78;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: Container(
          height: height,
          decoration: const BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 18,
                offset: Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: kBorder,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),

              // ===== Encabezado =====
              Container(
                margin: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [widget.primary, widget.primary.withOpacity(.75)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ===== Contenido =====
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    // Tarjeta Calendario
                    Container(
                      decoration: BoxDecoration(
                        color: kCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: kBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_month,
                                  size: 20,
                                  color: kSubtle,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Calendario',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: kText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: kBorder),

                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: kBorder),
                              ),
                              child: SizedBox(
                                height: 300,
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    const double _rowH = 38;
                                    const double _dowH = 20;
                                    const double _gridTop = 46;

                                    DateTime? hitTestDate(Offset p) {
                                      final width = constraints.maxWidth;
                                      final gridLeft = 0.0;
                                      final gridTop = _gridTop + _dowH;
                                      final gridW = width;
                                      final gridH = _rowH * 6;

                                      if (p.dx < gridLeft ||
                                          p.dx > gridLeft + gridW)
                                        return null;
                                      if (p.dy < gridTop ||
                                          p.dy > gridTop + gridH)
                                        return null;

                                      final col =
                                          ((p.dx - gridLeft) / (gridW / 7))
                                              .floor()
                                              .clamp(0, 6);
                                      final row = ((p.dy - gridTop) / _rowH)
                                          .floor()
                                          .clamp(0, 5);

                                      final firstOfMonth = DateTime(
                                        _focused.year,
                                        _focused.month,
                                        1,
                                      );
                                      final offset =
                                          (firstOfMonth.weekday + 6) % 7; // L=0
                                      final idx = row * 7 + col;
                                      final dayNum = idx - offset + 1;

                                      final daysInMonth = DateTime(
                                        _focused.year,
                                        _focused.month + 1,
                                        0,
                                      ).day;
                                      if (dayNum < 1 || dayNum > daysInMonth)
                                        return null;

                                      final d = DateTime(
                                        _focused.year,
                                        _focused.month,
                                        dayNum,
                                      );

                                      if (_startOfDay(
                                        d,
                                      ).isBefore(_startOfDay(widget.minDate)))
                                        return null;
                                      if (_startOfDay(
                                        d,
                                      ).isAfter(_startOfDay(widget.maxDate)))
                                        return null;
                                      return d;
                                    }

                                    return Listener(
                                      behavior: HitTestBehavior.translucent,
                                      onPointerMove: (ev) {
                                        if (!_draggingRange ||
                                            _rangeStart == null)
                                          return;
                                        final d = hitTestDate(ev.localPosition);
                                        if (d == null) return;
                                        setState(() {
                                          if (d.isBefore(_rangeStart!)) {
                                            _rangeEnd = _rangeStart;
                                            _rangeStart = d;
                                          } else {
                                            _rangeEnd = d;
                                          }
                                          _rangeMode =
                                              RangeSelectionMode.toggledOn;
                                        });
                                        final last = _rangeEnd ?? d;
                                        _apply(
                                          DateTime(
                                            last.year,
                                            last.month,
                                            last.day,
                                            _temp.hour,
                                            _temp.minute,
                                          ),
                                        );
                                      },
                                      onPointerUp: (_) {
                                        if (_draggingRange &&
                                            _rangeStart != null &&
                                            _rangeEnd == null) {
                                          setState(
                                            () => _rangeEnd = _rangeStart,
                                          );
                                        }
                                        _draggingRange = false;
                                      },
                                      onPointerCancel: (_) =>
                                          _draggingRange = false,
                                      child: TableCalendar(
                                        locale: 'es',
                                        firstDay: _startOfDay(widget.minDate),
                                        lastDay: _startOfDay(widget.maxDate),
                                        focusedDay: _focused,
                                        onPageChanged: (fd) => _focused = fd,
                                        startingDayOfWeek:
                                            StartingDayOfWeek.monday,
                                        availableGestures:
                                            AvailableGestures.horizontalSwipe,
                                        calendarFormat: CalendarFormat.month,
                                        availableCalendarFormats: const {
                                          CalendarFormat.month: 'Mes',
                                        },
                                        rowHeight: _rowH,
                                        daysOfWeekHeight: _dowH,

                                        enabledDayPredicate: (day) =>
                                            !_startOfDay(day).isBefore(
                                              _startOfDay(widget.minDate),
                                            ),

                                        // ====== RANGO por long-press + arrastre ======
                                        rangeSelectionMode: _rangeMode,
                                        rangeStartDay: _rangeStart,
                                        rangeEndDay: _rangeEnd,
                                        onDayLongPressed: (day, focused) {
                                          if (_startOfDay(day).isBefore(
                                            _startOfDay(widget.minDate),
                                          ))
                                            return;
                                          setState(() {
                                            _deactivateMarked();
                                            _draggingRange = true;
                                            _rangeMode =
                                                RangeSelectionMode.toggledOn;
                                            _rangeStart = DateTime(
                                              day.year,
                                              day.month,
                                              day.day,
                                            );
                                            _rangeEnd = null;
                                            _focused = focused;
                                          });
                                          _apply(
                                            DateTime(
                                              day.year,
                                              day.month,
                                              day.day,
                                              _temp.hour,
                                              _temp.minute,
                                            ),
                                          );
                                        },

                                        // ====== DÍAS SUELTOS por TAP ======
                                        selectedDayPredicate: (day) =>
                                            _isMarked(day),
                                        onDaySelected: (selected, focused) {
                                          if (_startOfDay(selected).isBefore(
                                            _startOfDay(widget.minDate),
                                          ))
                                            return;
                                          final k = _dayKey(selected);
                                          setState(() {
                                            _deactivateRange();
                                            if (_markedDays.contains(k)) {
                                              _markedDays.remove(k);
                                            } else {
                                              _markedDays.add(k);
                                            }
                                            _focused = focused;
                                          });
                                          final candidate = DateTime(
                                            selected.year,
                                            selected.month,
                                            selected.day,
                                            _temp.hour,
                                            _temp.minute,
                                          );
                                          _apply(candidate);
                                        },

                                        headerStyle: const HeaderStyle(
                                          titleCentered: true,
                                          formatButtonVisible: false,
                                          headerPadding: EdgeInsets.symmetric(
                                            vertical: 6,
                                          ),
                                          titleTextStyle: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: kText,
                                          ),
                                        ),
                                        daysOfWeekStyle: DaysOfWeekStyle(
                                          weekdayStyle: const TextStyle(
                                            color: kSubtle,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          weekendStyle: const TextStyle(
                                            color: kSubtle,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          dowTextFormatter: (date, _) {
                                            const labels = [
                                              'L',
                                              'M',
                                              'X',
                                              'J',
                                              'V',
                                              'S',
                                              'D',
                                            ];
                                            return labels[(date.weekday + 6) %
                                                7];
                                          },
                                        ),
                                        calendarStyle: const CalendarStyle(
                                          selectedDecoration: BoxDecoration(
                                            color: kSelectedGreen,
                                            shape: BoxShape.circle,
                                          ),
                                          selectedTextStyle: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                          ),
                                          rangeHighlightColor: kRangeFill,
                                          withinRangeTextStyle: TextStyle(
                                            color: kText,
                                          ),
                                          rangeStartDecoration: BoxDecoration(
                                            color: kSelectedGreen,
                                            shape: BoxShape.circle,
                                          ),
                                          rangeEndDecoration: BoxDecoration(
                                            color: kSelectedGreen,
                                            shape: BoxShape.circle,
                                          ),
                                          todayDecoration: BoxDecoration(
                                            color: Colors.transparent,
                                            shape: BoxShape.circle,
                                          ),
                                          todayTextStyle: TextStyle(
                                            color: kText,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          outsideDaysVisible: false,
                                          defaultTextStyle: TextStyle(
                                            color: kText,
                                          ),
                                          weekendTextStyle: TextStyle(
                                            color: kText,
                                          ),
                                          cellMargin: EdgeInsets.zero,
                                          cellPadding: EdgeInsets.zero,
                                        ),
                                        calendarBuilders: CalendarBuilders(
                                          todayBuilder:
                                              (context, day, focusedDay) {
                                                final inRange =
                                                    (_rangeStart != null &&
                                                    (_rangeEnd == null
                                                        ? _startOfDay(day) ==
                                                              _startOfDay(
                                                                _rangeStart!,
                                                              )
                                                        : !_startOfDay(
                                                                day,
                                                              ).isBefore(
                                                                _startOfDay(
                                                                  _rangeStart!,
                                                                ),
                                                              ) &&
                                                              !_startOfDay(
                                                                day,
                                                              ).isAfter(
                                                                _startOfDay(
                                                                  _rangeEnd!,
                                                                ),
                                                              )));
                                                if (inRange || _isMarked(day))
                                                  return null;
                                                return Center(
                                                  child: Container(
                                                    width: 34,
                                                    height: 34,
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: kSelectedGreen,
                                                        width: 1.4,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      '${day.day}',
                                                      style: const TextStyle(
                                                        color: kText,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),

                          // Subtítulo hora
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                            child: Row(
                              children: [
                                Icon(Icons.schedule, size: 20, color: kSubtle),
                                SizedBox(width: 8),
                                Text(
                                  'Hora (24h)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: kText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: kBorder),

                          // Rueda de hora
                          SizedBox(
                            height: 160,
                            child: CupertinoTheme(
                              data: const CupertinoThemeData(
                                brightness: Brightness.light,
                              ),
                              child: CupertinoDatePicker(
                                mode: CupertinoDatePickerMode.time,
                                use24hFormat: true,
                                minuteInterval: widget.minuteInterval.clamp(
                                  1,
                                  30,
                                ),
                                initialDateTime: DateTime(
                                  0,
                                  1,
                                  1,
                                  _temp.hour,
                                  _temp.minute,
                                ),
                                onDateTimeChanged: (dt) {
                                  _apply(
                                    DateTime(
                                      _temp.year,
                                      _temp.month,
                                      _temp.day,
                                      dt.hour,
                                      dt.minute,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ===== Acciones =====
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: const BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(24),
                  ),
                  border: Border(top: BorderSide(color: kBorder)),
                ),
                child: Row(
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () => Navigator.of(context).pop(null),
                      child: const Text('Cancelar'),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kSelectedGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.check),
                      label: const Text('Confirmar'),
                      onPressed: () async {
                        final ok = await _showSummaryDialog();
                        if (ok == true) {
                          final sel = _buildSelection();
                          Navigator.of(context).pop(sel);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== Helpers a nivel de archivo =====
DateTime _roundToInterval(DateTime dt, int interval) {
  if (interval <= 1) return dt;
  final total = dt.hour * 60 + dt.minute;
  final rounded = ((total / interval).round()) * interval;
  final hh = (rounded ~/ 60) % 24;
  final mm = rounded % 60;
  return DateTime(dt.year, dt.month, dt.day, hh, mm);
}
