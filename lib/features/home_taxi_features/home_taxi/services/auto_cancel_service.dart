import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

/// Servicio para cancelar automáticamente:
///  - Viajes normales en estado 'pedido' después de 5 minutos
///  - Viajes programados en estado 'pedido' cuyo horario programado ya venció
class AutoCancelService {
  static final AutoCancelService _instance = AutoCancelService._internal();
  factory AutoCancelService() => _instance;
  AutoCancelService._internal();

  final Map<String, Timer> _timers = {};
  StreamSubscription<QuerySnapshot>? _ordersSubscription;
  bool _isActive = false;

  // Timer para programados
  Timer? _programadosTimer;

  /// Inicia el monitoreo de órdenes normales para cancelación automática (5 min)
  void startMonitoring() {
    if (_isActive) return;
    _isActive = true;

    if (kDebugMode) {
      debugPrint(
        '🕐 AutoCancelService: Iniciando monitoreo de cancelación automática (normales)',
      );
    }

    // Escuchar todos los cambios en ordenes (viajes normales)
    _ordersSubscription = FirebaseFirestore.instance
        .collectionGroup('ordenes')
        .where('estado', isEqualTo: 'pedido')
        .snapshots()
        .listen(
          (snapshot) {
            for (var change in snapshot.docChanges) {
              final doc = change.doc;
              final data = doc.data();

              if (data == null) continue;

              // Identificar si es programado
              final isProgramado = _isProgramado(data);

              if (change.type == DocumentChangeType.added && !isProgramado) {
                _scheduleAutoCancellation(doc);
              } else if (change.type == DocumentChangeType.modified) {
                final newEstado = data['estado']?.toString();

                // Si cambió de estado, cancelar el timer
                if (newEstado != 'pedido') {
                  _cancelTimer(doc.id);
                }
              } else if (change.type == DocumentChangeType.removed) {
                _cancelTimer(doc.id);
              }
            }
          },
          onError: (error) {
            if (kDebugMode) {
              debugPrint('🟥 AutoCancelService: Error en monitoreo: $error');
            }
          },
        );
  }

