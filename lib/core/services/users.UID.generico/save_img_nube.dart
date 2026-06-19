import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class SaveImgNube {
  SaveImgNube._();

  static final _auth = FirebaseAuth.instance;
  static final _storage = FirebaseStorage.instance;

  static Future<String> upload({
    required String sectionName,
    File? file,
    Uint8List? bytes,
    String? filenameOverride,
    SettableMetadata? metadata,
  }) async {
    print('🖼️ [IMG] Preparando subida para sección "$sectionName"...');

    final user = _auth.currentUser;
    if (user == null) {
      throw Exception(
        '🚫 [IMG] No autenticado. Inicia sesión para subir imágenes.',
      );
    }
    final uid = user.uid;

    final ts = DateTime.now().millisecondsSinceEpoch;
    final ext = _guessExt(file) ?? 'jpg';
    final filename = filenameOverride ?? '$ts.$ext';
    final path = 'users/$uid/$sectionName/$filename';

    print('📦 [IMG] Path destino: $path');

    final ref = _storage.ref(path);

    final meta =
        metadata ??
        SettableMetadata(
          contentType: _contentTypeForExt(ext),
          cacheControl: 'public, max-age=31536000, immutable',
          customMetadata: {
            'uid': uid,
            'section': sectionName,
            'createdAt': DateTime.now().toIso8601String(),
          },
        );

    try {
      UploadTask task;
      if (file != null) {
        print('⬆️ [IMG] Subiendo desde File...');
        task = ref.putFile(file, meta);
      } else if (bytes != null) {
        print('⬆️ [IMG] Subiendo desde bytes...');
        task = ref.putData(bytes, meta);
      } else {
        throw ArgumentError('⚠️ [IMG] Debes pasar file o bytes.');
      }

      final snap = await task.whenComplete(() {});
      final url = await snap.ref.getDownloadURL();
      print('✅ [IMG] Subida OK. URL: $url');
      return url;
    } on FirebaseException catch (e, st) {
      debugPrint(
        '💥 [IMG] FirebaseStorage error: ${e.code} — ${e.message}\n$st',
      );
      rethrow;
    } catch (e, st) {
      debugPrint('💥 [IMG] Error inesperado: $e\n$st');
      rethrow;
    }
  }

  // -------- helpers --------
  static String? _guessExt(File? f) {
    if (f == null) return null;
    final name = f.path.toLowerCase();
    if (name.endsWith('.png')) return 'png';
    if (name.endsWith('.webp')) return 'webp';
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'jpg';
    return 'jpg';
  }

  static String _contentTypeForExt(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}

/* Ejemplo de uso:

File? _imgFile;

...

void _guardar() async {

try {

  if (_imgFile != null) {
    final url = await SaveImgNube.upload(
      sectionName: sectionName, // 'billetera'
      file: _imgFile,
      // filenameOverride: 'logo.jpg', // opcional
    );
    data['logoUrl'] = url; // guarda el URL en tu sección
  }

} catch (e) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error al guardar: $e')),
  );
}

...

SubirFotoWidget(
  icono: Icons.upload,
  texto: "Subir Logo",
  initialUrl: null, // No hay URL aún
  onPicked: (file) {
    setState(() {
      _imgFile = file; // <- guardamos el File
    });
  },
),
*/
