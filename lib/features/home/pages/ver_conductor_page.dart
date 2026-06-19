import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

import 'package:buses2/core/services/mapa_taxi/mapbox_taxi/mapa_widget_taxi.dart';
import 'package:buses2/core/services/mapa_taxi/mapbox_taxi/mapa_widget_taxi.dart'
    show MapaController;
import 'package:buses2/core/services/mapa/route_update_controller.dart';

class VerConductorPage extends StatefulWidget {
  const VerConductorPage({super.key});
  @override
  State<VerConductorPage> createState() => _VerConductorPageState();
}

class _VerConductorPageState extends State<VerConductorPage> {
  // ===================== Estilo (verde + blanco) =====================
  static const Color _verde = Color(0xFF16A34A);
  static const Color _verdeSuave = Color(0xFFEAF7EF);

  MapaController? _map;
  bool _mapReady = false;

  // args / estado de la orden
  String? _driverUid;
  String? _rutaDoc;

  // ORIGEN
  double? _origenLat;
  double? _origenLng;
  String? _origenTexto;

  // DESTINO
  double? _destinoLat;
  double? _destinoLng;
  String? _destinoTexto;

  // estado actual
  String _estadoActual = '';
  bool _rutaHaciaDestino = false; // false => a ORIGEN, true => a DESTINO

  // RTDB
  DatabaseReference? _ref;
  StreamSubscription<DatabaseEvent>? _sub;

  // Firestore order listener
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _orderSub;
  bool _arrivedPopupShown = false;
  bool _passengerOnWayShown = false;

  // estado visual / cache para reponer overlays
  bool _initialRouteDrawn = false;
  mb.Point? _lastDriverPoint; // conductor
  mb.Point? _lastObjectivePoint; // origen/destino actual
  int? _lastT; // timestamp RTDB
  DateTime? _lastUiUpdate;

  // filtros movimiento
  static const _minMeters = 10.0;
  static const _minMsBetweenUI = 20000;

  // ⭐ Control de rutas para evitar parpadeo
  bool _isUpdatingRoute = false;
  final RouteUpdateController _routeController = RouteUpdateController(
    minUpdateInterval: const Duration(seconds: 3),
    minDistanceMeters: 50.0,
    debounceDelay: const Duration(milliseconds: 800),
  );

  // retry para asegurar trazado cuando pasa a en_curso
  Timer? _ensureRouteTimer;
  int _ensureRouteTries = 0;
  static const int _ensureRouteMaxTries = 5;

  // ⭐ Guardar referencia al ScaffoldMessenger
  ScaffoldMessengerState? _scaffoldMessenger;

  // ===================== Distancia + ETA (pasajero) =====================
  double? _distanciaObjetivoM;
  int? _etaSegundos;

  // Para estimar velocidad usando RTDB (lat/lng/t)
  mb.Point? _prevDriverPoint;
  int? _prevT;
  double? _speedMps; // velocidad estimada m/s (suavizada)

  String get _distanciaTxt => _formatDistance(_distanciaObjetivoM);
  String get _etaTxt => _formatDuration(_etaSegundos);

  // ===================== NUEVO: Espera en “en_lugar” =====================
  DateTime? _arrivedAtLocal;
  Duration _waitElapsed = Duration.zero;
  Timer? _waitTimer;

  bool get _isEnLugar => _estadoMatch(_estadoActual, ['en_lugar', 'en lugar']);
  String get _waitTxt => _formatWait(_waitElapsed);

