import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:buses2/core/services/mapa_taxi/mapbox_taxi/mapa_widget_taxi.dart';
import 'package:buses2/core/services/mapa_taxi/mapbox_taxi/mapa_widget_taxi.dart'
    show MapaController;
import 'package:buses2/core/services/mapa/route_update_controller.dart';
import 'package:buses2/features/chats/data/repositories/chat_repository.dart';
import 'package:buses2/features/home_taxi_features/billetera_taxista/services/taxista_wallet_service.dart';
import 'package:buses2/shared/widgets/rating_modal/rating_modal.dart';

class EnCaminoPage extends StatefulWidget {
  const EnCaminoPage({super.key});
  @override
  State<EnCaminoPage> createState() => _EnCaminoPageState();
}

class _EnCaminoPageState extends State<EnCaminoPage> {
  // ✅ Para snackbars sin usar context (evita crash "deactivated widget")
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  MapaController? _map;
  bool _mapReady = false;

  // ORIGEN (recogida)
  double? _origLat;
  double? _origLng;
  String? _origLabel;

  // DESTINO (desde Firestore)
  double? _destLat;
  double? _destLng;
  String? _destLabel;

  // Firestore doc path y estado
  String? _rutaDoc;
  String _estado = ''; // en_camino | en_lugar | en_curso | completado | ...

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _docSub;

  // Identidad del conductor (tracking en RTDB)
  String? _driverUid;
  // Chat relacionado al viaje (si existe)
  String? _chatId;

  // RTDB: /taxistas/{uidTaxista}
  DatabaseReference? _driverRtdbRef;

  // Ubicación + timer
  geo.Position? _lastPos;
  geo.Position? _lastUploaded;
  Timer? _ticker;

  // Tracking control
  bool _tracking = false;
  static const _tickSeconds = 6;
  static const _minMeters = 2.0;
  static const _minHeading = 2.0;

  // Control de rutas
  bool _isDrawingRoute = false;
  final RouteUpdateController _routeController = RouteUpdateController(
    minUpdateInterval: const Duration(seconds: 4),
    minDistanceMeters: 30.0,
    debounceDelay: const Duration(milliseconds: 600),
  );

  // Anti doble acción
  bool _finishing = false; // evita doble tap en "Viaje completado"
  bool _navigated = false; // evita pop doble (listener + botón)
  bool _isHandlingCompletion = false;
  bool _cancelling = false; // evita doble cancelación

  // ================== Métricas (distancia / ETA) ==================

  double? _distanciaObjetivoM;
  int? _etaSegundos;

  String get _distanciaTxt => _formatDistance(_distanciaObjetivoM);
  String get _etaTxt => _formatDuration(_etaSegundos);

  // ================== Espera (cuando está en_lugar) ==================
  DateTime? _arrivedAtLocal;
  Duration _waitElapsed = Duration.zero;
  Timer? _waitTimer;

  String get _waitTxt => _formatWait(_waitElapsed);

  // ✅ Cancelación "no show" inmediata apenas esté en_lugar
  bool get _canCancelNoShow => _isEnLugar;

  // ================== Recordatorio “card flotante” ==================
  static const String _kDontShowMapsReminderKey = 'dont_show_maps_reminder_v1';
  bool _dontShowMapsReminder = false;

  // ================== Estilo / Estado (verde + blanco) ==================

  // Verde principal
  static const Color _verde = Color(0xFF16A34A);
  static const Color _verdeSuave = Color(0xFFEAF7EF);

  Color get _estadoColor => _verde;

  bool get _isEnCurso =>
      _estado.toLowerCase().replaceAll(' ', '_') == 'en_curso';
  bool get _isEnLugar =>
      _estado.toLowerCase().replaceAll(' ', '_') == 'en_lugar';
  bool get _isEnCamino =>
      _estado.toLowerCase().replaceAll(' ', '_') == 'en_camino';

  String get _estadoTxt {
    final est = _estado.toLowerCase().replaceAll(' ', '_');
    switch (est) {
      case 'en_camino':
        return 'En camino';
      case 'en_lugar':
        return 'En el lugar';
      case 'en_curso':
        return 'En curso';
      case 'completado':
        return 'Completado';
      default:
        return _estado.isEmpty ? '---' : _estado;
    }
  }

  IconData get _estadoIcono {
    final est = _estado.toLowerCase().replaceAll(' ', '_');
    switch (est) {
      case 'en_camino':
        return Icons.directions_car_filled_rounded;
      case 'en_lugar':
        return Icons.place_rounded;
      case 'en_curso':
        return Icons.route_rounded;
      case 'completado':
        return Icons.check_circle_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  String get _etiquetaPaso {
    final est = _estado.toLowerCase().replaceAll(' ', '_');
    if (est == 'en_curso') return 'En ruta';
    if (est == 'en_camino' || est == 'en_lugar') return 'Recogida';
    return 'Info';
  }

  // ================== Lifecycle ==================

  @override
  void initState() {
    super.initState();

    final args = (Modular.args.data as Map?) ?? {};
    _origLat = (args['origenLat'] as num?)?.toDouble();
    _origLng = (args['origenLng'] as num?)?.toDouble();
    _origLabel = (args['origenTexto'] as String?) ?? 'Recogida';
    _rutaDoc = (args['rutaDoc'] as String?);
    _driverUid =
        (args['driverUid'] as String?) ??
        fb.FirebaseAuth.instance.currentUser?.uid;

    _loadMapsReminderPref();

    _setupRtdbRef();
    _listenOrderDoc();
    _initLocationAndStart();
  }

  @override
  void dispose() {
    _docSub?.cancel();
    _stopTracking(eraseNode: false);
    _ticker?.cancel();
    _ticker = null;

    _waitTimer?.cancel();
    _waitTimer = null;

    _routeController.dispose();
    _map = null;
    super.dispose();
  }

  // ================== Preferencia recordatorio ==================

  Future<void> _loadMapsReminderPref() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final v = sp.getBool(_kDontShowMapsReminderKey) ?? false;
      if (!mounted) return;
      setState(() => _dontShowMapsReminder = v);
    } catch (_) {}
  }

