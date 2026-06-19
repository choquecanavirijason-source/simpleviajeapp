import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:buses2/features/chats/data/repositories/chat_repository.dart';

class TripService {
  final FirebaseFirestore _firestore;
  TripService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> cancelarViaje(
    String tripId,
    String canceladoPor,
    bool esProgramado,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final chatRepository = ChatRepository();

    if (uid == null) return;

    final coleccion = esProgramado ? 'ordenesProgramados' : 'ordenes';

    // Referencia al documento del pasajero
    final docRefPasajero = _firestore
        .collection('ordenesPasajeros')
        .doc(uid)
        .collection(coleccion)
        .doc(tripId);

    // Obtener datos del viaje antes de actualizar
    final snap = await docRefPasajero.get();
    final data = snap.data();

    if (!snap.exists || data == null) {
      throw Exception('Viaje no encontrado');
    }

    // Datos para actualización
    final updateData = {
      'estado': 'cancelado',
      'canceladoPor': canceladoPor,
      'canceladoEn': FieldValue.serverTimestamp(),
    };

    // Actualizar documento del pasajero
    await docRefPasajero.update(
      updateData,
    ); // Si hay taxista asignado, actualizar también su documento
    final uidTaxista = data['uidTaxista'] as String?;
    if (uidTaxista != null && uidTaxista.isNotEmpty) {
      try {
        final docRefTaxista = _firestore
            .collection('taxistas')
            .doc(uidTaxista)
            .collection(coleccion)
            .doc(tripId);

        // Verificar si existe el documento en la colección del taxista
        final taxistaSnap = await docRefTaxista.get();
        if (taxistaSnap.exists) {
          await docRefTaxista.update(updateData);
        }
      } catch (e) {
        print('⚠️ Error al actualizar documento del taxista: $e');
        // Continuar aunque falle la actualización del taxista
      }
    }

    // Eliminar chat asociado al viaje cancelado
    if (data.containsKey('chatId')) {
      final chatId = data['chatId'] as String?;
      if (chatId != null && chatId.isNotEmpty) {
        try {
          await chatRepository.cancelPreAcceptedTrip(chatId);
        } catch (e) {
          print('⚠️ Error al eliminar chat: $e');
        }
      }
    }
  }

  // obtener datos del taxista asignado a un viaje
  Future<Map<String, dynamic>?> obtenerTaxistaAsignado(
    String uidTaxista,
  ) async {
    final docRef = _firestore.collection('taxistas').doc(uidTaxista);
    final snap = await docRef.get();

    if (!snap.exists) return null;

    final data = snap.data();
    final Map<String, dynamic> dataResult = {
      ...(data?['perfilTaxista'] as Map<String, dynamic>? ?? {}),
      'promedioEstrellas': data?['promedioEstrellas'] ?? 5.0,
    };

    return dataResult;
  }
}
