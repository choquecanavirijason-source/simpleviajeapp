enum TripStatus {
  programado,
  pedido,
  aceptado,
  enCamino,
  enLugar, // 👈 NUEVO ESTADO
  enCurso,
  completado,
  cancelado,
}

extension TripStatusX on TripStatus {
  bool get isActivo =>
      this == TripStatus.programado ||
      this == TripStatus.pedido ||
      this == TripStatus.aceptado ||
      this == TripStatus.enCamino ||
      this == TripStatus.enLugar || // 👈 incluye enLugar como activo
      this == TripStatus.enCurso;

  bool get isCompletado => this == TripStatus.completado;
  bool get isCancelado => this == TripStatus.cancelado;

  String get texto {
    switch (this) {
      case TripStatus.programado:
        return 'Programado';
      case TripStatus.pedido:
        return 'Pedido';
      case TripStatus.aceptado:
        return 'Aceptado';
      case TripStatus.enCamino:
        return 'En camino';
      case TripStatus.enLugar: // 👈 NUEVO
        return 'En lugar';
      case TripStatus.enCurso:
        return 'En curso';
      case TripStatus.completado:
        return 'Completado';
      case TripStatus.cancelado:
        return 'Cancelado';
    }
  }
}

TripStatus parseEstado(String? s) {
  final v = (s ?? '').trim().toLowerCase();
  switch (v) {
    case 'programado':
      return TripStatus.programado;
    case 'pedido':
      return TripStatus.pedido;
    case 'aceptado':
    case 'aceptado taxista':
    case 'aceptado pasajero':
      return TripStatus.aceptado;
    case 'en_camino':
    case 'en camino':
      return TripStatus.enCamino;
    case 'en_lugar': // 👈 NUEVO
    case 'en lugar': // 👈 NUEVO
      return TripStatus.enLugar;
    case 'en_curso':
    case 'en curso':
    case 'activo':
      return TripStatus.enCurso;
    case 'completado':
      return TripStatus.completado;
    case 'cancelado':
      return TripStatus.cancelado;
    default:
      return TripStatus.pedido;
  }
}

class Trip {
  final String id;
  final String origen;
  final String destino;
  final DateTime fecha;
  final double km;

  /// IMPORTANTE: este campo representa **tarifa.total**
  /// (no precioRecomendado). Lo usamos en la UI como "Total".
  final double precio;

  /// Precio ofrecido por el pasajero (antes de aceptar oferta de taxista)
  final double? precioOfrecido;

  final TripStatus estado;
  final bool programado;
  final String? scheduleText;

  /// ===== CAMPOS PARA "VER CONDUCTOR" / RUTAS =====
  final double? origenLat;
  final double? origenLng;
  final double? destinoLat;
  final double? destinoLng;

  /// Conductor asignado
  final String? uidTaxista;

  /// Identificadores para construir `rutaDoc` si fuese necesario
  final String? uidPasajero; // NUEVO
  final String? ordenId; // NUEVO

  /// Path absoluto del documento de la orden (si viene en el map)
  final String? rutaDoc;

  //chat de la orden
  final String? chatId;

  Trip({
    required this.id,
    required this.origen,
    required this.destino,
    required this.fecha,
    required this.km,
    required this.precio, // ← viene de tarifa.total
    required this.estado,
    this.programado = false,
    this.scheduleText,
    this.precioOfrecido, // ← viene de tarifa.precioOfrecido
    // coords
    this.origenLat,
    this.origenLng,
    this.destinoLat,
    this.destinoLng,

    // ids
    this.uidTaxista,
    this.uidPasajero, // NUEVO
    this.ordenId, // NUEVO
    this.rutaDoc,
    //opcional chat id
    this.chatId,
  });

  /// Crea Trip desde un map de Firestore.
  /// - Lee `tarifa.total` → `precio`
  /// - Lee `tarifa.km` → `km`
  /// - Lee `tarifa.precioOfrecido` → `precioOfrecido`
  /// - Construye direcciones desde `origen`/`destino`
  /// - Lee `uidTaxista`, coords, `rutaDoc`
  /// - NUEVO: lee `uidPasajero` y `ordenId` con alias alternativos
  factory Trip.fromMap(Map<String, dynamic> m, String id) {
    final origenMap = asMap(m['origen']);
    final destinoMap = asMap(m['destino']);
    final tarifa = asMap(m['tarifa']);

    final totalNum = tarifa['total'];
    final kmNum = tarifa['km'];
    final precioOfrecidoNum =
        tarifa['precioOfrecido'] ?? tarifa['precioOfertado'];

    double? _numOrNull(dynamic v) {
      if (v is num) return v.toDouble();
      final parsed = double.tryParse(v?.toString() ?? '');
      return parsed;
    }

    // alias para ids
    String? _firstNonEmpty(List<dynamic> list) {
      for (final v in list) {
        if (v == null) continue;
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
      return null;
    }

    return Trip(
      id: id,
      origen: buildDireccion(origenMap),
      destino: buildDireccion(destinoMap),
      fecha: castToDate(m['updatedAt'] ?? m['createdAt']),
      km: (kmNum is num) ? kmNum.toDouble() : (toDouble(kmNum) ?? 0.0),
      precio: (totalNum is num)
          ? totalNum.toDouble()
          : (toDouble(totalNum) ?? 0.0),
      precioOfrecido: (precioOfrecidoNum is num)
          ? precioOfrecidoNum.toDouble()
          : toDouble(precioOfrecidoNum),
      estado: parseEstado(m['estado']?.toString()),
      programado:
          (m['tipo']?.toString().toLowerCase() == 'programado') ||
          (m['programado'] == true),
      scheduleText: m['scheduleText']?.toString(),

      // coords
      origenLat: _numOrNull(origenMap['lat']),
      origenLng: _numOrNull(origenMap['lng']),
      destinoLat: _numOrNull(destinoMap['lat']),
      destinoLng: _numOrNull(destinoMap['lng']),

      // conductor
      uidTaxista: _firstNonEmpty([
        m['uidTaxista'],
        m['idTaxista'],
        m['driverUid'],
      ]),

      // NUEVO: pasajero y orden (con alias)
      uidPasajero: _firstNonEmpty([
        m['uidPasajero'],
        m['idPasajero'],
        m['passengerUid'],
      ]),
      ordenId: _firstNonEmpty([m['ordenId'], m['orderId'], m['idOrden']]),

      // si no viene en Firestore, quedará null (TripsList puede construir fallback)
      rutaDoc: (m['rutaDoc'] as String?)?.trim(),
    );
  }
}

/// ==== helpers de parse ====

DateTime castToDate(dynamic v, {DateTime? fallback}) {
  if (v == null) return fallback ?? DateTime.now();
  if (v.runtimeType.toString() == 'Timestamp') {
    try {
      final toDate = (v as dynamic).toDate();
      if (toDate is DateTime) return toDate;
    } catch (_) {}
  }
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v) ?? (fallback ?? DateTime.now());
  return fallback ?? DateTime.now();
}

Map<String, dynamic> asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

double? toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

String buildDireccion(Map origenODestino) {
  final texto = origenODestino['texto']?.toString();
  if (texto != null && texto.trim().isNotEmpty) return texto;
  final calle = origenODestino['calle']?.toString() ?? '';
  final ciudad = origenODestino['ciudad']?.toString() ?? '';
  final pais = origenODestino['pais']?.toString() ?? '';
  return [calle, ciudad, pais].where((e) => e.isNotEmpty).join(', ');
}
