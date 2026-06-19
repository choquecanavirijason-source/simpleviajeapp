// lib/core/services/data/local/local_docs_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LocalDocsService {
  Future<Directory> _root() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/local_docs');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _index(String uid, String tid) async {
    final dir = await _root();
    final folder = Directory('${dir.path}/$uid/$tid');
    if (!await folder.exists()) await folder.create(recursive: true);
    return File('${folder.path}/index.json');
  }

  Future<Directory> _filesDir(String uid, String tid) async {
    final dir = await _root();
    final f = Directory('${dir.path}/$uid/$tid/files');
    if (!await f.exists()) await f.create(recursive: true);
    return f;
  }

  Future<Map<String, String>> saveDraft({
    required String uid,
    required String templateId,
    required Map<String, String> campos,
    required Map<String, File> archivos,
    bool markSynced = false,
  }) async {
    final filesDir = await _filesDir(uid, templateId);
    final copied = <String, String>{};

    for (final e in archivos.entries) {
      final key = e.key;
      final src = e.value;
      final ext = _ext(src.path);
      final dest = File('${filesDir.path}/$key$ext');
      await dest.writeAsBytes(await src.readAsBytes(), flush: true);
      copied[key] = dest.path;
    }

    final idx = await _index(uid, templateId);
    final data = {
      'uid': uid,
      'templateId': templateId,
      'updatedAt': DateTime.now().toIso8601String(),
      'synced': markSynced,
      'campos': campos,
      'archivos': copied, // rutas locales de las imágenes
    };
    await idx.writeAsString(jsonEncode(data), flush: true);
    return copied;
  }

  Future<void> markSynced(String uid, String templateId) async {
    final f = await _index(uid, templateId);
    if (!await f.exists()) return;
    final m = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    m['synced'] = true;
    m['syncedAt'] = DateTime.now().toIso8601String();
    await f.writeAsString(jsonEncode(m), flush: true);
  }

  Future<Map<String, dynamic>?> loadDraft(String uid, String templateId) async {
    final f = await _index(uid, templateId);
    if (!await f.exists()) return null;
    try {
      return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  String _ext(String p) {
    final l = p.toLowerCase();
    if (l.endsWith('.png')) return '.png';
    if (l.endsWith('.heic')) return '.heic';
    if (l.endsWith('.webp')) return '.webp';
    return '.jpg';
  }
}
