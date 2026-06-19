// lib/features/home_taxi_features/home_taxi/data/traer_ordenes.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';

import 'package:buses2/shared/services/save_traer_firebase/helpers/placeholders.dart';
import 'package:buses2/shared/services/save_traer_firebase/lecturas/docGet.dart';

/// =========================
/// =======  MODELOS  =======
/// =========================

class OrdenView {
  final bool isProgramado;
  final String? rutaDoc;
  final String? servicio;
  final String? estado;

  /// UID del pasajero (se guarda en la orden; si no existe, lo inferimos de la ruta)
  final String? uidPasajero;

  // Direcciones
  final String? origenCalle;
  final String? origenTexto;
  final String? destinoCalle;
  final String? destinoTexto;

  // Coordenadas (para trazar en el mapa)
  final double? origenLat;
  final double? origenLng;
  final double? destinoLat;
  final double? destinoLng;

  // Tarifa
  final double? km;
  final double? total;

  // Tiempos
  final String? timestampLocal; // creación (ISO local)
  final String? timeLocal; // hora programada, ej. "19:10"
  final List<dynamic>? datesLocal; // fechas programadas ISO ("2025-10-23", ...)

  OrdenView({
    required this.isProgramado,
    this.rutaDoc,
    this.servicio,
    this.estado,
    this.uidPasajero,
    this.origenCalle,
    this.origenTexto,
    this.destinoCalle,
    this.destinoTexto,
    this.origenLat,
    this.origenLng,
    this.destinoLat,
    this.destinoLng,
    this.km,
    this.total,
    this.timestampLocal,
    this.timeLocal,
    this.datesLocal,
  });

  // ---------- Helpers de UI ----------
  String get origenTitulo => (origenCalle?.trim().isNotEmpty == true)
      ? origenCalle!
      : (origenTexto ?? 'Origen');

  String get destinoTitulo => (destinoCalle?.trim().isNotEmpty == true)
      ? destinoCalle!
      : (destinoTexto ?? 'Destino');

  String get totalFmt {
    final t = total ?? 0;
    return (t % 1 == 0)
        ? 'ARS ${t.toStringAsFixed(0)}'
        : 'ARS ${t.toStringAsFixed(2)}';
  }

  /// "19:10 • 23 Oct" (desde `timestampLocal`)
  String get createdAtShort {
    final t = DateTime.tryParse(timestampLocal ?? '');
    if (t == null) return '';
    const mm = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m • ${t.day} ${mm[t.month - 1]}';
  }

  /// "23 Oct, 30 Oct, 31 Oct" (desde `datesLocal`)
  String get scheduleDatesLine {
    final fechas = (datesLocal ?? []).whereType<String>().map((d) {
      final dt = DateTime.tryParse(d);
      if (dt == null) return d;
      const mm = [
        'Ene',
        'Feb',
        'Mar',
        'Abr',
        'May',
        'Jun',
        'Jul',
        'Ago',
        'Sep',
        'Oct',
        'Nov',
        'Dic',
      ];
      return '${dt.day} ${mm[dt.month - 1]}';
    }).toList();
    return fechas.join(', ');
  }

  /// "19:10"
  String get scheduleTimeShort => timeLocal ?? '';

