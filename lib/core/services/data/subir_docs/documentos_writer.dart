// lib/core/services/data/subir_docs/documentos_writer.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'subir_docs.dart';

abstract class DocumentosWriter {
  Future<void> save({
    required String uid,
    required String templateId,
    required Map<String, String> campos,
    required Map<String, File?> archivos,
  });

  Future<void> guardarDocumentoEnNube({
    required String uid,
    required String templateId,
    required Map<String, String> campos,
    required Map<String, String> archivos, // URLs de archivos
  });
}

class DocumentosWriterImpl implements DocumentosWriter {
  final SubirDocsDataSource ds;
  DocumentosWriterImpl(this.ds);

  @override
  Future<void> save({
    required String uid,
    required String templateId,
    required Map<String, String> campos,
    required Map<String, File?> archivos,
  }) async {
    final payload = <String, dynamic>{
      ...campos,
      'templateId': templateId, // <-- ¡Agrega esto!
    };

    for (final entry in archivos.entries) {
      final key = entry.key;
      final file = entry.value;
      if (file != null) {
        final url = await ds.subirArchivoUsuario(
          uid: uid,
          templateId: templateId,
          key: key,
          file: file,
        );
        payload['$key:url'] = url;
      }
    }

    await ds.guardarCamposUsuario(
      uid: uid,
      templateId: templateId,
      data: payload,
    );
  }

  @override
  Future<void> guardarDocumentoEnNube({
    required String uid,
    required String templateId,
    required Map<String, String> campos,
    required Map<String, String> archivos, // URLs de archivos
  }) async {
    final data = <String, dynamic>{
      ...campos,
      ...archivos,
      'updatedAt': FieldValue.serverTimestamp(),
      'templateId': templateId, // <-- ¡Esto es lo que necesitas!
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('documentos')
        .doc(templateId) // Usa el templateId como ID del documento
        .set(data, SetOptions(merge: true));
  }
}
