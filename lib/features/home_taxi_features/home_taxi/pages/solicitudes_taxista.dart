// lib/features/home_taxi_features/home_taxi/solicitudes_taxista.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:buses2/core/services/data/usuarios_model/taxista_model.dart';

import 'package:buses2/features/home_taxi_features/home_taxi/home_taxista_page.dart';
import 'package:buses2/features/home_taxi_features/home_taxi/services/taxista_presence_service.dart';
import 'package:buses2/features/home_taxi_features/home_taxi/widgets/pedido_card_from_doc.dart';
import 'package:buses2/features/home_taxi_features/home_taxi/widgets/ride_request_card.dart';
import 'package:buses2/shared/widgets/switch/switch1.dart'; // ← usa Estado3 de aquí
import '../services/ride_request_service.dart';
import '../services/auto_cancel_service.dart'; // ← Servicio de cancelación automática
import '../services/orders_listener.dart';
import 'package:buses2/core/services/ubicacion_usuario/ubicacion_user.dart';
import 'package:buses2/features/home_taxi_features/billetera_taxista/services/taxista_wallet_service.dart';

/* =======================================================================
 * TOP-LEVEL: helpers compartidos (visibles para todo el archivo)
 * ======================================================================= */

class Tuple2<A, B> {
  final A item1;
  final B item2;
  const Tuple2(this.item1, this.item2);
}

void _printLong(String text) {
  const chunk = 800;
  for (var i = 0; i < text.length; i += chunk) {
    debugPrint(
      text.substring(i, (i + chunk > text.length) ? text.length : i + chunk),
    );
  }
}

String? _extractIndexUrl(String? message) {
  if (message == null) return null;
  final re = RegExp(
    r'https://console\.firebase\.google\.com[^\s]+',
    caseSensitive: false,
  );
  final m = re.firstMatch(message);
  return m?.group(0);
}

void _logFirestoreError(Object err, StackTrace? st, {String context = ''}) {
  if (!kDebugMode) return;
  debugPrint(
    '🟥 Firestore error${context.isNotEmpty ? " ($context)" : ""}: ${err.runtimeType}',
  );
  _printLong(err.toString());
  if (st != null) {
    debugPrint('— stack:');
    debugPrintStack(stackTrace: st);
  }

  if (err is FirebaseException /* firebase_core */ ) {
    final url = _extractIndexUrl(err.message);
    if (url != null) {
      debugPrint('🧩 Falta un índice compuesto. Ábrelo y créalo aquí:');
      _printLong(url);
    }
  } else {
    final url = _extractIndexUrl(err.toString());
    if (url != null) {
      debugPrint('🧩 Falta un índice compuesto. Ábrelo y créalo aquí:');
      _printLong(url);
    }
  }
}

/// Devuelve la mejor fecha del doc (updatedAt → createdAt → ahora).
DateTime _extractBestDate(Map<String, dynamic> d) {
  DateTime? dt;
  final upd = d['updatedAt'];
  final cre = d['createdAt'];
  if (upd is Timestamp) dt = upd.toDate();
  if (dt == null && cre is Timestamp) dt = cre.toDate();
  if (dt == null && upd is String) dt = DateTime.tryParse(upd);
  if (dt == null && cre is String) dt = DateTime.tryParse(cre);
  return dt ?? DateTime.now();
}

/// Obtiene fecha de agenda si existe; si no, fallback a created/updated.
DateTime _getScheduleOrFallback(Map<String, dynamic> d) {
  final s = d['scheduledAtLocal']?.toString();
  if (s is String) {
    final dt = DateTime.tryParse(s);
    if (dt != null) return dt;
  }
  if (d['programacion'] is Map) {
    final prog = Map<String, dynamic>.from(d['programacion']);
    final range = (prog['range'] is Map)
        ? Map<String, dynamic>.from(prog['range'])
        : const <String, dynamic>{};
    final start = (range['startLocal'] ?? range['start'])?.toString();
    if (start != null && start.length >= 10) {
      return DateTime.tryParse('${start}T00:00:00.000') ?? _extractBestDate(d);
    }
  }
  return _extractBestDate(d);
}

List<String>? crearFechasRango(String localStart, String localEnd) {
  String two(int n) => n.toString().padLeft(2, '0');
  if (localStart.isEmpty || localEnd.isEmpty) return null;

  DateTime? start = DateTime.tryParse(localStart);
  DateTime? end = DateTime.tryParse(localEnd);

  if (start == null || end == null) return null;

  var cur = DateTime(start.year, start.month, start.day);
  final last = DateTime(end.year, end.month, end.day);

  final ddmm = <String>[];
  while (!cur.isAfter(last)) {
    ddmm.add('${two(cur.day)}/${two(cur.month)}/${cur.year}');
    cur = cur.add(const Duration(days: 1));
  }

  return ddmm;
}

