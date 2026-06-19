// lib/core/services/doc_store/doc_store_service.dart
import 'package:flutter/foundation.dart';
import 'ports.dart';

class DocStoreService {
  final DocumentSaverPort saver;
  const DocStoreService(this.saver);

  Future<void> save({
    required String uid,
    required String docId,
    required Map<String, String> data,
    required Map<String, String?> files,
  }) async {
    await saver.save(uid: uid, docId: docId, data: data, files: files);
    debugPrint('[DocStoreService] Saved $uid/$docId');
  }
}
