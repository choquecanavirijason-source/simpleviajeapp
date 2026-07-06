import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'
    show Point, Position;
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:buses2/core/services/mapa_taxi/mapbox_taxi/mapa_widget_taxi.dart';
import 'package:buses2/features/home_taxi_features/home_taxi/controller/mapa_taxi_controller.dart';
import 'package:buses2/features/home_taxi_features/home_taxi/widgets/detallespedido/circular_countdown.dart';
import 'package:buses2/features/home_taxi_features/home_taxi/widgets/detallespedido/header_badge_button.dart';
import 'package:buses2/features/home_taxi_features/home_taxi/widgets/detallespedido/header_price_badge.dart';
import 'package:buses2/features/home_taxi_features/home_taxi/widgets/detallespedido/price_editor_dialog.dart';
import 'package:buses2/features/home_taxi_features/home_taxi/widgets/ride_request_card.dart';

class MapaTaxi extends StatefulWidget {
  const MapaTaxi({super.key});
  @override
  State<MapaTaxi> createState() => _MapaTaxiState();
}

class _MapaTaxiState extends State<MapaTaxi>
    with SingleTickerProviderStateMixin {
  late final MapaTaxiController c;

  bool _acceptedHandled = false;
  bool _rejectedHandled = false;

  // ✅ evita loop infinito cuando estado == pendiente
  bool _offerMarkedHandled = false;

  bool _isDisposing = false;

  @override
  void initState() {
    super.initState();

    final rawArgs = Modular.args.data;
    final Map<String, dynamic> safeArgs = rawArgs is Map
        ? Map<String, dynamic>.from(rawArgs)
        : {};

    c = MapaTaxiController(
      args: safeArgs,
      tickerProvider: this,
      onTimeout: () {
        if (!mounted) return;
        Navigator.of(context).pop({'accion': 'timeout'});
      },
      onToActivo: () {
        if (!mounted) return;
        Navigator.of(context).pop({'accion': 'activo'});
      },
    )..init();
  }

  @override
  void dispose() {
    _isDisposing = true;
    c.disposeAll();
    super.dispose();
  }

  Future<void> _trazarRutaConReintentos() async {
    if (_isDisposing) return;
    if (c.map == null || !c.mapReady) return;
    if (c.aLat == null || c.aLng == null || c.bLat == null || c.bLng == null) {
      return;
    }

    try {
      await c.map!.agregarPuntoFijo(
        Point(coordinates: Position(c.aLng!, c.aLat!)),
        fillColor: Colors.white,
        strokeColor: const Color(0xFF2196F3),
        radius: 6,
        strokeWidth: 6,
      );
      await c.map!.agregarPuntoFijo(
        Point(coordinates: Position(c.bLng!, c.bLat!)),
        fillColor: Colors.white,
        strokeColor: const Color(0xFF4CAF50),
        radius: 6,
        strokeWidth: 6,
      );
    } catch (_) {}

    const maxTries = 8;
    for (int i = 1; i <= maxTries; i++) {
      if (_isDisposing) return;
      try {
        await c.map!.dibujarRutaDesdeHasta(
          a: Point(coordinates: Position(c.aLng!, c.aLat!)),
          b: Point(coordinates: Position(c.bLng!, c.bLat!)),
          context: context,
        );
        return;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 180));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final alto = MediaQuery.of(context).size.height;
    final altoMapa = alto * 0.46;

    final ruta = c.rutaDoc?.trim();
    final idT = c.idTaxista?.trim();
    final bool canListenOffer =
        (ruta != null && ruta.isNotEmpty && idT != null && idT.isNotEmpty);

    final Stream<DocumentSnapshot<Map<String, dynamic>>>? offerDocStream =
        canListenOffer
        ? FirebaseFirestore.instance.doc('$ruta/ofertas/$idT').snapshots()
        : null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: altoMapa,
              child: Stack(
                children: [
                  MapaWidget(
                    centerLat: c.aLat ?? -17.3895,
                    centerLng: c.aLng ?? -66.1568,
                    onMapReady: (ctrl) async {
                      c.map = ctrl;
                      c.mapReady = true;
                      await Future.delayed(const Duration(milliseconds: 300));
                      if (!mounted) return;
                      await _trazarRutaConReintentos();
                    },
                  ),
                ],
              ),
            ),

            Expanded(
              child: AnimatedBuilder(
                animation: c,
                builder: (_, __) {
                  final bool puedeInteractuarPorTiempo =
                      c.isProgramado || c.secondsLeft > 0;

                  final List<dynamic>? schedDates = c.scheduleDates;
                  final String? schedTime = c.scheduleTime;
                  final bool hasDates =
                      schedDates != null &&
                      schedDates.isNotEmpty &&
                      c.isProgramado;
                  final bool hasTime =
                      schedTime != null &&
                      schedTime.trim().isNotEmpty &&
                      c.isProgramado;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Stack(
                          children: [
                            RideRequestCard2080(
                              leftFactor: 0.235,
                              minLeft: 96,
                              rating: c.pasajeroRating ?? 4.60,
                              ratingCount: c.pasajeroRatingCount ?? 120,
                              passengerName:
                                  (c.pasajeroNombre?.isNotEmpty ?? false)
                                  ? c.pasajeroNombre!
                                  : 'Pasajero',
                              avatarImage:
                                  (c.pasajeroFotoUrl != null &&
                                      c.pasajeroFotoUrl!.isNotEmpty)
                                  ? NetworkImage(c.pasajeroFotoUrl!)
                                  : null,
                              avatarInitial:
                                  (c.pasajeroFotoUrl == null ||
                                      c.pasajeroFotoUrl!.isEmpty)
                                  ? ((c.pasajeroNombre?.isNotEmpty ?? false)
                                        ? c.pasajeroNombre!.characters.first
                                              .toUpperCase()
                                        : 'P')
                                  : null,
                              avatarBg: const Color(0xFFFFF1E0),
                              timeText: c.createdAtShort,
                              distanceKm: c.distanciaKm ?? 0,
                              priceText: '',
                              title: c.aCalle ?? (c.aCiudad ?? 'Origen'),
                              subtitle: c.bCalle ?? (c.bTexto ?? 'Destino'),
                              isProgramado: false,
                              scheduleDatesText: null,
                              scheduleTimeText: null,
                              headerBadges: [
                                HeaderBadgeButton(
                                  buttonIcon: Icons.remove_rounded,
                                  onPressed: puedeInteractuarPorTiempo
                                      ? c.decPrecio
                                      : null,
                                ),
                                HeaderPriceBadge(
                                  texto: c.fmtPrecio(c.precioEditable),
                                  onTap: puedeInteractuarPorTiempo
                                      ? () async {
                                          final nuevo =
                                              await showEditarPrecioDialog(
                                                context,
                                                valorInicial: c.precioEditable,
                                                moneda: 'ARS',
                                              );
                                          if (nuevo != null) {
                                            c.setPrecioEditable(nuevo);
                                          }
                                        }
                                      : null,
                                ),
                                HeaderBadgeButton(
                                  buttonIcon: Icons.add_rounded,
                                  onPressed: puedeInteractuarPorTiempo
                                      ? c.incPrecio
                                      : null,
                                ),
                              ],
                              belowPriceBadges: c.isProgramado
                                  ? const [
                                      RideBadge(
                                        text: 'Viaje programado',
                                        bg: Color(0xFFE0F2FE),
                                        fg: Color(0xFF1D4ED8),
                                        icon: Icons.event_available_rounded,
                                      ),
                                    ]
                                  : (c.etiqueta != null &&
                                        c.etiqueta!.isNotEmpty)
                                  ? const [
                                      RideBadge(
                                        text: 'Solicitud',
                                        bg: Color(0xFFE8F5E9),
                                        fg: Colors.green,
                                        icon: Icons.local_offer_rounded,
                                      ),
                                    ]
                                  : const [],
                            ),

                            if (!c.isProgramado && !c.ofertaFueEnviada)
                              Positioned(
                                right: 10,
                                top: 10,
                                child: CircularCountdown(
                                  secondsLeft: c.secondsLeft,
                                  progress: c.progress,
                                  phaseColor: c.phaseColor(),
                                  scale: c.scale,
                                ),
                              ),
                          ],
                        ),

                        if (c.isProgramado && (hasDates || hasTime)) ...[
                          const SizedBox(height: 10),
                          ProgramadoMinimalBlock(
                            scheduleDatesText: schedDates,
                            scheduleTimeText: schedTime,
                          ),
                        ],

                        const SizedBox(height: 12),

                        if (offerDocStream != null)
                          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: offerDocStream,
                            builder: (context, snap) {
                              String estado = 'no_enviada';
                              if (snap.hasData && snap.data!.exists) {
                                final d = snap.data!.data();
                                if (d != null) {
                                  estado = (d['estado'] ?? 'pendiente')
                                      .toString();
                                }
                              }

                              // ✅ side-effects SOLO una vez, fuera del build loop
                              if (estado == 'pendiente' &&
                                  !_offerMarkedHandled) {
                                _offerMarkedHandled = true;
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (!mounted) return;
                                  c.marcarOfertaEnviada();
                                });
                              }

                              if (estado == 'aceptada' && !_acceptedHandled) {
                                _acceptedHandled = true;
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        '✅ ¡Tu oferta fue aceptada!',
                                      ),
                                    ),
                                  );
                                  Navigator.of(context).pop({
                                    'accion': 'oferta_aceptada',
                                    'precio': c.precioEditable,
                                  });
                                });
                              } else if ((estado == 'rechazada' ||
                                      estado == 'expirada') &&
                                  !_rejectedHandled) {
                                _rejectedHandled = true;
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        estado == 'rechazada'
                                            ? '❌ Tu oferta fue rechazada.'
                                            : '⏰ Tu oferta expiró.',
                                      ),
                                    ),
                                  );
                                });
                              }

                              Color bg = const Color(0xFFF3F4F6);
                              Color fg = Colors.black87;
                              IconData ic = Icons.hourglass_top_rounded;
                              String label =
                                  'Enviá una oferta para que el pasajero decida';

                              switch (estado) {
                                case 'pendiente':
                                  bg = const Color(0xFFE8F5E9);
                                  fg = Colors.green.shade800;
                                  ic = Icons.schedule_send_rounded;
                                  label =
                                      'Oferta enviada. Esperando respuesta del pasajero…';
                                  break;
                                case 'aceptada':
                                  bg = const Color(0xFFE6F4EA);
                                  fg = Colors.green.shade800;
                                  ic = Icons.check_circle_rounded;
                                  label =
                                      '¡Oferta aceptada! Preparando el viaje…';
                                  break;
                                case 'rechazada':
                                  bg = const Color(0xFFFFEBEE);
                                  fg = const Color(0xFFB71C1C);
                                  ic = Icons.cancel_rounded;
                                  label = 'El pasajero rechazó tu oferta.';
                                  break;
                                case 'expirada':
                                  bg = const Color(0xFFFFF3E0);
                                  fg = const Color(0xFFEF6C00);
                                  ic = Icons.timer_off_rounded;
                                  label = 'La oferta expiró.';
                                  break;
                                case 'no_enviada':
                                default:
                                  bg = const Color(0xFFF3F4F6);
                                  fg = Colors.black87;
                                  ic = Icons.info_outline_rounded;
                                  label =
                                      'Enviá una oferta para que el pasajero decida';
                              }

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: bg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(ic, color: fg),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        label,
                                        style: TextStyle(
                                          color: fg,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                        const SizedBox(height: 16),

                        Builder(
                          builder: (context) {
                            final bool mismoPrecioLocal = c.eq2(
                              c.precioEditable,
                              (c.precio ?? 0),
                            );
                            final bool canInteractByTime =
                                puedeInteractuarPorTiempo;

                            return ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              onPressed: canInteractByTime
                                  ? () async {
                                      try {
                                        await c.enviarOfertaTaxista(
                                          esAceptacion: mismoPrecioLocal,
                                          distanciaRecogidaKm: null,
                                        );
                                        if (!mounted) return;

                                        Navigator.of(
                                          context,
                                        ).pop({'accion': 'oferta_enviada'});

                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              mismoPrecioLocal
                                                  ? 'Oferta enviada al pasajero por ARS ${c.fmtPrecioPlano(c.precioEditable)}'
                                                  : 'Oferta enviada al pasajero por ARS ${c.fmtPrecioPlano(c.precioEditable)}',
                                            ),
                                          ),
                                        );
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Error al enviar oferta: $e',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  : null,
                              child: Text(
                                (mismoPrecioLocal
                                        ? 'Aceptar por ARS '
                                        : 'Hacer oferta por ARS ') +
                                    c.fmtPrecioPlano(c.precioEditable),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 12),

                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF3F4F6),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () =>
                              Navigator.of(context).pop({'accion': 'omitir'}),
                          child: const Text(
                            'Omitir',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
