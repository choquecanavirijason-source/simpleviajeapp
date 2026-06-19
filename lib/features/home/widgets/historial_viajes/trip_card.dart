import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:buses2/features/home/data/trip.dart';
import 'package:buses2/shared/widgets/justificacion_modal.dart';
import 'common.dart';

import 'package:intl/intl.dart';

/// ✅ ETA aproximado desde km (A -> B)
String etaFromKm(double km, {double avgKmh = 22}) {
  if (km <= 0) return '--';
  final minutes = (km / avgKmh) * 60.0;
  final m = minutes.isFinite ? minutes.round() : 0;

  if (m <= 1) return '1 min';
  if (m < 60) return '$m min';

  final h = m ~/ 60;
  final rem = m % 60;
  return '${h}h ${rem}m';
}

/// ===== TOP-LEVEL: modelo para las ocurrencias programadas =====
class _ProgrammedData {
  _ProgrammedData({
    required this.slots,
    required this.cancelled,
    required this.completed,
    this.summaryText,
  });

  final List<DateTime> slots; // ocurrencias (fecha/hora) ya calculadas
  final Set<String> cancelled; // YYYY-MM-DD canceladas
  final Set<String> completed; // YYYY-MM-DD completadas
  final String? summaryText; // resumen (opcional)
}

class TripCard extends StatefulWidget {
  const TripCard({
    super.key,
    required this.trip,
    this.ofertasCount = 0,
    this.onOfertas,
    this.onCancelar,
    this.onVerConductor,
    this.onVerRuta,
    this.onChatConductor,
    this.onDetalle,
  });

  final Trip trip;

  // Badge de ofertas
  final int ofertasCount;

  // Callbacks
  final void Function(Trip)? onOfertas;
  final void Function(Trip)? onCancelar;
  final void Function(Trip)? onVerConductor;
  final void Function(Trip)? onVerRuta;
  final void Function(Trip)? onChatConductor;
  final void Function(Trip)? onDetalle;

