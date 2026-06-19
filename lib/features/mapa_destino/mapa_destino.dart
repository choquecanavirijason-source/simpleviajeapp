// mapa_destino.dart
// ✅ Flujo actualizado:
// - autoDestino=true: traza ruta automáticamente al entrar (A -> destino recibido)
// - openSheet2=true: además abre el Sheet2 (resumen/costo) automáticamente
// - openSheet2=false: NO abre Sheet2; deja Sheet1 para elegir servicio y muestra botón "Ver costo"
//   (al presionarlo, abre Sheet2 y recién ahí aparece el botón "Pedir Driver")

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'dart:async';

import 'package:buses2/core/services/mapa/mapbox/mapa_widget.dart';
import 'package:buses2/core/services/mapa/mapbox/MarcadorAnimado.dart';
import 'package:buses2/core/services/mapa/mapbox/taxistas_markers_manager.dart'
    show TaxistaMarkerData;
import 'package:buses2/core/services/ubicacion_usuario/ubicacion_usuario.dart'
    show UbicacionUsuario;
import 'package:buses2/features/home/services/taxistas_cercanos_service.dart';

import 'package:buses2/core/utils/particionarDireccion.dart';
import 'package:buses2/features/mapa_destino/data/guardar_orden_programados.dart'; // bool
import 'package:buses2/features/mapa_destino/modal_programar_viaje/calendar_es_modal.dart';
import 'package:buses2/shared/widgets/botones/boton.dart';
import 'package:buses2/shared/widgets/botones/btn_fijo_abajo.dart';
import 'package:buses2/shared/widgets/overlays/btn_cargando.dart';

import 'package:buses2/features/mapa_destino/service/tarifas.dart'
    show TarifaHorasPicoAeropuerto;
import 'package:buses2/features/mapa_destino/service/calculo_tarifa.dart'
    show CalculoTarifaResult, calcularPrecioTotal;
import 'package:buses2/shared/services/codigos/codigos_service.dart';

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'
    show Point, Position;

import './widgets/modal_inferior1.dart';
import './widgets/modal_inferior2.dart';
import './widgets/modalpaso1_titulo_pill.dart';

// Guardado normal (bool)
import './service/guardar_orden.dart';
// Calendario + formateo
import 'package:intl/intl.dart';

class MapaDestino extends StatefulWidget {
  const MapaDestino({super.key});

  @override
  State<MapaDestino> createState() => _MapaDestinoState();
}

class _MapaDestinoState extends State<MapaDestino> {
  // ===== Punto A (origen) =====
  double? puntoALat;
  double? puntoALng;
  String? puntoACalle;
  String? puntoACiudad;
  String? puntoAPais;
  String? puntoADepartamento;

  // ===== Marcador animado =====
  bool _mostrandoTexto = true;
  MarcadorLineType _tipoLinea = MarcadorLineType.linea1;
  double _lineHeight = 50;
  bool _mostrarCaja = true;
  bool _mostrarMarcadorAnimado = true;

  bool _muteMovimientos = false;

  // ===== Punto B (destino) =====
  double? puntoBLat;
  double? puntoBLng;
  String? puntoBCalle;
  String? puntoBCiudad;
  String? puntoBPais;

  bool _cargarBtn = true;
  MapaController? _mapCtrl;
  String? _bFixDireccion;

  // Snapshot del destino confirmado
  String? _fixCalle, _fixCiudad, _fixPais;
  bool _bFijado = false;
  double? _bFixLat, _bFixLng;

  // Controllers de sheets
  final DraggableScrollableController _sheet1Ctrl =
      DraggableScrollableController();
  final DraggableScrollableController _sheet2Ctrl =
      DraggableScrollableController();

  // Modal inferior 1
  double _sheet1Min = 0.18;
  static const double _sheet1Initial = 0.46;
  static const double _sheet1Max = 0.46;

  // Modal inferior 2 (arranca oculto)
  double _sheet2Min = 0.00;
  static const double _sheet2Initial = 0.00;
  static const double _sheet2Max = 0.45;

  // Tarifa/control
  num? _tarifa;
  bool _tarifaTocada = false;
  String _servicioActual = 'Taxi';

  bool _mostrarBotonPedido = false;

  // Empresa fija (recibida desde el hijo)
  TarifaHorasPicoAeropuerto? _comboSel;
  String? _servicioSel;
  double? _precioEstimado;
  CalculoTarifaResult? _desglose;
  double? _ultimoKm;
  int? _ultimosMin;

  // Modo solo seleccionar ubicación (para guardar lugares)
  bool _soloSeleccionar = false;

  // ===== Programación (UI local) =====
  ProgramacionSeleccion? _programacion;
  final DateFormat _dFmt = DateFormat('d MMM', 'es');
  final DateFormat _dtFmt = DateFormat('d MMM, HH:mm', 'es');
  bool get _tieneProgramacion => _programacion != null;

  // ===== Args para auto-destino (desde Modular.args) =====
  double? _argDestLat, _argDestLng;
  String? _argDestTexto, _argDestCalle, _argDestCiudad, _argDestPais;

  // autoDestino traza ruta al entrar
  bool _argAutoDestino = false;

  // openSheet2 SOLO controla si se abre el resumen (Sheet2) automáticamente
  bool _argOpenSheet2 = false;