/// Genera (lineaFechas, horaCorta) desde programacion, mostrando TODAS las fechas.
Tuple2<List<String>?, String?> _computeScheduleLines(
  Map<String, dynamic> prog, {
  String? fallbackScheduledAt,
}) {
  String? fechasLinea;
  String? horaCorta;

  String two(int n) => n.toString().padLeft(2, '0');

  // 1) datesLocal + timeLocal
  if (prog['datesLocal'] is List && prog['timeLocal'] != null) {
    final dates = List<String>.from(prog['datesLocal']);
    final time = prog['timeLocal'].toString();

    if (dates.isNotEmpty) {
      final ddmm = <String>[];
      for (final ymd in dates) {
        if (ymd.length >= 10) {
          final y = int.tryParse(ymd.substring(0, 4));
          final m = int.tryParse(ymd.substring(5, 7));
          final d = int.tryParse(ymd.substring(8, 10));
          if (y != null && m != null && d != null) {
            ddmm.add('${two(d)}/${two(m)}/$y');
          }
        }
      }

      fechasLinea = ddmm.join(' · ');
      horaCorta = time;
    }
  }

  // 2) Rango range.start / range.end
  if (fechasLinea == null && prog['range'] is Map) {
    final r = Map<String, dynamic>.from(prog['range']);
    final startStr = (r['startLocal'] ?? r['start'])?.toString();
    final endStr = (r['endLocal'] ?? r['end'])?.toString();
    final time = (r['timeLocal'] ?? prog['timeLocal'])?.toString();

    if (startStr != null &&
        endStr != null &&
        startStr.length >= 10 &&
        endStr.length >= 10) {
      DateTime? start = DateTime.tryParse(startStr);
      DateTime? end = DateTime.tryParse(endStr);

      if (start != null && end != null) {
        var cur = DateTime(start.year, start.month, start.day);
        final last = DateTime(end.year, end.month, end.day);

        final ddmm = <String>[];
        while (!cur.isAfter(last)) {
          ddmm.add('${two(cur.day)}/${two(cur.month)}/${cur.year}');
          cur = cur.add(const Duration(days: 1));
        }

        fechasLinea = ddmm.join(' · ');
        horaCorta = time;
      }
    }
  }

  // 3) Fallback a scheduledAtLocal
  if (fechasLinea == null && fallbackScheduledAt != null) {
    final dt = DateTime.tryParse(fallbackScheduledAt);
    if (dt != null) {
      fechasLinea = '${two(dt.day)}/${two(dt.month)}/${dt.year}';
      horaCorta = '${two(dt.hour)}:${two(dt.minute)}';
    }
  }

  final fechasLineaList = fechasLinea
      ?.split(' · ')
      .map((s) => s.trim())
      .toList();

  return Tuple2(fechasLineaList, horaCorta);
}

double? _getKm(Map<String, dynamic> d) {
  final dynamic kmRaw = _firstNonNull([
    _fromMap(d, ['tarifa', 'km']),
    d['km'],
    d['distanciaKm'],
    d['distance_km'],
    _fromMap(d, ['distancia', 'km']),
  ]);
  if (kmRaw != null) return _toDouble(kmRaw);

  final dynamic mRaw = _firstNonNull([
    d['dist_m'],
    _fromMap(d, ['distancia', 'm']),
  ]);
  if (mRaw != null) {
    final m = _toDouble(mRaw);
    if (m != null) return m / 1000.0;
  }
  return null;
}

double? _computePrecio(num? crudo, double? km, Map<String, dynamic> d) {
  if (crudo != null) return crudo.toDouble();

  const _DEFAULT_BASE_FARE = 5.0;
  const _DEFAULT_PER_KM = 4.0;

  final base =
      _toDouble(
        _firstNonNull([
          d['base'],
          _fromMap(d, ['tarifa', 'base']),
        ]),
      ) ??
      _DEFAULT_BASE_FARE;
  final porKm =
      _toDouble(
        _firstNonNull([
          d['porKm'],
          d['precioPorKm'],
          _fromMap(d, ['tarifa', 'precioPorKm']),
          _fromMap(d, ['tarifa', 'porKm']),
        ]),
      ) ??
      _DEFAULT_PER_KM;
  if (km != null) return base + km * porKm;
  return null;
}

