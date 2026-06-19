import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:intl/intl.dart';

import 'package:buses2/features/home_taxi_features/billetera_taxista/services/taxista_wallet_service.dart';
import 'package:buses2/features/home_taxi_features/home_taxi/widgets/ride_request_card.dart';
import 'package:buses2/features/chats/data/repositories/chat_repository.dart';

/// Pequeña tupla usada para agenda (mismo patrón que en solicitudes_taxista.dart)
class Tuple2<A, B> {
  final A item1;
  final B item2;
  const Tuple2(this.item1, this.item2);
}

/// ✅ Helper: dice si HOY es una de las fechas programadas del viaje
bool _isTodayInProgramacion(Map<String, dynamic> d) {
  final progRaw = d['programacion'];
  // Si no hay programacion, probamos con scheduledAtLocal (una sola fecha)
  if (progRaw is! Map) {
    final schedStr = d['scheduledAtLocal']?.toString();
    if (schedStr != null) {
      final dt = DateTime.tryParse(schedStr);
      if (dt == null) return false;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final only = DateTime(dt.year, dt.month, dt.day);
      return only == today;
    }
    return false;
  }

  final prog = Map<String, dynamic>.from(progRaw);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  String two(int n) => n.toString().padLeft(2, '0');
  final todayYmd = '${today.year}-${two(today.month)}-${two(today.day)}';

  // 1) Caso datesLocal: lista de fechas sueltas (YYYY-MM-DD...)
  final datesLocalRaw = prog['datesLocal'];
  if (datesLocalRaw is List && datesLocalRaw.isNotEmpty) {
    for (final e in datesLocalRaw) {
      final s = e.toString();
      if (s.length >= 10) {
        if (s.substring(0, 10) == todayYmd) return true;
      }
    }
    return false;
  }

  // 2) Caso range: start/end + weekdays + excludes
  final rangeRaw = prog['range'];
  if (rangeRaw is! Map) return false;
  final range = Map<String, dynamic>.from(rangeRaw);

  DateTime? _parseDay(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    final base = s.length >= 10 ? s.substring(0, 10) : s;
    return DateTime.tryParse('${base}T00:00:00.000');
  }

  final start = _parseDay(range['startLocal'] ?? range['start']);
  final end = _parseDay(range['endLocal'] ?? range['end']);

  if (start == null || end == null) return false;
  if (today.isBefore(start) || today.isAfter(end)) return false;

  // Filtrar por weekdays (si existen)
  final weekdays = (range['weekdays'] is List)
      ? List<int>.from(range['weekdays'])
      : <int>[];
  if (weekdays.isNotEmpty && !weekdays.contains(today.weekday)) {
    return false;
  }

  // Excluir fechas en excludes
  final excludes = (range['excludes'] is List)
      ? Set<String>.from(range['excludes'].map((e) => e.toString()))
      : <String>{};
  if (excludes.contains(todayYmd)) return false;

  return true;
}

/// ✅ Estado específico de HOY para viajes programados:
/// 'pendiente' | 'cancelada' | 'completada' | null (si hoy no aplica)
String? _estadoHoyProgramadoRaw(Map<String, dynamic> d) {
  final progRaw = d['programacion'];

  // Sin mapa de programacion → revisamos scheduledAtLocal como único día
  if (progRaw is! Map) {
    final schedStr = d['scheduledAtLocal']?.toString();
    if (schedStr == null) return null;
    final dt = DateTime.tryParse(schedStr);
    if (dt == null) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final only = DateTime(dt.year, dt.month, dt.day);
    if (only != today) return null;

    // No tenemos arrays de canceladas/completadas en este modo → pendiente
    return 'pendiente';
  }

  final prog = Map<String, dynamic>.from(progRaw);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  String two(int n) => n.toString().padLeft(2, '0');
  final todayYmd = '${today.year}-${two(today.month)}-${two(today.day)}';

  final cancelled = (prog['cancelledDates'] is List)
      ? Set<String>.from(
          (prog['cancelledDates'] as List).map(
            (e) => e.toString().substring(0, 10),
          ),
        )
      : <String>{};

  final completed = (prog['completedDates'] is List)
      ? Set<String>.from(
          (prog['completedDates'] as List).map(
            (e) => e.toString().substring(0, 10),
          ),
        )
      : <String>{};

  if (cancelled.contains(todayYmd)) return 'cancelada';
  if (completed.contains(todayYmd)) return 'completada';

  // Si hoy está en la programación, pero no cancelada/completada → pendiente
  if (_isTodayInProgramacion(d)) return 'pendiente';

  return null;
}

