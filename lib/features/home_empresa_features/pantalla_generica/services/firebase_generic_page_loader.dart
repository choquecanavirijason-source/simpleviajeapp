// lib/features/home_empresa_features/pantalla_generica/services/firebase_generic_page_loader.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controller/controller.dart'; // para usar GenericPageController

class GenericPageFirebaseLoader {
  final FirebaseFirestore _db;
  GenericPageFirebaseLoader({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  /// Lee /users/{uid}/docs/{docId} y devuelve mapas (vacíos si no existe)
  Future<Map<String, Map<String, dynamic>>> fetch({
    required String uid,
    required String docId,
  }) async {
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('docs')
        .doc(docId)
        .get();

    if (!snap.exists) {
      return {'data': <String, dynamic>{}, 'files': <String, dynamic>{}};
    }
    final m = snap.data() ?? {};
    final data =
        (m['data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final files =
        (m['files'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    return {'data': data, 'files': files};
  }
}

/// Aplica prefill a la GenericPage SOLO si el campo/archivo está vacío.
class GenericPagePrefiller {
  static void apply({
    required GenericPageController controller,
    required Map<String, dynamic> data,
    required Map<String, dynamic> files,
  }) {
    // ---- Inputs (texto) ----
    for (final raw in controller.inputsCfg) {
      final key = controller.keyForInput(raw as Map);
      final ctrl = controller.ctrls[key]!;
      if (ctrl.text.trim().isEmpty) {
        final v = data[key] ?? data[_keyFallback(raw)];
        if (v != null && v.toString().isNotEmpty) {
          ctrl.text = v
              .toString(); // dispara listeners y habilita botón si corresponde
        }
      }
    }

    // ---- Archivos (URLs remotas para preview) ----
    for (final raw in controller.filesCfg) {
      final m = raw as Map<String, dynamic>;
      final key = controller.keyForFile(m);

      final hasLocal = controller.files[key] != null;
      final hasUrl = (m['initialUrl'] as String?)?.isNotEmpty == true;
      if (hasLocal || hasUrl) continue; // ya hay algo

      final v = files[key] ?? files[_safeKey(key)] ?? files[_keyFallback(m)];
      if (v is String && v.isNotEmpty) {
        m['initialUrl'] = v; // FileBox mostrará la imagen remota
      }
    }
  }

  static String _keyFallback(Map m) =>
      (m['key'] as String?) ?? (m['label'] as String?) ?? '';

  static String _safeKey(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
}