  static String _formatWait(Duration d) {
    final totalSec = d.inSeconds;
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    if (m <= 0) return '${s}s';
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  void _startWaitTimerIfNeeded() {
    _waitTimer?.cancel();

    final base = _arrivedAtLocal ?? DateTime.now();
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _waitElapsed = DateTime.now().difference(base);
        if (_waitElapsed.isNegative) _waitElapsed = Duration.zero;
      });
    });
  }

  void _stopWaitTimer({bool reset = true}) {
    _waitTimer?.cancel();
    _waitTimer = null;

    if (!mounted) return;
    setState(() {
      if (reset) {
        _arrivedAtLocal = null;
        _waitElapsed = Duration.zero;
      }
    });
  }

  DateTime? _parseArrivedAt(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate().toLocal();
    if (v is String) return DateTime.tryParse(v)?.toLocal();
    if (v is int) {
      // por si guardaste milis
      try {
        return DateTime.fromMillisecondsSinceEpoch(v).toLocal();
      } catch (_) {}
    }
    return null;
  }

  // Punto objetivo actual según estado (origen/destino)
  mb.Point? _getObjetivoPoint() {
    if (_rutaHaciaDestino) {
      if (_destinoLat == null || _destinoLng == null) return null;
      return mb.Point(coordinates: mb.Position(_destinoLng!, _destinoLat!));
    } else {
      if (_origenLat == null || _origenLng == null) return null;
      return mb.Point(coordinates: mb.Position(_origenLng!, _origenLat!));
    }
  }

  String get _objetivoTexto => _rutaHaciaDestino
      ? (_destinoTexto ?? 'Destino')
      : (_origenTexto ?? 'Origen');

  String get _estadoTxt {
    final e = _estadoActual.replaceAll('_', ' ').trim();
    if (e.isEmpty) return '---';
    return e
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  IconData get _estadoIcon {
    if (_rutaHaciaDestino) return Icons.route_rounded;
    return Icons.directions_car_filled_rounded;
  }

  void _recalcularDistanciaYETA({required mb.Point conductor, int? tMillis}) {
    final objetivo = _getObjetivoPoint();
    if (objetivo == null) {
      if (!mounted) return;
      setState(() {
        _distanciaObjetivoM = null;
        _etaSegundos = null;
      });
      return;
    }

    final lon1 = conductor.coordinates.lng;
    final lat1 = conductor.coordinates.lat;
    final lon2 = objetivo.coordinates.lng;
    final lat2 = objetivo.coordinates.lat;

    final metros = _haversineMeters(lon1, lat1, lon2, lat2);

    if (metros <= 25) {
      if (!mounted) return;
      setState(() {
        _distanciaObjetivoM = metros;
        _etaSegundos = 0;
      });
      return;
    }

    double? v;
    if (_prevDriverPoint != null && _prevT != null && tMillis != null) {
      final dtSec = (tMillis - _prevT!) / 1000.0;
      if (dtSec > 0.8 && dtSec < 30) {
        final dMove = _haversineMeters(
          _prevDriverPoint!.coordinates.lng,
          _prevDriverPoint!.coordinates.lat,
          conductor.coordinates.lng,
          conductor.coordinates.lat,
        );

        final inst = dMove / dtSec;
        if (inst.isFinite && inst > 0.5) {
          final smoothed = (_speedMps == null)
              ? inst
              : (_speedMps! * 0.7 + inst * 0.3);
          _speedMps = smoothed.clamp(2.5, 16.0);
          v = _speedMps;
        }
      }
    }

    v ??= 7.5;
    final etaSec = (metros / v!).round();

    if (!mounted) return;
    setState(() {
      _distanciaObjetivoM = metros;
      _etaSegundos = etaSec;
    });
  }

  static String _formatDistance(double? meters) {
    if (meters == null) return '--';
    if (meters < 1000) return '${meters.round()} m';
    final km = meters / 1000.0;
    final s = km < 10 ? km.toStringAsFixed(1) : km.toStringAsFixed(0);
    return '$s km';
  }

  static String _formatDuration(int? seconds) {
    if (seconds == null) return '--';
    if (seconds <= 0) return '0 min';
    final mins = (seconds / 60).round();
    if (mins < 60) return '$mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return '${h}h ${m}m';
  }

  @override
  void initState() {
    super.initState();
    final args = (Modular.args.data as Map?) ?? {};
    _driverUid =
        (args['driverUid'] as String?)?.trim() ??
        (args['uidTaxista'] as String?)?.trim();
    _origenLat = (args['origenLat'] as num?)?.toDouble();
    _origenLng = (args['origenLng'] as num?)?.toDouble();
    _rutaDoc = args['rutaDoc'] as String?;
    _origenTexto = (args['origenTexto'] as String?) ?? 'Origen';

    // Destino opcional desde args
    _destinoLat = (args['destinoLat'] as num?)?.toDouble() ?? _destinoLat;
    _destinoLng = (args['destinoLng'] as num?)?.toDouble() ?? _destinoLng;
    _destinoTexto = (args['destinoTexto'] as String?) ?? _destinoTexto;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ok = await _hydrateFromRutaDoc();
      if (!ok) {
        _err('No se pudo resolver datos de la orden (uid/coords).');
        if (mounted) Navigator.of(context).pop();
        return;
      }
      if (_origenLat == null || _origenLng == null) {
        _err('Faltan coordenadas de origen (lat/lng).');
        if (mounted) Navigator.of(context).pop();
        return;
      }
      if (_driverUid == null || _driverUid!.isEmpty) {
        _err('No se encontró el uid del conductor.');
        if (mounted) Navigator.of(context).pop();
        return;
      }

      // Estado + señales de la orden
      _listenOrderSignals();

      // Live del conductor en RTDB
      _ref = FirebaseDatabase.instance.ref('taxistas/${_driverUid!}');
      _sub = _ref!.onValue.listen(
        _onDriverSnapshot,
        onError: (e) {
          _err('RTDB error: $e');
        },
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
  }

  @override
  void dispose() {
    _ensureRouteTimer?.cancel();
    _waitTimer?.cancel();

    _sub?.cancel();
    _orderSub?.cancel();
    _routeController.dispose();

    _sub = null;
    _orderSub = null;
    super.dispose();
  }

  // =================== Firestore listener ===================

  void _listenOrderSignals() {
    if (_rutaDoc == null || _rutaDoc!.isEmpty) return;
    _orderSub?.cancel();
    _orderSub = FirebaseFirestore.instance.doc(_rutaDoc!).snapshots().listen((
      snap,
    ) {
      if (!snap.exists) return;
      final d = snap.data() ?? {};

      final estadoRaw = (d['estado'] ?? '').toString().trim().toLowerCase();
      final arrivedAt = _parseArrivedAt(d['arrivedAt']);

      // ✅ Timer de espera para pasajero: solo cuando estado == en_lugar
      final bool nowEnLugar = _estadoMatch(estadoRaw, ['en_lugar', 'en lugar']);
      if (nowEnLugar) {
        _arrivedAtLocal ??= arrivedAt ?? DateTime.now();
        _startWaitTimerIfNeeded();
      } else {
        _stopWaitTimer(reset: true);
      }

      if (estadoRaw != _estadoActual) {
        _estadoActual = estadoRaw;
        _onEstadoChange(_estadoActual, d);
      }

      // llegó al origen
      if (_estadoMatch(estadoRaw, ['en_lugar']) && !_arrivedPopupShown) {
        _arrivedPopupShown = true;
        _showArrivedDialog();
      }

      // pasajero en camino
      if (!_passengerOnWayShown) {
        final ping = (d['ping'] is Map)
            ? Map<String, dynamic>.from(d['ping'])
            : const {};
        final ts = ping['pasajeroEnCaminoAt'];
        if (ts != null) {
          _passengerOnWayShown = true;
          _showPassengerOnWayDialog();
        }
      }

      if (mounted) setState(() {});
    }, onError: (_) {});
  }

  bool _estadoMatch(String estado, List<String> keys) {
    final e = estado.replaceAll('_', ' ').trim();
    for (final k in keys) {
      final kk = k.replaceAll('_', ' ').trim();
      if (e == kk) return true;
    }
    return false;
  }

  // ======= CAMBIO DE ESTADO (one-shot + retry en en_curso) =======
  void _onEstadoChange(String estado, Map<String, dynamic> d) {
    // Cargar/actualizar destino desde doc
    _destinoLat ??= _toDouble(
      _firstNonNull([
        _fromMap(d, ['destino', 'lat']),
        d['destinoLat'],
        d['bLat'],
      ]),
    );
    _destinoLng ??= _toDouble(
      _firstNonNull([
        _fromMap(d, ['destino', 'lng']),
        d['destinoLng'],
        d['bLng'],
      ]),
    );
    _destinoTexto ??=
        _firstNonEmpty([
          _fromMap(d, ['destino', 'calle']),
          d['destinoCalle'],
          d['destinoTitulo'],
          d['bCalle'],
          d['bTitulo'],
        ]) ??
        'Destino';

    final esEnCamino = _estadoMatch(estado, ['en_camino', 'en camino']);
    final esEnCurso = _estadoMatch(estado, ['en_curso', 'en curso', 'activo']);

    bool toDestino = false;
    if (esEnCurso && _destinoLat != null && _destinoLng != null) {
      toDestino = true;
    } else if (esEnCamino) {
      toDestino = false;
    }

    final cambioObjetivo = (_rutaHaciaDestino != toDestino);
    _rutaHaciaDestino = toDestino;

    // ✅ Recalcular métricas si ya tenemos punto del conductor
    if (_lastDriverPoint != null) {
      _recalcularDistanciaYETA(conductor: _lastDriverPoint!, tMillis: _lastT);
    }

    Future<void>(() async {
      if (!_mapReady || _map == null) return;

      if (_rutaHaciaDestino) {
        if (_destinoLat == null || _destinoLng == null) return;

        if (_lastDriverPoint == null) {
          final p = await _fetchDriverPointOnce();
          if (p != null) {
            _lastDriverPoint = p;
            _initialRouteDrawn = false;
            await _trazarRutaDesde(p);
            await _putDriverPin(p);
          }
        } else if (cambioObjetivo) {
          _initialRouteDrawn = false;
          _pinsInitialized = false;
          _destinationPinAdded = false;
          await _map!.borrarPuntoFijo();
          await _trazarRutaDesde(_lastDriverPoint!);
          await _putDriverPin(_lastDriverPoint!);
        }

        _kickEnsureRouteRetry();
      } else {
        if (_lastDriverPoint != null && cambioObjetivo) {
          _initialRouteDrawn = false;
          _pinsInitialized = false;
          _destinationPinAdded = false;
          await _map!.borrarPuntoFijo();
          await _trazarRutaDesde(_lastDriverPoint!);
          await _putDriverPin(_lastDriverPoint!);
        }
      }
    });

    if (mounted) setState(() {});
  }

  void _kickEnsureRouteRetry() {
    _ensureRouteTimer?.cancel();
    _ensureRouteTries = 0;
    _ensureRouteTimer = Timer.periodic(const Duration(seconds: 2), (t) async {
      _ensureRouteTries++;
      if (_ensureRouteTries > _ensureRouteMaxTries) {
        t.cancel();
        return;
      }
      if (!_mapReady || _map == null) return;
      if (!_rutaHaciaDestino) return;
      if (_destinoLat == null || _destinoLng == null) return;

      if (_lastDriverPoint == null) {
        final p = await _fetchDriverPointOnce();
        if (p != null) _lastDriverPoint = p;
      }
      if (_lastDriverPoint != null) {
        _initialRouteDrawn = false;
        await _trazarRutaDesde(_lastDriverPoint!);
        await _putDriverPin(_lastDriverPoint!);
        t.cancel();
      }
    });
  }

  // =================== MAP ===================

  Future<void> _onMapReady(MapaController c) async {
    _map = c;
    _mapReady = true;

    await Future.delayed(const Duration(milliseconds: 300));

    if (_lastDriverPoint != null) {
      await _putDriverPin(_lastDriverPoint!);
      await _trazarRutaDesde(_lastDriverPoint!);
    }

    if (_lastDriverPoint == null &&
        _estadoMatch(_estadoActual, ['en_curso', 'en curso', 'activo'])) {
      final p = await _fetchDriverPointOnce();
      if (p != null) {
        _lastDriverPoint = p;
        await _trazarRutaDesde(p);
        await _putDriverPin(p);
      } else {
        _kickEnsureRouteRetry();
      }
    }
  }

  /// Reponer overlays tras zoom/pan del usuario
  Future<void> _restoreOverlays() async {
    if (!_mapReady || _map == null) return;

    final objetivo = _getObjetivoPoint();

    if (_lastDriverPoint != null && objetivo != null) {
      _initialRouteDrawn = false;
      _pinsInitialized = false;
      _destinationPinAdded = false;

      try {
        await _map!.dibujarRutaDesdeHasta(
          a: _lastDriverPoint!,
          b: objetivo,
          context: context,
        );
      } catch (_) {}

      try {
        await _map!.borrarPuntoFijo();

        await _addDestinationPin();

        await _map!.agregarPuntoFijo(
          _lastDriverPoint!,
          fillColor: Colors.white,
          strokeColor: _verde,
          radius: 5,
          strokeWidth: 6,
        );

        _pinsInitialized = true;
        _destinationPinAdded = true;
      } catch (_) {}
    }
  }

  Future<void> _onDriverSnapshot(DatabaseEvent ev) async {
    final snap = ev.snapshot;
    if (!snap.exists) return;

    final data = (snap.value is Map)
        ? Map<String, dynamic>.from(snap.value as Map)
        : <String, dynamic>{};

    final parsed = _parseLatLng(data);
    final lat = parsed.$1;
    final lng = parsed.$2;
    final t = (data['t'] is int)
        ? data['t'] as int
        : int.tryParse('${data['t']}');

    if (lat == null || lng == null) return;
    final newPoint = mb.Point(coordinates: mb.Position(lng, lat));

    if (_lastT != null && t != null && t <= _lastT!) return;

    _prevDriverPoint = _lastDriverPoint ?? _prevDriverPoint;
    _prevT = _lastT ?? _prevT;

    mb.Point? destinationPoint = _getObjetivoPoint();

    final shouldUpdate = _routeController.shouldUpdate(
      newOrigin: newPoint,
      newDestination: destinationPoint,
    );

    _lastDriverPoint = newPoint;
    _lastT = t ?? _lastT;
    _lastUiUpdate = DateTime.now();

    _recalcularDistanciaYETA(conductor: newPoint, tMillis: _lastT);

    if (!_mapReady || _map == null) return;

    if (!shouldUpdate && _initialRouteDrawn) {
      await _putDriverPin(newPoint);
      return;
    }

    if (_isUpdatingRoute) {
      debugPrint('⏭️ Update de ruta en curso, saltando...');
      return;
    }

    _isUpdatingRoute = true;
    try {
      await _trazarRutaDesde(newPoint);
      await _putDriverPin(newPoint);
    } finally {
      _isUpdatingRoute = false;
    }
  }

  Future<void> _trazarRutaDesde(mb.Point pConductor) async {
    if (_map == null) return;

    final objetivo = _getObjetivoPoint();
    if (objetivo == null) return;

    _lastObjectivePoint = objetivo;

    try {
      await _map!.dibujarRutaDesdeHasta(
        a: pConductor,
        b: objetivo,
        context: context,
      );
      _initialRouteDrawn = true;
    } catch (e) {
      _err('No se pudo trazar la ruta: $e');
    }
  }

  bool _pinsInitialized = false;
  bool _destinationPinAdded = false;

  Future<void> _putDriverPin(mb.Point p) async {
    if (_map == null) return;
    try {
      if (_pinsInitialized) {
        await _map!.borrarUltimoPuntoFijo();
        await _map!.agregarPuntoFijo(
          p,
          fillColor: Colors.white,
          strokeColor: _verde,
          radius: 5,
          strokeWidth: 6,
        );
      } else {
        await _map!.borrarPuntoFijo();

        await _addDestinationPin();
        _destinationPinAdded = true;

        await _map!.agregarPuntoFijo(
          p,
          fillColor: Colors.white,
          strokeColor: _verde,
          radius: 5,
          strokeWidth: 6,
        );

        _pinsInitialized = true;
      }
    } catch (_) {}
  }

  /// Pin del objetivo (origen/destino) en VERDE (no azul)
  Future<void> _addDestinationPin() async {
    if (_map == null) return;

    double? lat;
    double? lng;

    if (_rutaHaciaDestino) {
      lat = _destinoLat;
      lng = _destinoLng;
    } else {
      lat = _origenLat;
      lng = _origenLng;
    }

    if (lat == null || lng == null) return;

    try {
      await _map!.agregarPuntoFijo(
        mb.Point(coordinates: mb.Position(lng, lat)),
        fillColor: _verde,
        strokeColor: _verde,
        radius: 8,
        strokeWidth: 3,
      );
    } catch (_) {}
  }

  Future<mb.Point?> _fetchDriverPointOnce() async {
    if (_driverUid == null || _driverUid!.isEmpty) return null;
    try {
      final snap = await FirebaseDatabase.instance
          .ref('taxistas/${_driverUid!}')
          .get();
      if (!snap.exists || snap.value is! Map) return null;
      final m = Map<String, dynamic>.from(snap.value as Map);
      final parsed = _parseLatLng(m);
      final lat = parsed.$1;
      final lng = parsed.$2;
      if (lat == null || lng == null) return null;
      return mb.Point(coordinates: mb.Position(lng, lat));
    } catch (_) {
      return null;
    }
  }

  (double?, double?) _parseLatLng(Map<String, dynamic> m) {
    dynamic _pick(List<String> keys) {
      for (final k in keys) {
        if (m.containsKey(k) && m[k] != null) return m[k];
      }
      return null;
    }

    double? _asDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    final lat = _asDouble(_pick(['lat', 'latitude', 'lt', 'la']));
    final lng = _asDouble(
      _pick(['lng', 'lon', 'long', 'longitude', 'lg', 'lo']),
    );
    return (lat, lng);
  }

  // =================== Hidratación ===================

  Future<bool> _hydrateFromRutaDoc() async {
    if (_rutaDoc == null || _rutaDoc!.isEmpty) {
      return await _hydrateFromActiveQuery();
    }
    try {
      final snap = await FirebaseFirestore.instance.doc(_rutaDoc!).get();
      if (!snap.exists) return false;

      final d = snap.data() as Map<String, dynamic>? ?? {};

      _driverUid ??= (d['uidTaxista'] ?? d['idTaxista'] ?? d['driverUid'])
          ?.toString();

      _origenLat ??= _toDouble(
        _fromMap(d, ['origen', 'lat']) ?? d['origenLat'] ?? d['aLat'],
      );
      _origenLng ??= _toDouble(
        _fromMap(d, ['origen', 'lng']) ?? d['origenLng'] ?? d['aLng'],
      );
      _origenTexto ??=
          _firstNonEmpty([
            _fromMap(d, ['origen', 'calle']),
            d['origenCalle'],
            d['origenTitulo'],
            d['aCalle'],
            d['aTitulo'],
          ]) ??
          'Origen';

      _destinoLat ??= _toDouble(
        _fromMap(d, ['destino', 'lat']) ?? d['destinoLat'] ?? d['bLat'],
      );
      _destinoLng ??= _toDouble(
        _fromMap(d, ['destino', 'lng']) ?? d['destinoLng'] ?? d['bLng'],
      );
      _destinoTexto ??=
          _firstNonEmpty([
            _fromMap(d, ['destino', 'calle']),
            d['destinoCalle'],
            d['destinoTitulo'],
            d['bCalle'],
            d['bTitulo'],
          ]) ??
          _destinoTexto;

      _estadoActual = (d['estado'] ?? '').toString().trim().toLowerCase();
      _onEstadoChange(_estadoActual, d);

      // ✅ si ya venía en_lugar, activar timer desde el inicio
      if (_estadoMatch(_estadoActual, ['en_lugar', 'en lugar'])) {
        _arrivedAtLocal ??= _parseArrivedAt(d['arrivedAt']) ?? DateTime.now();
        _startWaitTimerIfNeeded();
      }

      if (_driverUid == null || _driverUid!.isEmpty) {
        final uidPas = d['uidPasajero']?.toString();
        if (uidPas != null && uidPas.isNotEmpty) {
          final exists = await _rtdbNodeExists(uidPas);
          if (exists) _driverUid = uidPas;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _hydrateFromActiveQuery() async {
    final uid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return false;

    try {
      final estados = [
        'aceptado',
        'aceptada',
        'en_camino',
        'en camino',
        'en_curso',
        'en curso',
        'activo',
        'en_lugar',
        'en lugar',
      ];
      final q = await FirebaseFirestore.instance
          .collectionGroup('ordenes')
          .where('uidPasajero', isEqualTo: uid)
          .where('estado', whereIn: estados)
          .orderBy('updatedAt', descending: true)
          .limit(1)
          .get();

      if (q.docs.isEmpty) return false;

      final doc = q.docs.first;
      final d = doc.data();

      _rutaDoc = doc.reference.path;

      _driverUid ??= (d['uidTaxista'] ?? d['idTaxista'] ?? d['driverUid'])
          ?.toString();

      _origenLat ??= _toDouble(
        _fromMap(d, ['origen', 'lat']) ?? d['origenLat'] ?? d['aLat'],
      );
      _origenLng ??= _toDouble(
        _fromMap(d, ['origen', 'lng']) ?? d['origenLng'] ?? d['aLng'],
      );
      _origenTexto ??=
          _firstNonEmpty([
            _fromMap(d, ['origen', 'calle']),
            d['origenCalle'],
            d['origenTitulo'],
            d['aCalle'],
            d['aTitulo'],
          ]) ??
          'Origen';

      _destinoLat ??= _toDouble(
        _fromMap(d, ['destino', 'lat']) ?? d['destinoLat'] ?? d['bLat'],
      );
      _destinoLng ??= _toDouble(
        _fromMap(d, ['destino', 'lng']) ?? d['destinoLng'] ?? d['bLng'],
      );
      _destinoTexto ??=
          _firstNonEmpty([
            _fromMap(d, ['destino', 'calle']),
            d['destinoCalle'],
            d['destinoTitulo'],
            d['bCalle'],
            d['bTitulo'],
          ]) ??
          _destinoTexto;

      _estadoActual = (d['estado'] ?? '').toString().trim().toLowerCase();
      _onEstadoChange(_estadoActual, d);

      // ✅ si ya venía en_lugar, activar timer
      if (_estadoMatch(_estadoActual, ['en_lugar', 'en lugar'])) {
        _arrivedAtLocal ??= _parseArrivedAt(d['arrivedAt']) ?? DateTime.now();
        _startWaitTimerIfNeeded();
      }

      if (_driverUid == null || _driverUid!.isEmpty) {
        final exists = await _rtdbNodeExists(uid);
        if (exists) _driverUid = uid;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _rtdbNodeExists(String uid) async {
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('taxistas/$uid')
          .get();
      return snapshot.exists && (snapshot.value is Map);
    } catch (_) {
      return false;
    }
  }

  // ============== Distancia (Haversine) ==============
  double _haversineMeters(num lon1, num lat1, num lon2, num lat2) {
    final double _lon1 = lon1.toDouble();
    final double _lat1 = lat1.toDouble();
    final double _lon2 = lon2.toDouble();
    final double _lat2 = lat2.toDouble();

    const R = 6371000.0; // metros
    final dLat = _deg2rad(_lat2 - _lat1);
    final dLon = _deg2rad(_lon2 - _lon1);
    final a =
        (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        math.cos(_deg2rad(_lat1)) *
            math.cos(_deg2rad(_lat2)) *
            (math.sin(dLon / 2) * math.sin(dLon / 2));
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double d) => d * math.pi / 180.0;

  // ===== helpers =====
  T? _fromMap<T>(Map<String, dynamic> m, List<String> path) {
    dynamic cur = m;
    for (final k in path) {
      if (cur is Map && cur.containsKey(k)) {
        cur = cur[k];
      } else {
        return null;
      }
    }
    return cur as T?;
  }

  T? _firstNonNull<T>(List<dynamic> list) {
    for (final v in list) {
      if (v != null) return v as T?;
    }
    return null;
  }

  String? _firstNonEmpty(List<dynamic> list) {
    for (final v in list) {
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  void _err(String m) {
    if (!mounted) return;
    _scaffoldMessenger?.hideCurrentSnackBar();
    _scaffoldMessenger?.showSnackBar(SnackBar(content: Text(m)));
  }

  // ===== Diálogos =====

  void _showArrivedDialog() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E)),
            SizedBox(width: 8),
            Text('¡El conductor llegó!'),
          ],
        ),
        content: Text(
          'El conductor ya se encuentra en tu ubicación'
          '${_origenTexto != null ? " (${_origenTexto!})" : ""}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPassengerOnWayDialog() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.directions_walk_rounded, color: _verde),
            SizedBox(width: 8),
            Text('El pasajero está en camino'),
          ],
        ),
        content: const Text(
          'El pasajero confirmó que se dirige hacia tu ubicación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final startLat = _origenLat ?? -17.3895;
    final startLng = _origenLng ?? -66.1568;

    return Scaffold(
      appBar: AppBar(title: const Text('Ver conductor'), centerTitle: true),
      body: Stack(
        children: [
          Positioned.fill(
            child: MapaWidget(
              key: const ValueKey('ver-conductor-map'),
              centerLat: startLat,
              centerLng: startLng,
              onMapReady: _onMapReady,
              onMoveEnd: _restoreOverlays,
            ),
          ),

          // ✅ Panel inferior bonito (verde/blanco) + Distancia + ETA + Espera
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.97),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 24,
                      offset: Offset(0, 10),
                      color: Color(0x22000000),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _verdeSuave,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _verde.withOpacity(0.22)),
                          ),
                          child: Icon(_estadoIcon, color: _verde),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Conductor en ruta',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Hacia: $_objetivoTexto',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black.withOpacity(0.55),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _verde,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _estadoTxt,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _MetricChip(
                            icon: Icons.social_distance_rounded,
                            title: 'Distancia',
                            value: _distanciaTxt,
                            accent: _verde,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MetricChip(
                            icon: Icons.timer_rounded,
                            title: 'Tiempo estimado',
                            value: _etaTxt,
                            accent: _verde,
                          ),
                        ),
                      ],
                    ),

                    // ✅ Espera del pasajero cuando el conductor está en_lugar
                    if (_isEnLugar) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FAF8),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _verde.withOpacity(0.18)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: _verde.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.hourglass_bottom_rounded,
                                size: 16,
                                color: _verde,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Tiempo de espera: $_waitTxt',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.title,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.black.withOpacity(0.55),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