/// Card genérica: adapta un documento de Firestore (orden / ordenProgramado)
/// a RideRequestCard2080, con el mismo flujo que en SolicitudesTaxistaPage
/// (marcar en camino, ver ruta, abrir /mapa-taxi, etc.).
class PedidoCardFromDoc extends StatelessWidget {
  const PedidoCardFromDoc({super.key, required this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final d = doc.data();

    // uid pasajero desde campo o ruta padre
    final String? uidPasajero =
        (d['uidPasajero'] as String?) ?? doc.reference.parent.parent?.id;

    // Origen / destino (solo calle / título)
    final String origenTitulo =
        _firstNonEmpty([
          _fromMap(d, ['origen', 'calle']),
          d['origenCalle'],
          d['origenTitulo'],
          d['aCalle'],
          d['aTitulo'],
        ]) ??
        'Origen';

    final String destinoTitulo =
        _firstNonEmpty([
          _fromMap(d, ['destino', 'calle']),
          d['destinoCalle'],
          d['destinoTitulo'],
          d['bCalle'],
          d['bTitulo'],
        ]) ??
        'Destino';

    // Distancia
    final double? km = _getKm(d);

    // Estado de la orden
    final String? estadoOrden = d['estado']?.toString();

    // Precio según estado:
    // - En 'pedido': Pasajero puede haber enviado contraoferta → leer precioOfrecido primero
    // - En 'aceptado': Taxista aceptó contraoferta del taxista → leer total primero
    final num? precioCrudo = (estadoOrden == 'pedido')
        ? _firstNonNull<num>([
            _fromMap(d, ['tarifa', 'precioOfrecido']),
            _fromMap(d, ['tarifa', 'total']),
            d['total'],
            d['precio'],
            d['monto'],
            d['montoEstimado'],
            d['fare'],
            d['price'],
          ])
        : _firstNonNull<num>([
            _fromMap(d, ['tarifa', 'total']),
            _fromMap(d, ['tarifa', 'precioOfrecido']),
            d['total'],
            d['precio'],
            d['monto'],
            d['montoEstimado'],
            d['fare'],
            d['price'],
          ]);
    final double? precio = _computePrecio(precioCrudo, km, d);

    // Hora corta (creación)
    final String timeShort = _getCreatedAtShort(d);

    // ¿Es programado?
    bool isProgramado =
        (d['isProgramado'] == true) || (d['programado'] == true);
    if (!isProgramado && doc.reference.path.contains('/ordenesProgramados/')) {
      isProgramado = true;
    }

    // Fechas y hora de agenda (igual que en Programados)
    List<dynamic>? scheduleDatesLine = d['scheduleDatesLine'];
    String? scheduleTimeShort = _firstNonEmpty([
      d['scheduleTimeShort'],
      _fromMap(d, ['programacion', 'horaCorta']),
    ]);
    Map<String, dynamic> prog = const <String, dynamic>{};

    if (isProgramado &&
        (scheduleDatesLine == null || scheduleTimeShort == null)) {
      prog = (d['programacion'] is Map)
          ? Map<String, dynamic>.from(d['programacion'])
          : const <String, dynamic>{};
      final computed = _computeScheduleLines(
        prog,
        fallbackScheduledAt: d['scheduledAtLocal']?.toString(),
      );
      scheduleDatesLine ??= computed.item1;
      scheduleTimeShort ??= computed.item2;
    } else if (isProgramado && d['programacion'] is Map) {
      prog = Map<String, dynamic>.from(d['programacion']);
    }

    // 🔹 Estado por día de HOY para viajes programados
    String? estadoHoyProgramado; // 'pendiente' | 'cancelada' | 'completada'
    if (isProgramado) {
      estadoHoyProgramado = _estadoHoyProgramadoRaw(d);
    }

    // 🔹 Decorar cada fecha con su estado (✅ completado / ❌ cancelado) y
    // formatear a "Vie 21 Nov 2025"
    if (isProgramado && scheduleDatesLine != null && prog.isNotEmpty) {
      final decorated = _decorateScheduleDatesWithStatus(
        prog: prog,
        labels: scheduleDatesLine.map((e) => e.toString()).toList(),
      );
      scheduleDatesLine = decorated;
    }

    // Estado & lógica de botones / navegación
    final myUid = fb.FirebaseAuth.instance.currentUser?.uid ?? '';
    final String estadoRaw = (d['estado'] ?? '').toString().trim();
    final String estado = estadoRaw.isEmpty ? 'desconocido' : estadoRaw;

    final String uidTaxista = (d['uidTaxista'] ?? d['idTaxista'] ?? '')
        .toString();

    // ✅ Solo mostrar botón en días válidos DE HOY y si está pendiente
    final bool isTodayAllowed = !isProgramado
        ? true
        : (estadoHoyProgramado == 'pendiente');

    final bool showMarkBtn =
        (estado == 'aceptado' || estado == 'aceptada') &&
        uidTaxista == myUid &&
        isTodayAllowed;

    final bool disableTap = (estado == 'aceptado' || estado == 'aceptada');

    final bool isEnCamino = (estado == 'en_camino' || estado == 'en camino');
    final bool isEnLugar = (estado == 'en_lugar');
    final bool isEnCurso = (estado == 'en_curso' || estado == 'en curso');

    // 🔹 Texto bonito para mostrar el estado de hoy junto a la hora
    if (isProgramado && estadoHoyProgramado != null) {
      String labelHoy;
      switch (estadoHoyProgramado) {
        case 'completada':
          labelHoy = 'Hoy completado';
          break;
        case 'cancelada':
          labelHoy = 'Hoy cancelado';
          break;
        case 'pendiente':
          labelHoy = 'Hoy pendiente';
          break;
        default:
          labelHoy = '';
      }
      if (labelHoy.isNotEmpty) {
        if (scheduleTimeShort != null && scheduleTimeShort!.isNotEmpty) {
          scheduleTimeShort = '$scheduleTimeShort · $labelHoy';
        } else {
          scheduleTimeShort = labelHoy;
        }
      }
    }

    // Perfil pasajero
    const String fallbackNombre = 'Pasajero';
    String? fallbackFoto;
    const double fallbackRating = 5.0;
    const int fallbackRatingCount = 0;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: (uidPasajero == null || uidPasajero.isEmpty)
          ? null
          : FirebaseFirestore.instance
                .collection('pasajeros')
                .doc(uidPasajero)
                .snapshots(),
      builder: (context, s) {
        String nombre = fallbackNombre;
        String? foto;
        double rating = fallbackRating;
        int ratingCount = fallbackRatingCount;

        if (s.hasData && s.data!.data() != null) {
          final raw = s.data!.data()!;
          final perfil = (raw['perfil'] is Map)
              ? Map<String, dynamic>.from(raw['perfil'])
              : const <String, dynamic>{};
          nombre = (raw['name'] ?? perfil['name'] ?? fallbackNombre).toString();
          foto = (raw['photoUrl'] ?? perfil['photoUrl'] ?? fallbackFoto)
              ?.toString();

          // Rating promedio y número de reseñas del pasajero
          final num? promedioRaw =
              (raw['promedioEstrellas'] ?? perfil['promedioEstrellas']) as num?;
          if (promedioRaw != null) {
            rating = promedioRaw.toDouble();
          }

          final num? countRaw =
              (raw['numeroResenias'] ?? perfil['numeroResenias']) as num?;
          if (countRaw != null) {
            ratingCount = countRaw.toInt();
          }
        }

        // Coords de origen + rutaDoc → /en-camino
        final double? oLat = _toDouble(
          _firstNonNull([
            _fromMap(d, ['origen', 'lat']),
            d['origenLat'],
            d['aLat'],
          ]),
        );
        final double? oLng = _toDouble(
          _firstNonNull([
            _fromMap(d, ['origen', 'lng']),
            d['origenLng'],
            d['aLng'],
          ]),
        );

        final String origenTexto =
            _firstNonEmpty([
              _fromMap(d, ['origen', 'calle']),
              d['origenCalle'],
              d['origenTitulo'],
              d['aCalle'],
              d['aTitulo'],
            ]) ??
            'Origen';

        // Si no tiene rutaDoc en campo, usamos path del doc actual
        final String rutaDoc = (d['rutaDoc'] as String?) ?? doc.reference.path;

        // 🔹 Verificar si el taxista ya envió una oferta
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: doc.reference.collection('ofertas').doc(myUid).snapshots(),
          builder: (context, ofertaSnapshot) {
            final bool tieneOferta =
                ofertaSnapshot.hasData && ofertaSnapshot.data!.exists;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔹 Badge "Oferta enviada" en verde
                if (tieneOferta &&
                    !showMarkBtn &&
                    !isEnCamino &&
                    !isEnLugar &&
                    !isEnCurso)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 4,
                      right: 4,
                      bottom: 6,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: const Color(0xFF4CAF50),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: Color(0xFF2E7D32),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Oferta enviada',
                            style: TextStyle(
                              color: Color(0xFF1B5E20),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // 🔹 Etiqueta arriba de la card para el estado del viaje programado HOY
                if (isProgramado && estadoHoyProgramado != null)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 4,
                      right: 4,
                      bottom: 6,
                    ),
                    child: _buildEstadoProgramadoTag(estadoHoyProgramado!),
                  ),
                RideRequestCard2080(
                  // IZQUIERDA
                  passengerName: nombre,
                  rating: rating,
                  ratingCount: ratingCount,
                  avatarInitial: (foto == null || foto.trim().isEmpty)
                      ? nombre.characters.first.toUpperCase()
                      : null,
                  avatarImage: (foto != null && foto.trim().isNotEmpty)
                      ? NetworkImage(foto)
                      : null,
                  avatarBg: const Color(0xFFE9F5FF),
                  timeText: timeShort,

                  // DERECHA
                  distanceKm: km ?? 0,
                  priceText: (precio != null) ? _formatBs(precio) : '',
                  title: origenTitulo,
                  subtitle: destinoTitulo,

                  // Programado (badge + agenda)
                  isProgramado: isProgramado,
                  scheduleDatesText: isProgramado ? scheduleDatesLine : null,
                  scheduleTimeText: isProgramado ? scheduleTimeShort : null,

                  // Botón “Marcar en camino” (cuando está aceptado por este taxista y HOY está pendiente)
                  showMarkEnCamino: showMarkBtn,
                  onMarkEnCamino: showMarkBtn
                      ? () async {
                          try {
                            await doc.reference.update({
                              'estado': 'en_camino',
                              'updatedAt': FieldValue.serverTimestamp(),
                            });

                            // Marcar el chat asociado como "permanente" (si existe)
                            try {
                              String? chatId;
                              // Intentamos leer desde el documento local primero
                              try {
                                final local = doc.data();
                                chatId = (local['chatId'] as String?)
                                    ?.toString();
                              } catch (_) {
                                chatId = null;
                              }

                              // Si no está en la versión local, leemos en la nube
                              if (chatId == null || chatId.isEmpty) {
                                try {
                                  final snap = await doc.reference.get();
                                  final latest = snap.data();
                                  chatId =
                                      (latest != null &&
                                          latest['chatId'] != null)
                                      ? latest['chatId'].toString()
                                      : null;
                                } catch (_) {
                                  chatId = null;
                                }
                              }

                              if (chatId != null && chatId.isNotEmpty) {
                                await ChatRepository().markChatAsPermanent(
                                  chatId,
                                );
                              }
                            } catch (e) {
                              if (kDebugMode)
                                debugPrint(
                                  'Error marcando chat permanente: $e',
                                );
                            }

                            if (oLat == null || oLng == null) {
                              _showPrettySnack(
                                context,
                                icon: Icons.info_rounded,
                                title: 'Origen sin coordenadas',
                                subtitle:
                                    'No puedo abrir En Camino sin lat/lng de origen.',
                              );
                              return;
                            }

                            await Modular.to.pushNamed(
                              '/en-camino',
                              arguments: {
                                'driverUid': myUid,
                                'origenLat': oLat,
                                'origenLng': oLng,
                                'origenTexto': origenTexto,
                                'rutaDoc': rutaDoc,
                              },
                            );

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '🚗 Estado actualizado a “en camino”.',
                                  ),
                                ),
                              );
                            }
                          } catch (e, st) {
                            if (kDebugMode) {
                              debugPrint(
                                'Error al actualizar/navegar a en_camino: $e\n$st',
                              );
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Error al actualizar/navegar: $e',
                                  ),
                                ),
                              );
                            }
                          }
                        }
                      : null,

                  // Botón “Ver ruta” cuando ya está en_lugar / en_curso
                  showVerRuta: (isEnLugar || isEnCurso),
                  onVerRuta: (isEnLugar || isEnCurso)
                      ? () async {
                          if (oLat == null || oLng == null) {
                            _showPrettySnack(
                              context,
                              icon: Icons.info_rounded,
                              title: 'Origen sin coordenadas',
                              subtitle:
                                  'No puedo abrir En Camino sin lat/lng de origen.',
                            );
                            return;
                          }
                          await Modular.to.pushNamed(
                            '/en-camino',
                            arguments: {
                              'driverUid': myUid,
                              'origenLat': oLat,
                              'origenLng': oLng,
                              'origenTexto': origenTexto,
                              'rutaDoc': rutaDoc,
                            },
                          );
                        }
                      : null,

                  // Tap según estado
                  onTap: disableTap
                      ? null
                      : (isEnCamino
                            ? () async {
                                if (oLat == null || oLng == null) {
                                  _showPrettySnack(
                                    context,
                                    icon: Icons.info_rounded,
                                    title: 'Origen sin coordenadas',
                                    subtitle:
                                        'No puedo abrir En Camino sin lat/lng de origen.',
                                  );
                                  return;
                                }
                                await Modular.to.pushNamed(
                                  '/en-camino',
                                  arguments: {
                                    'driverUid': myUid,
                                    'origenLat': oLat,
                                    'origenLng': oLng,
                                    'origenTexto': origenTexto,
                                    'rutaDoc': rutaDoc,
                                  },
                                );
                              }
                            : () => _goToMapIfPossible(
                                context,
                                d,
                                nombre,
                                foto,
                                rating,
                                ratingCount,
                                isProgramado: isProgramado,
                              )),

                  menuItems: const [],
                  onMenuSelect: null,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/* ================== Helpers de formato / agenda / precio ================== */

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

