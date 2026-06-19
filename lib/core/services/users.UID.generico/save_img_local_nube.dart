// import 'package:buses2/core/services/users.UID.generico/save_img_local_nube.dart';

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import 'package:buses2/core/services/users.UID.generico/save_img_nube.dart';
import 'package:buses2/core/services/users.UID.generico/save_img_local.dart';

class SaveImgLocalNubeResult {
  final String url; // downloadURL de Firebase Storage
  final String localPath; // ruta absoluta local
  const SaveImgLocalNubeResult({required this.url, required this.localPath});

  @override
  String toString() =>
      'SaveImgLocalNubeResult(url: $url, localPath: $localPath)';
}

class SaveImgLocalNube {
  SaveImgLocalNube._();

  /// Guarda PRIMERO en la NUBE y LUEGO en LOCAL.
  /// - Pasa UNO de: [file] o [bytes].
  /// - [sectionName]: carpeta lógica (p.ej. 'billetera').
  /// - [filenameOverride]: opcional; si lo pasas, se usa el mismo nombre en nube y local.
  static Future<SaveImgLocalNubeResult> uploadThenSaveLocal({
    required String sectionName,
    File? file,
    Uint8List? bytes,
    String? filenameOverride,
  }) async {
    if (file == null && bytes == null) {
      throw ArgumentError('⚠️ Debes pasar "file" o "bytes".');
    }

    print(
      '🚀 [IMG-ORQ] Iniciando guardado imagen (NUBE → LOCAL) para "$sectionName"...',
    );

    // 1) Subir a NUBE
    print('☁️ [IMG-ORQ] Subiendo a NUBE...');
    final url = await SaveImgNube.upload(
      sectionName: sectionName,
      file: file,
      bytes: bytes,
      filenameOverride: filenameOverride,
    );
    print('✅ [IMG-ORQ] NUBE OK → $url');

    // 2) Guardar en LOCAL (usa el mismo filename para mantener consistencia)
    print('📦 [IMG-ORQ] Guardando en LOCAL...');
    final localPath = await SaveImgLocal.save(
      sectionName: sectionName,
      file: file,
      bytes: bytes,
      filenameOverride: filenameOverride, // mantiene el nombre si lo definiste
    );
    print('✅ [IMG-ORQ] LOCAL OK → $localPath');

    print('🎉 [IMG-ORQ] Terminado (NUBE ✅ + LOCAL ✅)');
    return SaveImgLocalNubeResult(url: url, localPath: localPath);
  }
}

/* Ejemplo de uso:
void _guardar() async {
  // Guarda img 1ro en nube y luego en local
  if (_imgFile != null) {
    final res = await SaveImgLocalNube.uploadThenSaveLocal(
      sectionName: sectionName, // 'billetera'
      file: _imgFile,
      // filenameOverride: 'logo.jpg', // opcional (mismo nombre en nube y local)
    );

    // Si quieres persistir estos campos en tu map:
    data['logoUrl'] = res.url;                 // URL pública (nube)
    data['logoLocalPath'] = res.localPath;     // ruta local absoluta
  }
}
*/
