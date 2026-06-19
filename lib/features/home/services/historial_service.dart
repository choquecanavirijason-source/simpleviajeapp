import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:buses2/features/home/data/trip.dart';

class HistorialService {
  final FirebaseFirestore _db;
  HistorialService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  /// /ordenesPasajeros/{uid}/ordenes  (realtime)
  Stream<List<Trip>> streamOrdenesNormales(String uid) {
    final ref = _db
        .collection('ordenesPasajeros')
        .doc(uid)
        .collection('ordenes')
        .orderBy('createdAt', descending: true);

    return ref.snapshots().map((qs) {
      return qs.docs
          .map(
            (d) => _mapTripNormal(
              id: d.id,
              uidPasajeroFromPath: uid, // 👈 lo traemos del path
              m: asMap(d.data()),
            ),
          )
          .toList();
    });
  }

  /// /ordenesPasajeros/{uid}/ordenesProgramados  (realtime)
  Stream<List<Trip>> streamOrdenesProgramados(String uid) {
    final ref = _db
        .collection('ordenesPasajeros')
        .doc(uid)
        .collection('ordenesProgramados')
        .orderBy('createdAt', descending: true);

    return ref.snapshots().map((qs) {
      return qs.docs
          .map(
            (d) => _mapTripProgramado(
              id: d.id,
              uidPasajeroFromPath: uid, // 👈 lo traemos del path
              m: asMap(d.data()),
            ),
          )
          .toList();
    });
  }

  // ====== mapeos ======

