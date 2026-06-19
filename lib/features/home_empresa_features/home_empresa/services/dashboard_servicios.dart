// lib/features/home_empresa_features/home_empresa/services/dashboard_servicios.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Servicio de métricas para el Dashboard: pasajeros, programados y solicitados.
class DashboardServicios {
  final FirebaseFirestore _db;

  // Subcolecciones (collectionGroup)
  final String
  scheduledCollectionGroup; // /ordenesPasajeros/{uid}/ordenesProgramados/{doc}
  final String
  normalOrdersCollectionGroup; // /ordenesPasajeros/{uid}/ordenes/{doc}

  // Campos
  final String estadoField; // 'estado'
  final String tipoField; // 'tipo'
  final String tipoProgramado; // 'programado'
  final String createdAtField; // 'createdAt' (Timestamp)

  // Estados válidos para “programados”
  static const List<String> scheduledStates = <String>[
    'aceptado taxista',
    'aceptado pasajero',
    'activo',
    'completado',
  ];

  DashboardServicios({
    FirebaseFirestore? db,
    this.scheduledCollectionGroup = 'ordenesProgramados',
    this.normalOrdersCollectionGroup = 'ordenes',
    this.estadoField = 'estado',
    this.tipoField = 'tipo',
    this.tipoProgramado = 'programado',
    this.createdAtField = 'createdAt',
  }) : _db = db ?? FirebaseFirestore.instance;

  // ===================== PASAJEROS (total) =====================
  Future<int> fetchPassengersCount() async {
    try {
      final agg = await _db.collection('pasajeros').count().get();
      return agg.count ?? 0;
    } catch (e, st) {
      debugPrint('[DashboardServicios] pasajeros error: $e\n$st');
      return 0;
    }
  }

  // ===================== PROGRAMADOS (por día) =====================
  Future<int> fetchScheduledTripsCountForDay(DateTime dayLocal) async {
    final start = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
    final end = start.add(const Duration(days: 1));

    try {
      final q = _db
          .collectionGroup(scheduledCollectionGroup)
          .where(tipoField, isEqualTo: tipoProgramado)
          .where(estadoField, whereIn: scheduledStates)
          .where(
            createdAtField,
            isGreaterThanOrEqualTo: Timestamp.fromDate(start),
          )
          .where(createdAtField, isLessThan: Timestamp.fromDate(end));

      try {
        final agg = await q.count().get();
        return agg.count ?? 0;
      } catch (_) {
        final snap = await q.get();
        return snap.size;
      }
    } catch (e, st) {
      debugPrint('[DashboardServicios] scheduled/day error: $e\n$st');
      // Fallback: solo rango por fecha y contar en cliente por estado
      try {
        final snap = await _db
            .collectionGroup(scheduledCollectionGroup)
            .where(
              createdAtField,
              isGreaterThanOrEqualTo: Timestamp.fromDate(start),
            )
            .where(createdAtField, isLessThan: Timestamp.fromDate(end))
            .get();

        int total = 0;
        for (final d in snap.docs) {
          final st = ((d.data()[estadoField] as String?) ?? '')
              .trim()
              .toLowerCase();
          if (scheduledStates.contains(st)) total++;
        }
        return total;
      } catch (_) {
        return 0;
      }
    }
  }

