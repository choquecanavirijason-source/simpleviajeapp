import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:buses2/shared/widgets/ofertas/oferta_card.dart';

/// Construye una tarjeta de oferta a partir de un DocumentSnapshot.
/// Devuelve un [Widget] listo para insertar en listas.
Widget buildOfferCardFromDoc({
  required BuildContext context,
  required DocumentSnapshot ofertaDoc,

  /// ruta de la orden: 'ordenesPasajeros/{uid}/ordenes/{id}'
  required String ordenPath,
  required bool esProgramado,
  required void Function({
    required BuildContext context,
    required String ordenPath,
    required String ofertaId,
    required String precio,
  })
  onAccept,

  /// Opcional: callback para rechazar una oferta. Si se provee, la card
  /// mostrará un botón "Rechazar" junto al de "Aceptar".
  void Function({
    required BuildContext context,
    required String ordenPath,
    required String ofertaId,
  })?
  onReject,
}) {
  final ofertaData = ofertaDoc.data() as Map<String, dynamic>? ?? {};

  final nombre = ofertaData['nombre']?.toString() ?? 'Conductor';
  final fotoUrl = ofertaData['foto']?.toString() ?? '';
  final precioNum =
      ofertaData['precioOfertado'] ??
      ofertaData['precioOfrecido'] ??
      ofertaData['precioRecomendado'] ??
      0;
  final precioStr = (precioNum is num)
      ? precioNum.toString()
      : precioNum.toString();
  final estrellas = (ofertaData['estrellas'] is num)
      ? (ofertaData['estrellas'] as num).toDouble()
      : 5.0;
  final detallesVehiculo =
      '${ofertaData['marcaVehiculo'] ?? ''} ${ofertaData['modeloVehiculo'] ?? ''}'
          .trim();
  final placa = ofertaData['placaVehiculo']?.toString() ?? '';
  final colorVehiculo = ofertaData['colorVehiculo']?.toString() ?? '';
  final telefono = ofertaData['telefonoTaxista']?.toString() ?? '';

  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: OfertaCard(
      nombre: nombre,
      fotoUrl: fotoUrl,
      precioBs: precioStr,
      estrellas: estrellas,
      detallesVehiculo: detallesVehiculo,
      placa: placa,
      colorVehiculo: colorVehiculo,
      telefono: telefono,
      mostrarBadgeProgramado: esProgramado,
      onAccept: () => onAccept(
        context: context,
        ordenPath: ordenPath,
        ofertaId: ofertaDoc.id,
        precio: precioStr,
      ),
      onReject: onReject == null
          ? null
          : () => onReject(
              context: context,
              ordenPath: ordenPath,
              ofertaId: ofertaDoc.id,
            ),
    ),
  );
}
