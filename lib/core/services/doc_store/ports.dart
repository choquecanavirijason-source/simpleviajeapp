// lib/core/services/doc_store/ports.dart
abstract class DocumentSaverPort {
  /// files: key -> local path o URL ya remota
  Future<void> save({
    required String uid,
    required String docId,
    required Map<String, String> data,
    required Map<String, String?> files,
  });
}

// -------- helpers reutilizables --------
bool isUrl(String v) => v.startsWith('http://') || v.startsWith('https://');

String extFromPath(String path) {
  final p = path.split('?').first;
  final i = p.lastIndexOf('.');
  return i == -1 ? 'jpg' : p.substring(i + 1).toLowerCase();
}

String contentTypeFromExt(String ext) {
  switch (ext) {
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'jpeg':
    case 'jpg':
    default:
      return 'image/jpeg';
  }
}

/// Evita espacios/caracteres raros en nombres de archivo
String safeKey(String key) =>
    key.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
