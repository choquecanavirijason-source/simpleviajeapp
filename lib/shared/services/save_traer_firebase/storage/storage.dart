import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import '../reemplazar/reemplazar.dart';

/* Asi funciona Firebase Storagea
- upload (putFile/putData/putBlob) = → sube el archivos al link o ruta creada;
- download (getData/writeToFile) = descargar archivo (a memoria o a archivo local).
- delete = borrar archivo.
*/

/* Así funciona Firebase Storage
- ref(path) = crea la ruta users/abc/prestamos/xyz/fotos/img.jpg
- putFile  → subir cualquier archivo que exista en el dispositivo.
- putData  → Si tu app crea una img, pdf, etc. puedes subirlo a la nube sin guardarlo en el dispositivo.
- putBlob  → AppWeb, arrastras un archivo desde tu carpeta de tu PC a la appWeb y lo subes.

- getData  → Descarga el contenido con un limite de tamaño. Solo para ver archivos dentro
  de la propia app, ej: mostrar la foto de perfil, no se descarga en el celular, solo en la app.
- writeToFile → Descarga el contenido a un archivo local (sin límite de tamaño).
  Descarga el archivo al dispositivo, ej: descargar un PDF y verlo en tu galeria

- list(options) -> Filtro por prefijo "images/perfiles/" Trae una lista limitada, excelente para paginación.
- listAll() -> Filtro por prefijo "images/perfiles/" Trae todo lo que empiece por ese prefijo.
- getMetadata() -> Lee metadatos del archivo (tamaño, tipo, fecha, etc).
- updateMetadata(meta) -> Escribe o actualiza metadatos del archivo.
- delete() = Borra el archivo de la ruta indicada.
*/

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// 📥 Sube una sola foto a Firebase Storage
  Future<String?> uploadPhoto(File file, String rawPath) async {
    try {
      // 🔑 Resolvemos {uid}, {empresaID}, etc. con el mismo helper
      final path = Reemplazar.rutaUID(rawPath);
      final ref = _storage.ref().child(path);
      final snapshot = await ref.putFile(file);
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Error subiendo foto: $e");
      return null;
    }
  }

  /// 📸 API "inteligente" que acepta:
  /// - folderPath: String  -> sube a una ruta.   Devuelve List<String>.
  /// - folderPath: List<String> -> sube a múltiples rutas. Devuelve Map<ruta, List<String>>.
  ///
  /// Soporta placeholders (p.ej. {empresaID}) vía `reglas`, igual que DocSets/NMasUno.
  Future<dynamic> uploadPhotosSmart({
    required List<File> files,
    required dynamic folderPath, // String o List<String>
    String nombreFoto = 'foto',
    bool nombreImgAutomatico = false,
    Map<String, Map<String, String>> reglas = const {}, // 👈 NUEVO
  }) async {
    // 0) Normalizadores
    String _trimSlashes(String s) => s.replaceAll(RegExp(r'(^/+|/+$)'), '');
    List<String> _toListString(dynamic v) {
      if (v is String) return [v];
      if (v is List) return v.map((e) => e as String).toList();
      throw ArgumentError('folderPath debe ser String o List<String>');
    }

    final List<String> rawPaths = _toListString(folderPath);

    // 1) Resolver placeholders con `reglas`
    final resolvedPaths = <String>[];
    for (final p in rawPaths) {
      final r = await Reemplazar.resolverRuta(p, reglas: reglas);
      resolvedPaths.add(_trimSlashes(r));
    }

    // 2) Generar nombres de archivo UNA VEZ para que sean iguales en todas las rutas
    final filenames = <String>[];
    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final String original = file.path.split('/').last;
      final int dot = original.lastIndexOf('.');
      final String ext = (dot >= 0) ? original.substring(dot) : '';
      final String name = nombreImgAutomatico
          ? '${nombreFoto}_${DateTime.now().millisecondsSinceEpoch}_$i$ext'
          : '$nombreFoto${i + 1}$ext'; // gato1.jpg, gato2.jpg, ...
      filenames.add(name);
    }

    // 3) Subir:
    // - Si 1 ruta: devolvemos List<String>
    // - Si varias rutas: devolvemos Map<ruta, List<String>>
    if (resolvedPaths.length == 1) {
      final base = resolvedPaths.first;
      final futures = <Future<String?>>[];
      for (int i = 0; i < files.length; i++) {
        final fullPath = '$base/${filenames[i]}';
        futures.add(uploadPhoto(files[i], fullPath));
      }
      final results = await Future.wait(futures);
      return results.whereType<String>().toList(); // List<String>
    } else {
      final Map<String, List<String>> urlsByPath = {};
      for (final base in resolvedPaths) {
        final futures = <Future<String?>>[];
        for (int i = 0; i < files.length; i++) {
          final fullPath = '$base/${filenames[i]}';
          futures.add(uploadPhoto(files[i], fullPath));
        }
        final results = await Future.wait(futures);
        urlsByPath[base] = results.whereType<String>().toList();
      }
      return urlsByPath; // Map<String, List<String>>
    }
  }
}

/* Ejemplo de uso:
import 'dart:io';
import 'package:prestamos1/shared/services/save_traer_firebase/storage/storage.dart';
...
final List<File> _imagenes = []; // aquí guardaremos las fotos seleccionadas
...
final storage = StorageService();
final urlsFotos = await storage.uploadPhotosSmart( // 👈 url de fotos
  files: _fotosSeleccionadas,   
  folderPath: [
    'empresas/{empresaID}/clientes/$idClienteSanitizado/prestamos/$prestamoN1',
    'clientes/$idClienteSanitizado/empresas/{empresaID}/prestamos/$prestamoN1',
  ],
  nombreFoto: 'foto',
  nombreImgAutomatico: true, // foto1, foto2, ...
);

await DocSets.set(
  absoluteDocPath: [
    'clientes/$idClienteSanitizado',
  ],
  nombreMap: [
    'datosPrestatario',
  ],
  data: [
    {
      'fotos': urlsFotos,// 👈 url de fotos guardadas
    },
  ],
  reglas: reglas,
);
*/
