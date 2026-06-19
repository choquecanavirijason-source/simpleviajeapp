import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:buses2/core/services/mapa/mapbox/mapa_widget.dart';
import 'package:buses2/core/services/mapa/mapbox/taxistas_markers_manager.dart'
    show TaxistaMarkerData;
import 'package:buses2/features/mapa_destino/data/estado_orden.dart'; // actualizarEstadoOrden(...)
import 'package:buses2/shared/widgets/botones/boton.dart';
import 'package:buses2/features/mapa_destino/widgets/modalpaso1_titulo_pill.dart';
import 'package:buses2/shared/widgets/modal_inferior/modal_inferior2.dart';
// import 'package:buses2/shared/widgets/ofertas/oferta_card.dart'; // Ya incluido en oferta_builder
import 'package:buses2/shared/widgets/ofertas/oferta_builder.dart';

// DocGet util para lecturas puntuales
import 'package:buses2/shared/services/save_traer_firebase/lecturas/docGet.dart';
import 'package:buses2/features/chats/data/repositories/chat_repository.dart';
import 'package:buses2/features/chats/service/firestore_profiles.dart';
// import 'package:buses2/features/home/services/trip_service.dart'; // No usado explícitamente en el código original pero lo dejo si lo necesitas
// import 'package:buses2/shared/services/chat_listener_service.dart';

class ViajeSolicitadoPage extends StatefulWidget {
  const ViajeSolicitadoPage({super.key});

  @override
  State<ViajeSolicitadoPage> createState() => _ViajeSolicitadoPageState();
}

class _ViajeSolicitadoPageState extends State<ViajeSolicitadoPage> {
  // ========= Args =========
  String? _idViaje;
  String? _uidPasajero;
  String? _rutaDoc;

  double? puntoALat;
  double? puntoALng;
  bool esProgramado = false;

  // ========= Tarifa/UI =========
  String _servicio = 'taxi';
  double _sugerido = 0.0;
  double _ofrecido = 0.0;
  String _estadoViaje = 'pedido';
  static const double _step = 1.0;

  // ========= Control de estado =========
  bool _isSubmittingOffer = false; // Evitar múltiples clicks
  bool _cancelling = false;

  // ========= Sheets =========
  final DraggableScrollableController _sheetMainCtrl =
      DraggableScrollableController();
  // 50% inicial → deja la mitad superior del mapa visible.
  // El usuario puede arrastrar hasta 96% para ver todo el contenido.
  static const double _sheetMainInitial = 0.50;
  double _sheetMainMin = 0.18;
  static const double _sheetMainMax = 0.96;

  final DraggableScrollableController _sheetCancelCtrl =
      DraggableScrollableController();
  bool _showCancel = false;
  static const double _sheetCancelTarget = 0.44;

  // ========= Mapa + markers de taxistas que ofertaron =========
  MapaController? _mapCtrl;

  // Stream de ofertas (pendientes) para saber qué taxistas mostrar.
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ofertasMarkersSub;

  // Para cada taxista que ofertó, una suscripción a su presencia RTDB.
  final Map<String, StreamSubscription<DatabaseEvent>> _presenceSubs = {};

  // Estado actual de markers (uid → datos).
  final Map<String, TaxistaMarkerData> _markersByUid = {};

  @override
  void initState() {
    super.initState();
    final args = Modular.args.data as Map<String, dynamic>?;

    _idViaje = args?['idViaje']?.toString();
    _uidPasajero = args?['uidPasajero']?.toString();
    _rutaDoc = args?['rutaDoc']?.toString();

    puntoALat = (args?['puntoALat'] as num?)?.toDouble();
    puntoALng = (args?['puntoALng'] as num?)?.toDouble();
    esProgramado = (args?['esProgramado'] as bool?) ?? false;

    _servicio = (args?['servicio']?.toString() ?? _servicio);
    if (args?['sugerido'] is num) {
      _sugerido = (args!['sugerido'] as num).toDouble();
    }
    if (args?['ofrecido'] is num) {
      _ofrecido = (args!['ofrecido'] as num).toDouble();
    }

    _ensureRutaDoc();

    if (kDebugMode) {
      debugPrint(
        '📄 ViajeSolicitado init -> id=$_idViaje uidPasajero=$_uidPasajero rutaDoc=$_rutaDoc servicio=$_servicio sugerido=$_sugerido ofrecido=$_ofrecido',
      );
    }

    _cargarDesdeFirestoreSiHayRuta();
  }

