import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SaveDatosGenericos {
  SaveDatosGenericos._();

  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Guarda en users/<uid>.<nombreMap> = {...data}
  static Future<void> guardar({
    required Map<String, dynamic> data,
    required String nombreMap,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No autenticado');

    final sanitized = _sanitize(data)
      ..['updatedAt'] = FieldValue.serverTimestamp();

    await _db.collection('users').doc(user.uid).set({
      nombreMap: sanitized,
    }, SetOptions(merge: true));
  }

  /// 🔹 Utilidad para leer valores anidados con notación de puntos
  static dynamic _getNestedValue(Map<String, dynamic>? data, String keyPath) {
    if (data == null) return null;
    final parts = keyPath.split('.');
    dynamic current = data;
    for (final p in parts) {
      if (current is Map<String, dynamic> && current.containsKey(p)) {
        current = current[p];
      } else {
        return null;
      }
    }
    return current;
  }

  /// Guarda o actualiza campos dentro de un mapa.
  /// Puede aceptar una sola ruta (String) o varias rutas (List<String>).
  static Future<void> guardarCampoEnMap({
    required dynamic absoluteDocPath,
    required dynamic nombreMap,
    Map<String, dynamic>? data,
    List<Map<String, dynamic>?>? dataPorRuta,
    String? nombreCampo,
    dynamic valor,
    String? counterPath,
    String counterField = 'lastId',
    bool usarUidActual = false,
    String? uidKey,
    String? existeKey,
    String? existeDocPath,
    bool agregarTimestamps = true, // 👈 nuevo flag opcional
  }) async {
    final rutas = absoluteDocPath is String
        ? [absoluteDocPath]
        : (absoluteDocPath as List<String>);

    final maps = nombreMap is String
        ? List.filled(rutas.length, nombreMap)
        : (nombreMap as List<String>);

    if (rutas.length != maps.length) {
      throw Exception(
        'El número de rutas (${rutas.length}) no coincide con el número de maps (${maps.length})',
      );
    }

    // 1) ¿Ya existe un id guardado en algún doc?
    String? forcedId;
    if (existeKey != null && existeDocPath != null) {
      final checkPath = await _resolvePathAsync(
        existeDocPath,
        counterPath: counterPath,
        counterField: counterField,
      );
      final snap = await _db.doc(checkPath).get();
      final v = _getNestedValue(snap.data(), existeKey);
      if (v is String && v.isNotEmpty) {
        forcedId = v;
      }
    }

    // 2) Reemplazar {newUID} por el id existente si ya había
    final List<String> rutasInput = absoluteDocPath is String
        ? [absoluteDocPath]
        : (absoluteDocPath as List<String>);

    final rutasProcesadas = List<String>.from(rutasInput);
    if (forcedId != null) {
      for (int i = 0; i < rutasProcesadas.length; i++) {
        if (rutasProcesadas[i].contains('{newUID}')) {
          rutasProcesadas[i] = rutasProcesadas[i].replaceAll(
            '{newUID}',
            forcedId,
          );
        }
      }
    }

    try {
      String? newDocId = forcedId; // si ya había id, úsalo

      for (var i = 0; i < rutasProcesadas.length; i++) {
        final originalPath = rutasProcesadas[i];

        // 1) Resolver ruta real
        final resolvedPath = await _resolvePathAsync(
          originalPath,
          counterPath: counterPath,
          counterField: counterField,
        );

        // 2) ¿Se generó aquí el id (nuevo doc)?
        bool generatedHere = false;
        if (newDocId == null && originalPath.contains('{newUID}')) {
          newDocId = resolvedPath.split('/').last;
          generatedHere = true;
        }

        // 3) Resolver nombre del map
        final resolvedMapName = await _resolvePathAsync(
          maps[i],
          counterPath: counterPath,
          counterField: counterField,
        );

        // 👇 normalizamos para que @root no se guarde como campo
        final normalizedMapName = resolvedMapName == '@root'
            ? ''
            : resolvedMapName;

        // 4) Construir el submap para ESTA ruta
        final subMapThis = <String, dynamic>{};

        final base = (dataPorRuta != null && i < dataPorRuta.length)
            ? dataPorRuta[i]
            : data;
        if (base != null) {
          subMapThis.addAll(_sanitize(base));
        }

        if (nombreCampo != null) {
          subMapThis[nombreCampo] = valor;
        }

        if (uidKey != null && newDocId != null) {
          subMapThis[uidKey] ??= newDocId;
        }

        // 👇 timestamps solo si el flag está en true
        if (agregarTimestamps) {
          if (generatedHere) {
            subMapThis['createdAt'] = FieldValue.serverTimestamp();
          }
          subMapThis['updatedAt'] = FieldValue.serverTimestamp();
        }

        final isRoot = normalizedMapName.isEmpty;
        final updateData = isRoot
            ? subMapThis
            : _buildNestedMap(normalizedMapName, subMapThis);

        await _db.doc(resolvedPath).set(updateData, SetOptions(merge: true));
        print(
          '✅ [NUBE] Actualizado en $normalizedMapName en $resolvedPath: ${subMapThis.keys}',
        );
      }
    } catch (e) {
      print('❌ [NUBE] Error: $e');
      rethrow;
    }
  }

  static Map<String, dynamic> _buildNestedMap(
    String path,
    Map<String, dynamic> value,
  ) {
    final parts = path.split('.');
    Map<String, dynamic> result = value;
    for (final part in parts.reversed) {
      result = {part: result};
    }
    return result;
  }

  static String _resolvePath(String path) {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No autenticado');
    return path.replaceAll('{uid}', user.uid);
  }

  static Map<String, dynamic> _sanitize(Map<String, dynamic> data) {
    final out = <String, dynamic>{};
    data.forEach((k, v) {
      if (v == null) return;
      if (v is num && v.isNaN) return;
      out[k] = v;
    });
    return out;
  }

  static Future<String> _resolvePathAsync(
    String path, {
    String? counterPath,
    String counterField = 'lastId',
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No autenticado');
    path = path.replaceAll('{uid}', user.uid);

    if (counterPath != null) {
      counterPath = counterPath.replaceAll('{uid}', user.uid);
    }

    if (path.contains('{n+1}')) {
      if (counterPath == null) {
        throw Exception('Debes pasar counterPath si usas {n+1}');
      }

      final counterRef = _db.doc(counterPath);

      final newId = await _db.runTransaction<int>((txn) async {
        final snap = await txn.get(counterRef);
        int last = 0;
        if (snap.exists) {
          last = snap.data()?[counterField] ?? 0;
        }
        final next = last + 1;
        txn.set(counterRef, {counterField: next}, SetOptions(merge: true));
        return next;
      });

      return path.replaceAll('{n+1}', newId.toString());
    }

    if (path.contains('{newUID}')) {
      final parts = path.split('/');
      for (int i = 0; i < parts.length; i++) {
        if (parts[i] == '{newUID}') {
          if (i == 0) throw Exception('Ruta inválida para {newUID}: $path');
          final collectionPath = parts.take(i).join('/');
          final newId = _db.collection(collectionPath).doc().id;
          parts[i] = newId;
        }
      }
      return parts.join('/');
    }

    return path;
  }

  static Future<void> arrayUnionCampo({
    required dynamic absoluteDocPath,
    required String nombreCampo,
    required List<dynamic> valores,
    String nombreMap = '@root',
    String? existeKey,
    String? existeDocPath,
    String? counterPath,
    String counterField = 'lastId',
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No autenticado');

    final List<dynamic> resolvedValues = valores.map((v) {
      if (v is String && v == '{uid}') return user.uid;
      return v;
    }).toList();

    await guardarCampoEnMap(
      absoluteDocPath: absoluteDocPath,
      nombreMap: nombreMap,
      nombreCampo: nombreCampo,
      valor: FieldValue.arrayUnion(resolvedValues),
      counterPath: counterPath,
      counterField: counterField,
      existeKey: existeKey,
      existeDocPath: existeDocPath,
    );
  }
}
/* ejemplo de uso:
  await SaveDatosGenericos.arrayUnionCampo(
    absoluteDocPath: 'empresas/{newUID}', // crea doc y captura ese docId
    nombreMap: 'info.detalles',                 // escribe en la raíz del doc
    nombreCampo: 'uidPropietarios',      // campo array donde se agregará
    valores: ['{uid}'],                   // agrega el uid actual al array
    existeKey: 'uidEmpresa',              // si ya existe, reutiliza ese id
    existeDocPath: 'pasajeros/{uid}',     // si no existe el doc, lo crea
  );
  */
/*
await SaveDatosGenericos.arrayUnionCampo(
  absoluteDocPath: 'empresas/{newUID}',   // 📌 Documento(s) destino. Acepta placeholders:
                                          //    - {uid}  => UID del usuario actual
                                          //    - {newUID} => si hay existeKey/existeDocPath, se reutiliza ese ID (p.ej. uidEmpresa);
                                          //                  si no, genera un nuevo docId en esa colección.
                                          //    - {n+1} => usa counterPath/counterField para numerar (opcional)

  nombreCampo: 'uidPropietarios',         // 🔧 Campo (array) al que se aplicará arrayUnion(...)
                                          //    Si nombreMap != @root, quedará anidado (p.ej. info.uidPropietarios)

  valores: const ['{uid}'],               // ➕ Valores a agregar al array. Puedes usar '{uid}' para el UID actual.
                                          //    arrayUnion evita duplicados de forma atómica en Firestore.

  nombreMap: 'info.detalles',             // 🗂️ Dónde escribir dentro del doc:
                                          //    - '@root' o '' => raíz del documento (uidPropietarios directamente en el doc)
                                          //    - 'info' => info.uidPropietarios
                                          //    - 'info.detalles' => info.detalles.uidPropietarios

  existeKey: 'uidEmpresa',                // ♻️ Nombre del campo que contiene el ID a reutilizar (por ejemplo, uidEmpresa).
                                          //    Si se encuentra, {newUID} será reemplazado por ese ID y NO se creará otro doc.

  existeDocPath: 'pasajeros/{uid}',       // 🔎 Documento donde se leerá existeKey (solo LECTURA, no crea nada aquí).
                                          //    En tu flujo, este doc ya tiene uidEmpresa por la 1ª llamada.

  counterPath: null,                      // 🔢 SOLO si usas rutas con {n+1}. Ruta del contador (p.ej. 'counters/empresas').
                                          //    Si no usas {n+1}, déjalo en null.

  counterField: 'lastId',                 // 🔢 Nombre del campo dentro de counterPath que guarda el último número usado.
                                          //    Úsalo junto a {n+1}. Ignorado si counterPath == null.
);

*/

/* Ejemplo practico:
await SaveDatosGenericos.guardarCampoEnMap(
  absoluteDocPath: 'pasajeros/{uid}', // doc exacto
  nombreMap: '@root',                      // modo.nombre.etc
  nombreCampo: 'modo',                     // modo.nombre.etc
  valor: 'empresa',                        // valor fijo dentro de nombreCampo
);
*/

/* Ejemplo de uso con varios campos:
Future<void> _guardar() async {
  if (!_formKey.currentState!.validate()) return;

  final data = {
    'telefono': _numberCtrl.text.trim(),
    'nombreCompleto': _nameController.text.trim(),
    'correo': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
  };

  try {
    await SaveDatosGenericos.guardarCampoEnMap(
      absoluteDocPath: 'users/{uid}/nuevaColleccion/doc', // 👈 aquí decides la ruta desde el page
      data: data,
      nombreMap: 'taxista.datosLaborales', // map dentro del map infinatamente
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

/* Ejemplo de uso con un campo puntual:
Future<void> _guardar() async {
  if (!_formKey.currentState!.validate()) return;

  try {
    await SaveDatosGenericos.guardarCampoEnMap(
      absoluteDocPath: 'users/{uid}/nuevaColleccion/doc', // 👈 aquí decides la ruta desde el page
      nombreMap: 'taxista.datosLaborales', // map dentro del map infinatamente
      nombreCampo: 'telefono', // <-- si quieres guardar solo un campo puntual
      valor: _numberCtrl.text.trim(),
    );

  } catch (e) {
    
  }
}
*/

/* Ejemplo de uso con varias rutas:
await SaveDatosGenericos.guardarCampoEnMap(
  absoluteDocPath: [
    'users/{uid}',
    'users/{uid}/backup/doc',
    //'empresas/${_empresaController.text.trim()}',// Doc con nombre dinámico
  ],
  data: data,
  nombreMap: [
    'empresa.detalles', // map dentro del map infinatamente
    'info',
  ], // map para cada ruta
);
*/

/* Ejemplo de uso con contador {n+1}:
// Para usar el contador, debes pasar counterPath y counterField, eso creara un ruta
// donde se guardará el último id usado, y cada vez que se use {n+1} se sumará 1 a ese id.
await SaveDatosGenericos.guardarCampoEnMap(
  absoluteDocPath: 'empresas/empresa{n+1}', // 👈 aquí decides la ruta coleccion, doc.
  data: data,
  nombreMap: 'info', // map dentro del map infinatamente
  counterPath: 'counters/empresas', // 👈 decides la ruta del contador
  counterField: 'lastEmpresaId',    // 👈 decides el nombre del campo del contador
);
*/

/*
--- Crear un nuevo uid ---
await SaveDatosGenericos.guardarCampoEnMap(
  absoluteDocPath: [
    'empresas/{newUID}', // crea doc y captura ese docId
    'users/{uid}',       // aquí se escribirá el mismo uid en el campo
  ],
  nombreMap: [
    '@root', // escribe en la raíz del doc
    '@root',
  ],
  uidKey: 'uidEmpresa',// nombre del campo donde se guardará el newUID
  existeKey: 'uidEmpresa',// si no existe, lo crea
  existeDocPath: 'users/{uid}',// si no existe el doc, lo crea
  );
*/
/* 2025/05/08
  static Future<void> guardarCampoEnMap({
    required dynamic absoluteDocPath, // String o List<String>
    required dynamic nombreMap,       // String o List<String>
    Map<String, dynamic>? data,
    String? nombreCampo,
    dynamic valor,
    String? counterPath,
    String counterField = 'lastId',
  }) async {
    // Submapa que vamos a guardar
    final Map<String, dynamic> subMap = {};

    if (data != null) {
      subMap.addAll(_sanitize(data));
    }

    if (nombreCampo != null) {
      subMap[nombreCampo] = valor;
    }

    // Siempre actualizar updatedAt
    subMap['updatedAt'] = FieldValue.serverTimestamp();

    // Normalizar rutas a lista
    final rutas = absoluteDocPath is String
        ? [absoluteDocPath]
        : (absoluteDocPath as List<String>);

    // Normalizar nombreMap a lista (si es String, repetir en todas las rutas)
    final maps = nombreMap is String
        ? List.filled(rutas.length, nombreMap)
        : (nombreMap as List<String>);

    if (rutas.length != maps.length) {
      throw Exception(
        'El número de rutas (${rutas.length}) no coincide con el número de maps (${maps.length})',
      );
    }

    try {
      for (var i = 0; i < rutas.length; i++) {
        final resolvedPath = await _resolvePathAsync(
          rutas[i],
          counterPath: counterPath,
          counterField: counterField,
        );
        final mapName = maps[i];

        final updateData = _buildNestedMap(mapName, subMap);

        await _db.doc(resolvedPath).set(updateData, SetOptions(merge: true));
        print('✅ [NUBE] Actualizado en $mapName en $resolvedPath: ${subMap.keys}');
      }
    } catch (e) {
      print('❌ [NUBE] Error: $e');
      rethrow;
    }
  }
*/

/* Valor del input, se puede usar como nombre de ruta:
final data = {
  'tituloContrato': _tituloCtrl.text.trim(), // Por ejemplo de este input
  'plantilla': _plantillaCtrl.text.trim(),
};
nombreMap: '/${data['tituloContrato']}',
// De esta forma puedes crear mapas con nombres dinámicos
// basados en el contenido de un input.
*/

/* El mas completo hasta el momento: guarda en 2 rutas, crea un nuevo uid, y
   reutiliza el uidEmpresa si ya existía en pasajeros/{uid} , escribe en la raiz un valor fijo, escribe en la raiz
   uidEmpresa, y en la otra ruta escribe un mapa anidado con varios campos.
Future<void> _guardar() async {
  if (!(_formKey.currentState?.validate() ?? false)) return;

  // solo datos planos; el servicio pone timestamps / resuelve {newUID}
  final perfil = {
    'nombreEmpresa'     : _empresaController.text.trim(),
    'representanteLegal': _nameCtrl.text.trim(),
    'telefono'          : _numberCtrl.text.trim(),
    'correo'            : _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
  };

  // raíz: estado + uidEmpresa (lo agrega uidKey) + updatedAt/createdAt (lo agrega el servicio)
  final empresaRoot = {
    'estado': 'pendiente',
    'perfilEmpresa': perfil, // 👈 anidado
  };

  await SaveDatosGenericos.guardarCampoEnMap(
    absoluteDocPath: [
      'empresas/{newUID}', // crea doc y captura ese docId
      'pasajeros/{uid}',   // aquí solo raíz con uidEmpresa
    ],
    nombreMap: ['@root', '@root'],
    dataPorRuta: [
      empresaRoot, // empresas -> raíz con estado + perfilEmpresa{...}
      null,        // pasajeros -> sin payload extra (solo uidEmpresa)
    ],
    uidKey: 'uidEmpresa',          // 🔑 se escribe en raíz en ambas rutas
    existeKey: 'uidEmpresa',       // si ya existe en pasajeros, reutiliza ese id
    existeDocPath: 'pasajeros/{uid}',
  );

  // listo:
  // empresas/{newUID}:
  // {
  //   uidEmpresa: "...",
  //   estado: "pendiente",
  //   perfilEmpresa: { nombreEmpresa, representanteLegal, telefono, correo },
  //   createdAt, updatedAt
  // }
  // pasajeros/{uid}: { uidEmpresa: "...", updatedAt }
}
*/
