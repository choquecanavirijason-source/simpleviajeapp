import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:buses2/features/home/data/trip.dart';
import 'package:buses2/features/home/widgets/historial_viajes/common.dart';
import 'package:buses2/features/home/widgets/historial_viajes/trips_list.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../services/historial_taxista_service.dart';
// import 'package:buses2/features/home_taxi_features/home_taxi/widgets/pedido_card_from_doc.dart';

/// Página de historial para TAXISTAS
class HistorialTaxistaPage extends StatefulWidget {
  final String? uidTaxista;
  const HistorialTaxistaPage({super.key, this.uidTaxista});

  @override
  State<HistorialTaxistaPage> createState() => _HistorialTaxistaPageState();
}

class _HistorialTaxistaPageState extends State<HistorialTaxistaPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _service = HistorialTaxistaService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // 2 tabs
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _isCompletado(TripStatus s) => s == TripStatus.completado;
  bool _isCancelado(TripStatus s) => s == TripStatus.cancelado;

  int _cmpFechaDesc(Trip a, Trip b) => b.fecha.compareTo(a.fecha);

  Future<void> _goToDetallesViaje(Trip trip) async {
    try {
      Map<String, dynamic>? datosPasajero;
      if (trip.uidPasajero != null && trip.uidPasajero!.isNotEmpty) {
        final docRef = FirebaseFirestore.instance
            .collection('pasajeros')
            .doc(trip.uidPasajero);
        final snap = await docRef.get();
        if (snap.exists) {
          datosPasajero = snap.data();
        }
      }

      if (!mounted) return;

      Modular.to.pushNamed(
        '/detalles-viaje-taxista',
        arguments: {
          'idViaje': trip.id,
          'origen': trip.origen,
          'destino': trip.destino,
          'fecha': trip.fecha,
          'distancia': trip.km,
          'total': trip.precio,
          'estado': trip.estado,
          'datosPasajero': datosPasajero,
        },
      );
    } catch (e) {
      _snack('Error al ver detalles: $e');
    }
  }

  void _snack(String m) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.uidTaxista ?? FirebaseAuth.instance.currentUser?.uid;

    if (uid == null || uid.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.history, size: 24),
              SizedBox(width: 8),
              Text('Historial'),
            ],
          ),
        ),
        body: const Center(child: Text('No hay sesión activa. Inicia sesión.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.history, size: 24),
            SizedBox(width: 8),
            Text('Historial'),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 2,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.green[700],
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Colors.green[700],
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: 'Completados'),
            Tab(text: 'Cancelados'),
          ],
        ),
      ),
      body: StreamBuilder<List<Trip>>(
        stream: _service.streamOrdenesTaxista(uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorState(
              msg: 'Error al cargar historial: ${snapshot.error}',
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allTrips = snapshot.data ?? [];

          final completados =
              allTrips.where((t) => _isCompletado(t.estado)).toList()
                ..sort(_cmpFechaDesc);
          final cancelados =
              allTrips.where((t) => _isCancelado(t.estado)).toList()
                ..sort(_cmpFechaDesc);

          return TabBarView(
            controller: _tabController,
            children: [
              TripsList(
                dataBuilder: () => completados,
                emptyTitle: 'No hay viajes completados',
                emptySubtitle: 'Tus viajes finalizados aparecerán aquí',
                onDetalle: _goToDetallesViaje,
              ),

              TripsList(
                dataBuilder: () => cancelados,
                emptyTitle: 'No hay viajes cancelados',
                emptySubtitle: 'Los viajes cancelados aparecerán aquí',
                onDetalle: _goToDetallesViaje,
              ),
            ],
          );
        },
      ),
    );
  }
}

// Se eliminó la pestaña "Programados activos" y su widget asociado.