String _getCreatedAtShort(Map<String, dynamic> d) {
  final dynamic short = d['createdAtShort'];
  if (short is String && short.trim().isNotEmpty) return short;

  final ts = _firstNonNull([
    d['createdAt'],
    d['fechaCreacion'],
    _fromMap(d, ['meta', 'createdAt']),
  ]);
  DateTime? dt;
  if (ts is Timestamp) dt = ts.toDate();
  if (ts is int) dt = DateTime.fromMillisecondsSinceEpoch(ts);
  if (ts is String) {
    final p = int.tryParse(ts);
    if (p != null) dt = DateTime.fromMillisecondsSinceEpoch(p);
  }
  dt ??= DateTime.now();

  const meses = [
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
  String two(int n) => n.toString().padLeft(2, '0');

  final h = two(dt.hour);
  final m = two(dt.minute);
  final dd = two(dt.day);
  final mm = dt.month;
  return '$h:$m • $dd ${meses[mm - 1]}';
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

String _formatBs(double v) {
  final s2 = v.toStringAsFixed(2);
  return s2.endsWith('00') ? 'ARS ${v.toStringAsFixed(0)}' : 'ARS $s2';
}

/* ---------------- UI utils reusables ---------------- */

class _ItemDivider extends StatelessWidget {
  const _ItemDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 8, color: Color(0xFFF7F7F7));
  }
}

/// Tarjeta de stat para el header oscuro (ej: "Cerca de ti", "Servicio").
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                DefaultTextStyle.merge(
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: child,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 52, color: accent),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showPrettySnack(
  BuildContext context, {
  required IconData icon,
  required String title,
  String? subtitle,
  Color bg = const Color(0xFF14532D),
  Color accent = const Color(0xFF22C55E),
}) {
  final snack = SnackBar(
    behavior: SnackBarBehavior.floating,
    elevation: 6,
    backgroundColor: Colors.transparent,
    margin: const EdgeInsets.all(14),
    duration: const Duration(milliseconds: 2400),
    content: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15.5,
                    height: 1.05,
                  ),
                ),
                if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.90),
                      fontSize: 13.2,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );

  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(snack);
}

/* =======================================================================
 *  SolicitudesTaxistaPage (con Tabs: Normales / Programados)
 * ======================================================================= */

class SolicitudesTaxistaPage extends StatefulWidget {
  const SolicitudesTaxistaPage({super.key});

  @override
  State<SolicitudesTaxistaPage> createState() => _SolicitudesTaxistaPageState();
}