  /// Detiene el monitoreo y cancela todos los timers
  void stopMonitoring() {
    if (kDebugMode) {
      debugPrint('🛑 AutoCancelService: Deteniendo monitoreo');
    }

    _isActive = false;
    _ordersSubscription?.cancel();
    _ordersSubscription = null;

    // Cancelar todos los timers activos (normales)
    for (var timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();

    // Detener monitoreo de programados
    stopMonitoringProgramados();
  }

  /// Verifica si una orden es programada
  bool _isProgramado(Map<String, dynamic> data) {
    // Verificar flags directos
    if (data['isProgramado'] == true ||
        data['programado'] == true ||
        data['tipo'] == 'programado') {
      return true;
    }

    // Verificar si tiene programación
    if (data['programacion'] != null) {
      return true;
    }

    return false;
  }

  /// Programa la cancelación automática de una orden (viaje normal)
  void _scheduleAutoCancellation(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return;

    // Verificar que tenga createdAt
    final createdAt = data['createdAt'];
    DateTime? createdDate;

    if (createdAt is Timestamp) {
      createdDate = createdAt.toDate();
    } else if (createdAt is String) {
      createdDate = DateTime.tryParse(createdAt);
    }

    if (createdDate == null) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ AutoCancelService: Orden ${doc.id} sin createdAt válido',
        );
      }
      return;
    }

    // Calcular tiempo restante hasta los 5 minutos
    final now = DateTime.now();
    final elapsed = now.difference(createdDate);
    const cancelDuration = Duration(minutes: 5);
    final remaining = cancelDuration - elapsed;

    if (remaining.isNegative) {
      // Ya pasaron los 5 minutos, cancelar inmediatamente
      if (kDebugMode) {
        debugPrint(
          '⏰ AutoCancelService: Orden ${doc.id} ya expiró, cancelando ahora',
        );
      }
      _cancelOrder(doc);
      return;
    }

    // Cancelar timer anterior si existe
    _cancelTimer(doc.id);

    if (kDebugMode) {
      debugPrint(
        '⏲️ AutoCancelService: Orden ${doc.id} se cancelará en ${remaining.inSeconds}s',
      );
    }

    // Crear nuevo timer
    _timers[doc.id] = Timer(remaining, () {
      _cancelOrder(doc);
      _timers.remove(doc.id);
    });
  }

  /// Cancela el timer de una orden normal
  void _cancelTimer(String orderId) {
    final timer = _timers.remove(orderId);
    timer?.cancel();

    if (kDebugMode && timer != null) {
      debugPrint('✋ AutoCancelService: Timer cancelado para orden $orderId');
    }
  }

  /// Cancela una orden normal en Firestore (por timeout de 5 min)
  Future<void> _cancelOrder(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return;

      // Verificar el estado actual antes de cancelar
      final currentState = data['estado']?.toString();
      if (currentState != 'pedido') {
        if (kDebugMode) {
          debugPrint(
            '⏭️ AutoCancelService: Orden ${doc.id} ya no está en estado pedido (actual: $currentState)',
          );
        }
        return;
      }

      if (kDebugMode) {
        debugPrint(
          '❌ AutoCancelService: Cancelando orden ${doc.id} por timeout',
        );
      }

      // Actualizar estado a cancelado
      await doc.reference.update({
        'estado': 'cancelado',
        'canceladoPor': 'sistema',
        'motivoCancelacion': 'Tiempo de espera agotado (5 minutos)',
        'canceladoAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        debugPrint(
          '✅ AutoCancelService: Orden ${doc.id} cancelada exitosamente',
        );
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          '🟥 AutoCancelService: Error al cancelar orden ${doc.id}: $e',
        );
        debugPrint('Stack: $st');
      }
    }
  }

  /// Obtiene información de debug sobre timers activos (normales)
  Map<String, dynamic> getDebugInfo() {
    return {
      'isActive': _isActive,
      'activeTimers': _timers.length,
      'timerIds': _timers.keys.toList(),
    };
  }

  // ===========================================================
  // Monitoreo de viajes PROGRAMADOS
  // ===========================================================

  /// Inicia un monitoreo periódico de viajes programados en estado "pedido".
  /// Se cancelan cuando su horario programado (endLocal + timeLocal) ya venció.
  void startMonitoringProgramados() {
    if (_programadosTimer != null) return;

    if (kDebugMode) {
      debugPrint(
        '🕐 AutoCancelService: Iniciando monitoreo de viajes programados',
      );
    }

    // Ejecuta una vez al inicio
    _checkAndCancelExpiredProgramados();

    // Y luego cada minuto
    _programadosTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkAndCancelExpiredProgramados(),
    );
  }

  /// Detiene el monitoreo de programados
  void stopMonitoringProgramados() {
    if (kDebugMode) {
      debugPrint(
        '🛑 AutoCancelService: Deteniendo monitoreo de viajes programados',
      );
    }
    _programadosTimer?.cancel();
    _programadosTimer = null;
  }

  /// Revisa todos los viajes programados en estado "pedido" (cualquier pasajero)
  /// y los marca como cancelados si ya pasaron de su horario programado.
  Future<void> _checkAndCancelExpiredProgramados() async {
    try {
      final now = DateTime.now();

      final querySnap = await FirebaseFirestore.instance
          .collectionGroup('ordenesProgramados')
          .where('estado', isEqualTo: 'pedido')
          .get();

      if (querySnap.docs.isEmpty) return;

      if (kDebugMode) {
        debugPrint(
          '🔍 AutoCancelService: Revisando ${querySnap.docs.length} viajes programados en estado "pedido".',
        );
      }

      for (final doc in querySnap.docs) {
        final data = doc.data();
        final scheduled = _getProgramadoDateTime(data);
        if (scheduled == null) continue;

        // Si la fecha/hora límite del programado ya pasó, se cancela
        if (scheduled.isBefore(now)) {
          if (kDebugMode) {
            debugPrint(
              '⛔ AutoCancelService: Cancelando programado ${doc.id} - '
              'programado hasta $scheduled (ahora: $now)',
            );
          }

          await doc.reference.update({
            'estado': 'cancelado',
            'canceladoPor': 'sistema',
            'motivoCancelacion': 'Horario de viaje programado vencido',
            'canceladoAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('🟥 AutoCancelService: Error al revisar programados: $e');
        debugPrint('Stack: $st');
      }
    }
  }

  /// Obtiene la fecha/hora límite del viaje programado.
  ///
  /// Para `programacion.mode == "range"`:
  ///   - Usa `endLocal` + `timeLocal` como momento de fin del rango.
  /// Si no hay `range`, usa:
  ///   - `scheduledAtLocal`
  ///   - luego `timestampLocal` como fallback.
  DateTime? _getProgramadoDateTime(Map<String, dynamic> data) {
    // 1) programacion.range + timeLocal
    if (data['programacion'] is Map) {
      final prog = Map<String, dynamic>.from(data['programacion']);
      final range = (prog['range'] is Map)
          ? Map<String, dynamic>.from(prog['range'])
          : const <String, dynamic>{};

      final mode = (prog['mode'] ?? '').toString();

      String? baseStr;

      if (mode == 'range') {
        // Para rangos, consideramos que "termina" en endLocal
        baseStr = (range['endLocal'] ?? range['end'])?.toString();
        baseStr ??= (range['startLocal'] ?? range['start'])?.toString();
      } else {
        // Otros modos → usamos startLocal como base
        baseStr = (range['startLocal'] ?? range['start'])?.toString();
      }

      final timeStr = (range['timeLocal'] ?? prog['timeLocal'])?.toString();

      if (baseStr != null && baseStr.length >= 10) {
        // Nos quedamos con "yyyy-MM-dd"
        final datePart = baseStr.substring(0, 10); // ej: "2025-11-26"
        final base = DateTime.tryParse('${datePart}T00:00:00.000');
        if (base != null) {
          if (timeStr != null && timeStr.length >= 5) {
            // timeLocal tipo "HH:mm"
            final hh = int.tryParse(timeStr.substring(0, 2)) ?? 0;
            final mm = int.tryParse(timeStr.substring(3, 5)) ?? 0;
            return DateTime(base.year, base.month, base.day, hh, mm);
          } else {
            // Sin hora → medianoche del endLocal/startLocal
            return base;
          }
        }
      }
    }

    // 2) scheduledAtLocal (ej: "2025-11-19T04:20:00.000")
    final schedLocal = data['scheduledAtLocal']?.toString();
    if (schedLocal != null && schedLocal.isNotEmpty) {
      final dt = DateTime.tryParse(schedLocal);
      if (dt != null) return dt;
    }

    // 3) timestampLocal (fecha/hora de creación del programado)
    final tsLocal = data['timestampLocal']?.toString();
    if (tsLocal != null && tsLocal.isNotEmpty) {
      final dt = DateTime.tryParse(tsLocal);
      if (dt != null) return dt;
    }

    // 4) Nada válido
    return null;
  }
}