  void _ensureRutaDoc() {
    final uid = (_uidPasajero != null && _uidPasajero!.isNotEmpty)
        ? _uidPasajero
        : FirebaseAuth.instance.currentUser?.uid;

    if ((_rutaDoc == null || _rutaDoc!.trim().isEmpty) &&
        (uid != null && uid.isNotEmpty) &&
        (_idViaje != null && _idViaje!.isNotEmpty)) {
      _rutaDoc = 'ordenesPasajeros/$uid/ordenes/${_idViaje!}';
    }
  }

  Future<void> _cargarDesdeFirestoreSiHayRuta() async {
    if (_rutaDoc == null || _rutaDoc!.trim().isEmpty) return;
    try {
      final res = await DocGet.documentosGet(rutas: [_rutaDoc!]);
      if (!mounted) return;
      final data = (res.isNotEmpty)
          ? (res.first['data'] as Map<String, dynamic>?)
          : null;
      if (data == null) return;

      final servicio = data['servicio']?.toString();
      final estado = data['estado']?.toString();
      final tarifa = (data['tarifa'] is Map)
          ? Map<String, dynamic>.from(data['tarifa'] as Map)
          : <String, dynamic>{};

      final total = tarifa['total'];
      final precioOfrecido =
          tarifa['precioOfertado'] ?? tarifa['precioOfrecido'];

      setState(() {
        if (servicio != null && servicio.trim().isNotEmpty) {
          _servicio = servicio;
        }
        if (estado != null && estado.trim().isNotEmpty) {
          _estadoViaje = estado;
        }
        if (total is num) _sugerido = total.toDouble();
        if (precioOfrecido is num) _ofrecido = precioOfrecido.toDouble();
      });
    } catch (e, st) {
      debugPrint('🟥 Error cargando doc $_rutaDoc: $e\n$st');
    }
  }