String _formatBs(double v) {
  final s2 = v.toStringAsFixed(2);
  return s2.endsWith('00') ? 'ARS ${v.toStringAsFixed(0)}' : 'ARS $s2';
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

/// 🔹 Formato YYYY-MM-DD
String _ymd(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final dd = d.toLocal();
  return '${dd.year}-${two(dd.month)}-${two(dd.day)}';
}

/// 🔹 Parse de "dd/MM/yyyy" a DateTime
DateTime? _parseDdMmYyyy(String label) {
  final parts = label.trim().split('/');
  if (parts.length != 3) return null;
  final d = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final y = int.tryParse(parts[2]);
  if (d == null || m == null || y == null) return null;
  return DateTime(y, m, d);
}

/// 🔹 Formato largo tipo "Vie 21 Nov 2025"
String _formatFechaLarga(DateTime dt) {
  final df = DateFormat('EEE d MMM y', 'es');
  var s = df.format(dt); // viene en minúsculas
  if (s.isNotEmpty) {
    s = s[0].toUpperCase() + s.substring(1);
  }
  return s;
}

/// 🔹 Toma las labels (ej. ["20/11/2025", "21/11/2025"])
/// y les pone un prefijo según su estado en programacion:
/// ✅ si está en completedDates, ❌ si está en cancelledDates.
/// Además cambia el formato a "Vie 21 Nov 2025".
List<String> _decorateScheduleDatesWithStatus({
  required Map<String, dynamic> prog,
  required List<String> labels,
}) {
  final cancelled = (prog['cancelledDates'] is List)
      ? Set<String>.from(
          (prog['cancelledDates'] as List).map(
            (e) => e.toString().substring(0, 10),
          ),
        )
      : <String>{};

  final completed = (prog['completedDates'] is List)
      ? Set<String>.from(
          (prog['completedDates'] as List).map(
            (e) => e.toString().substring(0, 10),
          ),
        )
      : <String>{};

  return labels.map((lbl) {
    final dt = _parseDdMmYyyy(lbl);
    if (dt == null) return lbl;
    final ymd = _ymd(dt);
    final pretty = _formatFechaLarga(dt);

    if (completed.contains(ymd)) {
      return '✅ $pretty';
    }
    if (cancelled.contains(ymd)) {
      return '❌ $pretty';
    }
    return pretty;
  }).toList();
}

/// Genera lista de fechas dd/MM/yyyy a partir de startLocal / endLocal
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

/// Idéntico a _computeScheduleLines de solicitudes_taxista.dart
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
            color: Colors.black.withOpacity(.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: accent.withOpacity(.35), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: accent.withOpacity(.18),
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
                      color: Colors.white.withOpacity(.90),
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

/// 🔹 Chip de estado de viaje programado (arriba de la card)
Widget _buildEstadoProgramadoTag(String estadoHoy) {
  late String text;
  late Color bg;
  late Color fg;
  late IconData icon;

  switch (estadoHoy) {
    case 'completada':
      text = 'Viaje programado · Hoy completado';
      bg = const Color(0xFFE8F5E9);
      fg = const Color(0xFF1B5E20);
      icon = Icons.check_circle_rounded;
      break;
    case 'cancelada':
      text = 'Viaje programado · Hoy cancelado';
      bg = const Color(0xFFFFEBEE);
      fg = const Color(0xFFC62828);
      icon = Icons.cancel_rounded;
      break;
    default:
      text = 'Viaje programado · Hoy pendiente';
      bg = const Color(0xFFFFF8E1);
      fg = const Color(0xFFF9A825);
      icon = Icons.schedule_rounded;
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: fg),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: fg,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

/* ================== Lógica de mapa / comisión ================== */

Future<void> _goToMapIfPossible(
  BuildContext context,
  Map<String, dynamic> d,
  String nombre,
  String? foto,
  double? rating,
  int? ratingCount, {
  required bool isProgramado,
}) async {
  // Estado de la orden
  final String? estadoOrden = d['estado']?.toString();

  // Verificar saldo antes de abrir mapa
  final num? total = (estadoOrden == 'pedido')
      ? _firstNonNull<num>([
          _fromMap(d, ['tarifa', 'precioOfrecido']),
          _fromMap(d, ['tarifa', 'total']),
          d['total'],
          d['precio'],
          d['monto'],
          d['montoEstimado'],
          d['fare'],
          d['price'],
        ])
      : _firstNonNull<num>([
          _fromMap(d, ['tarifa', 'total']),
          _fromMap(d, ['tarifa', 'precioOfrecido']),
          d['total'],
          d['precio'],
          d['monto'],
          d['montoEstimado'],
          d['fare'],
          d['price'],
        ]);

  if (total != null && total > 0) {
    final String? servicio = _firstNonEmpty([
      d['servicio'],
      _fromMap(d, ['tarifa', 'servicio']),
    ]);

    final String? departamento = _firstNonEmpty([
      d['departamento'],
      _fromMap(d, ['origen', 'departamento']),
      _fromMap(d, ['origen', 'ciudad']),
    ]);

    double porcentajeComision = 10.0; // default

    if (servicio != null && departamento != null) {
      try {
        final comisionData = await _obtenerComisionServicio(
          empresaId: 'mujeresalvolante',
          departamento: departamento,
          servicio: servicio,
        );
        if (comisionData != null) {
          porcentajeComision = comisionData;
        }
      } catch (e) {
        debugPrint('⚠️ Error al obtener comisión: $e. Usando default 10%');
      }
    }

    final walletService = TaxistaWalletService();
    final verificacion = await walletService.verificarSaldoParaViaje(
      montoViaje: total.toDouble(),
      porcentajeComision: porcentajeComision,
    );

    if (verificacion['suficiente'] == false) {
      if (!context.mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: const Icon(
            Icons.warning_amber_rounded,
            size: 56,
            color: Colors.orange,
          ),
          title: const Text(
            'Saldo insuficiente para este viaje',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tu saldo actual:',
                          style: TextStyle(fontSize: 15),
                        ),
                        Text(
                          'ARS ${(verificacion['saldoActual'] as double).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Comisión del viaje:',
                          style: TextStyle(fontSize: 15),
                        ),
                        Text(
                          'ARS ${(verificacion['montoComision'] as double).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '💳 Necesitas recargar saldo para poder aceptar este viaje.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Entendido',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
      return;
    }
  }

  final double? oLat = _toDouble(
    _firstNonNull([
      _fromMap(d, ['origen', 'lat']),
      d['origenLat'],
      d['aLat'],
    ]),
  );
  final double? oLng = _toDouble(
    _firstNonNull([
      _fromMap(d, ['origen', 'lng']),
      d['origenLng'],
      d['aLng'],
    ]),
  );
  final double? dLat = _toDouble(
    _firstNonNull([
      _fromMap(d, ['destino', 'lat']),
      d['destinoLat'],
      d['bLat'],
    ]),
  );
  final double? dLng = _toDouble(
    _firstNonNull([
      _fromMap(d, ['destino', 'lng']),
      d['destinoLng'],
      d['bLng'],
    ]),
  );

  if (oLat == null || oLng == null || dLat == null || dLng == null) {
    _showPrettySnack(
      context,
      icon: Icons.info_rounded,
      title: 'Faltan coordenadas del viaje',
      subtitle: 'No se puede abrir el mapa para esta solicitud.',
      bg: Colors.green,
    );
    return;
  }

  final String origenTitulo =
      _firstNonEmpty([
        _fromMap(d, ['origen', 'calle']),
        d['origenCalle'],
        d['origenTitulo'],
        d['aCalle'],
        d['aTitulo'],
      ]) ??
      'Origen';

  final String destinoTitulo =
      _firstNonEmpty([
        _fromMap(d, ['destino', 'calle']),
        d['destinoCalle'],
        d['destinoTitulo'],
        d['bCalle'],
        d['bTitulo'],
      ]) ??
      'Destino';

  final double? km = _getKm(d);
  final String? rutaDoc = (d['rutaDoc'] as String?);

  final programacion = d['programacion'];
  final fechasProgramadas = programacion == null
      ? null
      : programacion['datesLocal'] != null
      ? (programacion['datesLocal'] as List).cast<dynamic>()
      : (programacion['range'] != null &&
            programacion['range']['startLocal'] != null &&
            programacion['range']['endLocal'] != null)
      ? crearFechasRango(
          programacion['range']['startLocal'],
          programacion['range']['endLocal'],
        )
      : null;

  final horaProgramada = d['timestampLocal']?.toString();

  await Modular.to.pushNamed(
    '/mapa-taxi',
    arguments: {
      'lat': oLat,
      'lng': oLng,
      'calle': origenTitulo,
      'ciudad': null,
      'pais': 'Bolivia',
      'destinoLat': dLat,
      'destinoLng': dLng,
      'destinoTexto': destinoTitulo,
      'destinoCalle': null,
      'destinoCiudad': null,
      'destinoPais': 'Bolivia',
      'precio': (total is num) ? total.toDouble() : null,
      'distanciaKm': km?.toDouble(),
      'isProgramado': isProgramado,
      'scheduleDates': fechasProgramadas,
      'scheduleTime': horaProgramada,
      'createdAtShort': _getCreatedAtShort(d),
      'pasajeroNombre': nombre,
      'pasajeroFotoUrl': foto,
      'pasajeroRating': rating,
      'pasajeroRatingCount': ratingCount,
      'etiqueta': isProgramado ? 'Viaje programado' : 'Solicitud',
      'rutaDoc': rutaDoc,
    },
  );
}

Future<double?> _obtenerComisionServicio({
  required String empresaId,
  required String departamento,
  required String servicio,
}) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('empresas')
        .doc(empresaId)
        .collection('tarifas')
        .doc(departamento)
        .get();

    if (!doc.exists) return null;

    final data = doc.data();
    if (data == null) return null;

    final servicioNormalizado = servicio
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^\w\-]'), '');

    Map<String, dynamic>? servicioData;

    if (data.containsKey(servicio)) {
      servicioData = data[servicio] as Map<String, dynamic>?;
    } else if (data.containsKey(servicioNormalizado)) {
      servicioData = data[servicioNormalizado] as Map<String, dynamic>?;
    } else {
      for (var key in data.keys) {
        if (key.toString().toLowerCase() == servicio.toLowerCase() ||
            key.toString().toLowerCase() == servicioNormalizado.toLowerCase()) {
          servicioData = data[key] as Map<String, dynamic>?;
          break;
        }
      }
    }

    if (servicioData == null) return null;

    dynamic comision = servicioData['comision'];

    if (comision == null && servicioData['tarifas'] is Map) {
      final tarifas = servicioData['tarifas'] as Map<String, dynamic>;
      comision = tarifas['comision'];
    }

    if (comision is num) return comision.toDouble();
    return null;
  } catch (e, stackTrace) {
    debugPrint('❌ Error al obtener comisión: $e');
    debugPrint('❌ Stack trace: $stackTrace');
    return null;
  }
}
