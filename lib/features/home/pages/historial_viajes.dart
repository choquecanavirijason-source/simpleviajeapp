import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:buses2/features/chats/data/repositories/chat_repository.dart';

import 'package:buses2/features/home/data/trip.dart'; // Trip + TripStatus
import 'package:buses2/features/home/widgets/historial_viajes/common.dart'; // ErrorState
import 'package:buses2/shared/widgets/rating_modal/rating_modal.dart';

import 'package:flutter_modular/flutter_modular.dart';
import '../services/historial_service.dart';
import '../services/trip_service.dart';
import '../widgets/historial_viajes/trips_list.dart';
import '../widgets/historial_viajes/dialog_cancel_trip.dart';

class HistorialViajesPage extends StatefulWidget {
  /// Si no se pasa, el uid se toma del usuario autenticado.
  final String? uidPasajero;
  const HistorialViajesPage({super.key, this.uidPasajero});

  @override
  State<HistorialViajesPage> createState() => _HistorialViajesPageState();
}

class _HistorialViajesPageState extends State<HistorialViajesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _service = HistorialService();
  final TripService _trip_service = TripService();
  final ChatRepository _chat_repository = ChatRepository();
  // Guarda el último estado conocido por id de viaje para detectar transiciones
  final Map<String, TripStatus> _prevEstados = {};
  // Evita mostrar varias veces el modal para el mismo viaje
  final Set<String> _ratingShown = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  /// Revisa la lista de viajes y muestra el modal de rating cuando un viaje
  /// cambie a estado `completado`. Se asegura de mostrarlo solo una vez por viaje.
  void _checkCompletados(List<Trip> allTrips) async {
    final uid =
        widget.uidPasajero ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    if (allTrips.isEmpty) return;

    // Determinar el viaje más reciente por fecha
    final tripsSorted = [...allTrips]
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    final mostRecent = tripsSorted.first;

    // Actualizar estados conocidos para todos (pero solo evaluamos el más reciente
    // para mostrar el modal). Esto mantiene _prevEstados sincronizado.
    for (final trip in allTrips) {
      _prevEstados[trip.id] = _prevEstados[trip.id] ?? trip.estado;
    }

    final prev = _prevEstados[mostRecent.id];

    // Sólo mostrar si ya teníamos un estado previo conocido (prev != null), y
    // este prev NO era completado, y ahora sí lo es. Evitamos así mostrar el modal
    // en la carga inicial si el viaje ya estaba completado.
    if (prev != null &&
        prev != TripStatus.completado &&
        mostRecent.estado == TripStatus.completado) {
      // Evitar mostrar más de una vez
      if (_ratingShown.contains(mostRecent.id)) {
        _prevEstados[mostRecent.id] = mostRecent.estado;
        return;
      }

      _ratingShown.add(mostRecent.id);
      _prevEstados[mostRecent.id] = mostRecent.estado;

      if (!mounted) return;

      // Construir ruta del documento según si es programado
      final rutaDoc = mostRecent.programado
          ? 'ordenesPasajeros/$uid/ordenesProgramados/${mostRecent.id}'
          : 'ordenesPasajeros/$uid/ordenes/${mostRecent.id}';

      // Si falta el id del taxista, omitimos (no hay a quién calificar)
      final idTaxista = mostRecent.uidTaxista ?? '';
      if (idTaxista.isEmpty) return;

      // Mostrar modal y esperar resultado (pero no es obligatorio usarlo)
      if (mounted) {
        await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (context) => RatingModal(
            rutaDoc: rutaDoc,
            idUsuarioOrigen: uid,
            idUsuarioDestino: idTaxista,
            rolDestino: 'taxista',
          ),
        );
      }
    } else {
      // Mantener actualizado el estado conocido (caso sin transición relevante)
      _prevEstados[mostRecent.id] = mostRecent.estado;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// ======= Helpers de clasificación/orden =======

  bool _isActivo(TripStatus s) =>
      s == TripStatus.pedido ||
      s == TripStatus.aceptado ||
      s == TripStatus.enCamino ||
      s == TripStatus.enLugar || // 👈 incluye EN LUGAR
      s == TripStatus.enCurso ||
      s == TripStatus.programado;

  bool _isCompletado(TripStatus s) => s == TripStatus.completado;

  bool _isCancelado(TripStatus s) => s == TripStatus.cancelado;

  int _cmpFechaDesc(Trip a, Trip b) => b.fecha.compareTo(a.fecha);

  /// Construye la lista del tab "Activos" con el orden requerido:
  /// pedido → aceptado → enCamino → enLugar → enCurso → programado
  List<Trip> _buildActivos(List<Trip> allTrips) {
    final activos = allTrips.where((t) => _isActivo(t.estado)).toList();

    final pedido = activos.where((t) => t.estado == TripStatus.pedido).toList()
      ..sort(_cmpFechaDesc);

    final aceptado =
        activos.where((t) => t.estado == TripStatus.aceptado).toList()
          ..sort(_cmpFechaDesc);

    final enCamino =
        activos.where((t) => t.estado == TripStatus.enCamino).toList()
          ..sort(_cmpFechaDesc);

    final enLugar =
        activos.where((t) => t.estado == TripStatus.enLugar).toList()
          ..sort(_cmpFechaDesc);

    final enCurso =
        activos.where((t) => t.estado == TripStatus.enCurso).toList()
          ..sort(_cmpFechaDesc);

    final programado =
        activos.where((t) => t.estado == TripStatus.programado).toList()
          ..sort(_cmpFechaDesc);

    return [
      ...pedido,
      ...aceptado,
      ...enCamino,
      ...enLugar, // 👈 aparece justo después de enCamino
      ...enCurso,
      ...programado,
    ];
  }

  // ===== Navegación a ViajeSolicitado con id y ruta del doc =====
  void _goToViajeSolicitado(Trip trip) {
    final uid =
        widget.uidPasajero ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    // Ruta exacta del documento en Firestore
    final rutaDoc = trip.programado
        ? 'ordenesPasajeros/$uid/ordenesProgramados/${trip.id}'
        : 'ordenesPasajeros/$uid/ordenes/${trip.id}';

    Modular.to.pushNamed(
      '/viaje-solicitado',
      arguments: {
        'idViaje': trip.id, // para mostrar el ID en la UI
        'ordenId': trip.id, // si tu pantalla lo espera con este nombre
        'rutaDoc': rutaDoc, // para que DocGet lea el doc correcto
        'esProgramado': trip.programado,
      },
    );
  }

  // ===== Cancelar viaje activo =====
  void _cancelarViaje(Trip trip) async {
    // final cs = Theme.of(context).colorScheme;
    // final tt = Theme.of(context).textTheme;
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => DialogCancelarViaje(
        onConfirmar: () => Navigator.of(context).pop(true),
        onVolver: () => Navigator.of(context).pop(false),
      ),
    );

    if (confirm == true) {
      try {
        await _trip_service.cancelarViaje(trip.id, 'pasajero', trip.programado);
        if (trip.chatId != null && trip.chatId!.isNotEmpty) {
          await _chat_repository.cancelPreAcceptedTrip(trip.chatId!);
        }

        if (mounted) {
          // Cambiar a la pestaña de cancelados después de cancelar
          _tabController.animateTo(2); // Índice 2 = pestaña "Cancelados"

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Viaje cancelado correctamente.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al cancelar el viaje: $e')),
          );
        }
      }
    }
  }

  // ===== Ver detalles del conductor =====
  void _verDetallesViaje(Trip trip) async {
    // al presionar en el boton ver detalle llama a esta funcion la cual debe navegar a una pagina con los detalles del viaje
    // los datos necesarios son id del viaje, estado, hora que pidio, origen, destinoo, distancia, total, pero quiero que hagas la logica para cambiar de pagina y pasarle los datos necesarios

    try {
      // 1) Extraemos datos necesarios
      String idViaje = trip.id;
      String origenViaje = trip.origen;
      String destinoViaje = trip.destino;
      DateTime fechaViajePedido = trip.fecha;
      double distanciaViaje = trip.km;
      double totalViaje = trip.precio;
      String estadoViaje = trip.estado == TripStatus.completado
          ? 'Completado'
          : 'Cancelado';
      Map<String, dynamic>? datosTaxista = await _trip_service
          .obtenerTaxistaAsignado(trip.uidTaxista ?? '');
      // 2) Navegamos a la pantalla de detalles
      Modular.to.pushNamed(
        '/home/detalles-viaje',
        arguments: {
          'idViaje': idViaje,
          'origen': origenViaje,
          'destino': destinoViaje,
          'fecha': fechaViajePedido,
          'distancia': distanciaViaje,
          'total': totalViaje,
          'estado': estadoViaje,
          'datosTaxista': datosTaxista,
        },
      );
    } catch (e) {
      // Manejo de errores
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al ver detalles: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid =
        widget.uidPasajero ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      return const ErrorState(
        msg: 'No hay sesión. Inicia sesión para ver tu historial.',
      );
    }

    final sNormales = _service.streamOrdenesNormales(uid);
    final sProgramados = _service.streamOrdenesProgramados(uid);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          title: const Text(
            'Mis viajes',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF2E7D32),
            labelColor: const Color(0xFF1B5E20),
            unselectedLabelColor: const Color(0xFF66BB6A),
            indicatorWeight: 3,
            indicatorPadding: const EdgeInsets.symmetric(horizontal: 16),
            labelStyle: const TextStyle(fontWeight: FontWeight.w800),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
            tabs: const [
              Tab(icon: Icon(Icons.local_taxi_rounded), text: 'Activos'),
              Tab(icon: Icon(Icons.check_circle_rounded), text: 'Completados'),
              Tab(icon: Icon(Icons.cancel_rounded), text: 'Cancelados'),
            ],
          ),
        ),
        body: StreamBuilder<List<Trip>>(
          stream: sNormales,
          builder: (context, snap1) {
            if (snap1.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap1.hasError) {
              return ErrorState(msg: 'Error leyendo viajes: ${snap1.error}');
            }
            final normales = snap1.data ?? const <Trip>[];

            return StreamBuilder<List<Trip>>(
              stream: sProgramados,
              builder: (context, snap2) {
                if (snap2.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap2.hasError) {
                  return ErrorState(
                    msg: 'Error leyendo programados: ${snap2.error}',
                  );
                }
                final programados = snap2.data ?? const <Trip>[];

                // Merge de ambos streams (normales + programados)
                final allTrips = <Trip>[...normales, ...programados];

                // Ejecutar la comprobación después del frame para no mostrar
                // diálogos durante el build.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _checkCompletados(allTrips);
                });

                return TabBarView(
                  controller: _tabController,
                  children: [
                    // ===== Activos (orden personalizado) =====
                    TripsList(
                      dataBuilder: () => _buildActivos(allTrips),
                      emptyTitle: 'No tienes viajes activos',
                      emptySubtitle:
                          'Cuando tengas solicitudes o viajes en curso aparecerán aquí.',
                      onOfertas: _goToViajeSolicitado, // <- aquí navega
                      onCancelar: _cancelarViaje,
                    ),

                    // ===== Completados =====
                    TripsList(
                      dataBuilder: () =>
                          [...allTrips.where((t) => _isCompletado(t.estado))]
                            ..sort(_cmpFechaDesc),
                      emptyTitle: 'Aún no hay viajes completados',
                      emptySubtitle:
                          'Cuando finalices un viaje, lo verás en este listado.',
                      onOfertas: _goToViajeSolicitado,
                      onDetalle: _verDetallesViaje,
                    ),

                    // ===== Cancelados =====
                    TripsList(
                      dataBuilder: () =>
                          [...allTrips.where((t) => _isCancelado(t.estado))]
                            ..sort(_cmpFechaDesc),
                      emptyTitle: 'Sin viajes cancelados',
                      emptySubtitle:
                          'Si cancelas o rechazas un viaje, aparecerá aquí para referencia.',
                      onOfertas: _goToViajeSolicitado,
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
