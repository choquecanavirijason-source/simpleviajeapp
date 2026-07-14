// lib/features/home_empresa_features/home_empresa/home_empresa_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:buses2/features/home_empresa_features/home_empresa/pages/dashboard/dashboard_empresa.dart';
import 'package:buses2/features/home_empresa_features/home_empresa/widgets/calendario.dart';
import 'package:buses2/features/home_empresa_features/home_empresa/widgets/menu_lateral.dart';
import 'package:buses2/shared/widgets/app_bar/app_bar.dart';

import 'package:buses2/features/home_empresa_features/home_empresa/services/dashboard_servicios.dart';
import 'package:buses2/shared/theme/app_colors.dart';

class HomeEmpresa extends StatefulWidget {
  const HomeEmpresa({super.key});

  @override
  State<HomeEmpresa> createState() => _HomeEmpresaState();
}

class _HomeEmpresaState extends State<HomeEmpresa> {
  final _ds = DashboardServicios();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  DateTime _day = DateTime.now();

  // Conteos que consume la UI
  TripCounts _dayCounts = TripCounts.zero;
  TripCounts _monthCounts = TripCounts.zero;

  // Flags de carga (para botones de refresco)
  bool _loadingPassengers = true;
  bool _loadingScheduled = true;
  bool _loadingRequested = true;

  @override
  void initState() {
    super.initState();
    _loadAllFor(_day);
  }

  Future<void> _loadAllFor(DateTime day) async {
    await Future.wait([
      _loadPassengersCount(),
      _loadScheduledCountsFor(day),
      _loadRequestedCountsFor(day),
    ]);
  }

  // ===== Pasajeros (total /pasajeros)
  Future<void> _loadPassengersCount() async {
    setState(() => _loadingPassengers = true);
    final total = await _ds.fetchPassengersCount();
    if (!mounted) return;
    setState(() {
      _dayCounts = _dayCounts.copyWith(passengers: total);
      _monthCounts = _monthCounts.copyWith(passengers: total);
      _loadingPassengers = false;
    });
  }

  // ===== Programados (programados por día/mes)
  Future<void> _loadScheduledCountsFor(DateTime day) async {
    setState(() => _loadingScheduled = true);
    final perDay = await _ds.fetchScheduledTripsCountForDay(day);
    final perMonth = await _ds.fetchScheduledTripsCountForMonth(
      day.year,
      day.month,
    );
    if (!mounted) return;
    setState(() {
      _dayCounts = _dayCounts.copyWith(scheduled: perDay);
      _monthCounts = _monthCounts.copyWith(scheduled: perMonth);
      _loadingScheduled = false;
    });
  }

  // ===== Solicitados (viajes normales /ordenes con estado 'pedido')
  Future<void> _loadRequestedCountsFor(DateTime day) async {
    setState(() => _loadingRequested = true);
    final perDay = await _ds.fetchRequestedTripsCountForDay(day);
    final perMonth = await _ds.fetchRequestedTripsCountForMonth(
      day.year,
      day.month,
    );
    if (!mounted) return;
    setState(() {
      _dayCounts = _dayCounts.copyWith(requested: perDay);
      _monthCounts = _monthCounts.copyWith(requested: perMonth);
      _loadingRequested = false;
    });
  }

  Future<void> _pickDayFromModal() async {
    final picked = await showCalendarDiaEsModal(
      context,
      initialDate: _day,
      minDate: DateTime(DateTime.now().year - 5, 1, 1),
      title: 'Elegir día',
      primaryColor: AppColors.navy,
    );
    if (!mounted) return;
    if (picked != null) {
      setState(() => _day = picked);
      _loadScheduledCountsFor(picked);
      _loadRequestedCountsFor(picked);
      // Pasajeros es total global; refresca si quieres:
      // _loadPassengersCount();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayLabel = DateFormat('EEE d MMM', 'es').format(_day);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar1(
        titleSize: TitleSize.big,
        titulo: "Modo Empresa",
        leftAction: LeftAction.custom,
        iconoIzquierda: Icons.menu,
        onTapIzquierda: () {
          debugPrint('🟢 [HomeEmpresa] tap menú — abriendo drawer');
          final st = _scaffoldKey.currentState;
          debugPrint('🟢 [HomeEmpresa] scaffold state: $st');
          st?.openDrawer();
        },
        iconoDerecha: Icons.business,
        onTapDerecha: () => debugPrint('Ajustes'),
      ),
      drawer: const EmpresaDrawer(
        fotoPerfilUrl: 'https://tu-servidor.com/foto.jpg',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Controles superiores
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickDayFromModal,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(dayLabel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    elevation: 0,
                  ),
                ),
                const Spacer(),
                // Refrescar Programados
                IconButton(
                  tooltip: 'Refrescar programados',
                  onPressed: _loadingScheduled
                      ? null
                      : () => _loadScheduledCountsFor(_day),
                  icon: _loadingScheduled
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.event_available),
                ),
                // Refrescar Solicitados
                IconButton(
                  tooltip: 'Refrescar solicitados',
                  onPressed: _loadingRequested
                      ? null
                      : () => _loadRequestedCountsFor(_day),
                  icon: _loadingRequested
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.outbound_rounded),
                ),
                // Refrescar Pasajeros
                IconButton(
                  tooltip: 'Refrescar pasajeros',
                  onPressed: _loadingPassengers ? null : _loadPassengersCount,
                  icon: _loadingPassengers
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.people_alt),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Dashboard (UI pura)
            DashboardEmpresa(
              day: _day,
              month: _day.month,
              year: _day.year,
              dayCounts: _dayCounts,
              monthCounts: _monthCounts,
              dayTitle: 'Por día',
              monthTitle: 'Totales del mes',
              statusMap: const {
                'pedido': 'solicitados',
                'activo': 'activos',
                'completado': 'completados',
                'cancelado': 'cancelados',
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ===== helper para copiar TripCounts (UI) =====
extension _TripCountsCopy on TripCounts {
  TripCounts copyWith({
    int? passengers,
    int? scheduled,
    int? requested,
    int? active,
    int? completed,
    int? canceled,
  }) {
    return TripCounts(
      passengers: passengers ?? this.passengers,
      scheduled: scheduled ?? this.scheduled,
      requested: requested ?? this.requested,
      active: active ?? this.active,
      completed: completed ?? this.completed,
      canceled: canceled ?? this.canceled,
    );
  }
}