  bool _pendingAutoDestino = false; // corre cuando el mapa esté listo

  // ===== Stream de taxistas online cercanos =====
  StreamSubscription<List<TaxistaOnline>>? _taxistasSub;

  // ===== Cupón =====
  final TextEditingController _cuponCtrl = TextEditingController();
  bool _validandoCupon = false;
  // Si está aplicado, contiene el código y el descuento calculado en Bs.
  CuponValidacion? _cuponAplicado;
  String? _errorCupon;

  // ===== Helpers =====
  bool _esNocturnoAhora(DateTime now) {
    final h = now.hour;
    return (h >= 22 || h < 6);
  }

  DateTime? _programacionDateTimeLocal(ProgramacionSeleccion p) {
    final time = p.timeLocal;
    switch (p.mode) {
      case 'single':
        final d = (p.datesLocal?.isNotEmpty ?? false)
            ? p.datesLocal!.first
            : time;
        return DateTime(d.year, d.month, d.day, time.hour, time.minute);
      case 'list':
        if (p.datesLocal != null && p.datesLocal!.isNotEmpty) {
          final list = List<DateTime>.from(p.datesLocal!);
          list.sort((a, b) => a.compareTo(b));
          final d = list.first;
          return DateTime(d.year, d.month, d.day, time.hour, time.minute);
        }
        return DateTime(
          time.year,
          time.month,
          time.day,
          time.hour,
          time.minute,
        );
      case 'range':
      default:
        if (p.rangeStartLocal != null) {
          final d = p.rangeStartLocal!;
          return DateTime(d.year, d.month, d.day, time.hour, time.minute);
        }
        return DateTime(
          time.year,
          time.month,
          time.day,
          time.hour,
          time.minute,
        );
    }
  }

  void _recalcularConCombo(
    TarifaHorasPicoAeropuerto combo,
    double distanciaKm,
    int minutos, {
    DateTime? referenceTime,
  }) {
    final destinoNombre =
        _bFixDireccion ??
        [
          if (_fixCalle != null) _fixCalle,
          if (_fixCiudad != null) _fixCiudad,
          if (_fixPais != null) _fixPais,
        ].whereType<String>().join(', ');

    final ref =
        referenceTime ??
        (_tieneProgramacion
            ? _programacionDateTimeLocal(_programacion!)
            : null) ??
        DateTime.now();

    final res = calcularPrecioTotal(
      combo: combo,
      distanciaKm: distanciaKm,
      minutos: minutos,
      destinoNombre: destinoNombre,
      aplicaNocturno: _esNocturnoAhora(ref),
      ahora: ref,
    );

    setState(() {
      _precioEstimado = res.total;
      _desglose = res;
      if (!_tarifaTocada) _tarifa = _precioEstimado;
    });
  }

  @override
  void initState() {
    super.initState();
    final args = Modular.args.data as Map<String, dynamic>?;

    if (args != null) {
      // Origen
      puntoALat = (args['lat'] as num?)?.toDouble();
      puntoALng = (args['lng'] as num?)?.toDouble();
      puntoACalle = args['calle'] as String?;
      puntoACiudad = args['ciudad'] as String?;
      puntoAPais = args['pais'] as String?;
      puntoADepartamento = args['departamento'] as String?;
      _soloSeleccionar = args['soloSeleccionar'] == true;

      // Destino precargado (si viene desde buscador)
      _argDestLat = (args['destinoLat'] as num?)?.toDouble();
      _argDestLng = (args['destinoLng'] as num?)?.toDouble();
      _argDestTexto = args['destinoTexto'] as String?;
      _argDestCalle = args['destinoCalle'] as String?;
      _argDestCiudad = args['destinoCiudad'] as String?;
      _argDestPais = args['destinoPais'] as String?;

      // ✅ flags (compatibles)
      _argOpenSheet2 = (args['openSheet2'] == true);
      _argAutoDestino = (args['autoDestino'] == true) || _argOpenSheet2;

      _pendingAutoDestino =
          _argAutoDestino && _argDestLat != null && _argDestLng != null;
    }

    debugPrint(
      '🟢 initState MapaDestino: autoDestino=$_argAutoDestino, openSheet2=$_argOpenSheet2, dest=($_argDestLat,$_argDestLng)',
    );

    // Si no nos pasaron departamento (o ciudad/país) por args, intentamos
    // detectarlo del GPS para que las tarifas se puedan leer.
    if ((puntoADepartamento == null || puntoADepartamento!.trim().isEmpty) ||
        (puntoAPais == null || puntoAPais!.trim().isEmpty)) {
      _detectarDepartamentoSiFalta();
    }
  }

