import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:buses2/features/home/data/trip.dart';
import 'package:rxdart/rxdart.dart';

/// Servicio para obtener el historial de viajes de un TAXISTA
/// Lee de collectionGroup('ordenes') filtrando por uidTaxista
class HistorialTaxistaService {
  final FirebaseFirestore _db;

  HistorialTaxistaService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  /// Stream de todas las órdenes donde el taxista es el conductor
  /// Incluye órdenes normales y programadas
  Stream<List<Trip>> streamOrdenesTaxista(String uidTaxista) {
    final Stream<List<Trip>> streamInmediatas = _db
        .collectionGroup('ordenes')
        .where('uidTaxista', isEqualTo: uidTaxista)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((qs) {
          return qs.docs.map((d) {
            final m = asMap(d.data());
            return _mapTrip(
              id: d.id,
              m: m,
              docRef: d.reference,
              isProgramado: false, // No es programada
            );
          }).toList();
        });

    final Stream<List<Trip>> streamProgramadas = _db
        .collectionGroup('ordenesProgramados')
        .where('uidTaxista', isEqualTo: uidTaxista)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((qs) {
          return qs.docs.map((d) {
            final m = asMap(d.data());
            return _mapTrip(
              id: d.id,
              m: m,
              docRef: d.reference,
              isProgramado: true, // Es programada
            );
          }).toList();
        });

    return CombineLatestStream.list<List<Trip>>([
      streamInmediatas,
      streamProgramadas,
    ]).map((listOfLists) {
      final allTrips = listOfLists.expand((list) => list).toList();

      return allTrips;
    });
  }

  /// También consultar ordenesProgramados si los taxistas las aceptan
  Stream<List<Trip>> streamOrdenesProgramadasTaxista(String uidTaxista) {
    final ref = _db
        .collectionGroup('ordenesProgramados')
        .where('uidTaxista', isEqualTo: uidTaxista)
        .orderBy('createdAt', descending: true)
        .limit(50);

    return ref.snapshots().map((qs) {
      return qs.docs.map((d) {
        final m = asMap(d.data());
        return _mapTrip(
          id: d.id,
          m: m,
          docRef: d.reference,
          isProgramado: true,
        );
      }).toList();
    });
  }

  // ====== Mapeo de Trip ======

  Trip _mapTrip({
    required String id,
    required Map<String, dynamic> m,
    required DocumentReference docRef,
    bool isProgramado = false,
  }) {
    final origen =
        (m['origen'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final destino =
        (m['destino'] as Map<String, dynamic>?) ?? <String, dynamic>{};
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

    // Coordenadas
    final origenLat = toDouble(origen['lat']);
    final origenLng = toDouble(origen['lng']);
    final destinoLat = toDouble(destino['lat']);
    final destinoLng = toDouble(destino['lng']);

    // Helper para IDs
    String? firstNonEmpty(List<dynamic> list) {
      for (final v in list) {
        if (v == null) continue;
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
      return null;
    }

    // IDs con fallbacks
    final uidTaxista = firstNonEmpty([
      m['uidTaxista'],
      m['idTaxista'],
      m['driverUid'],
    ]);
    final uidPasajero = firstNonEmpty([
      m['uidPasajero'],
      m['idPasajero'],
      m['passengerUid'],
    ]);
    final ordenId =
        firstNonEmpty([m['ordenId'], m['orderId'], m['idOrden']]) ?? id;

    // Extraer rutaDoc del DocumentReference
    final rutaDoc = docRef.path;

    // Schedule text para programados
    String? scheduleText;
    if (isProgramado) {
      final prog = (m['programacion'] as Map?) ?? {};
      final timeLocal = (prog['timeLocal'] ?? prog['range']?['timeLocal'])
          ?.toString();
      if (timeLocal != null) {
        scheduleText = 'Programado: $timeLocal';
      }
    }

    return Trip(
      id: id,
      origen: buildDireccion(origen),
      destino: buildDireccion(destino),
      fecha: fecha,
      km: km,
      precio: total,
      precioOfrecido: precioOfrecido,
      estado: parseEstado(m['estado']?.toString()),
      programado: isProgramado,
      scheduleText: scheduleText,
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
}

// ====== Helpers globales (copiados de HistorialService) ======

Map<String, dynamic> asMap(Object? o) =>
    (o is Map) ? Map<String, dynamic>.from(o) : const {};

double? toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

DateTime castToDate(dynamic v, {DateTime? fallback}) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) {
    final parsed = DateTime.tryParse(v);
    if (parsed != null) return parsed;
  }
  return fallback ?? DateTime.now();
}

String buildDireccion(Map<String, dynamic> m) {
  final calle = (m['calle'] ?? m['street'] ?? '').toString().trim();
  final ciudad = (m['ciudad'] ?? m['city'] ?? '').toString().trim();
  final pais = (m['pais'] ?? m['country'] ?? '').toString().trim();
  final texto = (m['texto'] ?? m['text'] ?? '').toString().trim();

  if (texto.isNotEmpty) return texto;

  final parts = <String>[];
  if (calle.isNotEmpty) parts.add(calle);
  if (ciudad.isNotEmpty) parts.add(ciudad);
  if (pais.isNotEmpty) parts.add(pais);

  return parts.isNotEmpty ? parts.join(', ') : 'Sin dirección';
}