  // ===================== PROGRAMADOS (por mes) =====================
  Future<int> fetchScheduledTripsCountForMonth(int year, int month) async {
    final first = DateTime(year, month, 1);
    final next = (month == 12)
        ? DateTime(year + 1, 1, 1)
        : DateTime(year, month + 1, 1);

    try {
      final q = _db
          .collectionGroup(scheduledCollectionGroup)
          .where(tipoField, isEqualTo: tipoProgramado)
          .where(estadoField, whereIn: scheduledStates)
          .where(
            createdAtField,
            isGreaterThanOrEqualTo: Timestamp.fromDate(first),
          )
          .where(createdAtField, isLessThan: Timestamp.fromDate(next));

      try {
        final agg = await q.count().get();
        return agg.count ?? 0;
      } catch (_) {
        final snap = await q.get();
        return snap.size;
      }
    } catch (e, st) {
      debugPrint('[DashboardServicios] scheduled/month error: $e\n$st');
      // Fallback: solo rango y conteo en cliente
      try {
        final snap = await _db
            .collectionGroup(scheduledCollectionGroup)
            .where(
              createdAtField,
              isGreaterThanOrEqualTo: Timestamp.fromDate(first),
            )
            .where(createdAtField, isLessThan: Timestamp.fromDate(next))
            .get();

        int total = 0;
        for (final d in snap.docs) {
          final st = ((d.data()[estadoField] as String?) ?? '')
              .trim()
              .toLowerCase();
          if (scheduledStates.contains(st)) total++;
        }
        return total;
      } catch (_) {
        return 0;
      }
    }
  }

  // ===================== SOLICITADOS (viajes normales /ordenes) =====================
  // -------- por día (estado == 'pedido') --------
  Future<int> fetchRequestedTripsCountForDay(DateTime dayLocal) async {
    final start = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
    final end = start.add(const Duration(days: 1));

    try {
      final q = _db
          .collectionGroup(normalOrdersCollectionGroup)
          .where(estadoField, isEqualTo: 'pedido')
          .where(
            createdAtField,
            isGreaterThanOrEqualTo: Timestamp.fromDate(start),
          )
          .where(createdAtField, isLessThan: Timestamp.fromDate(end));

      try {
        final agg = await q.count().get();
        return agg.count ?? 0;
      } catch (_) {
        final snap = await q.get();
        return snap.size;
      }
    } catch (e, st) {
      debugPrint('[DashboardServicios] requested/day error: $e\n$st');
      // Fallback: solo rango por fecha y contar en cliente
      try {
        final snap = await _db
            .collectionGroup(normalOrdersCollectionGroup)
            .where(
              createdAtField,
              isGreaterThanOrEqualTo: Timestamp.fromDate(start),
            )
            .where(createdAtField, isLessThan: Timestamp.fromDate(end))
            .get();

        int total = 0;
        for (final d in snap.docs) {
          final st = ((d.data()[estadoField] as String?) ?? '')
              .trim()
              .toLowerCase();
          if (st == 'pedido') total++;
        }
        return total;
      } catch (_) {
        return 0;
      }
    }
  }

  // -------- por mes (estado == 'pedido') --------
  Future<int> fetchRequestedTripsCountForMonth(int year, int month) async {
    final first = DateTime(year, month, 1);
    final next = (month == 12)
        ? DateTime(year + 1, 1, 1)
        : DateTime(year, month + 1, 1);

    try {
      final q = _db
          .collectionGroup(normalOrdersCollectionGroup)
          .where(estadoField, isEqualTo: 'pedido')
          .where(
            createdAtField,
            isGreaterThanOrEqualTo: Timestamp.fromDate(first),
          )
          .where(createdAtField, isLessThan: Timestamp.fromDate(next));

      try {
        final agg = await q.count().get();
        return agg.count ?? 0;
      } catch (_) {
        final snap = await q.get();
        return snap.size;
      }
    } catch (e, st) {
      debugPrint('[DashboardServicios] requested/month error: $e\n$st');
      // Fallback: rango por fecha y conteo en cliente
      try {
        final snap = await _db
            .collectionGroup(normalOrdersCollectionGroup)
            .where(
              createdAtField,
              isGreaterThanOrEqualTo: Timestamp.fromDate(first),
            )
            .where(createdAtField, isLessThan: Timestamp.fromDate(next))
            .get();

        int total = 0;
        for (final d in snap.docs) {
          final st = ((d.data()[estadoField] as String?) ?? '')
              .trim()
              .toLowerCase();
          if (st == 'pedido') total++;
        }
        return total;
      } catch (_) {
        return 0;
      }
    }
  }
}
