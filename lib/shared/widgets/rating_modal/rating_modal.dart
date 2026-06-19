import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RatingModal extends StatefulWidget {
  final String rutaDoc;
  final String idUsuarioOrigen; // Quien califica (ej. Pasajero)
  final String idUsuarioDestino; // A quien califican (ej. Taxista)
  final String
  rolDestino; // 'taxista' o 'pasajero' (Define la colección a usar)

  const RatingModal({
    super.key,
    required this.rutaDoc,
    required this.idUsuarioOrigen,
    required this.idUsuarioDestino,
    required this.rolDestino, // IMPORTANTE: Debe ser 'taxista' o 'pasajero'
  });

  @override
  State<RatingModal> createState() => _RatingModalState();
}

class _RatingModalState extends State<RatingModal> {
  int _rating = 5;
  // String _comment = '';
  bool _isLoading = false;

  Future<void> _submitRating() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;

      // 1. Definir la colección según el rol del destinatario
      // Si califico a un taxista -> colección 'taxistas'
      // Si califico a un pasajero -> colección 'pasajeros'
      final String collectionName = widget.rolDestino.toLowerCase() == 'taxista'
          ? 'taxistas'
          : 'pasajeros';
      print('Collection to update: $collectionName');

      final userRef = firestore
          .collection(collectionName)
          .doc(widget.idUsuarioDestino);

      // 2. Ejecutar Transacción (Seguridad total de datos)
      await firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);

        if (!userDoc.exists) {
          throw Exception(
            "El usuario a calificar no existe en la colección $collectionName",
          );
        }

        // 3. Obtener datos actuales (o iniciar en 0 si es la primera vez)
        final data = userDoc.data()!;
        print('Current user data: $data');
        final int currentTotal = data['totalPuntuacion'] ?? 0;
        final int currentCount = data['numeroResenias'] ?? 0;

        // 4. Calcular nuevos valores
        final int newTotal = currentTotal + _rating;
        final int newCount = currentCount + 1;
        final double newAverage = newTotal / newCount;

        // 5. Crear el documento de la reseña individual (Historial)
        // Esto es útil para mostrar "Qué dicen de ti" en el futuro
        final resenaRef = firestore.collection('resenias').doc();
        transaction.set(resenaRef, {
          'rutaDoc': widget.rutaDoc,
          'idOrigen': widget.idUsuarioOrigen,
          'idDestino': widget.idUsuarioDestino,
          'collectionDestino':
              collectionName, // Para saber a qué tipo de usuario se calificó
          'puntuacion': _rating,
          // 'comentario': _comment,
          'fecha': FieldValue.serverTimestamp(),
        });

        // 6. Actualizar el perfil del usuario (Taxista o Pasajero)
        transaction.update(userRef, {
          'totalPuntuacion': newTotal,
          'numeroResenias': newCount,
          'promedioEstrellas': double.parse(
            newAverage.toStringAsFixed(2),
          ), // Redondeo a 2 decimales
        });
      });

      if (mounted) Navigator.pop(context, true); // Retorna true si fue exitoso
    } catch (e) {
      debugPrint('Error al calificar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar la calificación: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (El diseño visual del modal es el mismo que vimos antes con las estrellas)
    return AlertDialog(
      title: Text('Califica a tu ${widget.rolDestino.toLowerCase()}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('¿Cómo estuvo el viaje?'),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < _rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 40,
                ),
                onPressed: () => setState(() => _rating = index + 1),
              );
            }),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Omitir'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitRating,
          child: _isLoading
              ? const CircularProgressIndicator()
              : const Text('Enviar'),
        ),
      ],
    );
  }
}