  /// Clave para ordenar por “más reciente”
  DateTime get sortKey {
    if (isProgramado &&
        (datesLocal?.isNotEmpty ?? false) &&
        timeLocal != null) {
      final d0 = datesLocal!.first;
      final dt = DateTime.tryParse('${d0}T$timeLocal:00');
      if (dt != null) return dt;
    }
    return DateTime.tryParse(timestampLocal ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Mapea un raw dinámico (de Firestore/DocGet) a un modelo tipado.
  factory OrdenView.fromRaw(
    Map<String, dynamic> raw, {
    required bool isProgramado,
  }) {
    Map<String, dynamic> _asStringMap(Object? v) {
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return v.map((k, v) => MapEntry(k.toString(), v));
      return <String, dynamic>{};
    }

    String? _asString(Object? v) => v == null ? null : v.toString();
    double? _asDouble(Object? v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    final origen = _asStringMap(raw['origen']);
    final destino = _asStringMap(raw['destino']);
    final tarifa = _asStringMap(raw['tarifa']);
    final prog = _asStringMap(raw['programacion']);
    final estado = _asString(raw['estado']);

    return OrdenView(
      isProgramado: isProgramado,
      rutaDoc: _asString(raw['rutaDoc']),
      servicio: _asString(raw['servicio']),
      estado: estado,

      /// UID del pasajero (puede venir guardado en la orden o lo setea el repo por fallback)
      uidPasajero: _asString(raw['uidPasajero']),

      // Direcciones
      origenCalle: _asString(origen['calle']) ?? _asString(origen['texto']),
      origenTexto: _asString(origen['texto']),
      destinoCalle: _asString(destino['calle']) ?? _asString(destino['texto']),
      destinoTexto: _asString(destino['texto']),

      // Coordenadas
      origenLat: _asDouble(origen['lat']),
      origenLng: _asDouble(origen['lng']),
      destinoLat: _asDouble(destino['lat']),
      destinoLng: _asDouble(destino['lng']),

      // Tarifa - Precio según estado:
      // - En 'pedido': priorizar precioOfrecido (contraoferta del pasajero)
      // - En otros estados: priorizar total (precio final después de aceptar)
      km: _asDouble(tarifa['km']),
      total: (estado == 'pedido')
          ? _asDouble(
              tarifa['precioOfrecido'] ??
                  tarifa['total'] ??
                  tarifa['precioRecomendado'],
            )
          : _asDouble(
              tarifa['total'] ??
                  tarifa['precioOfrecido'] ??
                  tarifa['precioRecomendado'],
            ),

      // Tiempos
      timestampLocal:
          _asString(raw['timestampLocal']) ?? _asString(raw['createdAt']),
      timeLocal: _asString(prog['timeLocal']),
      datesLocal: (prog['datesLocal'] is List)
          ? prog['datesLocal'] as List
          : null,
    );
  }
}

/// Resultado para la pantalla (agrupado)
class OrdenesResult {
  final String basePath;
  final List<OrdenView> normales;
  final List<OrdenView> programados;

  OrdenesResult({
    required this.basePath,
    required this.normales,
    required this.programados,
  });
}

/// =====================================
/// =====  REPOSITORIO (usa DocGet)  ====
/// =====================================

class OrdenesRepositoryDocGet {
  final FirebaseFirestore _db;
  OrdenesRepositoryDocGet({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  /// Resuelve la ruta dinámica `ordenesPasajeros/{uid}` con Placeholders
  Future<String> _resolverBase() async {
    return Placeholders.resolverRuta('ordenesPasajeros/{uid}');
  }

  /// Trae órdenes y programados UNA VEZ.
  /// Si pasas [soloPedidos] = true, filtra por estado == 'pedido'.
  Future<OrdenesResult> fetchOnce({bool soloPedidos = false}) async {
    final base = await _resolverBase();

    Query<Map<String, dynamic>> qOrd = _db.collection('$base/ordenes');
    Query<Map<String, dynamic>> qPro = _db.collection(
      '$base/ordenesProgramados',
    );

    if (soloPedidos) {
      qOrd = qOrd.where('estado', isEqualTo: 'pedido');
      qPro = qPro.where('estado', isEqualTo: 'pedido');
    }

    // 1) Listar IDs (barato)
    final ordIds = (await qOrd.get()).docs.map((d) => d.id).toList();
    final progIds = (await qPro.get()).docs.map((d) => d.id).toList();

    if (kDebugMode) {
      debugPrint('🔎 Base: $base');
      debugPrint('📝 Ordenes: ${ordIds.length} -> $ordIds');
      debugPrint('🗓  Programados: ${progIds.length} -> $progIds');
    }

    // 2) Construir rutas y tipos
    final rutas = <String>[
      ...ordIds.map((id) => '$base/ordenes/$id'),
      ...progIds.map((id) => '$base/ordenesProgramados/$id'),
    ];
    final tipos = <String>[
      ...List.filled(ordIds.length, 'normal'),
      ...List.filled(progIds.length, 'programado'),
    ];

    if (rutas.isEmpty) {
      return OrdenesResult(
        basePath: base,
        normales: const [],
        programados: const [],
      );
    }

    // 3) Leer docs con DocGet (doc completo)
    final docs = await DocGet.documentosGet(
      rutas: rutas,
      nombreMapas: List.filled(rutas.length, ''), // '' => doc completo
    );

    // 4) Mapear seguro a OrdenView
    final normales = <OrdenView>[];
    final programados = <OrdenView>[];

    for (int i = 0; i < docs.length; i++) {
      final raw = docs[i]['data'];
      if (raw == null) continue;

      final map = _asStringMap(raw);
      // Determinación robusta del tipo
      final tipoRaw = (map['tipo'] ?? '').toString().toLowerCase();
      final isProg = tipos[i] == 'programado' || tipoRaw == 'programado';

      final view = OrdenView.fromRaw(map, isProgramado: isProg);
      (isProg ? programados : normales).add(view);
    }

    // 5) Ordenar para UI (más recientes arriba)
    normales.sort((a, b) => b.sortKey.compareTo(a.sortKey));
    programados.sort((a, b) => b.sortKey.compareTo(a.sortKey));

    return OrdenesResult(
      basePath: base,
      normales: normales,
      programados: programados,
    );
  }

  /// Variante por IDs conocidos (sin listar colecciones).
  Future<OrdenesResult> fetchByIds({
    required List<String> ordenIds,
    required List<String> programadoIds,
  }) async {
    final base = await _resolverBase();

    final rutas = <String>[
      ...ordenIds.map((id) => '$base/ordenes/$id'),
      ...programadoIds.map((id) => '$base/ordenesProgramados/$id'),
    ];
    final tipos = <String>[
      ...List.filled(ordenIds.length, 'normal'),
      ...List.filled(programadoIds.length, 'programado'),
    ];

    if (rutas.isEmpty) {
      return OrdenesResult(
        basePath: base,
        normales: const [],
        programados: const [],
      );
    }

    final docs = await DocGet.documentosGet(
      rutas: rutas,
      nombreMapas: List.filled(rutas.length, ''),
    );

    final normales = <OrdenView>[];
    final programados = <OrdenView>[];

    for (int i = 0; i < docs.length; i++) {
      final raw = docs[i]['data'];
      if (raw == null) continue;

      final map = _asStringMap(raw);
      final tipoRaw = (map['tipo'] ?? '').toString().toLowerCase();
      final isProg = tipos[i] == 'programado' || tipoRaw == 'programado';

      final view = OrdenView.fromRaw(map, isProgramado: isProg);
      (isProg ? programados : normales).add(view);
    }

    normales.sort((a, b) => b.sortKey.compareTo(a.sortKey));
    programados.sort((a, b) => b.sortKey.compareTo(a.sortKey));

    return OrdenesResult(
      basePath: base,
      normales: normales,
      programados: programados,
    );
  }
}

/// =====================================================
/// ========= REPO EN TIEMPO REAL (STREAM) =============
/// =====================================================

extension OrdenesRepositoryLive on OrdenesRepositoryDocGet {
  /// Stream en tiempo real de órdenes normales y programadas.
  /// Si [soloPedidos] es true, filtra por estado == 'pedido'.
  Stream<OrdenesResult> streamPedidos({bool soloPedidos = false}) async* {
    final base = await _resolverBase();

    Query<Map<String, dynamic>> qOrd = _db.collection('$base/ordenes');
    Query<Map<String, dynamic>> qPro = _db.collection(
      '$base/ordenesProgramados',
    );

    if (soloPedidos) {
      qOrd = qOrd.where('estado', isEqualTo: 'pedido');
      qPro = qPro.where('estado', isEqualTo: 'pedido');
    }

    final ordStream = qOrd.snapshots();
    final proStream = qPro.snapshots();

    yield* Rx.combineLatest2<
      QuerySnapshot<Map<String, dynamic>>,
      QuerySnapshot<Map<String, dynamic>>,
      OrdenesResult
    >(ordStream, proStream, (ordSnap, proSnap) {
      // Mapear normales
      final normales = ordSnap.docs.map((d) {
        final map = _asStringMap(d.data());
        map['rutaDoc'] ??= d.reference.path; // ruta real del doc
        map['uidPasajero'] ??= _uidFromRuta(
          map['rutaDoc'],
        ); // fallback desde ruta base
        return OrdenView.fromRaw(map, isProgramado: false);
      }).toList();

      // Mapear programados
      final programados = proSnap.docs.map((d) {
        final map = _asStringMap(d.data());
        map['rutaDoc'] ??= d.reference.path;
        map['uidPasajero'] ??= _uidFromRuta(map['rutaDoc']);
        return OrdenView.fromRaw(map, isProgramado: true);
      }).toList();

      // Ordenar para UI (más recientes arriba)
      normales.sort((a, b) => b.sortKey.compareTo(a.sortKey));
      programados.sort((a, b) => b.sortKey.compareTo(a.sortKey));

      return OrdenesResult(
        basePath: base,
        normales: normales,
        programados: programados,
      );
    });
  }
}

/// ===============================
/// ======  HELPERS DE TIPO  ======
/// ===============================

Map<String, dynamic> _asStringMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((k, v) => MapEntry(k?.toString() ?? '', v));
  }
  return <String, dynamic>{};
}

String? _asString(Object? v) {
  if (v == null) return null;
  if (v is String) return v;
  return v.toString();
}

double? _asDouble(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

/// Extrae el UID desde la ruta 'ordenesPasajeros/{uid}/...'
String? _uidFromRuta(String? ruta) {
  if (ruta == null) return null;
  final re = RegExp(r'ordenesPasajeros/([^/]+)/');
  final m = re.firstMatch(ruta);
  return m?.group(1);
}
