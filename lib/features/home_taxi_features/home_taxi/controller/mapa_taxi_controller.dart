// lib/features/home_taxi_features/home_taxi/controller/mapa_taxi_controller.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:buses2/core/services/data/usuarios_model/taxista_model.dart';
import 'package:buses2/core/services/mapa_taxi/mapbox_taxi/mapa_widget_taxi.dart'
    show MapaController;

/// Fases del contador para colorear el progreso
enum _Phase { green, orange, red }

class MapaTaxiController extends ChangeNotifier {
  MapaTaxiController({
    required Map<String, dynamic> args,
    required TickerProvider tickerProvider,
    required this.onTimeout,
    required this.onToActivo,
  }) : _args = args,
       _ticker = tickerProvider;

  // ========= Callbacks externos =========
  final VoidCallback onTimeout; // -> Navigator.pop({'accion':'timeout'})
  final VoidCallback onToActivo; // -> Navigator.pop({'accion':'activo'})

  // ========= Args crudos =========
  final Map<String, dynamic> _args;
  final TickerProvider _ticker;

  // ========= Datos mostrados en UI =========
  // Origen (A)
  double? aLat, aLng;
  String? aCalle, aCiudad, aPais;

  // Destino (B)
  double? bLat, bLng;
  String? bTexto, bCalle, bCiudad, bPais;

  // Pedido
  double? precio; // precio base/mostrado al taxista
  double precioEditable = 0;
  double? distanciaKm;
  bool isProgramado = false;
  List<dynamic>? scheduleDates;
  String? scheduleTime;
  String createdAtShort = '';

  // Pasajero / etiqueta
  String? pasajeroNombre;
  String? pasajeroFotoUrl;
  String? etiqueta;
  double? pasajeroRating;
  int? pasajeroRatingCount;

  // Flujo / base
  String? rutaDoc; // path absoluto de la orden
  String? idTaxista; // UID del conductor
  String? nombreTaxista;
  String? fotoTaxista;
  bool ofertaFueEnviada = false;
  Taxista? _taxista; // Modelo completo en memoria

  // ========= Mapa =========
  MapaController? map;
  bool mapReady = false;

  // ========= Timer / animación =========
  static const int _totalSeconds = 30;
  Timer? _timer;
  double progress = 0.0; // 0..1
  int secondsLeft = _totalSeconds;

  late final AnimationController _beatCtrl;
  late final Animation<double> scale;
  bool _pulsedAt6 = false;
  bool _pulsedAt3 = false;
  _Phase _phase = _Phase.green;

  // ========= Listener de la orden =========
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _orderSub;
  bool _finalizado = false;

  // ========= INIT / DISPOSE =========
  void init() {
    _leerArgs();
    precioEditable = (precio ?? 0).clamp(0, 100000).toDouble();

    _beatCtrl = AnimationController(
      vsync: _ticker,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 220),
    );
    scale = Tween<double>(
      begin: 1.0,
      end: 1.12,
    ).chain(CurveTween(curve: Curves.easeOut)).animate(_beatCtrl);

    // UID del taxista desde sesión
    idTaxista = FirebaseAuth.instance.currentUser?.uid;

    // Pre-cargar perfil del taxista (nombre/foto) desde /taxistas/{uid}
    if (idTaxista != null && idTaxista!.isNotEmpty) {
      _cargarPerfilTaxista(idTaxista!);
    }

