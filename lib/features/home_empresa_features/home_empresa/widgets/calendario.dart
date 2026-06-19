import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart' as fl;
import 'package:table_calendar/table_calendar.dart';

/// Abre un modal (estilo hoja inferior) en español que permite elegir **solo una fecha**.
/// Retorna la fecha elegida truncada a día (local) o null si se cancela.
Future<DateTime?> showCalendarDiaEsModal(
  BuildContext context, {
  DateTime? initialDate,
  DateTime? minDate,
  DateTime? maxDate,
  Color primaryColor = const Color(0xFF22C55E),
  String title = 'Elegir día',
}) {
  final now = DateTime.now();
  // ✅ Permite históricos (por defecto 5 años hacia atrás; puedes pasarlo por parámetro con minDate)
  final first = minDate ?? DateTime(now.year - 5, 1, 1);
  final last = maxDate ?? DateTime(now.year + 2, 12, 31);
  final init = initialDate ?? now;

  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return Localizations(
        locale: const Locale('es'),
        delegates: const [
          fl.GlobalMaterialLocalizations.delegate,
          fl.GlobalWidgetsLocalizations.delegate,
          fl.GlobalCupertinoLocalizations.delegate,
        ],
        child: _CalendarDiaSheetEs(
          initial: init,
          minDate: first,
          maxDate: last,
          primary: primaryColor,
          title: title,
        ),
      );
    },
  );
}

class _CalendarDiaSheetEs extends StatefulWidget {
  final DateTime initial;
  final DateTime minDate;
  final DateTime maxDate;
  final Color primary;
  final String title;

  const _CalendarDiaSheetEs({
    required this.initial,
    required this.minDate,
    required this.maxDate,
    required this.primary,
    required this.title,
  });

  @override
  State<_CalendarDiaSheetEs> createState() => _CalendarDiaSheetEsState();
}

class _CalendarDiaSheetEsState extends State<_CalendarDiaSheetEs> {
  // Paleta
  static const Color kSurface = Color(0xFFF8FAFC);
  static const Color kCard = Colors.white;
  static const Color kBorder = Color(0xFFE2E8F0);
  static const Color kText = Color(0xFF0F172A);
  static const Color kSubtle = Color(0xFF475569);
  static const Color kGreen = Color(0xFF22C55E);

  late DateTime _focused;
  DateTime? _selected;

  @override
  void initState() {
    super.initState();
    _selected = _startOfDay(widget.initial);
    _focused = _selected!;
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final height = media.size.height * 0.60;

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

              // Calendario
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
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
                              child: TableCalendar(
                                locale: 'es',
                                firstDay: _startOfDay(widget.minDate),
                                lastDay: _startOfDay(widget.maxDate),
                                focusedDay: _focused,
                                onPageChanged: (fd) => _focused = fd,
                                startingDayOfWeek: StartingDayOfWeek.monday,
                                availableGestures:
                                    AvailableGestures.horizontalSwipe,
                                calendarFormat: CalendarFormat.month,
                                availableCalendarFormats: const {
                                  CalendarFormat.month: 'Mes',
                                },
                                rowHeight: 38,
                                daysOfWeekHeight: 20,

                                // ✅ Permitimos cualquier día >= minDate (incluye pasado si así se configuró)
                                enabledDayPredicate: (day) => !_startOfDay(
                                  day,
                                ).isBefore(_startOfDay(widget.minDate)),

                                selectedDayPredicate: (day) =>
                                    _selected != null &&
                                    _startOfDay(day) == _selected,

                                onDaySelected: (selected, focused) {
                                  if (_startOfDay(
                                    selected,
                                  ).isBefore(_startOfDay(widget.minDate)))
                                    return;
                                  setState(() {
                                    _selected = _startOfDay(selected);
                                    _focused = focused;
                                  });
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
                                    return labels[(date.weekday + 6) % 7];
                                  },
                                ),
                                calendarStyle: const CalendarStyle(
                                  selectedDecoration: BoxDecoration(
                                    color: kGreen,
                                    shape: BoxShape.circle,
                                  ),
                                  selectedTextStyle: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
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
                                  defaultTextStyle: TextStyle(color: kText),
                                  weekendTextStyle: TextStyle(color: kText),
                                  cellMargin: EdgeInsets.zero,
                                  cellPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Botones
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
                        backgroundColor: kGreen,
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
                      onPressed: () {
                        if (_selected == null) return;
                        Navigator.of(context).pop(_selected);
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