  /// Detecta el departamento/país del pasajero por GPS si no vinieron en args.
  /// Llamado solo si `puntoADepartamento` o `puntoAPais` están vacíos —
  /// necesarios para resolver el doc `empresas/.../tarifas/{pais}__{depto}`.
  Future<void> _detectarDepartamentoSiFalta() async {
    try {
      final svc = UbicacionUsuario();
      final res = await svc.obtenerUbicacion40mtrs();
      if (!mounted || res == null) return;

      final depDetectado = (res['departamento'] as String?)?.trim();
      final paisDetectado = (res['pais'] as String?)?.trim();

      if ((depDetectado == null || depDetectado.isEmpty) &&
          (paisDetectado == null || paisDetectado.isEmpty)) {
        debugPrint('⚠️ GPS no devolvió departamento/país');
        return;
      }

      setState(() {
        if ((puntoADepartamento == null || puntoADepartamento!.isEmpty) &&
            depDetectado != null &&
            depDetectado.isNotEmpty) {
          puntoADepartamento = depDetectado;
        }
        if ((puntoAPais == null || puntoAPais!.isEmpty) &&
            paisDetectado != null &&
            paisDetectado.isNotEmpty) {
          puntoAPais = paisDetectado;
        }
      });
      debugPrint(
        '🏛️ MapaDestino: detectado GPS depto="$puntoADepartamento" pais="$puntoAPais"',
      );
    } catch (e) {
      debugPrint('🟥 _detectarDepartamentoSiFalta: $e');
    }
  }

  @override
  void dispose() {
    _taxistasSub?.cancel();
    _cuponCtrl.dispose();
    _sheet1Ctrl.dispose();
    _sheet2Ctrl.dispose();
    super.dispose();
  }

  // ============ Cupón ============

  /// Precio base sobre el que se aplica el cupón (el que el pasajero pagaría
  /// sin descuento).
  double get _precioBaseParaCupon =>
      (_tarifa ?? _precioEstimado ?? 0).toDouble();

  Future<void> _aplicarCupon() async {
    if (_validandoCupon) return;
    final code = _cuponCtrl.text.trim();
    if (code.isEmpty) {
      setState(() {
        _errorCupon = 'Ingresa un código';
        _cuponAplicado = null;
      });
      return;
    }

    final monto = _precioBaseParaCupon;
    if (monto <= 0) {
      setState(() {
        _errorCupon = 'Selecciona un servicio primero';
        _cuponAplicado = null;
      });
      return;
    }

    setState(() {
      _validandoCupon = true;
      _errorCupon = null;
    });

    try {
      final res = await CodigosService.instance.validarCupon(
        codigoIngresado: code,
        montoViaje: monto,
      );
      if (!mounted) return;
      setState(() {
        _cuponAplicado = res;
        _errorCupon = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cuponAplicado = null;
        _errorCupon = e is String
            ? CodigoErrorCodes.mensaje(e)
            : 'No se pudo validar el cupón';
      });
    } finally {
      if (mounted) setState(() => _validandoCupon = false);
    }
  }

  void _quitarCupon() {
    setState(() {
      _cuponAplicado = null;
      _errorCupon = null;
      _cuponCtrl.clear();
    });
  }

  /// Suscribe el mapa al stream de taxistas online dentro de 5km del pasajero.
  /// Llamar UNA vez cuando ya hay mapa. Si no tenemos puntoA (no se pasó
  /// como argumento), pedimos el centro del mapa.
  Future<void> _suscribirTaxistasCercanos() async {
    if (_taxistasSub != null) {
      debugPrint('🟡 taxistas: ya suscrito, salto');
      return;
    }
    if (_mapCtrl == null) {
      debugPrint('🟡 taxistas: mapCtrl null, salto');
      return;
    }

    // Resolver centro: usar puntoA si está, sino centro de cámara
    double? lat = puntoALat;
    double? lng = puntoALng;

    if (lat == null || lng == null) {
      try {
        final c = await _mapCtrl!.getCameraCenter();
        lat = c.coordinates.lat.toDouble();
        lng = c.coordinates.lng.toDouble();
        debugPrint('🟢 taxistas: centro del mapa $lat,$lng');
      } catch (e) {
        debugPrint('🟥 taxistas: no se pudo obtener centro mapa: $e');
        return;
      }
    } else {
      debugPrint('🟢 taxistas: centro puntoA $lat,$lng');
    }

    _taxistasSub = TaxistasCercanosService.instance
        .streamCercanos(
          centerLat: lat,
          centerLng: lng,
          radiusKm: 5.0,
        )
        .listen((lista) async {
          debugPrint('🟢 taxistas: recibidos ${lista.length} en radio 5km');
          if (_mapCtrl == null) return;
          final markers = lista
              .map((t) => TaxistaMarkerData(
                    uid: t.uid,
                    lat: t.lat,
                    lng: t.lng,
                    servicio: t.servicio,
                  ))
              .toList();
          await _mapCtrl!.sincronizarTaxistas(markers);
        }, onError: (e) {
          debugPrint('🟥 stream taxistas cercanos: $e');
        });
    debugPrint('🟢 taxistas: suscrito al stream OK');
  }

  Future<void> _silenciarMovimientosVoid(Future<void> Function() action) async {
    if (!mounted) return;
    setState(() => _muteMovimientos = true);
    try {
      await action();
    } finally {
      if (!mounted) return;
      setState(() => _muteMovimientos = false);
    }
  }

