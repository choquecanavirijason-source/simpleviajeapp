// lib/core/services/data/subir_docs/firebase_subir_docs.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'subir_docs.dart';

class FirebaseSubirDocsDataSource implements SubirDocsDataSource {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  @override
  Future<void> guardarCamposUsuario({
    required String uid,
    required String templateId,
    required Map<String, dynamic> data,
  }) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('documentos')
        .doc(templateId)
        .set({
          ...data,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  @override
  Future<String> subirArchivoUsuario({
    required String uid,
    required String templateId,
    required String key,
    required File file,
  }) async {
    final ref = _storage.ref().child(
      'users/$uid/documentos/$templateId/$key.jpg',
    );
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }
}