class _SolicitudesTaxistaPageState extends State<SolicitudesTaxistaPage>
    with SingleTickerProviderStateMixin {
  Estado3 _estado = Estado3.libre;
  late final TabController _tabController;
  bool _datosIncompletos = false;
  String?
  _servicioSeleccionado; // Servicio del taxista (Taxi, Moto taxi)

  // Servicio global que escucha órdenes y aplica filtros (ubicación, servicio, estado libre)
  final OrderService _orderService = OrderService.instance;

  // Indica si la ubicación del dispositivo está disponible (GPS/permisos)
  bool _ubicacionDisponible = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _verificarDocumentosCompletos();
    _cargarEstadoInicial();
    // _verificarDatosTaxi();

    // ⏲️ Iniciar servicios de cancelación automática
    AutoCancelService().startMonitoring(); // normales
    AutoCancelService().startMonitoringProgramados(); // programados

    // Estado inicial (por defecto libre, pero puede cambiar en _cargarEstadoInicial)
    _orderService.updateDisponibilidad(_estado == Estado3.libre);

    // Intentar cargar una vez la ubicación actual del taxista
    _cargarUbicacionInicial();

    // Si llegamos desde una notificación con rutaDoc/esProgramado, ajustar pestaña inicial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rawArgs = Modular.args.data;
      if (rawArgs is Map) {
        final args = Map<String, dynamic>.from(rawArgs);
        final rutaDoc = args['rutaDoc']?.toString();
        final esProgramado =
            args['esProgramado'] == true ||
            (rutaDoc != null && rutaDoc.contains('ordenesProgramados'));

        if (esProgramado) {
          _tabController.index = 1; // Programados
        } else {
          _tabController.index = 0; // Normales
        }
      }
    });
  }

  Future<void> _cargarUbicacionInicial() async {
    final ubicacionSvc = UbicacionUsuario();
    try {
      final coords = await ubicacionSvc.coordenadasUser();
      if (!mounted) return;

      if (coords == null) {
        setState(() {
          _ubicacionDisponible = false;
        });
        _orderService.markLocationUnavailable();
        return;
      }

      final lat = coords['lat'];
      final lng = coords['lng'];

      if (lat == null || lng == null) {
        setState(() {
          _ubicacionDisponible = false;
        });
        _orderService.markLocationUnavailable();
        return;
      }

      setState(() {
        _ubicacionDisponible = true;
      });
      _orderService.updateLocation(lat, lng);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error al obtener ubicación inicial: $e');
      }
      if (!mounted) return;
      setState(() {
        _ubicacionDisponible = false;
      });
      _orderService.markLocationUnavailable();
    }
  }

  Future<void> _cargarEstadoInicial() async {
    try {
      final uid = fb.FirebaseAuth.instance.currentUser?.uid;
      debugPrint('\n🔍 CARGANDO SERVICIO DEL TAXISTA...');
      debugPrint('UID del taxista: $uid');

      if (uid == null) {
        debugPrint('❌ UID es null, no se puede cargar servicio');
        return;
      }

      final docSnapshot = await FirebaseFirestore.instance
          .collection('taxistas')
          .doc(uid)
          .get();

      debugPrint('¿Documento taxista existe?: ${docSnapshot.exists}');

      if (!docSnapshot.exists) {
        debugPrint('❌ Documento taxista/$uid no existe');
        return;
      }

      final data = docSnapshot.data();
      debugPrint('Datos del documento: ${data?.keys.toList()}');

      final documentosVehiculo =
          data?['documentosVehiculo'] as Map<String, dynamic>?;

      debugPrint('¿documentosVehiculo existe?: ${documentosVehiculo != null}');
      if (documentosVehiculo != null) {
        debugPrint(
          'Campos en documentosVehiculo: ${documentosVehiculo.keys.toList()}',
        );
        debugPrint(
          'servicioSeleccionado RAW: "${documentosVehiculo['servicioSeleccionado']}"',
        );
      }

      if (documentosVehiculo == null ||
          documentosVehiculo['habilitado'] != true) {
        if (mounted) {
          setState(() {
            _estado = Estado3.ocupado;
          });
          _orderService.updateDisponibilidad(false);
        }
      } else {
        // Documentos habilitados → respetamos el estado actual (por defecto libre)
        if (mounted) {
          _orderService.updateDisponibilidad(_estado == Estado3.libre);
        }
      }

      // 🔹 Cargar el servicio seleccionado del taxista
      final servicioSel = documentosVehiculo?['servicioSeleccionado']
          ?.toString();

      debugPrint('servicioSeleccionado después de toString(): "$servicioSel"');

      if (mounted) {
        setState(() {
          _servicioSeleccionado = servicioSel;
        });
        // Notificamos el tipo de servicio al listener de órdenes
        _orderService.updateServiceType(servicioSel);
      }
      debugPrint(
        '✅ Servicio del taxista cargado en estado: "$_servicioSeleccionado"',
      );
      debugPrint('=====================================\n');

      // 📍 Si el taxista quedó libre tras el chequeo, ya empezamos a publicar
      // su presencia para que los pasajeros lo vean en el mapa.
      if (mounted && _estado == Estado3.libre) {
        await TaxistaPresenceService.instance.startPublishing(
          servicio: _servicioSeleccionado ?? 'Taxi',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error al cargar estado inicial: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Normaliza el nombre del servicio para comparación (lowercase, trim)
  String? _normalizeService(String? service) {
    if (service == null) return null;
    return service.trim().toLowerCase();
  }

  /// Convierte identificadores internos a etiqueta legible para el UI.
  /// Ej: "simple_uber" → "Simple Uber", "Moto_taxi" → "Moto Taxi"
  static IconData _iconVehiculo(String? s) {
    if (s == null) return Icons.directions_car_filled_rounded;
    final l = s.toLowerCase();
    if (l.contains('moto')) return Icons.two_wheeler_rounded;
    if (l.contains('confort') || l.contains('premium') || l.contains('vip')) {
      return Icons.drive_eta_rounded;
    }
    return Icons.directions_car_filled_rounded;
  }

  static String _formatServicio(String s) {
    return s
        .trim()
        .replaceAll('_', ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  Future<void> _cambiarEstado(Estado3? nuevoEstado) async {
    if (nuevoEstado == null) return;

    if (nuevoEstado == Estado3.libre) {
      final puedePonerseLibre = await _verificarDocumentosVerificados();
      if (!puedePonerseLibre) {
        if (!mounted) return;
        _mostrarDialogoDocumentosNoVerificados();
        return;
      }
    }

    setState(() => _estado = nuevoEstado);

    // Actualizar disponibilidad en el servicio de órdenes
    _orderService.updateDisponibilidad(_estado == Estado3.libre);

    // 📍 Publicar/borrar presencia en RTDB para que los pasajeros vean
    // al taxista en el mapa SOLO cuando está libre.
    if (_estado == Estado3.libre) {
      await TaxistaPresenceService.instance.startPublishing(
        servicio: _servicioSeleccionado ?? 'Taxi',
      );
    } else {
      await TaxistaPresenceService.instance.stopPublishing();
    }
  }

  // Future<void> _verificarDatosTaxi() async {
  //   try {
  //     final uid = fb.FirebaseAuth.instance.currentUser?.uid;
  //     if (uid == null) {
  //       debugPrint('🔍 _verificarDatosTaxi: No hay UID');
  //       return;
  //     }

  //     // Verificar en la colección taxistas/documentosVehiculo
  //     final taxistaDoc = await FirebaseFirestore.instance
  //         .collection('taxistas')
  //         .doc(uid)
  //         .get();
  //     // Convertir los datos del documento a un mapa
  //     final data = taxistaDoc.data() as Map<String, dynamic>;

  //     // Convertir el mapa a un objeto Taxista
  //     final taxista = Taxista.fromJson(data);

  //     Map<String, dynamic>? documentosVehiculo;
  //     documentosVehiculo = taxista.documentosVehiculo.toJson();

  //     // if (documentosVehiculo == null) {
  //     //   if (mounted) setState(() => _datosIncompletos = true);
  //     //   return;
  //     // }

  //     // Campos requeridos
  //     final campos = [
  //       'marca',
  //       'modelo',
  //       'placa',
  //       'color',
  //       'numeroAsientos',
  //       'numeroLicencia',
  //     ];
  //     bool faltaAlguno = false;
  //     for (final campo in campos) {
  //       final v = documentosVehiculo[campo];
  //       if (v == null) {
  //         faltaAlguno = true;
  //         break;
  //       }
  //       if (v is String && v.trim().isEmpty) {
  //         faltaAlguno = true;
  //         break;
  //       }
  //       // Si es Timestamp, lo consideramos como presente (no vacío)
  //       // Si es otro tipo, solo se marca como faltante si es null
  //     }

  //     if (mounted) {
  //       setState(() => _datosIncompletos = faltaAlguno);
  //     }
  //   } catch (e) {
  //     debugPrint('❌ Error al verificar datos del taxi: $e');
  //   }
  // }

  Future<bool> _verificarDocumentosVerificados() async {
    try {
      final uid = fb.FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return false;

      final docSnapshot = await FirebaseFirestore.instance
          .collection('taxistas')
          .doc(uid)
          .get();

      if (!docSnapshot.exists) return false;

      final data = docSnapshot.data();
      final documentosVehiculo =
          data?['documentosVehiculo'] as Map<String, dynamic>?;

      if (documentosVehiculo == null) return false;

      final habilitado = documentosVehiculo['habilitado'] == true;
      return habilitado;
    } catch (e) {
      debugPrint('Error al verificar documentos verificados: $e');
      return false;
    }
  }

  void _mostrarDialogoDocumentosNoVerificados() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Documentos no verificados',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'No puedes ponerte en estado "Libre" porque tus documentos aún no han sido verificados por el administrador.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            SizedBox(height: 12),
            Text(
              '📋 Para recibir solicitudes de viaje necesitas:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              '• Todos tus documentos deben estar verificados\n'
              '• El administrador revisará tus documentos\n'
              '• Una vez aprobados, podrás ponerte en "Libre"',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        actions: [
          
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Entendido',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    AutoCancelService().stopMonitoring();
    // Al salir de la pantalla, dejamos de aparecer en el mapa de los pasajeros.
    TaxistaPresenceService.instance.stopPublishing();
    super.dispose();
  }

  Future<void> _verificarDocumentosCompletos() async {
    // DESACTIVADA: La validación se hace en home_taxista_page.dart
    // Esta validación duplicada causaba loops de redirección
    return;

    /* CÓDIGO ANTIGUO COMENTADO
    try {
      final uid = fb.FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final docSnapshot = await FirebaseFirestore.instance
          .collection('taxistas')
          .doc(uid)
          .get();

      if (!docSnapshot.exists) return;

      final data = docSnapshot.data();
      final documentosVehiculo =
          data?['documentosVehiculo'] as Map<String, dynamic>?;

      if (documentosVehiculo == null) {
        if (!mounted) return;
        _redirigirADocumentos();
        return;
      }

      final camposObligatorios = [
        'numeroLicencia',
        'marca',
        'color',
        'numeroAsientos',
        'fotoAntecedentesPenales',
        'fotoConductor',
        'fotoCarneIdentidadAnverso',
        'fotoCarneIdentidadReverso',
        'fotoLicenciaConducirAnverso',
        'fotoLicenciaConducirReverso',
        'fotoSoat',
        'fotoPermisoCirculacion',
        'fotoRevisionTecnica',
        'fotoVehiculo1',
      ];

      for (final campo in camposObligatorios) {
        final v = documentosVehiculo[campo];
        if (v == null || (v is String && v.isEmpty)) {
          if (!mounted) return;
          _redirigirADocumentos();
          return;
        }
      }
    } catch (e) {
      debugPrint('Error al verificar documentos: $e');
    }
    */
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      // El drawer se gestiona en el Scaffold padre (HomeTaxista) para que
      // al abrirse cubra también la floating bottom nav.
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildDarkHeader(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _buildBodyByEstado(_estado),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ================== Header oscuro estilo Uber/Indrive ================== */

  Widget _buildDarkHeader() {
    final estadoLabel = _estado == Estado3.libre
        ? 'En línea'
        : _estado == Estado3.ocupado
            ? 'Desconectado'
            : 'Suspendido';
    final estadoDot = _estado == Estado3.libre
        ? const Color(0xFF22C55E)
        : _estado == Estado3.ocupado
            ? const Color(0xFFEF4444)
            : const Color(0xFFF59E0B);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF111827)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fila superior: menú + título + estado dot
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.menu_rounded, color: Colors.white),
                onPressed: () =>
                    HomeTaxista.scaffoldKey.currentState?.openDrawer(),
                splashRadius: 22,
              ),
              const SizedBox(width: 2),
              const Expanded(
                child: Text(
                  'Solicitudes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: estadoDot,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: estadoDot.withValues(alpha: 0.55),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      estadoLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Switch de disponibilidad
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Switch1(
              value: _estado,
              onChanged: (v) => _cambiarEstado(v),
              colorOcupado: Colors.red,
              colorLibre: Colors.green,
              colorSuspendido: Colors.orange,
              textColorSelected: Colors.white,
              unselectedBgColor: Colors.white.withValues(alpha: 0.08),
              borderColor: Colors.white.withValues(alpha: 0.18),
            ),
          ),
          const SizedBox(height: 14),
          // Stats
          _buildStatsRow(),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.near_me_rounded,
            label: 'CERCA DE TI',
            child: StreamBuilder<
                List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
              stream: _orderService.ordersStream,
              builder: (_, snap) {
                final n = (_estado == Estado3.libre && _ubicacionDisponible)
                    ? (snap.data?.length ?? 0)
                    : 0;
                return Text('$n pedidos');
              },
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: _iconVehiculo(_servicioSeleccionado),
            label: 'SERVICIO',
            child: Text(
              (_servicioSeleccionado == null ||
                      _servicioSeleccionado!.trim().isEmpty)
                  ? '—'
                  : _formatServicio(_servicioSeleccionado!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBodyByEstado(Estado3 estado) {
    // Sheet blanco redondeado que se "engancha" debajo del header oscuro
    return Container(
      key: ValueKey(estado),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 14,
            offset: Offset(0, -2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildSheetContent(estado),
    );
  }

  Widget _buildSheetContent(Estado3 estado) {
    if (estado != Estado3.libre) {
      if (estado == Estado3.ocupado) {
        return const _EmptyState(
          icon: Icons.power_settings_new_rounded,
          title: 'Estás desconectado',
          subtitle: 'No estás recibiendo solicitudes en este momento.',
          accent: Colors.red,
        );
      }
      return const _EmptyState(
        icon: Icons.privacy_tip_rounded,
        title: 'Cuenta suspendida',
        subtitle: 'Tu cuenta está en revisión.',
        accent: Colors.orange,
      );
    }

    return Column(
      children: [
        // Handle visual del sheet
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // Segmented control iOS-style
        _buildSegmentedTabs(),
        if (_datosIncompletos) _buildDatosIncompletosBanner(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildNormalesView(), _buildProgramadosView()],
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentedTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: AnimatedBuilder(
          animation: _tabController,
          builder: (_, __) {
            final i = _tabController.index;
            return Stack(
              children: [
                AnimatedAlign(
                  alignment:
                      i == 0 ? Alignment.centerLeft : Alignment.centerRight,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  child: FractionallySizedBox(
                    widthFactor: 0.5,
                    heightFactor: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _segmentLabel(
                        'Normales',
                        Icons.local_taxi_rounded,
                        0,
                        i == 0,
                      ),
                    ),
                    Expanded(
                      child: _segmentLabel(
                        'Programados',
                        Icons.event_available_rounded,
                        1,
                        i == 1,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _segmentLabel(String text, IconData icon, int idx, bool active) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _tabController.animateTo(idx),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: active ? const Color(0xFF0F172A) : Colors.black54,
            ),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                color: active ? const Color(0xFF0F172A) : Colors.black54,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatosIncompletosBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade50, Colors.orange.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade200,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline,
              color: Colors.orange,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Completa los datos del vehículo',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Para una mejor experiencia con los pasajeros',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Completar',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /* ================== TAB 1: Normales ================== */

  Widget _buildNormalesView() {
    final db = FirebaseFirestore.instance;
    final uid = fb.FirebaseAuth.instance.currentUser?.uid;

    if (uid == null || uid.isEmpty) {
      return const _EmptyState(
        icon: Icons.person_off_rounded,
        title: 'Sin sesión',
        subtitle: 'Inicia sesión para recibir solicitudes.',
        accent: Colors.blueGrey,
      );
    }

    final estadosActivos = <String>[
      'aceptado',
      'aceptada',
      'en_camino',
      'en camino',
      'en_lugar',
      'en_curso',
      'en curso',
      'activo',
    ];

    final activaNormal = db
        .collectionGroup('ordenes')
        .where('uidTaxista', isEqualTo: uid)
        .where('estado', whereIn: estadosActivos)
        .orderBy('updatedAt', descending: true)
        .limit(1)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: activaNormal,
      builder: (context, activeSnap) {
        if (activeSnap.hasError) {
          _logFirestoreError(
            activeSnap.error!,
            activeSnap.stackTrace,
            context: 'activa normal',
          );
          return _EmptyState(
            icon: Icons.error_outline,
            title: 'Error al cargar (activo)',
            subtitle: activeSnap.error.toString(),
            accent: Colors.red,
          );
        }
        if (activeSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final act = activeSnap.data?.docs ?? const [];
        if (act.isNotEmpty) {
          return RefreshIndicator(
            onRefresh: () async {},
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: 1,
              separatorBuilder: (_, __) => const _ItemDivider(),
              itemBuilder: (_, __) => PedidoCardFromDoc(doc: act.first),
            ),
          );
        }

        // Si la ubicación está desactivada o no disponible, avisamos al usuario.
        if (!_ubicacionDisponible) {
          return const _EmptyState(
            icon: Icons.location_off_rounded,
            title: 'Ubicación no disponible',
            subtitle:
                'Activa los servicios de ubicación y concede permisos para ver pedidos cercanos.',
            accent: Colors.blueGrey,
          );
        }

        // Usamos el stream ya filtrado del OrderService
        return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          stream: _orderService.ordersStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final nearby = snapshot.data ?? const [];

            if (nearby.isEmpty) {
              return const _EmptyState(
                icon: Icons.local_taxi_rounded,
                title: 'Sin pedidos cercanos',
                subtitle: 'No hay pedidos a menos de 5 km.\nPuede que estés en una zona sin demanda.',
                accent: Color(0xFF16A34A),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {},
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: nearby.length,
                separatorBuilder: (_, __) => const _ItemDivider(),
                itemBuilder: (_, i) => PedidoCardFromDoc(doc: nearby[i]),
              ),
            );
          },
        );
      },
    );
  }

  /* ================== TAB 2: Programados ================== */

  Widget _buildProgramadosView() {
    final db = FirebaseFirestore.instance;
    final uid = fb.FirebaseAuth.instance.currentUser?.uid;

    if (uid == null || uid.isEmpty) {
      return const _EmptyState(
        icon: Icons.person_off_rounded,
        title: 'Sin sesión',
        subtitle: 'Inicia sesión para recibir solicitudes.',
        accent: Colors.blueGrey,
      );
    }

    // Estados permitidos para Programados (ya NO van al historial)
    final estadosProgramados = <String>[
      'aceptado',
      'aceptada',
      'en_camino',
      'en camino',
      'en_lugar',
      'en_curso',
      'en curso',
      'pedido',
    ];

    final pedidosProg = db
        .collectionGroup('ordenesProgramados')
        .where('estado', whereIn: estadosProgramados)
        .orderBy('createdAt', descending: true) // requerido por Firestore
        .limit(200)
        .snapshots();

    int _priorityEstado(String e) {
      final s = e.toLowerCase().trim();
      if (s == 'aceptado' || s == 'aceptada') return 0;
      if (s == 'en_camino' || s == 'en camino') return 1;
      if (s == 'en_lugar') return 2;
      if (s == 'en_curso' || s == 'en curso') return 3;
      if (s == 'pedido') return 4;
      return 99;
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: pedidosProg,
      builder: (context, pedSnap) {
        if (pedSnap.hasError) {
          _logFirestoreError(
            pedSnap.error!,
            pedSnap.stackTrace,
            context: 'pedidos programado',
          );
          return _EmptyState(
            icon: Icons.error_outline,
            title: 'Error al cargar',
            subtitle: pedSnap.error.toString(),
            accent: Colors.red,
          );
        }
        if (pedSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var allDocs = pedSnap.data?.docs ?? const [];

        debugPrint('\n========== FILTRANDO ÓRDENES PROGRAMADAS ==========');
        debugPrint(
          '🔵 Servicio del taxista: "$_servicioSeleccionado" (norm: "${_normalizeService(_servicioSeleccionado)}")',
        );
        debugPrint(
          '📍 Total de órdenes programadas antes de filtrar: ${allDocs.length}',
        );

        // 1. Si estado es 'pedido' -> Mostrar a todos.
        // 2. Si estado NO es 'pedido' (ej. aceptado) -> Mostrar SOLO si soy el conductor.
        final docs = allDocs.where((doc) {
          final data = doc.data();
          final estado = data['estado']?.toString() ?? '';
          final conductorAsignado = data['uidTaxista'];

          debugPrint(
            '🔍 Evaluando orden programada ${doc.id}: estado="$estado", conductor="$conductorAsignado"',
          );

          // Filtro de asignación
          final perteneceAlConductor =
              estado == 'pedido' || conductorAsignado == uid;
          if (!perteneceAlConductor) {
            debugPrint(
              '⏭️ Orden programada ${doc.id} filtrada: no pertenece al conductor (estado=$estado, asignado=$conductorAsignado)',
            );
            return false;
          }

          // 🔹 Filtrar por servicio del taxista
          if (_servicioSeleccionado != null) {
            final ordenServicio = data['servicio']?.toString();
            debugPrint(
              '   Orden programada ${doc.id} tiene servicio: "$ordenServicio"',
            );
            final normalizedDriverService = _normalizeService(
              _servicioSeleccionado,
            );
            final normalizedOrderService = _normalizeService(ordenServicio);

            if (normalizedOrderService != normalizedDriverService) {
              debugPrint(
                '❌ Orden programada ${doc.id} FILTRADA: '
                'servicio orden="$ordenServicio" (norm: "$normalizedOrderService") != '
                'servicio taxista="$_servicioSeleccionado" (norm: "$normalizedDriverService")',
              );
              return false;
            } else {
              debugPrint(
                '✅ Orden programada ${doc.id} ACEPTA: '
                'servicio="$ordenServicio" (norm: "$normalizedOrderService") coincide',
              );
            }
          } else {
            debugPrint(
              '⚠️ Orden programada ${doc.id}: Sin filtro de servicio (_servicioSeleccionado es null)',
            );
          }

          return true;
        }).toList();

        debugPrint(
          '📊 Resultado: ${docs.length} órdenes programadas del mismo servicio',
        );
        debugPrint('========================================\n');

        if (docs.isEmpty) {
          return const _EmptyState(
            icon: Icons.event_available_rounded,
            title: 'Sin viajes programados',
            subtitle: 'No hay solicitudes programadas\npara tu servicio por ahora.',
            accent: Color(0xFF0EA5E9),
          );
        }

        // ✅ Orden: prioridad por estado, luego fecha programada
        docs.sort((a, b) {
          final ea = (a.data()['estado'] ?? '').toString();
          final eb = (b.data()['estado'] ?? '').toString();
          final pa = _priorityEstado(ea);
          final pb = _priorityEstado(eb);
          if (pa != pb) return pa.compareTo(pb);

          final ta = _getScheduleOrFallback(a.data());
          final tb = _getScheduleOrFallback(b.data());
          return ta.compareTo(tb);
        });

        return RefreshIndicator(
          onRefresh: () async {},
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const _ItemDivider(),
            itemBuilder: (_, i) => PedidoCardFromDoc(doc: docs[i]),
          ),
        );
      },
    );
  }
}