  /// ✅ Abre el resumen (Sheet2) y habilita el flujo de "Pedir Driver"
  Future<void> _abrirSheet2Resumen() async {
    // cierra sheet1
    setState(() => _sheet1Min = 0.00);
    await WidgetsBinding.instance.endOfFrame;
    await _sheet1Ctrl.animateTo(
      0.00,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    // abre sheet2
    setState(() => _sheet2Min = 0.25);
    await WidgetsBinding.instance.endOfFrame;
    await _sheet2Ctrl.animateTo(
      0.63,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );

    // ahora sí mostramos botones de pedido/programación
    if (!mounted) return;
    setState(() => _mostrarBotonPedido = true);
  }

  /// Orquestador: auto destino (traza ruta) + opcional abre resumen si openSheet2=true
  Future<void> _autoAbrirSheet2ConRuta() async {
    if (!_pendingAutoDestino) return;
    if (_mapCtrl == null) return;
    if (puntoALat == null || puntoALng == null) return;
    if (_argDestLat == null || _argDestLng == null) return;

    _pendingAutoDestino = false;

    debugPrint('🚀 AutoDestino: iniciando...');
    const maxTries = 8;
    int intento = 0;

    while (intento < maxTries) {
      intento++;
      try {
        await _silenciarMovimientosVoid(() async {
          setState(() => _cargarBtn = true);

          // 1) set fijo B
          _bFijado = true;
          _bFixLat = _argDestLat;
          _bFixLng = _argDestLng;

          _bFixDireccion =
              [
                    if ((_argDestTexto ?? '').trim().isNotEmpty) _argDestTexto,
                    if ((_argDestCalle ?? '').trim().isNotEmpty) _argDestCalle,
                    if ((_argDestCiudad ?? '').trim().isNotEmpty)
                      _argDestCiudad,
                    if ((_argDestPais ?? '').trim().isNotEmpty) _argDestPais,
                  ]
                  .whereType<String>()
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .join(', ');

          final partesFix = direccionPorPartes(_bFixDireccion ?? '');
          _fixCalle = _argDestCalle ?? partesFix['calle'];
          _fixCiudad = _argDestCiudad ?? partesFix['ciudad'];
          _fixPais = _argDestPais ?? partesFix['pais'];

          // ocultar marcador/caja para no tapar ruta
          setState(() {
            _mostrarMarcadorAnimado = false;
            _mostrarCaja = false;
          });

          // 2) punto fijo en mapa
          await _mapCtrl!.agregarPuntoFijo(
            Point(coordinates: Position(_bFixLng!, _bFixLat!)),
            fillColor: Colors.white,
            strokeColor: const Color(0xFF4CAF50),
            radius: 6,
            strokeWidth: 6,
          );

          // 3) ruta A → B
          await _mapCtrl!.dibujarRutaDesdeHasta(
            a: Point(coordinates: Position(puntoALng!, puntoALat!)),
            b: Point(coordinates: Position(_bFixLng!, _bFixLat!)),
            context: context,
          );

          // 4) métricas
          final info = await _mapCtrl!.metricasEntre(
            aLat: puntoALat!,
            aLng: puntoALng!,
            bLat: _bFixLat!,
            bLng: _bFixLng!,
            dibujar: false,
          );

          _ultimoKm = info.distanciaKm;
          _ultimosMin = info.minutos;

          // Sincronizar label del mapa con los km/min calculados
          await _mapCtrl!.actualizarDistanciaLabel(
            info.distanciaKm,
            info.minutos,
          );

          // 5) recalculo si ya hay combo
          if (_comboSel != null && _ultimoKm != null && _ultimosMin != null) {
            _recalcularConCombo(
              _comboSel!,
              _ultimoKm!,
              _ultimosMin!,
              referenceTime: _tieneProgramacion
                  ? _programacionDateTimeLocal(_programacion!)
                  : null,
            );
          } else {
            _precioEstimado ??= 0;
          }

          // 6) estado UI
          setState(() {
            puntoBLat = _bFixLat;
            puntoBLng = _bFixLng;

            // ✅ IMPORTANTE:
            // - si openSheet2=true => mostramos botones de pedir (porque abriremos resumen)
            // - si openSheet2=false => NO mostramos pedir todavía; mostramos botón "Ver costo"
            _mostrarBotonPedido = _argOpenSheet2;
          });

          // 7) Sheets
          if (_argOpenSheet2) {
            await _abrirSheet2Resumen();
          } else {
            // asegurar resumen cerrado
            setState(() => _sheet2Min = 0.00);

            // dejar sheet1 visible para elegir servicio
            setState(() => _sheet1Min = 0.18);
            await WidgetsBinding.instance.endOfFrame;
            await _sheet1Ctrl.animateTo(
              _sheet1Initial,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
            );
          }
        });

        if (!mounted) return;
        setState(() => _cargarBtn = false);
        return;
      } catch (e, st) {
        debugPrint('🟠 AutoDestino intento $intento falló: $e\n$st');
        await Future.delayed(const Duration(milliseconds: 160));
      }
    }

    if (!mounted) return;
    setState(() => _cargarBtn = false);
    debugPrint('🟥 AutoDestino: agotados los reintentos.');
  }

  Future<void> _buscarTaxi() async {
    if (_mapCtrl == null || puntoALat == null || puntoALng == null) return;

    await _silenciarMovimientosVoid(() async {
      setState(() => _cargarBtn = true);
      try {
        setState(() {
          _mostrarCaja = false;
          _mostrarMarcadorAnimado = false;
        });

        if (puntoBLat == null || puntoBLng == null) {
          final cam = await _mapCtrl!.getCameraCenter();
          puntoBLat = cam.coordinates.lat.toDouble();
          puntoBLng = cam.coordinates.lng.toDouble();
        }

        _bFijado = true;
        _bFixLat = puntoBLat;
        _bFixLng = puntoBLng;

        _bFixDireccion ??= [
          if (puntoBCalle != null) puntoBCalle,
          if (puntoBCiudad != null) puntoBCiudad,
          if (puntoBPais != null) puntoBPais,
        ].whereType<String>().join(', ');

        final partesFix = direccionPorPartes(_bFixDireccion ?? '');
        _fixCalle = partesFix['calle'] ?? puntoBCalle;
        _fixCiudad = partesFix['ciudad'] ?? puntoBCiudad;
        _fixPais = partesFix['pais'] ?? puntoBPais;

        await _mapCtrl!.agregarPuntoFijo(
          Point(coordinates: Position(_bFixLng!, _bFixLat!)),
          fillColor: Colors.white,
          strokeColor: const Color(0xFF4CAF50),
          radius: 6,
          strokeWidth: 6,
        );

        await _mapCtrl!.dibujarRutaDesdeHasta(
          a: Point(coordinates: Position(puntoALng!, puntoALat!)),
          b: Point(coordinates: Position(_bFixLng!, _bFixLat!)),
          context: context,
        );

        final info = await _mapCtrl!.metricasEntre(
          aLat: puntoALat!,
          aLng: puntoALng!,
          bLat: _bFixLat!,
          bLng: _bFixLng!,
          dibujar: false,
        );

        final km = info.distanciaKm;
        final min = info.minutos;
        _ultimoKm = km;
        _ultimosMin = min;

        // Sincronizar label del mapa con los km/min calculados
        await _mapCtrl!.actualizarDistanciaLabel(km, min);

        if (_comboSel != null) {
          _recalcularConCombo(
            _comboSel!,
            km,
            min,
            referenceTime: _tieneProgramacion
                ? _programacionDateTimeLocal(_programacion!)
                : null,
          );
        }

        setState(() {
          puntoBLat = _bFixLat;
          puntoBLng = _bFixLng;
          _mostrarBotonPedido = true;
        });

        // Modo solo seleccionar: retornar y cerrar
        if (_soloSeleccionar) {
          final result = {
            'lat': _bFixLat,
            'lng': _bFixLng,
            'calle': _fixCalle,
            'ciudad': _fixCiudad,
            'pais': _fixPais,
            'departamento': puntoADepartamento,
            'texto': _bFixDireccion,
          };
          if (mounted) Modular.to.pop(result);
          return;
        }

        await _abrirSheet2Resumen();
      } finally {
        if (!mounted) return;
        setState(() => _cargarBtn = false);
      }
    });
  }

  // ====== PEDIDO ======
  bool _pidiendo = false;

  Future<void> _onPedirTaxiPressed() async {
    if (_pidiendo) return;
    setState(() => _pidiendo = true);

    try {
      final ok = await _pedirTaxi().timeout(const Duration(seconds: 12));
      if (!mounted) return;
      if (!ok) return;

      Modular.to.pushNamedAndRemoveUntil('/home', (route) => false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Modular.to.navigate('/home/historial');
      });
    } catch (_) {
      // opcional snackbar
    } finally {
      if (!mounted) return;
      setState(() => _pidiendo = false);
    }
  }