  Future<void> _setDontShowMapsReminder(bool value) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(_kDontShowMapsReminderKey, value);
      if (!mounted) return;
      setState(() => _dontShowMapsReminder = value);
    } catch (_) {}
  }

  // ================== Punto objetivo ==================

  /// Punto objetivo según estado:
  /// - en_camino / en_lugar -> ORIGEN (recogida)
  /// - en_curso -> DESTINO
  ({double lat, double lng, String etiqueta})? _getPuntoObjetivo() {
    final est = _estado.toLowerCase().replaceAll(' ', '_');

    if (est == 'en_curso') {
      if (_destLat != null && _destLng != null) {
        return (
          lat: _destLat!,
          lng: _destLng!,
          etiqueta: _destLabel ?? 'Destino',
        );
      }
      return null;
    }

    if (_origLat != null && _origLng != null) {
      return (
        lat: _origLat!,
        lng: _origLng!,
        etiqueta: _origLabel ?? 'Recogida',
      );
    }
    return null;
  }

  // ================== Métricas ==================

  void _recalcularDistanciaYETA(geo.Position pos) {
    final t = _getPuntoObjetivo();
    if (t == null) {
      if (!mounted) return;
      setState(() {
        _distanciaObjetivoM = null;
        _etaSegundos = null;
      });
      return;
    }

    final metros = geo.Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      t.lat,
      t.lng,
    );

    if (metros <= 25) {
      if (!mounted) return;
      setState(() {
        _distanciaObjetivoM = metros;
        _etaSegundos = 0;
      });
      return;
    }

    final est = _estado.toLowerCase().replaceAll(' ', '_');
    final fallbackMps = (est == 'en_curso') ? 9.0 : 7.5;

    final s = (pos.speed.isFinite && pos.speed > 1.5) ? pos.speed : fallbackMps;
    final speed = s.clamp(4.0, 16.0);

    final etaSec = (metros / speed).round();

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

  // ================== Firestore: escuchar orden ==================

  void _listenOrderDoc() {
    if (_rutaDoc == null || _rutaDoc!.isEmpty) return;
    final ref = FirebaseFirestore.instance.doc(_rutaDoc!);

    _docSub = ref.snapshots().listen((snap) async {
      if (!mounted) return;

      final data = snap.data() ?? const <String, dynamic>{};
      final String nuevoEstado = (data['estado'] ?? '').toString().trim();

      // destino
      double? dLat = _toDouble(
        _firstNonNull([
          _fromMap(data, ['destino', 'lat']),
          data['destinoLat'],
          data['bLat'],
        ]),
      );
      double? dLng = _toDouble(
        _firstNonNull([
          _fromMap(data, ['destino', 'lng']),
          data['destinoLng'],
          data['bLng'],
        ]),
      );
      final String dLabel =
          _firstNonEmpty([
            _fromMap(data, ['destino', 'calle']),
            data['destinoCalle'],
            data['destinoTitulo'],
            data['bCalle'],
            data['bTitulo'],
          ]) ??
          'Destino';

      // arrivedAt
      DateTime? arrivedAt;
      final a = data['arrivedAt'];
      if (a is Timestamp) arrivedAt = a.toDate().toLocal();
      if (a is String) arrivedAt = DateTime.tryParse(a)?.toLocal();

      final lower = nuevoEstado.toLowerCase().replaceAll(' ', '_');

      if (!mounted) return;
      setState(() {
        _estado = nuevoEstado;
        _destLat = dLat;
        _destLng = dLng;
        _destLabel = dLabel;

        // chatId
        try {
          final c = data['chatId'];
          if (c != null && c.toString().isNotEmpty) _chatId = c.toString();
        } catch (_) {}

        if (lower == 'en_curso') {
          _origLat = null;
          _origLng = null;
        }

        if (lower == 'en_lugar') {
          _arrivedAtLocal = arrivedAt ?? _arrivedAtLocal ?? DateTime.now();
        } else {
          _arrivedAtLocal = null;
        }
      });

      // Timer de espera
      if (lower == 'en_lugar') {
        _startWaitTimerIfNeeded();
      } else {
        _stopWaitTimer(reset: true);
      }

      // métricas
      if (_lastPos != null) _recalcularDistanciaYETA(_lastPos!);

      // tracking
      if (lower == 'en_curso' || lower == 'en_camino' || lower == 'en_lugar') {
        _startTrackingIfNeeded();
      } else if (lower == 'completado') {
        await _stopTracking(eraseNode: false);
      }

      if (_mapReady && _lastPos != null) {
        await _map!.borrarPuntoFijo();
        await _drawByEstado(from: _lastPos!, forceImmediate: true);
        if (!mounted) return;
        await _putCarEmojiAt(_lastPos!);
        await _addDestinationPinIfNeeded();
      }

      if (nuevoEstado == 'completado' && !_navigated && mounted) {
        _navigated = true;

        await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => RatingModal(
            rutaDoc: data['rutaDoc'] ?? '',
            idUsuarioOrigen: _driverUid!,
            idUsuarioDestino: data['uidPasajero'] ?? '',
            rolDestino: 'pasajero',
          ),
        );

        if (!mounted) return;

        await Navigator.of(context).maybePop();
        await _stopTracking(eraseNode: false);
        Modular.to.pushReplacementNamed('/home-taxista/historial_taxista');
      }
    });
  }

  // ================== RTDB ==================

  void _setupRtdbRef() {
    if (_driverUid == null || _driverUid!.isEmpty) return;
    _driverRtdbRef = FirebaseDatabase.instance.ref('taxistas/${_driverUid!}');
  }

  Future<void> _publishDriverLoc(geo.Position pos) async {
    if (!_tracking || _driverRtdbRef == null) return;
    try {
      await _driverRtdbRef!.update({
        'lat': pos.latitude,
        'lng': pos.longitude,
        't': ServerValue.timestamp,
      });
    } catch (_) {}
  }

  // ================== Tracking ==================

  void _startTrackingIfNeeded() {
    if (_tracking) return;
    _tracking = true;

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: _tickSeconds), (_) async {
      if (!_tracking) return;
      try {
        final pos = await geo.Geolocator.getCurrentPosition(
          desiredAccuracy: geo.LocationAccuracy.best,
        );
        if (_shouldUpload(pos)) {
          _lastPos = pos;

          _recalcularDistanciaYETA(pos);

          if (_mapReady) {
            await _map!.borrarPuntoFijo();
            await _drawByEstado(from: pos);
            if (!mounted) return;
            await _putCarEmojiAt(pos);
            await _addDestinationPinIfNeeded();
          }
          await _publishDriverLoc(pos);
        }
      } catch (_) {}
    });
  }

  Future<void> _stopTracking({bool eraseNode = false}) async {
    _tracking = false;
    _ticker?.cancel();
    _ticker = null;
    _lastUploaded = null;

    if (eraseNode && _driverRtdbRef != null) {
      try {
        await _driverRtdbRef!.remove();
      } catch (_) {}
    }
  }

  // ================== Ubicación / Mapa ==================

  Future<void> _initLocationAndStart() async {
    var p = await geo.Geolocator.checkPermission();
    if (p == geo.LocationPermission.denied) {
      p = await geo.Geolocator.requestPermission();
    }
    if (p == geo.LocationPermission.denied ||
        p == geo.LocationPermission.deniedForever) {
      _snack('Necesito permiso de ubicación para trazar la ruta.');
      return;
    }

    try {
      final pos = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
      _lastPos = pos;

      _recalcularDistanciaYETA(pos);

      if (_mapReady) {
        await _map!.borrarPuntoFijo();
        await _drawByEstado(from: pos, forceImmediate: true);
        if (!mounted) return;
        await _putCarEmojiAt(pos);
        await _addDestinationPinIfNeeded();
      }

      _lastUploaded = null;

      final lower = _estado.toLowerCase().replaceAll(' ', '_');
      if (lower == 'en_curso' || lower == 'en_camino' || lower == 'en_lugar') {
        _startTrackingIfNeeded();
        await _publishDriverLoc(pos);
      }
    } catch (_) {}
  }

  bool _shouldUpload(geo.Position p) {
    if (_lastUploaded == null) {
      _lastUploaded = p;
      return true;
    }
    final d = geo.Geolocator.distanceBetween(
      _lastUploaded!.latitude,
      _lastUploaded!.longitude,
      p.latitude,
      p.longitude,
    );
    final headingDelta = (p.heading - _lastUploaded!.heading).abs();
    if (d >= _minMeters || headingDelta >= _minHeading) {
      _lastUploaded = p;
      return true;
    }
    return false;
  }

  Future<void> _onMapReady(MapaController ctrl) async {
    _map = ctrl;
    _mapReady = true;

    await Future.delayed(const Duration(milliseconds: 300));

    if (_lastPos != null) {
      await _map!.borrarPuntoFijo();
      await _drawByEstado(from: _lastPos!, forceImmediate: true);
      if (!mounted) return;
      await _putCarEmojiAt(_lastPos!);
      await _addDestinationPinIfNeeded();
    }
  }

  // ========== Trazado según estado ==========

  Future<void> _drawByEstado({
    required geo.Position from,
    bool forceImmediate = false,
  }) async {
    if (_map == null || !_mapReady) return;

    if (_isDrawingRoute) {
      debugPrint('⏭️ Ya hay una ruta dibujándose, saltando...');
      return;
    }

    final est = _estado.toLowerCase().replaceAll(' ', '_');

    if (est == 'en_curso') {
      if (_destLat != null && _destLng != null) {
        final origin = mb.Point(
          coordinates: mb.Position(from.longitude, from.latitude),
        );
        final destination = mb.Point(
          coordinates: mb.Position(_destLng!, _destLat!),
        );

        if (forceImmediate) {
          _isDrawingRoute = true;
          try {
            await _draw(from: from, toLat: _destLat!, toLng: _destLng!);
          } finally {
            _isDrawingRoute = false;
          }
        } else {
          _routeController.scheduleUpdate(
            origin: origin,
            destination: destination,
            onUpdate: () async {
              _isDrawingRoute = true;
              try {
                await _draw(from: from, toLat: _destLat!, toLng: _destLng!);
              } finally {
                _isDrawingRoute = false;
              }
            },
          );
        }
      }
    } else {
      if (_origLat != null && _origLng != null) {
        final origin = mb.Point(
          coordinates: mb.Position(from.longitude, from.latitude),
        );
        final destination = mb.Point(
          coordinates: mb.Position(_origLng!, _origLat!),
        );

        if (forceImmediate) {
          _isDrawingRoute = true;
          try {
            await _draw(from: from, toLat: _origLat!, toLng: _origLng!);
          } finally {
            _isDrawingRoute = false;
          }
        } else {
          _routeController.scheduleUpdate(
            origin: origin,
            destination: destination,
            onUpdate: () async {
              _isDrawingRoute = true;
              try {
                await _draw(from: from, toLat: _origLat!, toLng: _origLng!);
              } finally {
                _isDrawingRoute = false;
              }
            },
          );
        }
      }
    }
  }

  Future<void> _draw({
    required geo.Position from,
    required double toLat,
    required double toLng,
  }) async {
    try {
      await _map!.dibujarRutaDesdeHasta(
        a: mb.Point(coordinates: mb.Position(from.longitude, from.latitude)),
        b: mb.Point(coordinates: mb.Position(toLng, toLat)),
        context: context,
      );
    } catch (e) {
      _snack('No se pudo trazar la ruta: $e');
    }
  }

  // ================== "Autito" con emoji 🚕 ==================

  Future<void> _putCarEmojiAt(geo.Position pos) async {
    if (_map == null || !_mapReady) return;
    try {
      await _map!.agregarPuntoFijo(
        mb.Point(coordinates: mb.Position(pos.longitude, pos.latitude)),
        fillColor: Colors.white,
        strokeColor: _verde,
        radius: 5,
        strokeWidth: 6,
        label: '🚕',
      );
    } catch (_) {}
  }

  // ================== Pin verde del objetivo 📍 ==================

  Future<void> _addDestinationPinIfNeeded() async {
    if (_map == null || !_mapReady) return;

    final est = _estado.toLowerCase().replaceAll(' ', '_');

    if (est == 'en_curso') {
      if (_destLat != null && _destLng != null) {
        await _putDestinationPin(_destLat!, _destLng!);
      }
    } else {
      if (_origLat != null && _origLng != null) {
        await _putDestinationPin(_origLat!, _origLng!);
      }
    }
  }

  Future<void> _putDestinationPin(double lat, double lng) async {
    if (_map == null || !_mapReady) return;
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

  // ================== Snack sin context ==================

  void _snack(String m) {
    final ms = _messengerKey.currentState;
    if (ms == null) return;

    ms.clearSnackBars();
    ms.showSnackBar(
      SnackBar(content: Text(m), behavior: SnackBarBehavior.floating),
    );
  }

  // ================== Card flotante (Aceptar / No mostrar más) ==================

  Future<bool> _showMapsReminderCard() async {
    if (_dontShowMapsReminder) return true;
    if (!mounted) return true;

    final est = _estado.toLowerCase().replaceAll(' ', '_');
    final destinoTxt = (est == 'en_curso') ? 'al destino' : 'a la recogida';

    final res = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'recordatorio',
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) {
        return SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 30,
                    offset: Offset(0, 16),
                    color: Color(0x33000000),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: _verde.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.info_rounded, color: _verde),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Aviso',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Vas a abrir Google Maps $destinoTxt.\n'
                      'Recuerda volver a la app para informar al pasajero y actualizar tu estado.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.25,
                        color: Colors.black.withOpacity(0.75),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              await _setDontShowMapsReminder(true);
                              if (!mounted) return;
                              Navigator.of(context).pop(true);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _verde,
                              side: BorderSide(
                                color: _verde.withOpacity(0.35),
                                width: 1.4,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: const Text(
                              'No mostrar más',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (!mounted) return;
                              Navigator.of(context).pop(true);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _verde,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: const Text(
                              'Aceptar',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, anim, __, child) {
        final curve = CurvedAnimation(parent: anim, curve: Curves.easeOut);
        return Transform.translate(
          offset: Offset(0, (1 - curve.value) * 30),
          child: Opacity(opacity: curve.value, child: child),
        );
      },
    );

    // Si el usuario tocó afuera (dismiss), no abrimos maps
    return res == true;
  }

  // ================== Google Maps (según estado) ==================

  Future<void> _openGoogleMaps() async {
    final t = _getPuntoObjetivo();
    if (t == null) return _snack('No tengo coordenadas del punto objetivo.');

    // ✅ Card flotante con Aceptar / No mostrar más
    final ok = await _showMapsReminderCard();
    if (!ok) return;

    final dest = '${t.lat},${t.lng}';
    final originLatLng = (_lastPos != null)
        ? '${_lastPos!.latitude},${_lastPos!.longitude}'
        : null;

    final params = <String, String>{
      'api': '1',
      'destination': dest,
      'travelmode': 'driving',
      'dir_action': 'navigate',
    };
    if (originLatLng != null) params['origin'] = originLatLng;

    final uri = Uri.https('www.google.com', '/maps/dir/', params);

    try {
      final okLaunch = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!okLaunch) _snack('No se pudo abrir Google Maps.');
    } catch (e) {
      _snack('No se pudo abrir Google Maps: $e');
    }
  }

  // ================== Acciones ==================

  Future<void> _marcarLlegada() async {
    if (_rutaDoc == null || _rutaDoc!.isEmpty) {
      return _snack('No tengo la ruta del documento.');
    }
    try {
      await FirebaseFirestore.instance.doc(_rutaDoc!).update({
        'estado': 'en_lugar',
        'arrivedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Inicia contador local inmediato
      if (!mounted) return;
      setState(() {
        _arrivedAtLocal = DateTime.now();
        _waitElapsed = Duration.zero;
      });
      _startWaitTimerIfNeeded();

      // enviar mensaje al chat avisando que el conductor llegó
      try {
        String? chatId = _chatId;
        if (chatId == null || chatId.isEmpty) {
          try {
            final snap = await FirebaseFirestore.instance.doc(_rutaDoc!).get();
            final d = snap.data();
            final c = d != null ? d['chatId'] : null;
            if (c != null && c.toString().isNotEmpty) chatId = c.toString();
          } catch (_) {}
        }

        final myUid =
            _driverUid ?? fb.FirebaseAuth.instance.currentUser?.uid ?? '';
        if (chatId != null && chatId.isNotEmpty && myUid.isNotEmpty) {
          await ChatRepository().sendMessage(
            chatId: chatId,
            myUid: myUid,
            text: 'Ya llegué a tu ubicación. ¿Me ves?',
          );
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Error enviando mensaje de llegada: $e');
      }

      _snack('Marcado como “Ya me encuentro en la ubicación”.');
    } catch (e) {
      _snack('Error al actualizar: $e');
    }
  }

  Future<void> _iniciarViaje() async {
    if (_rutaDoc == null || _rutaDoc!.isEmpty) {
      return _snack('No tengo la ruta del documento.');
    }
    try {
      await FirebaseFirestore.instance.doc(_rutaDoc!).update({
        'estado': 'en_curso',
        'startedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _stopWaitTimer(reset: true);

      if (!mounted) return;
      setState(() {
        _estado = 'en_curso';
        _origLat = null;
        _origLng = null;
      });

      if (_lastPos != null) _recalcularDistanciaYETA(_lastPos!);

      _startTrackingIfNeeded();

      if (_mapReady && _lastPos != null) {
        await _map!.borrarPuntoFijo();
        await _drawByEstado(from: _lastPos!, forceImmediate: true);
        if (!mounted) return;
        await _putCarEmojiAt(_lastPos!);
        await _addDestinationPinIfNeeded();
      }

      _snack('Viaje iniciado.');
    } catch (e) {
      _snack('Error al actualizar: $e');
    }
  }

  Future<void> _cancelTripByDriver() async {
    if (_cancelling) return;

    if (_rutaDoc == null || _rutaDoc!.isEmpty) {
      return _snack('No tengo la ruta del documento.');
    }

    // Confirmación básica
    final shouldCancel = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final motivoTexto = _isEnLugar
            ? 'El pasajero no se presenta y quieres cancelar el viaje.'
            : 'Quieres cancelar este viaje.';
        return AlertDialog(
          title: const Text('Cancelar viaje'),
          content: Text(
            '$motivoTexto\n\nEsta acción marcará el viaje como cancelado.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Volver'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Cancelar viaje'),
            ),
          ],
        );
      },
    );

    if (shouldCancel != true) return;

    setState(() => _cancelling = true);

    try {
      final docRef = FirebaseFirestore.instance.doc(_rutaDoc!);
      final snap = await docRef.get();
      final data = snap.data() ?? <String, dynamic>{};

      final String? rutaDocPasajero = (data['rutaDoc'] is String)
          ? data['rutaDoc'] as String
          : null;

      final motivo = _isEnLugar ? 'taxista_no_show' : 'taxista';

      final updateData = <String, dynamic>{
        'estado': 'cancelado',
        'canceladoPor': motivo,
        'canceladoEn': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Actualizar documento que está viendo el taxista
      await docRef.update(updateData);

      // Intentar actualizar el documento del pasajero si tenemos la ruta
      if (rutaDocPasajero != null && rutaDocPasajero.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .doc(rutaDocPasajero)
              .update(updateData);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error al actualizar doc pasajero: $e');
          }
        }
      }

      await _stopTracking(eraseNode: true);
      _stopWaitTimer(reset: true);

      if (!mounted) return;

      // ✅ Directo (sin delay)
      _snack('Viaje cancelado.');
      Modular.to.pushReplacementNamed('/home-taxista/historial_taxista');
    } catch (e, st) {
      if (mounted) {
        _snack('Error al cancelar: $e');
      }
      if (kDebugMode) {
        debugPrint('ERROR cancelar viaje taxista: $e\n$st');
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _finishTrip() async {
    if (_finishing) return;
    setState(() => _finishing = true);

    if (_rutaDoc == null || _rutaDoc!.isEmpty) {
      setState(() => _finishing = false);
      return _snack('No tengo la ruta del documento.');
    }

    try {
      await _stopTracking(eraseNode: false);
      _stopWaitTimer(reset: true);

      final ref = FirebaseFirestore.instance.doc(_rutaDoc!);
      final viajeDoc = await ref.get();
      final viajeData = viajeDoc.data();

      bool esProgramado = false;
      bool todasFechasCompletadas = false;

      if (viajeData != null) {
        esProgramado =
            (viajeData['isProgramado'] == true) ||
            (viajeData['programado'] == true) ||
            (viajeData['programacion'] is Map);

        if (esProgramado) {
          final hoy = DateTime.now().toLocal();
          final ymdHoy = _ymd(hoy);

          try {
            await _registrarComisionFechaProgramada(viajeData, ymdHoy);
          } catch (e, st) {
            debugPrint('❌ Error al registrar comisión programada: $e\n$st');
          }

          try {
            todasFechasCompletadas = await _marcarProgramadoHoyComoCompletado(
              viajeData,
            );
          } catch (e, st) {
            debugPrint('⚠️ Error marcando fecha completada: $e\n$st');
          }
        }
      }

      final String nuevoEstado = esProgramado
          ? (todasFechasCompletadas ? 'completado' : 'aceptado')
          : 'completado';

      await ref.update({
        'estado': nuevoEstado,
        'finishedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) setState(() => _estado = nuevoEstado);

      String comisionMsg = '';
      final debeRegistrarComision = !esProgramado;

      if (viajeData != null && debeRegistrarComision) {
        try {
          await _registrarComisionViaje(viajeData);
          comisionMsg = ' comisión registrada';
        } catch (e, st) {
          comisionMsg = ' | Error comisión';
          debugPrint('ERROR COMISIÓN: $e\n$st');
        }
      } else if (esProgramado) {
        comisionMsg = ' | Comisión por fecha ✅';
      }

      if (!mounted) return;
      _snack(
        nuevoEstado == 'completado'
            ? '¡Viaje completado!$comisionMsg'
            : 'Día programado completado. El viaje sigue activo para otras fechas.',
      );
    } catch (e, st) {
      if (mounted) _snack('Error al completar: $e');
      debugPrint('ERROR finishTrip: $e\n$st');
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  // ================== Programados + comisión ==================

  Future<bool> _marcarProgramadoHoyComoCompletado(
    Map<String, dynamic> viajeData,
  ) async {
    if (_rutaDoc == null || _rutaDoc!.isEmpty) return false;

    final progRaw = viajeData['programacion'];
    if (progRaw is! Map) return false;

    final prog = Map<String, dynamic>.from(progRaw);

    final hoy = DateTime.now().toLocal();
    final ymdHoy = _ymd(hoy);

    final cancelled = (prog['cancelledDates'] is List)
        ? Set<String>.from(
            (prog['cancelledDates'] as List).map(
              (e) => e.toString().substring(0, 10),
            ),
          )
        : <String>{};

    final completedExistentes = (prog['completedDates'] is List)
        ? Set<String>.from(
            (prog['completedDates'] as List).map(
              (e) => e.toString().substring(0, 10),
            ),
          )
        : <String>{};

    final completedActualizados = Set<String>.from(completedExistentes)
      ..add(ymdHoy);

    final Set<String> todasFechasProgramadas = _buildProgrammedYmds(
      data: viajeData,
      prog: prog,
    );

    final Set<String> fechasActivas = todasFechasProgramadas
        .where((f) => !cancelled.contains(f))
        .toSet();

    final bool todasCompletadas =
        fechasActivas.isNotEmpty &&
        completedActualizados.containsAll(fechasActivas);

    final docRef = FirebaseFirestore.instance.doc(_rutaDoc!);

    await docRef.update({
      'programacion.completedDates': FieldValue.arrayUnion([ymdHoy]),
    });

    await docRef.collection('events').add({
      'type': 'occurrence_completed',
      'createdAt': FieldValue.serverTimestamp(),
      'by': 'taxista',
      'ymd': ymdHoy,
    });

    return todasCompletadas;
  }

  Set<String> _buildProgrammedYmds({
    required Map<String, dynamic> data,
    required Map<String, dynamic> prog,
  }) {
    final result = <String>{};

    final datesLocal = (prog['datesLocal'] is List)
        ? List<String>.from(prog['datesLocal'])
        : <String>[];
    final timeList = prog['timeLocal']?.toString();

    if (timeList != null && datesLocal.isNotEmpty) {
      for (final d in datesLocal) {
        if (d.length >= 10) result.add(d.substring(0, 10));
      }
      if (result.isNotEmpty) return result;
    }

    final range = (prog['range'] as Map?) ?? {};
    final timeLocal = (range['timeLocal'] ?? prog['timeLocal'])?.toString();
    final startLocal = (range['startLocal'] ?? range['start'])?.toString();
    final endLocal = (range['endLocal'] ?? range['end'])?.toString();

    DateTime? _parseYMD(String s) {
      final base = s.length >= 10 ? s.substring(0, 10) : s;
      return DateTime.tryParse('${base}T00:00:00.000');
    }

    if (timeLocal != null && startLocal != null && endLocal != null) {
      final start = _parseYMD(startLocal);
      final end = _parseYMD(endLocal);
      if (start != null && end != null && !end.isBefore(start)) {
        final weekdays = (range['weekdays'] is List)
            ? List<int>.from(range['weekdays'])
            : <int>[];
        final excludes = (range['excludes'] is List)
            ? Set<String>.from(
                range['excludes'].map((e) => e.toString().substring(0, 10)),
              )
            : <String>{};

        String two(int n) => n.toString().padLeft(2, '0');

        for (
          DateTime cur = DateTime(start.year, start.month, start.day);
          !cur.isAfter(end);
          cur = cur.add(const Duration(days: 1))
        ) {
          final ymd = '${cur.year}-${two(cur.month)}-${two(cur.day)}';
          if (weekdays.isNotEmpty && !weekdays.contains(cur.weekday)) continue;
          if (excludes.contains(ymd)) continue;
          result.add(ymd);
        }
        if (result.isNotEmpty) return result;
      }
    }

    final sched = (data['scheduledAtLocal'] ?? '').toString();
    if (sched.isNotEmpty) {
      final dt = DateTime.tryParse(sched);
      if (dt != null) result.add(_ymd(dt));
    }

    return result;
  }

  Future<void> _registrarComisionViaje(Map<String, dynamic> viajeData) async {
    final montoTotal =
        ((viajeData['tarifa']?['total'] ?? viajeData['total'] ?? 0) as num)
            .toDouble();
    final servicio = (viajeData['servicio'] as String?) ?? 'Taxi';
    final viajeId = _rutaDoc?.split('/').last ?? '';
    final pasajeroId = viajeData['uidPasajero'] as String?;
    final pasajeroNombre = viajeData['nombrePasajero'] as String?;

    final departamento = viajeData['departamento'] as String? ?? 'Cochabamba';
    double porcentajeComision = 0.0;

    final servicioKey = servicio
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^\w\-]'), '')
        .toLowerCase();

    final tarifaDocPath = 'empresas/mujeresalvolante/tarifas/$departamento';
    final tarifaDoc = await FirebaseFirestore.instance.doc(tarifaDocPath).get();

    if (tarifaDoc.exists) {
      final tarifaData = tarifaDoc.data();
      final servicioData = tarifaData?[servicioKey] as Map<String, dynamic>?;
      final tarifasMap = servicioData?['tarifas'] as Map<String, dynamic>?;
      porcentajeComision = ((tarifasMap?['comision'] ?? 0) as num).toDouble();
    }

    if (porcentajeComision <= 0) {
      throw Exception(
        'No se registra comisión: porcentaje=$porcentajeComision (debe ser > 0)',
      );
    }
    if (montoTotal <= 0) {
      throw Exception(
        'No se registra comisión: monto=$montoTotal (debe ser > 0)',
      );
    }

    final walletService = TaxistaWalletService();
    await walletService.registrarComision(
      montoViaje: montoTotal,
      porcentajeComision: porcentajeComision,
      viajeId: viajeId,
      servicio: servicio,
      pasajeroId: pasajeroId,
      pasajeroNombre: pasajeroNombre,
    );
  }

  Future<void> _registrarComisionFechaProgramada(
    Map<String, dynamic> viajeData,
    String ymdFecha,
  ) async {
    if (_rutaDoc == null || _rutaDoc!.isEmpty) return;

    final comisionesCobradas = (viajeData['comisionesCobradas'] is List)
        ? List<String>.from(viajeData['comisionesCobradas'])
        : <String>[];

    if (comisionesCobradas.contains(ymdFecha)) return;

    final montoTotal =
        ((viajeData['tarifa']?['total'] ?? viajeData['total'] ?? 0) as num)
            .toDouble();
    final servicio = (viajeData['servicio'] as String?) ?? 'Taxi';
    final ordenId = _rutaDoc?.split('/').last ?? '';
    final viajeIdUnico = '${ordenId}_$ymdFecha';
    final pasajeroId = viajeData['uidPasajero'] as String?;
    final pasajeroNombre = viajeData['nombrePasajero'] as String?;

    final departamento = viajeData['departamento'] as String? ?? 'Cochabamba';
    double porcentajeComision = 0.0;

    final servicioKey = servicio
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^\w\-]'), '')
        .toLowerCase();

    final tarifaDocPath = 'empresas/mujeresalvolante/tarifas/$departamento';
    final tarifaDoc = await FirebaseFirestore.instance.doc(tarifaDocPath).get();

    if (tarifaDoc.exists) {
      final tarifaData = tarifaDoc.data();
      final servicioData = tarifaData?[servicioKey] as Map<String, dynamic>?;
      final tarifasMap = servicioData?['tarifas'] as Map<String, dynamic>?;
      porcentajeComision = ((tarifasMap?['comision'] ?? 0) as num).toDouble();
    }

    if (porcentajeComision <= 0) {
      throw Exception('No se puede registrar comisión: porcentaje inválido');
    }
    if (montoTotal <= 0) {
      throw Exception('No se puede registrar comisión: monto inválido');
    }

    final walletService = TaxistaWalletService();
    await walletService.registrarComision(
      montoViaje: montoTotal,
      porcentajeComision: porcentajeComision,
      viajeId: viajeIdUnico,
      servicio: servicio,
      pasajeroId: pasajeroId,
      pasajeroNombre: pasajeroNombre,
    );

    final docRef = FirebaseFirestore.instance.doc(_rutaDoc!);
    await docRef.update({
      'comisionesCobradas': FieldValue.arrayUnion([ymdFecha]),
    });
  }

  // ================== UI ==================

  @override
  Widget build(BuildContext context) {
    final punto = _getPuntoObjetivo();
    final mostrarAccionesRecogida = _isEnCamino || _isEnLugar;
    final mostrarAccionCurso = _isEnCurso;

    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: MapaWidget(
                centerLat:
                    (_isEnCurso ? (_destLat ?? _origLat) : _origLat) ??
                    -17.3895,
                centerLng:
                    (_isEnCurso ? (_destLng ?? _origLng) : _origLng) ??
                    -66.1568,
                onMapReady: _onMapReady,
              ),
            ),

            // Panel inferior
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: SafeArea(
                top: false,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
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
                      // Encabezado
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _verdeSuave,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _verde.withOpacity(0.25),
                              ),
                            ),
                            child: Icon(_estadoIcono, color: _estadoColor),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _estadoTxt,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  punto?.etiqueta ??
                                      (_isEnCurso ? 'Destino' : 'Recogida'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.black.withOpacity(0.55),
                                    fontWeight: FontWeight.w600,
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
                              _etiquetaPaso,
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

                      // Métricas
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

                      // Espera
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
                                child: Icon(
                                  Icons.hourglass_bottom_rounded,
                                  size: 16,
                                  color: _verde,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Esperando: $_waitTxt',
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

                      const SizedBox(height: 12),

                      // Dirección objetivo
                      _PlaceRow(
                        icon: _isEnCurso
                            ? Icons.flag_rounded
                            : Icons.my_location_rounded,
                        label: _isEnCurso ? 'Destino' : 'Punto de recogida',
                        text: _isEnCurso
                            ? (_destLabel ?? 'Destino')
                            : (_origLabel ?? 'Recogida'),
                        accent: _verde,
                      ),

                      const SizedBox(height: 12),

                      // ✅ Botón Google Maps
                      if (punto != null) ...[
                        _SecondaryActionButton(
                          icon: Icons.map_rounded,
                          text: _isEnCurso
                              ? 'Google Maps (Destino)'
                              : 'Google Maps (Recogida)',
                          onPressed: _openGoogleMaps,
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Botones por estado
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Column(
                          key: ValueKey<String>(
                            _estado.toLowerCase().replaceAll(' ', '_'),
                          ),
                          children: [
                            if (mostrarAccionesRecogida) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: _PrimaryActionButton(
                                      icon: Icons.place_rounded,
                                      text: 'Ya llegué',
                                      onPressed: _marcarLlegada,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _SecondaryActionButton(
                                      icon: Icons.play_arrow_rounded,
                                      text: 'Iniciar viaje',
                                      onPressed: _iniciarViaje,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 8),

                              // ✅ Cancelar directo (sin espera)
                              _SecondaryActionButton(
                                icon: Icons.cancel_rounded,
                                text: _cancelling
                                    ? 'Cancelando...'
                                    : (_canCancelNoShow
                                          ? 'Cancelar (pasajero no llegó)'
                                          : 'Cancelar viaje'),
                                onPressed: _cancelling
                                    ? null
                                    : _cancelTripByDriver,
                              ),
                            ],
                            if (mostrarAccionCurso) ...[
                              _PrimaryActionButton(
                                icon: Icons.check_rounded,
                                text: _finishing
                                    ? 'Finalizando...'
                                    : 'Finalizado',
                                onPressed: _finishing ? null : _finishTrip,
                                fullWidth: true,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================== Widgets UI ==================

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

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.icon,
    required this.label,
    required this.text,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        color: Colors.white,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.black.withOpacity(0.55),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
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

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.icon,
    required this.text,
    required this.onPressed,
    this.fullWidth = false,
  });

  final IconData icon;
  final String text;
  final VoidCallback? onPressed;
  final bool fullWidth;

  static const Color _verde = Color(0xFF16A34A);

  @override
  Widget build(BuildContext context) {
    final child = SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _verde,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          disabledBackgroundColor: _verde.withOpacity(0.45),
          disabledForegroundColor: Colors.white.withOpacity(0.85),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (fullWidth) return child;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 0),
      child: child,
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({
    required this.icon,
    required this.text,
    required this.onPressed,
  });

  final IconData icon;
  final String text;
  final VoidCallback? onPressed;

  static const Color _verde = Color(0xFF16A34A);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: _verde,
          side: BorderSide(color: _verde.withOpacity(0.35), width: 1.4),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          backgroundColor: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: _verde),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ================== helpers ================== */

String _ymd(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final dd = d.toLocal();
  return '${dd.year}-${two(dd.month)}-${two(dd.day)}';
}

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
