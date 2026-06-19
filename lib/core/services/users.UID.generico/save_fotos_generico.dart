import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class SaveFotoStorage {
  SaveFotoStorage._();

  static final _storage = FirebaseStorage.instance;
  static final _auth = FirebaseAuth.instance;

  /// Sube un archivo a Firebase Storage y devuelve la URL pública.
  /// La ruta puede contener {uid} y se reemplaza automáticamente.
  static Future<String> subir({
    required File file,
    required String path,
    bool replace = true, // 👈 por defecto reemplaza
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No autenticado');

    var resolvedPath = path.replaceAll('{uid}', user.uid);

    if (!replace) {
      // 👇 si no queremos reemplazar, agregamos un id único al archivo
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ext = file.path.split('.').last;
      resolvedPath = resolvedPath.replaceAll(
        '.jpg',
        '_$timestamp.$ext',
      ); // ej. foto_123123.jpg
    }

    final ref = _storage.ref().child(resolvedPath);

    await ref.putFile(file);
    return await ref.getDownloadURL();
  }
}

/* Ejemplo de uso:
Future<void> _guardar() async {
  if (!_formKey.currentState!.validate()) return;

  String? fotoUrl;
  if (_logoFile != null) {
    fotoUrl = await SaveFotoStorage.subir(
      file: _logoFile!,
      path: 'users/{uid}/perfil/foto.jpg', // ruta para guardar la foto
      replace: true, // true reemplaza foto, false guarda todas las fotos
    );
  }

  final data = {
    if (fotoUrl != null) 'fotoPerfil': fotoUrl, // nombre del campo en Firestore
  };

  try {
    await SaveDatosGenericos.guardarCampoEnMap(
      absoluteDocPath: 'users/{uid}', // 👈 aquí decides la ruta desde el page
      data: data,
      nombreMap: 'taxista', // map dentro del map infinatamente
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Datos guardados')),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al guardar: $e')),
    );
  }
}
*/
/* Bloque de codigo exacto para subir foto:
fotoUrl = await SaveFotoStorage.subir(
  file: _logoFile!,
  path: 'users/{uid}/perfil/foto.jpg', // ruta para guardar la foto
  replace: true, // true reemplaza foto, false guarda todas las fotos
);
*/
