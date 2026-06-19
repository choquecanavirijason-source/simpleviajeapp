// lib/core/services/data/subir_docs/subir_docs.dart
import 'dart:io';

abstract class SubirDocsDataSource {
  Future<void> guardarCamposUsuario({
    required String uid,
    required String templateId,
    required Map<String, dynamic> data,
  });

  Future<String> subirArchivoUsuario({
    required String uid,
    required String templateId,
    required String key,
    required File file,
  });
}
