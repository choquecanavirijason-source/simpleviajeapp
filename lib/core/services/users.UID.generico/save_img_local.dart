import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SaveImgLocal {
  SaveImgLocal._();

  static final _auth = FirebaseAuth.instance;

  /// Guarda la imagen localmente y devuelve la ruta absoluta del archivo.
  /// Pasa UNO de: [file] o [bytes].
  /// Si no pasas [filenameOverride], se genera <timestamp>.<ext>
  static Future<String> save({
    required String sectionName,
    File? file,
    Uint8List? bytes,
    String? filenameOverride,
  }) async {
    print('📦 [IMG-LOCAL] Preparando guardado local para "$sectionName"...');

    final user = _auth.currentUser;
    if (user == null) {
      throw Exception(
        '🚫 [IMG-LOCAL] No autenticado. Inicia sesión para guardar imágenes.',
      );
    }
    final uid = user.uid;

    // Directorio base de documentos de la app
    final baseDir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(
      p.join(baseDir.path, 'users', uid, sectionName),
    );
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
      print('📁 [IMG-LOCAL] Carpeta creada: ${targetDir.path}');
    }

    // Nombre de archivo
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ext = filenameOverride != null
        ? _extFromName(filenameOverride) ?? _extFromFile(file) ?? 'jpg'
        : _extFromFile(file) ?? 'jpg';
    final filename = filenameOverride ?? '$ts.$ext';
    final destPath = p.join(targetDir.path, filename);
    final destFile = File(destPath);

    // Escritura
    if (file != null) {
      print('⬇️ [IMG-LOCAL] Copiando desde File...');
      await file.copy(destPath);
    } else if (bytes != null) {
      print('⬇️ [IMG-LOCAL] Escribiendo desde bytes...');
      await destFile.writeAsBytes(bytes, flush: true);
    } else {
      throw ArgumentError('⚠️ [IMG-LOCAL] Debes pasar file o bytes.');
    }

    print('✅ [IMG-LOCAL] Guardado OK → $destPath');
    return destPath; // Ruta absoluta local
  }

  // ------ helpers ------
  static String? _extFromFile(File? f) {
    if (f == null) return null;
    final e = p.extension(f.path).toLowerCase();
    if (e.isEmpty) return null;
    return e.replaceFirst('.', '').isEmpty ? null : e.replaceFirst('.', '');
  }

  static String? _extFromName(String name) {
    final e = p.extension(name).toLowerCase();
    if (e.isEmpty) return null;
    return e.replaceFirst('.', '').isEmpty ? null : e.replaceFirst('.', '');
  }
}

/* Ejemplo de uso:

File? _imgFile;

...

void _guardar() async {

try {

  if (_imgFile != null) {
    final localPath = await SaveImgLocal.save(
      sectionName: sectionName, // 'billetera'
      file: _imgFile,
      // filenameOverride: 'logo.jpg', // opcional
    );
    // Guardamos la ruta local JUNTO al resto de datos, SOLO local
    data['logoLocalPath'] = localPath;
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