  Trip _mapTripNormal({
    required String id,
    required String uidPasajeroFromPath,
    required Map<String, dynamic> m,
  }) {
    final origen = (m['origen'] as Map?) ?? {};
    final destino = (m['destino'] as Map?) ?? {};
    final tarifa = (m['tarifa'] as Map?) ?? {};

    final fecha = castToDate(
      m['createdAt'] ?? m['updatedAt'] ?? m['timestampLocal'],
      fallback: DateTime.now(),
    );
    final km = toDouble(((tarifa['km']) ?? m['km'])) ?? 0;
    final total = toDouble(((tarifa['total']) ?? m['total'])) ?? 0;
    final precioOfrecido = toDouble(
      tarifa['precioOfrecido'] ?? tarifa['precioOfertado'],
    );

    // extras para Ver Conductor / rutas
    final origenLat = toDouble(origen['lat']);
    final origenLng = toDouble(origen['lng']);
    final destinoLat = toDouble(destino['lat']);
    final destinoLng = toDouble(destino['lng']);

    // ids
    String? _firstNonEmpty(List<dynamic> list) {
      for (final v in list) {
        if (v == null) continue;
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
      return null;
    }

    final uidTaxista = _firstNonEmpty([
      m['uidTaxista'],
      m['idTaxista'],
      m['driverUid'],
    ]);
    final uidPasajero =
        _firstNonEmpty([
          m['uidPasajero'],
          m['idPasajero'],
          m['passengerUid'],
        ]) ??
        uidPasajeroFromPath;
    final ordenId =
        _firstNonEmpty([m['ordenId'], m['orderId'], m['idOrden']]) ?? id;
    final rutaDoc = 'ordenesPasajeros/$uidPasajeroFromPath/ordenes/$id';

    return Trip(
      id: id,
      origen: buildDireccion(origen),
      destino: buildDireccion(destino),
      fecha: fecha,
      km: km,
      precio: total,
      precioOfrecido: precioOfrecido,
      estado: parseEstado(m['estado']?.toString()),
      programado: false,
      scheduleText: null,
      // extras
      origenLat: origenLat,
      origenLng: origenLng,
      destinoLat: destinoLat,
      destinoLng: destinoLng,
      uidTaxista: uidTaxista,
      uidPasajero: uidPasajero,
      ordenId: ordenId,
      rutaDoc: rutaDoc,
    );
  }

  Trip _mapTripProgramado({
    required String id,
    required String uidPasajeroFromPath,
    required Map<String, dynamic> m,
  }) {
    final origen = (m['origen'] as Map?) ?? {};
    final destino = (m['destino'] as Map?) ?? {};
    final tarifa = (m['tarifa'] as Map?) ?? {};
    final prog = (m['programacion'] as Map?) ?? {};

    DateTime fecha = castToDate(
      m['scheduledAtLocal'] ?? m['createdAt'] ?? m['timestampLocal'],
      fallback: DateTime.now(),
    );

    final timeLocal = prog['timeLocal']?.toString();
    final datesLocal = (prog['datesLocal'] is List)
        ? List<String>.from(prog['datesLocal'])
        : <String>[];

    if (timeLocal != null && datesLocal.isNotEmpty) {
      final iso = '${datesLocal.first}T${timeLocal.padLeft(5, '0')}:00.000';
      fecha = DateTime.tryParse(iso) ?? fecha;
    }

    final km = toDouble(((tarifa['km']) ?? m['km'])) ?? 0;
    final total = toDouble(((tarifa['total']) ?? m['total'])) ?? 0;
    final precioOfrecido = toDouble(
      tarifa['precioOfrecido'] ?? tarifa['precioOfertado'],
    );

    String? scheduleText;
    if (timeLocal != null && datesLocal.isNotEmpty) {
      scheduleText =
          '${_fmtFechaCorta(datesLocal.first)} · ${_fmtHoraCorta(timeLocal)}';
    } else if (m['scheduledAtLocal'] != null) {
      final dt = DateTime.tryParse(m['scheduledAtLocal'].toString());
      if (dt != null) {
        scheduleText =
            '${_fmtFechaCorta(dt.toIso8601String().substring(0, 10))} · ${_fmtHoraCortaTime(dt)}';
      }
    }

    // extras para Ver Conductor / rutas
    final origenLat = toDouble(origen['lat']);
    final origenLng = toDouble(origen['lng']);
    final destinoLat = toDouble(destino['lat']);
    final destinoLng = toDouble(destino['lng']);

    String? _firstNonEmpty(List<dynamic> list) {
      for (final v in list) {
        if (v == null) continue;
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
      return null;
    }

    final uidTaxista = _firstNonEmpty([
      m['uidTaxista'],
      m['idTaxista'],
      m['driverUid'],
    ]);
    final uidPasajero =
        _firstNonEmpty([
          m['uidPasajero'],
          m['idPasajero'],
          m['passengerUid'],
        ]) ??
        uidPasajeroFromPath;
    final ordenId =
        _firstNonEmpty([m['ordenId'], m['orderId'], m['idOrden']]) ?? id;
    final rutaDoc =
        'ordenesPasajeros/$uidPasajeroFromPath/ordenesProgramados/$id';

    final estadoRaw = m['estado']?.toString();
    final estadoParsed = estadoRaw != null
        ? parseEstado(estadoRaw)
        : TripStatus.programado;

    // Debug log para ver estados
    if (estadoRaw != null) {
      print(
        '📋 Viaje programado $id - Estado raw: "$estadoRaw" → Parsed: $estadoParsed',
      );
    }

    return Trip(
      id: id,
      origen: buildDireccion(origen),
      destino: buildDireccion(destino),
      fecha: fecha,
      km: km,
      precio: total,
      precioOfrecido: precioOfrecido,
      estado: estadoParsed,
      programado: true,
      scheduleText: scheduleText,
      // extras
      origenLat: origenLat,
      origenLng: origenLng,
      destinoLat: destinoLat,
      destinoLng: destinoLng,
      uidTaxista: uidTaxista,
      uidPasajero: uidPasajero,
      ordenId: ordenId,
      rutaDoc: rutaDoc,
    );
  }

  // ====== helpers locales ======

  static String _fmtFechaCorta(String yyyyMmDd) {
    if (yyyyMmDd.length >= 10) {
      final y = yyyyMmDd.substring(0, 4);
      final m = yyyyMmDd.substring(5, 7);
      final d = yyyyMmDd.substring(8, 10);
      return '$d/$m/$y';
    }
    return yyyyMmDd;
  }

  static String _fmtHoraCorta(String hhmm) => hhmm;

  static String _fmtHoraCortaTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.hour)}:${two(dt.minute)}';
  }
}