  Future<bool> _pedirTaxi() async {
    try {
      final uid = fb.FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) return false;

      // Si el pasajero validó un cupón, lo consumimos AHORA (atómico).
      // Si falla (ej. otro pasajero lo agotó justo antes), abortamos el pedido
      // con un snackbar y dejamos al usuario revisar.
      Map<String, dynamic>? descuentoInfo;
      if (_cuponAplicado != null) {
        try {
          final consumido = await CodigosService.instance.consumirCupon(
            codigoIngresado: _cuponAplicado!.codigoId,
            montoViaje: _precioBaseParaCupon,
          );
          descuentoInfo = {
            'codigo': consumido.codigoId,
            'monto': consumido.descuento,
          };
        } catch (e) {
          if (mounted) {
            final msg = e is String
                ? CodigoErrorCodes.mensaje(e)
                : 'El cupón ya no es válido';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg), backgroundColor: Colors.orange),
            );
            setState(() {
              _cuponAplicado = null;
              _errorCupon = msg;
            });
          }
          return false;
        }
      }

      final esProgramado = _programacion != null;
      if (esProgramado) {
        final scheduled = _programacionDateTimeLocal(_programacion!);
        return await pedirTaxiYGuardarProgramado(
          comboSelNullable: _comboSel == null
              ? null
              : <String, dynamic>{'ok': true},
          precioEstimado: _precioEstimado,
          ultimoKm: _ultimoKm,
          ultimosMin: _ultimosMin,
          desgloseMap: _desglose == null ? null : {'ok': true},
          desgloseTotal: _desglose?.total,
          puntoALat: puntoALat,
          puntoALng: puntoALng,
          puntoACalle: puntoACalle,
          puntoACiudad: puntoACiudad,
          puntoAPais: puntoAPais,
          bFixLat: _bFixLat,
          bFixLng: _bFixLng,
          fixCalle: _fixCalle,
          fixCiudad: _fixCiudad,
          fixPais: _fixPais,
          bFixDireccion: _bFixDireccion,
          puntoBCalle: puntoBCalle,
          puntoBCiudad: puntoBCiudad,
          puntoBPais: puntoBPais,
          tarifa: _tarifa,
          servicioSel: _servicioSel,
          programacion: _programacion,
          scheduledAtLocal: scheduled,
        );
      }

      return await pedirTaxiYGuardar(
        comboSelNullable: _comboSel == null
            ? null
            : <String, dynamic>{'ok': true},
        precioEstimado: _precioEstimado,
        ultimoKm: _ultimoKm,
        ultimosMin: _ultimosMin,
        desgloseMap: _desglose == null ? null : {'ok': true},
        desgloseTotal: _desglose?.total,
        puntoALat: puntoALat,
        puntoALng: puntoALng,
        puntoACalle: puntoACalle,
        puntoACiudad: puntoACiudad,
        puntoAPais: puntoAPais,
        bFixLat: _bFixLat,
        bFixLng: _bFixLng,
        fixCalle: _fixCalle,
        fixCiudad: _fixCiudad,
        fixPais: _fixPais,
        bFixDireccion: _bFixDireccion,
        puntoBCalle: puntoBCalle,
        puntoBCiudad: puntoBCiudad,
        puntoBPais: puntoBPais,
        tarifa: _tarifa,
        servicioSel: _servicioSel,
        descuentoInfo: descuentoInfo,
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> _handleBack() async {
    try {
      final s2 = _sheet2Ctrl.size;
      if (s2 > 0.001) {
        // cerrar sheet2
        setState(() => _sheet2Min = 0.00);
        await WidgetsBinding.instance.endOfFrame;
        await _sheet2Ctrl.animateTo(
          0.00,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
        );

        await _volverAModoSeleccion();

        // volver sheet1
        setState(() => _sheet1Min = 0.18);
        await WidgetsBinding.instance.endOfFrame;
        await _sheet1Ctrl.animateTo(
          _sheet1Initial,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );

        setState(() {
          _mostrarBotonPedido = false;
          _mostrarCaja = true;
          _mostrarMarcadorAnimado = true;
        });

        return false;
      }
    } catch (_) {}
    return true;
  }

  Future<void> _volverAModoSeleccion() async {
    await _mapCtrl?.borrarPuntoFijo();

    if (!mounted) return;
    setState(() {
      _bFijado = false;
      _bFixLat = null;
      _bFixLng = null;
      _bFixDireccion = null;

      _mostrandoTexto = true;
      _tipoLinea = MarcadorLineType.linea1;
      _lineHeight = 50;
    });
  }

  String _fmtProgramacionBonita(ProgramacionSeleccion s) {
    switch (s.mode) {
      case 'range':
        final a = _dFmt.format(s.rangeStartLocal!);
        final b = _dFmt.format(s.rangeEndLocal!);
        final h = DateFormat('HH:mm').format(s.timeLocal);
        return 'Programado: $a – $b a las $h';
      case 'list':
        final dias = (s.datesLocal ?? [])
            .map((d) => _dFmt.format(d))
            .join(', ');
        final h2 = DateFormat('HH:mm').format(s.timeLocal);
        return 'Programado: $dias a las $h2';
      case 'single':
      default:
        return 'Programado: ${_dtFmt.format(s.timeLocal)}';
    }
  }

  Future<void> _abrirProgramacionModal() async {
    final sel = await showCalendarEsModal(
      context,
      initialDate: DateTime.now(),
      minuteInterval: 5,
      primaryColor: const Color(0xFF4CB050),
      title: 'Programar viaje',
    );
    if (!mounted) return;

    if (sel != null) {
      setState(() => _programacion = sel);
      if (_comboSel != null && _ultimoKm != null && _ultimosMin != null) {
        _recalcularConCombo(
          _comboSel!,
          _ultimoKm!,
          _ultimosMin!,
          referenceTime: _programacionDateTimeLocal(sel),
        );
      }
    }
  }

  void _cancelarProgramacion() {
    setState(() => _programacion = null);
    if (_comboSel != null && _ultimoKm != null && _ultimosMin != null) {
      _recalcularConCombo(
        _comboSel!,
        _ultimoKm!,
        _ultimosMin!,
        referenceTime: DateTime.now(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBack,
      child: ScaffoldConBottom(
        body: Stack(
          children: [
            // Mapa
            MapaWidget(
              centerLat: puntoALat ?? -17.3895,
              centerLng: puntoALng ?? -66.1568,
              onMapReady: (c) async {
                _mapCtrl = c;
                debugPrint('🗺️ onMapReady');

                // 🚕 Empezar a mostrar taxistas online cercanos en el mapa.
                // Lo lanzamos sin await para no bloquear el flujo principal.
                _suscribirTaxistasCercanos();

                if (_pendingAutoDestino) {
                  await Future.delayed(const Duration(milliseconds: 60));
                  await _autoAbrirSheet2ConRuta();
                } else {
                  setState(() => _cargarBtn = false);
                }
              },
              onMoveStart: () {
                if (_muteMovimientos || _bFijado) return;
                setState(() {
                  _cargarBtn = true;
                  _mostrarBotonPedido = false;
                  puntoBCalle = null;
                  puntoBCiudad = null;
                  puntoBPais = null;
                  _mostrandoTexto = false;
                  _tipoLinea = MarcadorLineType.linea2;
                  _lineHeight = 35;
                });
              },
              onUbicacionCambiada: (latitud, longitud, direccion) {
                if (_muteMovimientos || _bFijado) return;
                if (direccion == null) return;

                final partes = direccionPorPartes(direccion);

                setState(() {
                  puntoBLat = latitud;
                  puntoBLng = longitud;
                  puntoBCalle = partes['calle'];
                  puntoBCiudad = partes['ciudad'];
                  puntoBPais = partes['pais'];
                  _bFixDireccion = direccion;
                  _mostrandoTexto = true;
                  _tipoLinea = MarcadorLineType.linea1;
                  _lineHeight = 50;
                  _cargarBtn = false;
                });
              },
            ),

            // Etiqueta superior
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Paso1TituloPill(texto: 'Desliza el mapa'),
              ),
            ),

            // Botón "Volver atrás": cierra Sheet2 → modo selección,
            // o sale de la pantalla si no hay paso interno al cual volver.
            Positioned(
              top: MediaQuery.of(context).padding.top + 48,
              left: 12,
              child: Material(
                color: Colors.white,
                elevation: 4,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () async {
                    final puedeSalir = await _handleBack();
                    if (puedeSalir && mounted) {
                      Modular.to.pop();
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      Icons.arrow_back,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
            ),

            // Marcador animado
            if (_mostrarMarcadorAnimado)
              MarcadorAnimado(
                line: _tipoLinea,
                lineHeight: _lineHeight,
                tiempoTexto: puntoBCalle ?? 'Cargando ubicación...',
                textoSecundario: puntoBCiudad != null && puntoBPais != null
                    ? '$puntoBCiudad - $puntoBPais'
                    : '',
                icono: (puntoBCalle == null)
                    ? const WidgetCargandoPro2(size: 28, color: Colors.green)
                    : Icons.flag,
                iconColor: Colors.green,
                lineColor: Colors.green,
                offsetY: -155,
                mostrarTiempo: _mostrandoTexto,
                mostrarSecundario: _mostrandoTexto,
                mostrarCajaTexto: _mostrarCaja,
              ),

            // Banner de programación
            if (_tieneProgramacion)
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 70),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 360),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFEFFBF2), Color(0xFFFFFFFF)],
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.event_available,
                          color: Color(0xFF4CB050),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _fmtProgramacionBonita(_programacion!),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Modal inferior 1 (servicios)
            ModalInferior1(
              controller: _sheet1Ctrl,
              initialChildSize: _sheet1Initial,
              minChildSize: _sheet1Min,
              maxChildSize: _sheet1Max,
              // Punto A
              puntoALat: puntoALat,
              puntoALng: puntoALng,
              puntoACalle: puntoACalle,
              puntoACiudad: puntoACiudad,
              puntoAPais: puntoAPais,
              puntoADepartamento: puntoADepartamento,
              // Punto B
              puntoBLat: puntoBLat,
              puntoBLng: puntoBLng,
              puntoBCalle: puntoBCalle,
              puntoBCiudad: puntoBCiudad,
              puntoBPais: puntoBPais,

              distanciaKm: _ultimoKm,
              minutos: _ultimosMin,

              // ✅ al seleccionar servicio: recalcula precio (si ya hay km/min)
              onComboChange:
                  (TarifaHorasPicoAeropuerto combo, String servicio) {
                    setState(() {
                      _comboSel = combo;
                      _servicioSel = servicio;
                      _servicioActual = servicio;
                      _tarifaTocada = false; // recalcular precio al cambiar servicio
                      _tarifa = null;
                    });

                    if (_ultimoKm != null && _ultimosMin != null) {
                      _recalcularConCombo(
                        combo,
                        _ultimoKm!,
                        _ultimosMin!,
                        referenceTime: _tieneProgramacion
                            ? _programacionDateTimeLocal(_programacion!)
                            : null,
                      );
                    }
                  },
            ),

            // Modal inferior 2 (resumen/costo)
            ModalInferior2Block(
              controller: _sheet2Ctrl,
              initialChildSize: _sheet2Initial,
              minChildSize: _sheet2Min,
              maxChildSize: _sheet2Max,
              tarifa: (_tarifa ?? _precioEstimado ?? 0),
              precioEstimado: _precioEstimado,
              distanciaKm: _ultimoKm,
              minutos: _ultimosMin,
              onTarifaChanged: (v) => setState(() {
                _tarifaTocada = true;
                _tarifa = v;
              }),
              servicio: _servicioSel ?? _servicioActual,
              onTaxiTap: () => setState(() => _servicioActual = 'Taxi'),
              onMotoTap: () => setState(() => _servicioActual = 'Moto Taxi'),
              puntoACalle: puntoACalle,
              puntoACiudad: puntoACiudad,
              puntoAPais: puntoAPais,
              bFijado: _bFijado,
              fixCalle: _fixCalle,
              fixCiudad: _fixCiudad,
              fixPais: _fixPais,
              puntoBCalle: puntoBCalle,
              puntoBCiudad: puntoBCiudad,
              puntoBPais: puntoBPais,
              onDestinoTap: () {},
              programacion: _programacion,
            ),
          ],
        ),

        // === BTN FIJO ABAJO ===
        btnFijoAbajo: _mostrarBotonPedido
            ? Btn_Cargando(
                loading: _pidiendo,
                borde: BtnBorde.borde1,
                workingLabel: 'Enviando pedido...',
                overlayColor: Colors.grey,
                spinnerColor: Colors.white,
                child: Padding(
                  // Margen lateral para que los botones no ocupen todo el ancho.
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 🎟️ Cupón de descuento (opcional)
                      _CuponWidget(
                        controller: _cuponCtrl,
                        validando: _validandoCupon,
                        cuponAplicado: _cuponAplicado,
                        errorCupon: _errorCupon,
                        precioBase: _precioBaseParaCupon,
                        onAplicar: _aplicarCupon,
                        onQuitar: _quitarCupon,
                      ),
                      const SizedBox(height: 10),
                      Boton1(
                        label: 'Pedir Driver',
                        color: BotonColor.color3,
                        borde: BotonBorde.borde1,
                        iconoIzquierdo: Icons.check_circle,
                        iconoDerecho: Icons.send,
                        onPressed: _onPedirTaxiPressed,
                      ),
                      const SizedBox(height: 8),
                      if (!_tieneProgramacion)
                        Boton1(
                          label: 'Viaje programado',
                          color: BotonColor.color1,
                          borde: BotonBorde.borde1,
                          iconoIzquierdo: Icons.schedule,
                          iconoDerecho: Icons.arrow_forward_ios,
                          onPressed: _abrirProgramacionModal,
                        )
                      else
                        Boton1(
                          label: 'Cancelar programa',
                          color: BotonColor.color2,
                          borde: BotonBorde.borde1,
                          iconoIzquierdo: Icons.cancel,
                          iconoDerecho: Icons.close,
                          onPressed: _cancelarProgramacion,
                        ),
                    ],
                  ),
                ),
              )
            : Btn_Cargando(
                loading: _cargarBtn,
                borde: BtnBorde.borde1,
                workingLabel: 'Encontrando...',
                overlayColor: Colors.grey,
                spinnerColor: Colors.white,
                child: Boton1(
                  label: (_argAutoDestino && !_argOpenSheet2 && _bFijado)
                      ? 'Ver costo'
                      : 'Confirmar destino',
                  color: BotonColor.color3,
                  borde: BotonBorde.borde1,
                  iconoIzquierdo: Icons.local_taxi,
                  iconoDerecho: Icons.arrow_forward_ios,
                  onPressed: () async {
                    // ✅ Caso nuevo: venimos con destino ya fijo (autoDestino)
                    // y el usuario debe elegir servicio y luego ver costo
                    if (_argAutoDestino && !_argOpenSheet2 && _bFijado) {
                      if (_comboSel == null || _servicioSel == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Selecciona un servicio primero para ver el costo.',
                            ),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        return;
                      }
                      if (_ultimoKm == null || _ultimosMin == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Calculando distancia... intenta otra vez.',
                            ),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        return;
                      }

                      await _abrirSheet2Resumen();
                      return;
                    }

                    // Flujo normal: confirmar destino desde el mapa
                    await _buscarTaxi();
                  },
                ),
              ),
        colorFondo: const Color(0xFFFFFFFF),
      ),
    );
  }
}