  // ========= Cancelar =========
  Future<void> _cancelarViaje() async {
    if (_cancelling) return;
    if (!mounted) return;
    setState(() => _cancelling = true);

    try {
      final ok = await actualizarEstadoOrden(
        programado: esProgramado,
        nuevoEstado: 'cancelado',
        motivo: 'pasajero',
      );

      debugPrint(
        ok ? '✅ Viaje cancelado exitosamente' : '⚠️ No se pudo cancelar',
      );

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e, st) {
      debugPrint('🟥 Error al cancelar viaje: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cancelar: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(milliseconds: 1500),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    }
  }

  Future<void> _mostrarModalCancelacion() async {
    if (_showCancel) return;
    setState(() => _sheetMainMin = 0.00);
    await WidgetsBinding.instance.endOfFrame;
    await _sheetMainCtrl.animateTo(
      0.00,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
    );

    if (!mounted) return;
    setState(() => _showCancel = true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sheetCancelCtrl
        ..jumpTo(0.00)
        ..animateTo(
          _sheetCancelTarget,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
    });
  }

  Future<void> _volverAlModalPrincipal() async {
    await _sheetCancelCtrl.animateTo(
      0.00,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
    );

    if (!mounted) return;
    setState(() => _showCancel = false);

    setState(() => _sheetMainMin = 0.25);
    await WidgetsBinding.instance.endOfFrame;
    await _sheetMainCtrl.animateTo(
      _sheetMainInitial,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  // ========= Oferta (subir/bajar y enviar) =========
  bool get _isDirty => (_ofrecido - _sugerido).abs() > 1e-6;
  void _dec() =>
      setState(() => _ofrecido = (_ofrecido - _step).clamp(0, 100000));
  void _inc() => setState(() => _ofrecido = (_ofrecido + _step));
  void _useSuggested() => setState(() => _ofrecido = _sugerido);

  Future<void> _submitOffer() async {
    // Protección contra doble envío
    if (_isSubmittingOffer) return;
    if (_rutaDoc == null || _rutaDoc!.trim().isEmpty) return;
    if (!mounted) return;

    setState(() => _isSubmittingOffer = true);

    try {
      final ref = FirebaseFirestore.instance.doc(_rutaDoc!);
      final nowTs = FieldValue.serverTimestamp();

      // Actualizar Orden Principal
      await ref.update({
        'tarifa.precioOfrecido': _ofrecido,
        'updatedAt': nowTs,
      });

      // Actualizar contraoferta en subcolección 'ofertas'
      try {
        final ofertasSnap = await ref
            .collection('ofertas')
            .where('estado', isEqualTo: 'pendiente')
            .get();

        for (final doc in ofertasSnap.docs) {
          await doc.reference.update({
            'tarifa.precioOfrecido': _ofrecido,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('🟥 Error sync ofertas: $e\n$st');
        }
      }

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      Future.delayed(const Duration(milliseconds: 200), () {
        try {
          final currentContext =
              Modular.routerDelegate.navigatorKey.currentContext;
          if (currentContext != null && currentContext.mounted) {
            ScaffoldMessenger.of(currentContext).showSnackBar(
              SnackBar(
                content: Row(
                  children: const [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '¡Nueva oferta enviada!',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF16A34A),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                duration: const Duration(milliseconds: 1500),
              ),
            );
          }
        } catch (_) {}
      });
    } catch (e) {
      if (!mounted) return;
      // Desbloquear botón si falla
      setState(() => _isSubmittingOffer = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar oferta: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Future<bool> _handleBack() async {
    if (_showCancel) {
      await _volverAlModalPrincipal();
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    _ofertasMarkersSub?.cancel();
    for (final s in _presenceSubs.values) {
      s.cancel();
    }
    _presenceSubs.clear();
    _markersByUid.clear();
    _sheetMainCtrl.dispose();
    _sheetCancelCtrl.dispose();
    super.dispose();
  }

  // ========= Markers de taxistas que ofertaron =========

  /// Arranca la escucha del stream de ofertas pendientes y, por cada taxista
  /// que oferta, mantiene un listener a su posición en RTDB para mostrarlo
  /// en el mapa. Llamar cuando `_mapCtrl` y `_rutaDoc` ya estén disponibles.
  void _iniciarMarkersOfertas() {
    if (_mapCtrl == null) return;
    if (_rutaDoc == null || _rutaDoc!.trim().isEmpty) return;
    if (_ofertasMarkersSub != null) return; // ya inició

    debugPrint('🟢 markers ofertas: suscribiendo a ofertas de $_rutaDoc');

    _ofertasMarkersSub = FirebaseFirestore.instance
        .doc(_rutaDoc!)
        .collection('ofertas')
        .where('estado', isEqualTo: 'pendiente')
        .snapshots()
        .listen((snap) {
      final uidsActivos = <String>{};

      for (final doc in snap.docs) {
        final data = doc.data();
        final uid =
            (data['uidTaxista'] ?? data['idTaxista'] ?? '').toString().trim();
        if (uid.isEmpty) continue;
        uidsActivos.add(uid);
        _engancharPresenceDelTaxista(uid);
      }

      // Cancelar listeners y markers de taxistas cuya oferta ya no está pendiente.
      final stale = _presenceSubs.keys
          .where((uid) => !uidsActivos.contains(uid))
          .toList();
      for (final uid in stale) {
        _presenceSubs[uid]?.cancel();
        _presenceSubs.remove(uid);
        _markersByUid.remove(uid);
      }

      _sincronizarMapa();
    }, onError: (e) {
      debugPrint('🟥 markers ofertas error: $e');
    });
  }

  /// Engancha un listener a la presencia RTDB de UN taxista (solo si no existe).
  void _engancharPresenceDelTaxista(String uid) {
    if (_presenceSubs.containsKey(uid)) return;

    final ref = FirebaseDatabase.instance.ref('taxistas_online/$uid');
    _presenceSubs[uid] = ref.onValue.listen((event) {
      final raw = event.snapshot.value;
      if (raw is Map) {
        final lat = (raw['lat'] as num?)?.toDouble();
        final lng = (raw['lng'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          _markersByUid[uid] = TaxistaMarkerData(
            uid: uid,
            lat: lat,
            lng: lng,
            servicio: raw['servicio']?.toString(),
          );
          _sincronizarMapa();
        }
      } else {
        // El taxista se desconectó (estado != libre) → ocultar su marker.
        if (_markersByUid.remove(uid) != null) {
          _sincronizarMapa();
        }
      }
    }, onError: (e) {
      debugPrint('🟥 presence $uid error: $e');
    });
  }

  Future<void> _sincronizarMapa() async {
    final ctrl = _mapCtrl;
    if (ctrl == null) return;
    await ctrl.sincronizarTaxistas(_markersByUid.values.toList());
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBack,
      child: Scaffold(
        body: Stack(
          children: [
            // MAPA
            MapaWidget(
              centerLat: puntoALat ?? -17.3895,
              centerLng: puntoALng ?? -66.1568,
              onMapReady: (c) {
                _mapCtrl = c;
                // Empezar a pintar markers de los taxistas que ofertaron.
                _iniciarMarkersOfertas();
              },
            ),

            // Botón back
            Positioned(
              top: 12,
              left: 12,
              child: SafeArea(
                child: Material(
                  color: Colors.white,
                  elevation: 2,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        Modular.to.navigate('/home/historial');
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Pill superior
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 45),
                child: Paso1TituloPill(texto: 'Buscando conductor cerca…'),
              ),
            ),

            // Sheet principal
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                child: ModalInferior2(
                  controller: _sheetMainCtrl,
                  initialChildSize: _sheetMainInitial,
                  minChildSize: _sheetMainMin,
                  maxChildSize: _sheetMainMax,
                  builder: (_, scroll) {
                    if (_rutaDoc == null || _rutaDoc!.isEmpty) {
                      return ListView(
                        controller: scroll,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                        children: [
                          _FareCardSolid(
                            idViaje: _idViaje,
                            servicio: _servicio,
                            sugerido: _sugerido,
                            ofrecido: _ofrecido,
                            isDirty: _isDirty,
                            isLoading: _isSubmittingOffer,
                            onMinus: _dec,
                            onPlus: _inc,
                            onUseSuggested: _useSuggested,
                            onSubmitOffer: _submitOffer,
                            estadoViaje: _estadoViaje,
                          ),
                          const SizedBox(height: 16),
                          // Usamos la versión Stateful para evitar reload
                          _OffersListRealtime(rutaDocOrden: _rutaDoc),
                          const SizedBox(height: 12),
                          Boton1(
                            label: _cancelling
                                ? 'Cancelando…'
                                : 'Cancelar viaje',
                            color: BotonColor.color3,
                            borde: BotonBorde.borde1,
                            onPressed: _cancelling
                                ? null
                                : _mostrarModalCancelacion,
                          ),
                        ],
                      );
                    }

                    // Stream principal de la ORDEN (para estado y precios)
                    return StreamBuilder<
                      DocumentSnapshot<Map<String, dynamic>>
                    >(
                      stream: FirebaseFirestore.instance
                          .doc(_rutaDoc!)
                          .snapshots(),
                      builder: (context, snap) {
                        String estadoActual = _estadoViaje;

                        if (snap.hasData && snap.data?.data() != null) {
                          final data = snap.data!.data()!;
                          final nuevoEstado =
                              data['estado']?.toString() ?? 'pedido';
                          final tarifa = (data['tarifa'] is Map)
                              ? Map<String, dynamic>.from(data['tarifa'] as Map)
                              : <String, dynamic>{};

                          final total = tarifa['total'];
                          final precioOfrecido =
                              tarifa['precioOfertado'] ??
                              tarifa['precioOfrecido'];

                          final needsUpdate =
                              _estadoViaje != nuevoEstado ||
                              (_sugerido != (total as num?)?.toDouble() &&
                                  total is num) ||
                              (!_isDirty &&
                                  _ofrecido !=
                                      (precioOfrecido as num?)?.toDouble() &&
                                  precioOfrecido is num);

                          if (needsUpdate) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted) return;
                              setState(() {
                                estadoActual = nuevoEstado;
                                _estadoViaje = nuevoEstado;
                                if (total is num) _sugerido = total.toDouble();
                                if (!_isDirty && precioOfrecido is num) {
                                  _ofrecido = precioOfrecido.toDouble();
                                }
                              });
                            });
                          } else {
                            estadoActual = nuevoEstado;
                          }
                        }

                        if (estadoActual == 'aceptado') {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                          });
                          return const SizedBox.shrink();
                        }

                        return ListView(
                          controller: scroll,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                          children: [
                            _FareCardSolid(
                              idViaje: _idViaje,
                              servicio: _servicio,
                              sugerido: _sugerido,
                              ofrecido: _ofrecido,
                              isDirty: _isDirty,
                              isLoading:
                                  _isSubmittingOffer, // Pasamos el loading
                              onMinus: _dec,
                              onPlus: _inc,
                              onUseSuggested: _useSuggested,
                              onSubmitOffer: _submitOffer,
                              estadoViaje: estadoActual,
                            ),

                            const SizedBox(height: 16),

                            // IMPORTANTE: Aquí se usa el widget Stateful.
                            // Al ser Stateful y tener el stream en initState,
                            // no se recarga cuando el padre hace setState.
                            _OffersListRealtime(
                              key: const ValueKey('offers-list-realtime'),
                              rutaDocOrden: _rutaDoc,
                            ),

                            const SizedBox(height: 12),

                            Boton1(
                              label: _cancelling
                                  ? 'Cancelando…'
                                  : 'Cancelar viaje',
                              color: BotonColor.color3,
                              borde: BotonBorde.borde1,
                              onPressed: _cancelling
                                  ? null
                                  : _mostrarModalCancelacion,
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),

            // Sheet cancelar
            if (_showCancel)
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  top: false,
                  child: ModalInferior2(
                    controller: _sheetCancelCtrl,
                    initialChildSize: 0.00,
                    minChildSize: 0.00,
                    maxChildSize: 0.42,
                    builder: (context, scroll) {
                      final tt = Theme.of(context).textTheme;
                      final cs = Theme.of(context).colorScheme;
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: cs.error,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.warning_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '¿Cancelar el viaje?',
                                  style: tt.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Se notificará a los conductores y puede afectar tu calificación.',
                            style: tt.bodySmall?.copyWith(
                              color: tt.bodySmall?.color?.withOpacity(.75),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _volverAlModalPrincipal,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text('Volver'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _cancelling
                                      ? null
                                      : _cancelarViaje,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    backgroundColor: cs.error,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    _cancelling ? 'Cancelando…' : 'Cancelar',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ==========================
// Tarifa (UI) + botón "Hacer oferta"
// ==========================

class _FareCardSolid extends StatelessWidget {
  const _FareCardSolid({
    required this.idViaje,
    required this.servicio,
    required this.sugerido,
    required this.ofrecido,
    required this.isDirty,
    required this.isLoading, // Recibimos el estado de carga
    required this.onMinus,
    required this.onPlus,
    required this.onUseSuggested,
    this.onSubmitOffer,
    this.estadoViaje,
  });

  final String? idViaje;
  final String servicio;
  final double sugerido;
  final double ofrecido;
  final bool isDirty;
  final bool isLoading;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onUseSuggested;
  final VoidCallback? onSubmitOffer;
  final String? estadoViaje;

  static const kAccent = Color(0xFF22C55E);
  static const kAccentDark = Color(0xFF16A34A);
  static const kSoftBg = Color(0xFFF1F5F9);

  String _fmtDoubleFull(double v) => v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isOfferMode = isDirty;
    // Si está cargando, deshabilitamos la interacción
    final bool buttonsEnabled =
        (estadoViaje == null || estadoViaje == 'pedido') && !isLoading;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withOpacity(.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 8,
            decoration: const BoxDecoration(
              color: kAccent,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),

          if (idViaje != null && idViaje!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F3F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'ID: $idViaje',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    servicio.isEmpty ? 'taxi' : servicio,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: .2,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 10,
                  ),
                  decoration: BoxDecoration(
                    color: kSoftBg,
                    border: Border.all(color: kAccent.withOpacity(.35)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    estadoViaje == 'aceptado'
                        ? 'Total: ${_fmtDoubleFull(ofrecido)} Bs'
                        : 'Recomendado: ${_fmtDoubleFull(sugerido)} Bs',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: kAccentDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              children: [
                if (estadoViaje != null && estadoViaje!.isNotEmpty) ...[
                  Text(
                    estadoViaje == 'aceptado'
                        ? 'Total Acordado'
                        : 'Precio Ofrecido',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    _RoundIconBtn(
                      icon: Icons.remove_rounded,
                      onTap: buttonsEnabled ? onMinus : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: kAccent.withOpacity(.22),
                            width: 1.3,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              ofrecido.toStringAsFixed(1),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                height: 1.0,
                                letterSpacing: .2,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'ARS',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _RoundIconBtn(
                      icon: Icons.add_rounded,
                      onTap: buttonsEnabled ? onPlus : null,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (estadoViaje == null || estadoViaje == 'pedido') ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      // Bloqueamos si está cargando
                      onPressed: buttonsEnabled
                          ? (isOfferMode
                                ? (onSubmitOffer ?? () {})
                                : onUseSuggested)
                          : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: isOfferMode
                            ? kAccentDark
                            : Colors.white,
                        foregroundColor: isOfferMode
                            ? Colors.white
                            : Colors.black87,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isOfferMode ? kAccentDark : Colors.black12,
                          ),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isOfferMode ? 'Hacer oferta' : 'Usar sugerido',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: isOfferMode
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(Icons.info_outline, size: 16, color: kAccentDark),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Ajusta la tarifa según distancia, tiempo o demanda.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================
// OFERTAS en tiempo real + confirmación + aceptar (uidTaxista)
// REFACTORIZADO A STATEFUL PARA EVITAR REBUILDS/FLICKERING
// ==========================

class _OffersListRealtime extends StatefulWidget {
  const _OffersListRealtime({
    super.key, // Usar keys ayuda a la estabilidad del widget
    required this.rutaDocOrden,
  });

  final String? rutaDocOrden;

  @override
  State<_OffersListRealtime> createState() => _OffersListRealtimeState();
}

class _OffersListRealtimeState extends State<_OffersListRealtime> {
  // Guardamos el stream en una variable para no recrearlo en cada build
  late Stream<QuerySnapshot<Map<String, dynamic>>> _offersStream;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  void _initStream() {
    if (widget.rutaDocOrden != null && widget.rutaDocOrden!.trim().isNotEmpty) {
      _offersStream = FirebaseFirestore.instance
          .doc(widget.rutaDocOrden!)
          .collection('ofertas')
          .orderBy('createdAt', descending: true)
          .snapshots();
      _initialized = true;
    } else {
      _initialized = false;
    }
  }

  @override
  void didUpdateWidget(covariant _OffersListRealtime oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si la ruta cambia (raro en esta pantalla, pero posible), reiniciamos el stream
    if (widget.rutaDocOrden != oldWidget.rutaDocOrden) {
      _initStream();
    }
  }

  Future<bool?> _showConfirmDialog(
    BuildContext context, {
    required String precioTexto,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar'),
        content: Text('¿Estás seguro de aceptar por: $precioTexto Bs?'),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop(true);
              Modular.to.pushNamedAndRemoveUntil('/home', (route) => false);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Modular.to.navigate('/home/historial');
              });
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndAccept(
    BuildContext context, {
    required String ofertaId,
    required String precioTexto,
  }) async {
    final ok = await _showConfirmDialog(context, precioTexto: precioTexto);
    if (ok == true) {
      await _aceptarOfertaTx(context, ofertaId: ofertaId);
    }
  }

  Future<void> _aceptarOfertaTx(
    BuildContext context, {
    required String ofertaId,
  }) async {
    if (widget.rutaDocOrden == null || widget.rutaDocOrden!.trim().isEmpty)
      return;

    final db = FirebaseFirestore.instance;
    final ordenRef = db.doc(widget.rutaDocOrden!);
    final ofertaRef = ordenRef.collection('ofertas').doc(ofertaId);

    String? uidTaxistaFromOffer;
    try {
      await db.runTransaction((tx) async {
        final ofertaSnap = await tx.get(ofertaRef);
        if (!ofertaSnap.exists) {
          throw 'La oferta ya no existe.';
        }
        final data = ofertaSnap.data() as Map<String, dynamic>;
        final estado = (data['estado'] ?? '').toString();
        if (estado != 'pendiente') return;

        final uidTaxista = (data['uidTaxista'] ?? data['idTaxista'] ?? '')
            .toString();
        uidTaxistaFromOffer = uidTaxista;

        final precioOfertadoNum =
            data['precioOfertado'] ??
            data['precioOfrecido'] ??
            data['precioRecomendado'];
        final precioOfertado = (precioOfertadoNum is num)
            ? precioOfertadoNum.toDouble()
            : null;

        tx.update(ofertaRef, {
          'estado': 'aceptado',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final updates = <String, dynamic>{
          'estado': 'aceptado',
          'uidTaxista': uidTaxista,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (precioOfertado != null) {
          updates['tarifa.total'] = precioOfertado;
          updates['tarifa.precioOfertado'] = precioOfertado;
        }

        tx.update(ordenRef, updates);

        try {
          final uidTaxista = uidTaxistaFromOffer;
          String? uidPasajero;
          try {
            final parts = widget.rutaDocOrden?.split('/') ?? [];
            if (parts.length >= 2 && parts[1].isNotEmpty) {
              uidPasajero = parts[1];
            }
          } catch (_) {}
          uidPasajero ??= FirebaseAuth.instance.currentUser?.uid;

          if (uidTaxista != null &&
              uidTaxista.isNotEmpty &&
              uidPasajero != null &&
              uidPasajero.isNotEmpty) {
            String pasajeroNombre = 'Pasajero';
            String pasajeroPhotoUrl = '';
            try {
              final p = await getPassengerPublic(uidPasajero);
              pasajeroNombre = p['name'] ?? pasajeroNombre;
              pasajeroPhotoUrl = p['photoUrl'] ?? pasajeroPhotoUrl;
            } catch (_) {}

            String taxistaNombre = data['nombre']?.toString() ?? 'Conductor';
            String taxistaPhotoUrl = data['foto']?.toString() ?? '';

            final chatId = await ChatRepository().createChat(
              uidTaxista,
              uidPasajero,
              taxistaNombre,
              pasajeroNombre,
              taxistaPhotoUrl,
              pasajeroPhotoUrl,
            );
            if (chatId != null) {
              try {
                await ordenRef.set({'chatId': chatId}, SetOptions(merge: true));
              } catch (_) {}
            }
            Modular.to.navigate('/home/historial');
          }
        } catch (e) {
          if (kDebugMode)
            debugPrint('Error creando chat tras aceptar oferta: $e');
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Oferta aceptada')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo aceptar: $e')));
      }
    }
  }

  /// Marca una oferta como `'rechazada'` para que desaparezca de la lista.
  /// No bloquea otras ofertas del mismo viaje ni cancela la orden — solo
  /// descarta visualmente esa oferta específica.
  Future<void> _rechazarOferta(
    BuildContext context, {
    required String ofertaId,
  }) async {
    if (widget.rutaDocOrden == null || widget.rutaDocOrden!.trim().isEmpty) {
      return;
    }

    final ofertaRef = FirebaseFirestore.instance
        .doc(widget.rutaDocOrden!)
        .collection('ofertas')
        .doc(ofertaId);

    try {
      await ofertaRef.update({
        'estado': 'rechazada',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Oferta rechazada'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo rechazar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_initialized) {
      return _infoBox(
        theme,
        const Row(
          children: [
            Icon(Icons.local_taxi_outlined, color: Colors.black45),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cargando ofertas…',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          ],
        ),
      );
    }

    // Usamos el Stream almacenado en initState
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _offersStream,
      builder: (context, snap) {
        Widget content;

        if (snap.connectionState == ConnectionState.waiting) {
          // Si es la primera vez (no hay datos previos), mostramos loader.
          // Pero como el stream está en initState, generalmente mantiene los datos si solo se repinta.
          content = Row(
            children: const [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cargando ofertas en tiempo real…',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            ],
          );
        } else if (snap.hasError) {
          content = Text(
            'Error leyendo ofertas: ${snap.error}',
            style: const TextStyle(color: Colors.green),
          );
        } else {
          final docs = snap.data?.docs ?? const [];
          if (docs.isEmpty) {
            content = Row(
              children: const [
                Icon(Icons.local_taxi_outlined, color: Colors.black45),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Aún no hay ofertas. Te avisaremos en cuanto lleguen.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              ],
            );
          } else {
            final items = docs.map((d) {
              return buildOfferCardFromDoc(
                context: context,
                ofertaDoc: d,
                ordenPath: widget.rutaDocOrden ?? '',
                esProgramado:
                    (widget.rutaDocOrden?.contains('ordenesProgramados') ??
                    false),
                onAccept:
                    ({
                      required BuildContext context,
                      required String ordenPath,
                      required String ofertaId,
                      required String precio,
                    }) {
                      _confirmAndAccept(
                        context,
                        ofertaId: ofertaId,
                        precioTexto: precio,
                      );
                    },
              );
            }).toList();

            content = Column(
              children: [
                for (final w in items) ...[w, const SizedBox(height: 10)],
              ],
            );
          }
        }

        return _infoBox(theme, content);
      },
    );
  }

  Widget _infoBox(ThemeData theme, Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.local_offer_rounded,
                size: 18,
                color: Color(0xFF16A34A),
              ),
              SizedBox(width: 8),
              Text(
                'Ofertas de Conductores',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ==========================
// Botón redondo reutilizado
// ==========================

class _RoundIconBtn extends StatelessWidget {
  const _RoundIconBtn({
    required this.icon,
    this.onTap,
    this.bg = const Color(0xFFF1F5F9),
    this.border = const Color(0x22000000),
    this.fg = const Color(0xFF16A34A),
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color bg;
  final Color border;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Opacity(
        opacity: isDisabled ? 0.4 : 1.0,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Icon(icon, color: fg, size: 28),
        ),
      ),
    );
  }
}
