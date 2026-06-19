// lib/core/services/doc_store/firebase_adapter.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'ports.dart';

class FirebaseDocumentSaverAdapter implements DocumentSaverPort {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  FirebaseDocumentSaverAdapter({
    FirebaseFirestore? db,
    FirebaseStorage? storage,
  }) : _db = db ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  @override
  Future<void> save({
    required String uid,
    required String docId,
    required Map<String, String> data,
    required Map<String, String?> files,
  }) async {
    // 1) Subir archivos locales
    final urls = <String, String>{};
    for (final e in files.entries) {
      final keySan = safeKey(e.key);
      final val = e.value;
      if (val == null || val.isEmpty) continue;

      if (isUrl(val)) {
        urls[keySan] = val;
      } else {
        final f = File(val);
        if (!await f.exists()) continue;
        final ext = extFromPath(val);
        final ref = _storage.ref('users/$uid/docs/$docId/$keySan.$ext');
        await ref.putFile(
          f,
          SettableMetadata(contentType: contentTypeFromExt(ext)),
        );
        urls[keySan] = await ref.getDownloadURL();
      }
    }

    // 2) Guardar metadata + URLs en Firestore, reemplazando 'data' y 'files'
    final ref = _db.collection('users').doc(uid).collection('docs').doc(docId);

    await _db.runTransaction((txn) async {
      final snap = await txn.get(ref);
      final createdAtPrev =
          (snap.data() as Map<String, dynamic>?)?['createdAt'];

      // 2.a) borrar los mapas completos para evitar "fantasmas"
      txn.set(ref, {
        'data': FieldValue.delete(),
        'files': FieldValue.delete(),
      }, SetOptions(merge: true));

      // 2.b) escribir los nuevos valores
      txn.set(ref, {
        'data': data,
        'files': urls,
        'updatedAt': FieldValue.serverTimestamp(),
        if (createdAtPrev == null)
          'createdAt': FieldValue.serverTimestamp()
        else
          'createdAt': createdAtPrev,
      }, SetOptions(merge: true));
    });
  }
}
