// lib/features/home_empresa_features/home_empresa/pages/dashboard/dashboard_empresa.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:buses2/shared/widgets/cards/app_card.dart';

/// Modelo simple que consume la UI
class TripCounts {
  final int passengers;
  final int scheduled;
  final int requested;
  final int active;
  final int completed;
  final int canceled;

  const TripCounts({
    required this.passengers,
    required this.scheduled,
    required this.requested,
    required this.active,
    required this.completed,
    required this.canceled,
  });

  static const zero = TripCounts(
    passengers: 0,
    scheduled: 0,
    requested: 0,
    active: 0,
    completed: 0,
    canceled: 0,
  );
}

/// UI pura: muestra contadores que vienen ya calculados
class DashboardEmpresa extends StatelessWidget {
  final DateTime day;
  final int month;
  final int year;

  final TripCounts dayCounts;
  final TripCounts monthCounts;

  final String dayTitle;
  final String monthTitle;

  final Map<String, String> statusMap;

  const DashboardEmpresa({
    super.key,
    required this.day,
    required this.month,
    required this.year,
    required this.dayCounts,
    required this.monthCounts,
    this.dayTitle = 'Por día',
    this.monthTitle = 'Totales del mes',
    this.statusMap = const {
      'pedido': 'solicitados',
      'activo': 'activos',
      'completado': 'completados',
      'cancelado': 'cancelados',
    },
  });

  @override
  Widget build(BuildContext context) {
    final dayFmt = DateFormat('EEE d MMM', 'es');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ====== POR DÍA ======
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(dayTitle, style: Theme.of(context).textTheme.titleLarge),
            Text(dayFmt.format(day)),
          ],
        ),
        const SizedBox(height: 8),
        _StatsGrid(
          loading: false,
          items: [
            _StatItem('Pasajeros', dayCounts.passengers, Icons.people_alt),
            _StatItem(
              'Programados',
              dayCounts.scheduled,
              Icons.event_available,
            ),
            _StatItem(
              _labelFor('pedido'),
              dayCounts.requested,
              Icons.outbound_rounded,
            ),
            _StatItem(
              _labelFor('activo'),
              dayCounts.active,
              Icons.directions_car_filled,
            ),
            _StatItem(
              _labelFor('completado'),
              dayCounts.completed,
              Icons.verified_rounded,
            ),
            _StatItem(
              _labelFor('cancelado'),
              dayCounts.canceled,
              Icons.cancel_rounded,
            ),
          ],
          colorScheme: Theme.of(context).colorScheme,
        ),

        const SizedBox(height: 20),

        // ====== MES ======
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(monthTitle, style: Theme.of(context).textTheme.titleLarge),
            Text(
              DateFormat('MMMM yyyy', 'es').format(DateTime(year, month)),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _StatsGrid(
          loading: false,
          items: [
            _StatItem('Pasajeros', monthCounts.passengers, Icons.people_alt),
            _StatItem(
              'Programados',
              monthCounts.scheduled,
              Icons.event_available,
            ),
            _StatItem(
              _labelFor('pedido'),
              monthCounts.requested,
              Icons.outbound_rounded,
            ),
            _StatItem(
              _labelFor('activo'),
              monthCounts.active,
              Icons.directions_car_filled,
            ),
            _StatItem(
              _labelFor('completado'),
              monthCounts.completed,
              Icons.verified_rounded,
            ),
            _StatItem(
              _labelFor('cancelado'),
              monthCounts.canceled,
              Icons.cancel_rounded,
            ),
          ],
          colorScheme: Theme.of(context).colorScheme,
        ),
      ],
    );
  }

  String _labelFor(String key) => statusMap[key] ?? key;
}

/// ======= UI helpers =======
class _StatItem {
  final String label;
  final int value;
  final IconData icon;
  _StatItem(this.label, this.value, this.icon);
}

class _StatsGrid extends StatelessWidget {
  final List<_StatItem> items;
  final bool loading;
  final ColorScheme colorScheme;
  const _StatsGrid({
    required this.items,
    required this.colorScheme,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    const double itemHeight = 130;

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: loading
          ? const SizedBox(
              height: 96,
              child: Center(child: CircularProgressIndicator()),
            )
          : GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: itemHeight,
              ),
              itemBuilder: (_, i) {
                final it = items[i];
                return Container(
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 12,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(it.icon, size: 22, color: colorScheme.primary),
                      const SizedBox(height: 6),
                      Text(
                        '${it.value}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        it.label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
