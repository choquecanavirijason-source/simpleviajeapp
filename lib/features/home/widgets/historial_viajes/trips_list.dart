import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'
    as fb; // 👈 fallback de uidPasajero
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:buses2/features/home/data/trip.dart';
import 'trip_card.dart';
import 'common.dart';

class TripsList extends StatefulWidget {
  const TripsList({
    super.key,
    required this.dataBuilder,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.offersCountOf,
    this.onOfertas,
    this.onCancelar,
    this.onVerConductor,
    this.onVerRuta,
    this.onChatConductor,
    this.onDetalle,
  });

  final List<Trip> Function() dataBuilder;
  final String emptyTitle;
  final String emptySubtitle;

  final int Function(Trip)? offersCountOf;

  final void Function(Trip)? onOfertas;
  final void Function(Trip)? onCancelar;
  final void Function(Trip)? onVerConductor;
  final void Function(Trip)? onVerRuta;
  final void Function(Trip)? onChatConductor;
  final void Function(Trip)? onDetalle;

  @override
  State<TripsList> createState() => _TripsListState();
}

class _TripsListState extends State<TripsList> {
  Future<void> _fakeRefresh() async {
    await Future.delayed(const Duration(milliseconds: 650));
    setState(() {});
  }

  Future<void> _pushVerConductor(Trip trip) async {
    try {
      // 0) Asegurar rutaDoc (si falta, construirla con uidPasajero || auth.uid, y ordenId || trip.id)
      String? rutaDoc = (trip.rutaDoc != null && trip.rutaDoc!.isNotEmpty)
          ? trip.rutaDoc
          : _buildRutaDocFallback(trip);

      // 1) Enriquecer origen desde Firestore si tengo rutaDoc
      double? oLat = trip.origenLat;
      double? oLng = trip.origenLng;
      String? origenTexto = (trip.origen.trim().isNotEmpty)
          ? trip.origen
          : null;

      if ((oLat == null || oLng == null || origenTexto == null) &&
          rutaDoc != null &&
          rutaDoc.isNotEmpty) {
        try {
          final snap = await FirebaseFirestore.instance.doc(rutaDoc).get();
          if (snap.exists) {
            final d = snap.data() as Map<String, dynamic>? ?? {};
            oLat ??= _toDouble(
              _firstNonNull([
                _fromMap(d, ['origen', 'lat']),
                d['origenLat'],
                d['aLat'],
              ]),
            );
            oLng ??= _toDouble(
              _firstNonNull([
                _fromMap(d, ['origen', 'lng']),
                d['origenLng'],
                d['aLng'],
              ]),
            );
            origenTexto ??= _firstNonEmpty([
              _fromMap(d, ['origen', 'calle']),
              d['origenCalle'],
              d['origenTitulo'],
              d['aCalle'],
              d['aTitulo'],
            ]);
          }
        } catch (_) {
          /* no bloqueamos */
        }
      }

      // 2) Podemos navegar si: a) hay uidTaxista, o b) al menos hay rutaDoc (la page lo resuelve)
      final String? uidTaxista =
          (trip.uidTaxista != null && trip.uidTaxista!.isNotEmpty)
          ? trip.uidTaxista
          : null;

      if (uidTaxista == null && (rutaDoc == null || rutaDoc.isEmpty)) {
        _snack(
          'Faltan datos para abrir "Ver conductor": uidTaxista vacío y no se pudo construir rutaDoc.\n'
          'uidPasajero=${trip.uidPasajero} ordenId=${trip.ordenId}',
        );
        return;
      }

      await Modular.to.pushNamed(
        '/ver-conductor',
        arguments: {
          if (uidTaxista != null) 'uidTaxista': uidTaxista,
          if (uidTaxista != null) 'driverUid': uidTaxista, // compat
          if (oLat != null) 'origenLat': oLat,
          if (oLng != null) 'origenLng': oLng,
          if (rutaDoc != null && rutaDoc.isNotEmpty) 'rutaDoc': rutaDoc,
          if (origenTexto != null && origenTexto.isNotEmpty)
            'origenTexto': origenTexto,
        },
      );
    } catch (e) {
      _snack('Error al abrir Ver Conductor: $e');
    }
  }

  /// Fallback robusto para construir la ruta del doc:
  /// - uidPasajero: primero el del Trip, si no el usuario logueado
  /// - ordenId: primero el del Trip, si no el id del Trip (doc id)
  String? _buildRutaDocFallback(Trip t) {
    final uidP = (t.uidPasajero != null && t.uidPasajero!.isNotEmpty)
        ? t.uidPasajero
        : fb.FirebaseAuth.instance.currentUser?.uid; // 👈 fallback con auth

    final oid = (t.ordenId != null && t.ordenId!.isNotEmpty)
        ? t.ordenId
        : t.id; // 👈 usa trip.id

    if (uidP == null || uidP.isEmpty || oid == null || oid.isEmpty) return null;
    return 'ordenesPasajeros/$uidP/ordenes/$oid';
  }

  void _snack(String m) {
    final ms = ScaffoldMessenger.maybeOf(context);
    ms?.hideCurrentSnackBar();
    ms?.showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.dataBuilder();

    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.inbox_rounded,
        title: widget.emptyTitle,
        subtitle: widget.emptySubtitle,
        accent: const Color(0xFF37474F),
      );
    }

    return RefreshIndicator(
      onRefresh: _fakeRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, thickness: 8, color: Color(0xFFF7F7F7)),
        itemBuilder: (_, i) {
          final t = items[i];
          final ofertasCount = widget.offersCountOf?.call(t) ?? 0;

          // Animación escalonada de entrada
          return TweenAnimationBuilder<double>(
            duration: Duration(milliseconds: 300 + (i * 50)),
            tween: Tween(begin: 0.0, end: 1.0),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: Opacity(opacity: value, child: child),
              );
            },
            child: TripCard(
              trip: t,
              ofertasCount: ofertasCount,
              onOfertas: widget.onOfertas,
              onCancelar: widget.onCancelar,
              onVerConductor: widget.onVerConductor ?? _pushVerConductor,
              onVerRuta: widget.onVerRuta ?? _pushVerConductor,
              onChatConductor: widget.onChatConductor,
              onDetalle: widget.onDetalle,
            ),
          );
        },
      ),
    );
  }

  // ===== Helpers =====
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
}
