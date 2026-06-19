import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:buses2/shared/widgets/rating_modal/rating_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Importa tus modelos y servicios...

class TripStatusWatcher extends StatefulWidget {
  final Widget child;
  const TripStatusWatcher({super.key, required this.child});

  @override
  State<TripStatusWatcher> createState() => _TripStatusWatcherState();
}

class _TripStatusWatcherState extends State<TripStatusWatcher> {
  bool _isModalOpen = false;
  final Set<String> _ratingShown = {}; // Para evitar mostrar múltiples veces
  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _setupListener();
  }

  void _setupListener() {
    print('TripStatusWatcher: Configurando escuchas de estado de viaje...');
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final db = FirebaseFirestore.instance;

    print('TripStatusWatcher: Usuario actual UID: $uid');

    // --- 1. ESCUCHA DE ÓRDENES NORMALES ---
    final subNormales = db
        .collection('ordenesPasajeros/$uid/ordenes')
        .where('estado', isEqualTo: 'completado')
        .limit(10)
        .orderBy('estado')
        .snapshots()
        .listen((snapshot) {
          print('Change type: ${snapshot.docChanges.map((e) => e.type)}');
          _processSnapshot(snapshot, isProgramado: false);
        });

    _subscriptions.add(subNormales); // Guardamos la suscripción

    // --- 2. ESCUCHA DE ÓRDENES PROGRAMADAS (que también tienen estado) ---
    final subProgramados = db
        .collection('ordenesPasajeros/$uid/ordenesProgramados')
        .where('estado', isEqualTo: 'completado')
        .limit(10)
        .orderBy('estado')
        .snapshots()
        .listen((snapshot) {
          print('Change type: ${snapshot.docChanges.map((e) => e.type)}');
          _processSnapshot(snapshot, isProgramado: true);
        });

    _subscriptions.add(subProgramados); // Guardamos la suscripción
  }

  void _processSnapshot(QuerySnapshot snapshot, {required bool isProgramado}) {
    print(
      'TripStatusWatcher: Procesando ${snapshot.docChanges.length} cambios en snapshot...',
    );

    for (var change in snapshot.docChanges) {
      final data = change.doc.data() as Map<String, dynamic>?;
      if (data == null) continue;
      final nuevoEstado = data['estado'] ?? '';

      // Si el documento aparece por primera vez en este estado (ADD)
      // Esto sucede cuando el estado pasa de 'pendiente' -> 'en_curso' o 'completado'
      if (change.type == DocumentChangeType.added) {
        print(
          'TripStatusWatcher: Documento ADDED (aparece en el filtro): ${change.doc.id}',
        );

        // Si el estado es COMPLETADO, lo tratamos como un cambio reciente (Cold Start)
        if (nuevoEstado == 'completado') {
          _checkAndOpenModalOnFinished(
            change.doc,
            data,
            isProgramado: isProgramado,
          );
        }
      }
      // Si el documento ya estaba en el filtro y acaba de cambiar de estado (MODIFIED)
      // Esto sucede cuando el estado pasa de 'en_curso' -> 'completado'
      else if (change.type == DocumentChangeType.modified) {
        print(
          'TripStatusWatcher: Documento MODIFIED (cambio de estado): ${change.doc.id}',
        );

        if (nuevoEstado == 'completado') {
          // En un MODIFIED, solo verificamos que no sea un cambio viejo.
          _checkAndOpenModalOnFinished(
            change.doc,
            data,
            isProgramado: isProgramado,
            requireRecentTimestamp: true,
          );
        }
      }
    }
  }

  void _checkAndOpenModalOnFinished(
    DocumentSnapshot doc,
    Map<String, dynamic> data, {
    required bool isProgramado,
    bool requireRecentTimestamp = false,
  }) {
    // Si se requiere un timestamp reciente (típicamente para MODIFIED)
    if (requireRecentTimestamp) {
      final updatedAt = data['updatedAt'] as Timestamp?;
      if (updatedAt != null) {
        final diff = DateTime.now().difference(updatedAt.toDate());
        // Aumentamos a 60 segundos por seguridad de latencia.
        if (diff.inSeconds.abs() > 60) {
          print("Ignorado (viejo): ${doc.id}");
          return;
        }
      }
    }
    // Si no se requiere timestamp (típicamente para ADDED en cold start),
    // podríamos verificar el 'finishedAt' para evitar modales muy viejos.
    else {
      final finishedAt = data['finishedAt'] as Timestamp?;
      if (finishedAt != null) {
        final diff = DateTime.now().difference(finishedAt.toDate());
        if (diff.inMinutes.abs() > 5) {
          // Por ejemplo, solo si se completó en los últimos 5 minutos
          print("Ignorado (demasiado viejo para Cold Start): ${doc.id}");
          return;
        }
      }
    }

    // Si pasa las validaciones...
    _gestionarAperturaModal(doc, isProgramado: isProgramado);
  }

  void _gestionarAperturaModal(
    DocumentSnapshot doc, {
    required bool isProgramado,
  }) async {
    final idViaje = doc.id;

    print(
      'TripStatusWatcher: Intentando abrir modal de calificación para viaje $idViaje...',
    );

    // Evitar duplicados en tiempo de ejecución
    if (_ratingShown.contains(idViaje)) return;

    // Verificar si ya estoy mostrando un modal actualmente
    if (_isModalOpen) return;

    _ratingShown.add(idViaje);
    _isModalOpen = true;

    // Extraer datos
    final data = doc.data() as Map<String, dynamic>;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final modo = await _resolveUserMode();

    if (!mounted) {
      // Si no está montado, salimos inmediatamente antes de usar el context.
      return;
    }

    final String destinoId = modo == 'pasajero'
        ? data['uidTaxista'] as String? ??
              '' // Usamos 'uidTaxista'
        : data['uidPasajero'] as String? ?? ''; // Usamos 'uidPasajero'
    print('TripStatusWatcher: Modo $modo, destinoId: $destinoId');
    if (destinoId.isEmpty) return; // Validación de seguridad

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => RatingModal(
        rutaDoc: data['rutaDoc'],
        idUsuarioOrigen: uid,
        idUsuarioDestino: modo == 'pasajero'
            ? data['uidTaxista']
            : data['uidPasajero'],
        rolDestino: modo == 'pasajero' ? 'taxista' : 'pasajero',
      ),
    );

    if (!mounted) return;
    _isModalOpen = false;
  }

  Future<String> _resolveUserMode() async {
    try {
      // Solo usar cache local: si existe 'modo' en SharedPreferences lo devolvemos,
      // si no, devolvemos 'pasajero' por defecto. No se hacen consultas a Firestore.
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('modo');
      if (cached != null && cached.isNotEmpty) {
        return cached.toLowerCase() == 'taxista' ? 'taxista' : 'pasajero';
      }
      return 'pasajero';
    } catch (e) {
      print('Error resolviendo modo de usuario: $e');
      return 'pasajero';
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void dispose() {
    // Cerramos todas las escuchas al destruir el widget para evitar fugas de memoria
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}
