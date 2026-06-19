// lib/core/services/data/firebase_documentos_data_source.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'recibir_docs.dart';

class FirebaseDocumentosDataSource implements DocumentosDataSource {
  @override
  Future<List<Map<String, dynamic>>> fetchDocumentos() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('crear-documentos')
        .where('activo', isEqualTo: true)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }
}
