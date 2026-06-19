import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

/// Estructura estándar que usamos para doc guardado/traído
typedef StoredDocPayload = Map<String, Map<String, dynamic>>;

/// => { 'data': <String,dynamic>, 'files': <String,dynamic> }

/// Origen de los datos
enum DocSource { local, remote, localFallback }

/// Resultado que incluye payload + origen
class DocFetchResult {
  final StoredDocPayload payload;
  final DocSource source;
  const DocFetchResult(this.payload, this.source);
}

class DocStoreCache {
  Future<String> _baseDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'doc_store_cache');
  }

  Future<File> _fileFor(String uid, String docId) async {
    final base = await _baseDir();
    final fDir = p.join(base, uid, 'docs');
    await Directory(fDir).create(recursive: true);
    return File(p.join(fDir, '$docId.json'));
  }

  /// Lee del caché local. Devuelve {} si no existe.
  Future<StoredDocPayload> readLocal({
    required String uid,
    required String docId,
  }) async {
    try {
      final file = await _fileFor(uid, docId);
      if (!await file.exists()) {
        return {'data': <String, dynamic>{}, 'files': <String, dynamic>{}};
      }
      final raw = await file.readAsString();
      final m = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return {
        'data':
            (m['data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
        'files':
            (m['files'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{},
      };
    } catch (_) {
      return {'data': <String, dynamic>{}, 'files': <String, dynamic>{}};
    }
  }

  /// Escribe el caché local.
  Future<void> writeLocal({
    required String uid,
    required String docId,
    required StoredDocPayload doc,
  }) async {
    final file = await _fileFor(uid, docId);
    final payload = jsonEncode({
      'data': doc['data'] ?? <String, dynamic>{},
      'files': doc['files'] ?? <String, dynamic>{},
      'updatedAt': DateTime.now().toIso8601String(),
    });
    await file.writeAsString(payload, flush: true);
  }

  /// Limpia el caché de un doc.
  Future<void> clear({required String uid, required String docId}) async {
    final file = await _fileFor(uid, docId);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Igual que `fetchAndCache`, pero además devuelve el ORIGEN (local/remoto/fallback)
  Future<DocFetchResult> fetchAndCacheWithSource({
    required String uid,
    required String docId,
    required Future<StoredDocPayload?> Function(String uid, String docId)
    remoteFetch,
    bool preferCacheFirst = true,
    bool cacheEnabled = true,
  }) async {
    StoredDocPayload local = {'data': {}, 'files': {}};

    if (preferCacheFirst) {
      local = await readLocal(uid: uid, docId: docId);
      if (local['data']!.isNotEmpty || local['files']!.isNotEmpty) {
        debugPrint('[DocStoreCache] ORIGIN=LOCAL PHONE uid=$uid doc=$docId');
        // refresco en background
        unawaited(_refreshRemote(uid, docId, remoteFetch, cacheEnabled));
        return DocFetchResult(local, DocSource.local);
      }
    }

    // Intentamos remoto
    final remote = await remoteFetch(uid, docId);
    if (remote != null) {
      if (cacheEnabled) {
        unawaited(writeLocal(uid: uid, docId: docId, doc: remote));
      }
      debugPrint('[DocStoreCache] ORIGIN=REMOTE CLOUD uid=$uid doc=$docId');
      return DocFetchResult(remote, DocSource.remote);
    }

    // Fallback local (vacío o lo que haya)
    final fallback = preferCacheFirst
        ? local
        : await readLocal(uid: uid, docId: docId);
    debugPrint('[DocStoreCache] ORIGIN=LOCAL FALLBACK uid=$uid doc=$docId');
    return DocFetchResult(fallback, DocSource.localFallback);
  }

  /// Versión simple que devuelve solo el payload
  Future<StoredDocPayload> fetchAndCache({
    required String uid,
    required String docId,
    required Future<StoredDocPayload?> Function(String uid, String docId)
    remoteFetch,
    bool preferCacheFirst = true,
    bool cacheEnabled = true,
  }) async {
    final res = await fetchAndCacheWithSource(
      uid: uid,
      docId: docId,
      remoteFetch: remoteFetch,
      preferCacheFirst: preferCacheFirst,
      cacheEnabled: cacheEnabled,
    );
    return res.payload;
  }

  Future<void> _refreshRemote(
    String uid,
    String docId,
    Future<StoredDocPayload?> Function(String, String) remoteFetch,
    bool cacheEnabled,
  ) async {
    try {
      final remote = await remoteFetch(uid, docId);
      if (remote != null && cacheEnabled) {
        await writeLocal(uid: uid, docId: docId, doc: remote);
        debugPrint(
          '🔄 REFRESH FINALIZADO: REMOTO → CACHÉ LOCAL | uid=$uid | docId=$docId',
        );
      }
    } catch (_) {}
  }
}