  @override
  State<TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<TripCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  String _fmtHoraCorta(DateTime dt) {
    final d = dt.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    // Animación de pulsación para viajes activos
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (_shouldPulse()) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  bool _shouldPulse() {
    final estado = widget.trip.estado;
    return estado == TripStatus.pedido ||
        estado == TripStatus.enCamino ||
        estado == TripStatus.enLugar;
  }

  // ====== Colores Mejorados ======
  static const verdeStrong = Color(0xFF14532D);
  static const verdeMedio = Color(0xFF16A34A);
  static const verdeClaro = Color(0xFF22C55E);
  static const verdeMuyClaro = Color(0xFF86EFAC);

  // ====== Colores por Estado ======
  static const amarilloEstado = Color(0xFFFFBF24); // Pedido
  static const azulEstado = Color(0xFF3B82F6); // En camino
  static const moradoEstado = Color(0xFF8B5CF6); // En lugar
  static const naranjaEstado = Color(0xFFF97316); // En curso
  static const verdeEstado = Color(0xFF10B981); // Completado
  static const rojoEstado = Color(0xFFEF4444); // Cancelado
  static const grisEstado = Color(0xFF9CA3AF); // Programado

  // ====== Colores Rojo ======
  static const rojoStrong = Color(0xFFC62828);

  String _ymd(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final dd = d.toLocal();
    return '${dd.year}-${two(dd.month)}-${two(dd.day)}';
  }

  Color _estadoBg(TripStatus s) {
    switch (s) {
      case TripStatus.pedido:
        return amarilloEstado.withOpacity(0.15);
      case TripStatus.aceptado:
        return verdeEstado.withOpacity(0.15);
      case TripStatus.enCamino:
        return azulEstado.withOpacity(0.15);
      case TripStatus.enLugar:
        return moradoEstado.withOpacity(0.15);
      case TripStatus.enCurso:
        return naranjaEstado.withOpacity(0.15);
      case TripStatus.completado:
        return verdeEstado;
      case TripStatus.cancelado:
        return rojoEstado.withOpacity(0.1);
      case TripStatus.programado:
        return grisEstado.withOpacity(0.1);
    }
  }

  Color _estadoFg(TripStatus s) {
    switch (s) {
      case TripStatus.pedido:
        return const Color(0xFFB45309);
      case TripStatus.aceptado:
        return verdeStrong;
      case TripStatus.enCamino:
        return const Color(0xFF1E40AF);
      case TripStatus.enLugar:
        return const Color(0xFF6B21A8);
      case TripStatus.enCurso:
        return const Color(0xFFC2410C);
      case TripStatus.completado:
        return Colors.white;
      case TripStatus.cancelado:
        return rojoEstado;
      case TripStatus.programado:
        return const Color(0xFF374151);
    }
  }

  IconData _estadoIcon(TripStatus s) {
    switch (s) {
      case TripStatus.pedido:
        return Icons.search_rounded;
      case TripStatus.aceptado:
        return Icons.check_circle_rounded;
      case TripStatus.enCamino:
        return Icons.directions_car_rounded;
      case TripStatus.enLugar:
        return Icons.place_rounded;
      case TripStatus.enCurso:
        return Icons.navigation_rounded;
      case TripStatus.completado:
        return Icons.verified_rounded;
      case TripStatus.cancelado:
        return Icons.cancel_rounded;
      case TripStatus.programado:
        return Icons.schedule_rounded;
    }
  }

  LinearGradient? _getCardGradient(TripStatus s) {
    if (!s.isActivo) return null;

    switch (s) {
      case TripStatus.pedido:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, amarilloEstado.withOpacity(0.05)],
        );
      case TripStatus.enCamino:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, azulEstado.withOpacity(0.05)],
        );
      case TripStatus.enLugar:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, moradoEstado.withOpacity(0.08)],
        );
      case TripStatus.enCurso:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, naranjaEstado.withOpacity(0.05)],
        );
      default:
        return null;
    }
  }

  String _fmtFechaCorta(DateTime dt, {DateTime? now}) {
    final n = (now ?? DateTime.now()).toLocal();
    final d = dt.toLocal();
    final startN = DateTime(n.year, n.month, n.day);
    final startD = DateTime(d.year, d.month, d.day);
    final diffDays = startD.difference(startN).inDays;

    String two(int x) => x.toString().padLeft(2, '0');
    final hhmm = '${two(d.hour)}:${two(d.minute)}';

    const dias = [
      'lunes',
      'martes',
      'miércoles',
      'jueves',
      'viernes',
      'sábado',
      'domingo',
    ];
    String diaNombre(int weekday) => dias[weekday - 1];

    if (diffDays == 0) return 'hoy $hhmm';
    if (diffDays == -1) return 'ayer $hhmm';
    if (diffDays == 1) return 'mañana $hhmm';

    if (diffDays.abs() <= 6) {
      final nombre = diaNombre(d.weekday);
      final dd = two(d.day);
      return '$nombre $dd $hhmm';
    }

    if (n.year == d.year) {
      final dd = two(d.day);
      final mm = two(d.month);
      return '$dd/$mm $hhmm';
    }

    final dd = two(d.day);
    final mm = two(d.month);
    return '$dd/$mm/${d.year} $hhmm';
  }

  String _fmtChip(DateTime dt) {
    String two(int x) => x.toString().padLeft(2, '0');
    final d = dt.toLocal();
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }

  String _fmtDoubleFull(double v) => v.toStringAsFixed(2);

  // ====== Notificar: “pasajero en camino” (solo En lugar) ======
  Future<void> _notifyPassengerEnCamino(BuildContext context) async {
    final rutaDoc = (widget.trip.rutaDoc ?? '').trim();
    final messenger = ScaffoldMessenger.maybeOf(context);

    if (rutaDoc.isEmpty) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('No se pudo notificar: falta la ruta del viaje.'),
        ),
      );
      return;
    }

    try {
      final docRef = FirebaseFirestore.instance.doc(rutaDoc);

      await docRef.update({
        'pasajeroEnCamino': true,
        'pasajeroEnCaminoAt': FieldValue.serverTimestamp(),
      });

      await docRef.collection('events').add({
        'type': 'pasajero_en_camino',
        'createdAt': FieldValue.serverTimestamp(),
        'by': 'pasajero',
      });

      if (!context.mounted || messenger == null) return;
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF14532D),
            content: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Aviso enviado: estás en camino hacia el conductor.',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('No se pudo enviar el aviso: $e')),
      );
    }
  }

  // ====== Cargar slots + estados por-ocurrencia ======
  Future<_ProgrammedData> _loadProgrammedData() async {
    final rutaDoc = widget.trip.rutaDoc?.trim() ?? '';
    if (rutaDoc.isEmpty) {
      return _ProgrammedData(
        slots: <DateTime>[],
        cancelled: <String>{},
        completed: <String>{},
        summaryText: null,
      );
    }

    final snap = await FirebaseFirestore.instance.doc(rutaDoc).get();
    if (!snap.exists) {
      return _ProgrammedData(
        slots: <DateTime>[],
        cancelled: <String>{},
        completed: <String>{},
        summaryText: null,
      );
    }

    final data = snap.data() as Map<String, dynamic>? ?? {};
    final prog = (data['programacion'] as Map?) ?? {};

    final cancelled = (prog['cancelledDates'] is List)
        ? Set<String>.from(
            (prog['cancelledDates'] as List).map(
              (e) => e.toString().substring(0, 10),
            ),
          )
        : <String>{};
    final completed = (prog['completedDates'] is List)
        ? Set<String>.from(
            (prog['completedDates'] as List).map(
              (e) => e.toString().substring(0, 10),
            ),
          )
        : <String>{};

    final datesLocal = (prog['datesLocal'] is List)
        ? List<String>.from(prog['datesLocal'])
        : <String>[];
    final timeList = prog['timeLocal']?.toString();

    List<DateTime> _buildFromDates(List<String> dates, String timeHHmm) {
      final List<DateTime> out = [];
      for (final d in dates) {
        if (d.length >= 10) {
          final iso =
              '${d.substring(0, 10)}T${timeHHmm.padLeft(5, '0')}:00.000';
          final dt = DateTime.tryParse(iso);
          if (dt != null) out.add(dt.toLocal());
        }
      }
      out.sort((a, b) => a.compareTo(b));
      return out;
    }

    if (timeList != null && datesLocal.isNotEmpty) {
      final slots = _buildFromDates(datesLocal, timeList);
      final summary = (widget.trip.scheduleText?.isNotEmpty ?? false)
          ? widget.trip.scheduleText
          : null;
      return _ProgrammedData(
        slots: slots,
        cancelled: cancelled,
        completed: completed,
        summaryText: summary,
      );
    }

    final range = (prog['range'] as Map?) ?? {};
    final timeLocal = (range['timeLocal'] ?? prog['timeLocal'])?.toString();
    final startLocal = (range['startLocal'] ?? range['start'])?.toString();
    final endLocal = (range['endLocal'] ?? range['end'])?.toString();

    if (timeLocal == null || startLocal == null || endLocal == null) {
      final dt = DateTime.tryParse((data['scheduledAtLocal'] ?? '').toString());
      final slots = (dt != null) ? [dt.toLocal()] : <DateTime>[];
      final summary = (widget.trip.scheduleText?.isNotEmpty ?? false)
          ? widget.trip.scheduleText
          : null;
      return _ProgrammedData(
        slots: slots,
        cancelled: cancelled,
        completed: completed,
        summaryText: summary,
      );
    }

    DateTime? _parseYMD(String s) {
      final base = s.length >= 10 ? s.substring(0, 10) : s;
      return DateTime.tryParse('${base}T00:00:00.000');
    }

    final start = _parseYMD(startLocal);
    final end = _parseYMD(endLocal);
    if (start == null || end == null || end.isBefore(start)) {
      return _ProgrammedData(
        slots: <DateTime>[],
        cancelled: cancelled,
        completed: completed,
        summaryText: widget.trip.scheduleText,
      );
    }

    final weekdays = (range['weekdays'] is List)
        ? List<int>.from(range['weekdays'])
        : <int>[];
    final excludes = (range['excludes'] is List)
        ? Set<String>.from(range['excludes'].map((e) => e.toString()))
        : <String>{};

    String two(int n) => n.toString().padLeft(2, '0');
    final List<DateTime> slots = [];

    for (
      DateTime cur = DateTime(start.year, start.month, start.day);
      !cur.isAfter(end);
      cur = cur.add(const Duration(days: 1))
    ) {
      final ymd = '${cur.year}-${two(cur.month)}-${two(cur.day)}';

      if (weekdays.isNotEmpty && !weekdays.contains(cur.weekday)) continue;
      if (excludes.contains(ymd)) continue;

      final iso = '${ymd}T${timeLocal.padLeft(5, '0')}:00.000';
      final dt = DateTime.tryParse(iso);
      if (dt != null) slots.add(dt.toLocal());
    }
    slots.sort((a, b) => a.compareTo(b));

    final summary = (widget.trip.scheduleText?.isNotEmpty ?? false)
        ? widget.trip.scheduleText
        : null;
    return _ProgrammedData(
      slots: slots,
      cancelled: cancelled,
      completed: completed,
      summaryText: summary,
    );
  }

  Future<void> _updateOccurrence({
    required String ymd,
    required String op,
    String? motivo,
  }) async {
    final rutaDoc = widget.trip.rutaDoc?.trim();
    if (rutaDoc == null || rutaDoc.isEmpty) return;

    final docRef = FirebaseFirestore.instance.doc(rutaDoc);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) return;

      final data = snap.data()!;
      final prog = (data['programacion'] as Map?) ?? {};

      List<String> cancelled = List<String>.from(prog['cancelledDates'] ?? []);
      List<String> completed = List<String>.from(prog['completedDates'] ?? []);

      Map<String, dynamic> reasonsMap = Map<String, dynamic>.from(
        prog['cancelledReasons'] ?? {},
      );

      if (op == 'cancel') {
        if (!cancelled.contains(ymd)) cancelled.add(ymd);
        completed.remove(ymd);

        if (motivo != null && motivo.isNotEmpty) {
          reasonsMap[ymd] = {
            'reason': motivo,
            'by': 'pasajero',
            'at': FieldValue.serverTimestamp(),
            'timeText': _fmtHoraCorta(DateTime.now()),
          };
        }
      } else if (op == 'complete') {
        if (!completed.contains(ymd)) completed.add(ymd);
        cancelled.remove(ymd);
        reasonsMap.remove(ymd);
      }

      tx.update(docRef, {
        'programacion.cancelledDates': cancelled,
        'programacion.completedDates': completed,
        'programacion.cancelledReasons': reasonsMap,
        if (op == 'cancel' && motivo != null) 'lastCancelReason': motivo,
        if (op == 'cancel') 'lastCancelAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> _openOccurrenceSheet(
    DateTime dt, {
    required bool isCancelled,
    required bool isCompleted,
  }) async {
    final ymd = _ymd(dt);

    final snap = await FirebaseFirestore.instance
        .doc(widget.trip.rutaDoc!)
        .get();
    final data = snap.data() as Map<String, dynamic>? ?? {};
    final prog = (data['programacion'] as Map?) ?? {};

    final reasonsMap = prog['cancelledReasons'] as Map?;
    final motivoData = reasonsMap?[ymd] as Map?;
    final motivoTexto = motivoData?['reason']?.toString();
    final horaCancel =
        motivoData?['timeText']?.toString() ??
        (motivoData?['at'] != null
            ? _fmtHoraCorta((motivoData!['at'] as Timestamp).toDate())
            : null);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 26),
                const SizedBox(width: 10),
                const Text(
                  'Ocurrencia programada',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (isCancelled)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Cancelada',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  )
                else if (isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Completada',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 20,
                  color: Colors.black87,
                ),
                const SizedBox(width: 8),
                Text(
                  '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} • ${_fmtChip(dt).split(' ').last}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                const Icon(
                  Icons.payments_rounded,
                  size: 22,
                  color: Colors.black87,
                ),
                const SizedBox(width: 10),
                Text(
                  'Total: ARS ${_fmtDoubleFull(widget.trip.precio)}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (isCancelled && motivoTexto != null && motivoTexto.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.red.shade700,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cancelado por Pasajero: $motivoTexto',
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          if (horaCancel != null)
                            Text(
                              horaCancel,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            if (!isCancelled && !isCompleted)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final result = await JustificacionModal.show(
                      context: context,
                      title: 'Cancelar esta fecha',
                      subtitle: '¿Por qué deseas cancelar esta ocurrencia?',
                    );

                    if (result?.confirmed == true && mounted) {
                      await _updateOccurrence(
                        ymd: ymd,
                        op: 'cancel',
                        motivo: result!.motivo,
                      );
                      Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.cancel_rounded, color: Colors.red),
                  label: const Text('Cancelar esta fecha'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // ====== Botonera por estado ======
  Widget _buildActions(BuildContext context) {
    final isPedido = widget.trip.estado == TripStatus.pedido;
    final isProgramado = widget.trip.estado == TripStatus.programado;
    final isAceptado = widget.trip.estado == TripStatus.aceptado;
    final isEnCamino = widget.trip.estado == TripStatus.enCamino;
    final isEnCurso = widget.trip.estado == TripStatus.enCurso;
    final isCompletado = widget.trip.estado == TripStatus.completado;

    final isEnLugar =
        widget.trip.estado.texto.toLowerCase() == 'en lugar' ||
        widget.trip.estado.toString().toLowerCase().contains('enlugar');

    final btnStyle = TextButton.styleFrom(foregroundColor: verdeStrong);
    final btnStyleCancel = TextButton.styleFrom(foregroundColor: rojoStrong);

    List<Widget> buttons = [];

    if (isPedido || isProgramado) {
      buttons = [
        TextButton.icon(
          onPressed: () => widget.onOfertas?.call(widget.trip),
          style: btnStyle,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.local_offer_rounded),
              if (widget.ofertasCount > 0)
                Positioned(
                  right: -8,
                  top: -6,
                  child: _BadgeCount(count: widget.ofertasCount),
                ),
            ],
          ),
          label: const Text('Ofertas'),
        ),
        TextButton.icon(
          onPressed: () => widget.onCancelar?.call(widget.trip),
          style: btnStyleCancel,
          icon: const Icon(Icons.close_rounded),
          label: const Text('Cancelar viaje'),
        ),
      ];
    } else if (isAceptado) {
      buttons = [
        TextButton.icon(
          onPressed: () => widget.onCancelar?.call(widget.trip),
          style: btnStyleCancel,
          icon: const Icon(Icons.close_rounded),
          label: const Text('Cancelar viaje'),
        ),
      ];
    } else if (isEnLugar) {
      buttons = [
        TextButton.icon(
          onPressed: () => widget.onVerConductor?.call(widget.trip),
          style: btnStyle,
          icon: const Icon(Icons.directions_car_filled_rounded),
          label: const Text('Ver conductor'),
        ),
        TextButton.icon(
          onPressed: () => _notifyPassengerEnCamino(context),
          style: btnStyle,
          icon: const Icon(Icons.route),
          label: const Text('En camino'),
        ),
      ];
    } else if (isEnCamino) {
      buttons = [
        TextButton.icon(
          onPressed: () => widget.onVerConductor?.call(widget.trip),
          style: btnStyle,
          icon: const Icon(Icons.directions_car_filled_rounded),
          label: const Text('Ver conductor'),
        ),
      ];
    } else if (isEnCurso) {
      buttons = [
        TextButton.icon(
          onPressed: () =>
              (widget.onVerRuta ?? widget.onVerConductor)?.call(widget.trip),
          style: btnStyle,
          icon: const Icon(Icons.map_rounded),
          label: const Text('Ver ruta'),
        ),
      ];
    } else if (isCompletado) {
      buttons = [
        TextButton.icon(
          onPressed: () => widget.onDetalle?.call(widget.trip),
          style: btnStyle,
          icon: const Icon(Icons.receipt_long_rounded),
          label: const Text('Detalle'),
        ),
      ];
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 4,
          children: buttons,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEnLugar =
        widget.trip.estado.toString().toLowerCase().contains('enlugar') ||
        (widget.trip.estado.texto.toLowerCase() == 'en lugar');

    final isPedido = widget.trip.estado == TripStatus.pedido;

    // ✅ label distancia con ETA solo en PEDIDO
    final distanciaLabel = isPedido
        ? '${widget.trip.km.toStringAsFixed(1)} km · ${etaFromKm(widget.trip.km)}'
        : '${widget.trip.km.toStringAsFixed(1)} km';

    // ===== Contenido del Card =====
    final cardBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: estado + (fecha si NO es programado)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: _estadoBg(widget.trip.estado),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: isEnLugar
                        ? [
                            BoxShadow(
                              color: verdeClaro.withOpacity(.55),
                              blurRadius: 5,
                              spreadRadius: 1.5,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : const [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _estadoIcon(widget.trip.estado),
                        size: 16,
                        color: _estadoFg(widget.trip.estado),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.trip.estado.texto,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _estadoFg(widget.trip.estado),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.trip.programado) ...[
                  const SizedBox(height: 8),
                  const BadgePill(
                    text: 'Programado',
                    icon: Icons.event_available_rounded,
                    bg: Color(0xFFEFF4FF),
                    fg: verdeStrong,
                  ),
                ],
              ],
            ),
            const Spacer(),
            if (!widget.trip.programado)
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F3F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _fmtFechaCorta(widget.trip.fecha),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 12),

        // Origen / Destino
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DotLine(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TileLine(title: 'Origen', value: widget.trip.origen),
                  const SizedBox(height: 8),
                  TileLine(title: 'Destino', value: widget.trip.destino),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 10),

        // Distancia / Total o Precio Ofrecido
        Row(
          children: [
            Flexible(
              child: InfoPill(
                icon: Icons.straighten_rounded,
                label: distanciaLabel,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: InfoPill(
                icon: Icons.payments_rounded,
                label:
                    widget.trip.estado == TripStatus.pedido &&
                        widget.trip.precioOfrecido != null
                    ? 'Ofrecido: ARS ${_fmtDoubleFull(widget.trip.precioOfrecido!)}'
                    : 'Total: ARS ${_fmtDoubleFull(widget.trip.precio)}',
              ),
            ),
          ],
        ),

        // ===== Fechas programadas =====
        if (widget.trip.programado) ...[
          const SizedBox(height: 10),
          FutureBuilder<_ProgrammedData>(
            future: _loadProgrammedData(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return _ProgrammedBand.loading();
              }
              final data =
                  snap.data ??
                  _ProgrammedData(
                    slots: <DateTime>[],
                    cancelled: <String>{},
                    completed: <String>{},
                    summaryText: null,
                  );
              final slots = data.slots;

              if (slots.isEmpty) {
                return _ProgrammedBand.single(
                  text: (widget.trip.scheduleText?.isNotEmpty ?? false)
                      ? widget.trip.scheduleText!
                      : _fmtFechaCorta(widget.trip.fecha),
                );
              }

              if (slots.length > 12) {
                String two(int n) => n.toString().padLeft(2, '0');
                String fmt(DateTime d) =>
                    '${two(d.day)}/${two(d.month)}/${d.year}';
                final first = slots.first;
                final last = slots.last;
                final hhmm = '${two(first.hour)}:${two(first.minute)}';

                final resumen =
                    data.summaryText ?? '${fmt(first)} – ${fmt(last)} · $hhmm';

                return _ProgrammedBand.range(
                  rangoResumen: resumen,
                  count: slots.length,
                  onTap: () => _showAllOccurrences(
                    slots,
                    data.cancelled,
                    data.completed,
                  ),
                );
              }

              return _ProgrammedBand.listChips(
                title: 'Fechas programadas',
                items: slots.map((dt) {
                  final ymd = _ymd(dt);
                  final isCancelled = data.cancelled.contains(ymd);
                  final isCompleted = data.completed.contains(ymd);
                  return _OccurrenceChip(
                    text: _fmtChip(dt),
                    isCancelled: isCancelled,
                    isCompleted: isCompleted,
                    onTap: () => _openOccurrenceSheet(
                      dt,
                      isCancelled: isCancelled,
                      isCompleted: isCompleted,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],

        // Botones
        _buildActions(context),
      ],
    );

    final isActivo =
        widget.trip.estado == TripStatus.enCurso ||
        widget.trip.estado == TripStatus.enCamino ||
        isEnLugar;
    final gradient = isActivo ? _getCardGradient(widget.trip.estado) : null;

    final cardContent = Card(
      elevation: 0,
      color: gradient == null ? Colors.white : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: gradient != null
            ? BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(20),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: cardBody,
        ),
      ),
    );

    final decoratedCard = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: isEnLugar
            ? [
                BoxShadow(
                  color: verdeMedio.withOpacity(.55),
                  blurRadius: 5,
                  spreadRadius: 2,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: verdeClaro.withOpacity(.35),
                  blurRadius: 5,
                  spreadRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : isActivo
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: cardContent,
      ),
    );

    if (isActivo) {
      return ScaleTransition(scale: _pulseAnimation, child: decoratedCard);
    }

    return decoratedCard;
  }

  // ===== Helpers UI para “ver todas” en rango largo =====
  Future<void> _showAllOccurrences(
    List<DateTime> slots,
    Set<String> cancelled,
    Set<String> completed,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Todas las fechas',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: slots.map((dt) {
                        final ymd = _ymd(dt);
                        final isCancelled = cancelled.contains(ymd);
                        final isCompleted = completed.contains(ymd);
                        return _OccurrenceChip(
                          text: _fmtChip(dt),
                          isCancelled: isCancelled,
                          isCompleted: isCompleted,
                          onTap: () => _openOccurrenceSheet(
                            dt,
                            isCancelled: isCancelled,
                            isCompleted: isCompleted,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ====== Banda visual (verde suave) y variantes ======
class _ProgrammedBand extends StatelessWidget {
  const _ProgrammedBand._({required this.child, this.onTap});

  factory _ProgrammedBand.loading() => const _ProgrammedBand._(
    child: Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 8),
        Text('Cargando fechas...', style: TextStyle(fontSize: 13)),
      ],
    ),
  );

  factory _ProgrammedBand.single({required String text}) => _ProgrammedBand._(
    child: Row(
      children: [
        Icon(Icons.calendar_month_rounded, size: 20, color: Colors.black54),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  factory _ProgrammedBand.listChips({
    required String title,
    required List<Widget> items,
  }) => _ProgrammedBand._(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.calendar_month_rounded, size: 20, color: Colors.black54),
            SizedBox(width: 8),
            Text(
              'Fechas programadas',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: items),
      ],
    ),
  );

  factory _ProgrammedBand.range({
    required String rangoResumen,
    required int count,
    VoidCallback? onTap,
  }) => _ProgrammedBand._(
    onTap: onTap,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.date_range_rounded, size: 20, color: Colors.black54),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rangoResumen,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$count ocurrencias programadas • Toca para ver todas',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCCE6D2)),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: box,
    );
  }
}

// ====== Chip de ocurrencia con colores por estado y onTap ======
class _OccurrenceChip extends StatelessWidget {
  const _OccurrenceChip({
    required this.text,
    required this.isCancelled,
    required this.isCompleted,
    required this.onTap,
  });

  final String text;
  final bool isCancelled;
  final bool isCompleted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color border;

    if (isCompleted) {
      bg = Colors.green;
      fg = Colors.white;
      border = Colors.green;
    } else if (isCancelled) {
      bg = const Color(0xFFFFEBEE);
      fg = const Color(0xFFC62828);
      border = const Color(0xFFFFCDD2);
    } else {
      bg = const Color(0xFFF6F7FB);
      fg = Colors.black87;
      border = const Color(0xFFE6E8EE);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: fg,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _BadgeCount extends StatelessWidget {
  const _BadgeCount({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final txt = (count > 99) ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Text(
        txt,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
    );
  }
}