// ============================================================
// Widget de cupón (descuento) — usado en btnFijoAbajo
// ============================================================
class _CuponWidget extends StatelessWidget {
  const _CuponWidget({
    required this.controller,
    required this.validando,
    required this.cuponAplicado,
    required this.errorCupon,
    required this.precioBase,
    required this.onAplicar,
    required this.onQuitar,
  });

  final TextEditingController controller;
  final bool validando;
  final CuponValidacion? cuponAplicado;
  final String? errorCupon;
  final double precioBase;
  final VoidCallback onAplicar;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    // Si ya hay cupón aplicado: mostrar chip verde con info y botón "Quitar".
    if (cuponAplicado != null) {
      final c = cuponAplicado!;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          border: Border.all(color: const Color(0xFF22C55E)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF16A34A)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Cupón ${c.codigoId} aplicado',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF14532D),
                    ),
                  ),
                  Text(
                    '−ARS ${c.descuento.toStringAsFixed(2)} · '
                    'Total: ARS ${c.precioFinal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFF14532D),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onQuitar,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB91C1C),
              ),
              child: const Text('Quitar'),
            ),
          ],
        ),
      );
    }

    // Sin cupón aplicado: input + botón "Aplicar" + error opcional.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.characters,
                enabled: !validando,
                decoration: InputDecoration(
                  hintText: '¿Tienes cupón?',
                  prefixIcon: const Icon(Icons.local_offer_outlined),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: validando ? null : onAplicar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                child: validando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Aplicar'),
              ),
            ),
          ],
        ),
        if (errorCupon != null) ...[
          const SizedBox(height: 6),
          Text(
            errorCupon!,
            style: const TextStyle(
              color: Color(0xFFB91C1C),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