    if (!isProgramado) {
      _iniciarTimerProgreso();
      _iniciarListenerOrden();
    } else {
      secondsLeft = _totalSeconds;
      progress = 0;
    }
  }

  void disposeAll() {
    _orderSub?.cancel();
    _timer?.cancel();
    _beatCtrl.dispose();
  }

  // ========= Parseo de argumentos =========
  void _leerArgs() {
    // Origen
    aLat = (_args['lat'] as num?)?.toDouble();
    aLng = (_args['lng'] as num?)?.toDouble();
    aCalle = _args['calle'] as String?;
    aCiudad = _args['ciudad'] as String?;
    aPais = _args['pais'] as String?;

    // Destino
    bLat = (_args['destinoLat'] as num?)?.toDouble();
    bLng = (_args['destinoLng'] as num?)?.toDouble();
    bTexto = _args['destinoTexto'] as String?;
    bCalle = _args['destinoCalle'] as String?;
    bCiudad = _args['destinoCiudad'] as String?;
    bPais = _args['destinoPais'] as String?;

    // Visual
    precio = (_args['precio'] as num?)?.toDouble();
    distanciaKm = (_args['distanciaKm'] as num?)?.toDouble();
    isProgramado = _args['isProgramado'] == true;
    scheduleDates = _args['scheduleDates'] as List<dynamic>?;
    scheduleTime = _args['scheduleTime'] as String?;
    createdAtShort = (_args['createdAtShort'] as String?) ?? '';

    pasajeroNombre = _args['pasajeroNombre'] as String?;
    pasajeroFotoUrl = _args['pasajeroFotoUrl'] as String?;
    etiqueta = _args['etiqueta'] as String?;

    pasajeroRating = (_args['pasajeroRating'] as num?)?.toDouble();
    pasajeroRatingCount = (_args['pasajeroRatingCount'] as num?)?.toInt();

    // Ruta del doc de orden
    rutaDoc = _args['rutaDoc'] as String?;
    // Revisa si ya hay una oferta enviada al iniciar
    if (rutaDoc != null && rutaDoc!.isNotEmpty) {
      final ofertasRef = FirebaseFirestore.instance
          .doc(rutaDoc!)
          .collection('ofertas')
          .doc(FirebaseAuth.instance.currentUser?.uid);

      ofertasRef.get().then((snap) {
        if (snap.exists) {
          final data = snap.data();
          if (data?['estado'] == 'pendiente') {
            ofertaFueEnviada = true;
            notifyListeners();
          }
        }
      });
    }
  }

  // ========= Timer / animación =========
  void _iniciarTimerProgreso() {
    const tick = Duration(milliseconds: 50);
    final steps = (_totalSeconds * 1000) ~/ 50;
    int count = 0;
    secondsLeft = _totalSeconds;
    progress = 0;
    _phase = _calcPhase(secondsLeft);
    _pulsedAt6 = false;
    _pulsedAt3 = false;

    _timer = Timer.periodic(tick, (t) {
      if (_finalizado) {
        t.cancel();
        return;
      }

      if (ofertaFueEnviada) {
        t.cancel();
        return;
      }
      count++;
      final newProg = count / steps;
      final elapsedMs = count * 50;
      final left = ((_totalSeconds * 1000) - elapsedMs) ~/ 1000;
      final nextSeconds = left >= 0 ? left : 0;
      final nextPhase = _calcPhase(nextSeconds);

      if (nextSeconds == 6 && !_pulsedAt6) {
        _pulseOnce();
        _pulsedAt6 = true;
      }
      if (nextSeconds == 3 && !_pulsedAt3) {
        _pulseOnce();
        _pulsedAt3 = true;
      }

      progress = newProg.clamp(0.0, 1.0);
      secondsLeft = nextSeconds;
      _phase = nextPhase;
      notifyListeners();

      if (count >= steps) {
        t.cancel();
        if (!_finalizado) {
          _finalizado = true;
          onTimeout(); // deja que la UI navegue
        }
      }
    });
  }

  _Phase _calcPhase(int secs) {
    if (secs <= 3) return _Phase.red;
    if (secs <= 6) return _Phase.orange;
    return _Phase.green;
  }

  Future<void> _pulseOnce() async {
    try {
      await _beatCtrl.forward();
    } finally {
      await _beatCtrl.reverse();
    }
  }

  Color phaseColor() {
    switch (_phase) {
      case _Phase.green:
        return Colors.green;
      case _Phase.orange:
        return const Color(0xFFFFA726);
      case _Phase.red:
        return const Color(0xFFE53935);
    }
  }

  // ========= Listener de orden =========
  void _iniciarListenerOrden() {
    if (rutaDoc == null || rutaDoc!.isEmpty) return;
    final ref = FirebaseFirestore.instance.doc(rutaDoc!);

    _orderSub = ref.snapshots().listen((snap) async {
      if (!snap.exists) return;
      final d = snap.data() ?? {};
      final bool aceptadoTaxista = (d['aceptadoTaxista'] == true);
      final bool aceptadoPasajero = (d['aceptadoPasajero'] == true);
      String? estado = (d['estado'] as String?);

      if (aceptadoTaxista && aceptadoPasajero && estado != 'activo') {
        try {
          await ref.set({
            'estado': 'activo',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          estado = 'activo';
        } catch (_) {}
      }

      if (!_finalizado && estado == 'activo') {
        _finalizado = true;
        _timer?.cancel();
        onToActivo();
      } else if (!_finalizado && estado == 'pendiente') {
        ofertaFueEnviada = true;
        notifyListeners();
      }
    });
  }

  // ========= Precio =========
  void decPrecio() {
    precioEditable = (precioEditable - 1).clamp(0, 100000);
    notifyListeners();
  }

  void incPrecio() {
    precioEditable = (precioEditable + 1).clamp(0, 100000);
    notifyListeners();
  }

  void setPrecioEditable(double v) {
    precioEditable = v.clamp(0, 100000);
    notifyListeners();
  }

  void marcarOfertaEnviada() {
    ofertaFueEnviada = true;
    _timer?.cancel();
    notifyListeners();
  }

  bool eq2(double a, double b) =>
      (a.toStringAsFixed(2) == b.toStringAsFixed(2));

  String fmtPrecio(double? v) {
    if (v == null) return '--';
    return (v % 1 == 0)
        ? 'ARS ${v.toStringAsFixed(0)}'
        : 'ARS ${v.toStringAsFixed(2)}';
  }

  String fmtPrecioPlano(double? v) {
    if (v == null) return '--';
    return (v % 1 == 0) ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  }

  // ========= Perfil del taxista desde /taxistas/{uid} =========
  Future<void> _cargarPerfilTaxista(String uid) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('taxistas')
          .doc(uid)
          .get();
      if (snap.exists && snap.data() != null) {
        _taxista = Taxista.fromJson(snap.data()!);
        nombreTaxista = _taxista!.perfilTaxista.nombre.trim();
        fotoTaxista = _taxista!.perfilTaxista.fotoPerfil.trim();
      }
    } catch (_) {
      // silencioso
    }

    // Fallbacks desde FirebaseAuth si faltan
    nombreTaxista ??=
        FirebaseAuth.instance.currentUser?.displayName ??
        FirebaseAuth.instance.currentUser?.email?.split('@').first ??
        'Conductor';
    fotoTaxista ??= FirebaseAuth.instance.currentUser?.photoURL;
  }

  // ========= Enviar oferta (y/o aceptación) =========
  Future<void> enviarOfertaTaxista({
    required bool esAceptacion,
    double? distanciaRecogidaKm,
  }) async {
    // 1. Validaciones previas rápidas (Fail Fast)
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('Usuario no autenticado');
    if (rutaDoc == null || rutaDoc!.isEmpty)
      throw Exception('Ruta de orden inválida');

    final idUsuario = currentUser.uid;

    // Aseguramos tener cargado el modelo Taxista para extraer datos del vehículo y rating
    if (_taxista == null) {
      await _cargarPerfilTaxista(idUsuario);
    }
    final taxista = _taxista;
    final vehiculo = taxista?.documentosVehiculo;
    final promedioEstrellas = taxista?.promedioEstrellas;
    final numeroTelefono = taxista?.perfilTaxista.telefono;

    // Calcular tiempo aproximado de llegada en minutos a partir de la distancia
    double? tiempoLlegadaMin;
    final distanciaBaseKm = distanciaRecogidaKm ?? distanciaKm;
    if (distanciaBaseKm != null) {
      const velocidadPromedioKmH = 25.0; // velocidad promedio en ciudad
      tiempoLlegadaMin = (distanciaBaseKm / velocidadPromedioKmH) * 60.0;
    }

    // 2. Preparación de referencias
    final ordenRef = FirebaseFirestore.instance.doc(rutaDoc!);
    final ofertaRef = ordenRef.collection('ofertas').doc(idUsuario);

    // 3. Construcción del payload (usando sintaxis de Dart más limpia)
    final data = <String, dynamic>{
      'estado': 'pendiente',
      'uidTaxista': idUsuario,
      'idTaxista': idUsuario,
      'precioOfertado': precioEditable,
      'precioRecomendado': (_args['precio'] as num?)?.toDouble(),
      'esAceptacion': esAceptacion,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'distanciaRecogidaKm': distanciaRecogidaKm,
      // Datos de vehículo
      if (vehiculo != null) 'colorVehiculo': vehiculo.color,
      if (vehiculo != null) 'marcaVehiculo': vehiculo.marca,
      if (vehiculo != null) 'modeloVehiculo': vehiculo.modelo,
      if (vehiculo != null) 'placaVehiculo': vehiculo.placa,
      // Rating del taxista
      if (promedioEstrellas != null) 'promedioEstrellas': promedioEstrellas,
      if (numeroTelefono != null) 'telefonoTaxista': numeroTelefono,
      // Tiempo aproximado del recorrigo, sugerencia, sacar de google maps si es posible
      if (tiempoLlegadaMin != null) 'tiempoLlegadaMin': tiempoLlegadaMin,
      // Aseguramos que los datos del perfil existan o enviamos placeholders
      'nombre': nombreTaxista ?? taxista?.perfilTaxista.nombre ?? 'Conductor',
      'foto': fotoTaxista ?? taxista?.perfilTaxista.fotoPerfil ?? '',
    }..removeWhere((key, value) => value == null); // Limpia nulos automáticamente

    try {
      // 4. Ejecución con Timeout para mejorar UX en red inestable
      await ofertaRef
          .set(data, SetOptions(merge: true))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Tiempo de conexión agotado'),
          );

      marcarOfertaEnviada();
    } catch (e) {
      // 5. Manejo de errores centralizado
      rethrow;
    }
  }

  /// Aceptación del taxista (solo marca su intención; NO cambia precios del doc padre)
  Future<void> aceptarTaxista({VoidCallback? onFallback}) async {
    try {
      if (rutaDoc != null && rutaDoc!.isNotEmpty) {
        await FirebaseFirestore.instance.doc(rutaDoc!).set({
          'aceptadoTaxista': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // También registra/actualiza su oferta con esAceptacion=true (pero sin tocar la orden)
      await enviarOfertaTaxista(esAceptacion: true);
    } catch (_) {
      if (onFallback != null) onFallback();
    }
  }
}
