import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SaveDatosGenericos {
  SaveDatosGenericos._();

  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Guarda en users/<uid>.<nombreMap> = {...data}
  ///
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

  /// Guarda o actualiza campos dentro de un mapa.
  /// Puede aceptar una sola ruta (String) o varias rutas (List<String>).
  static Future<void> guardarCampoEnMap({
    required dynamic absoluteDocPath,
    required dynamic nombreMap,
    Map<String, dynamic>? data,
    String? nombreCampo,
    dynamic valor,
    String? counterPath,
    String counterField = 'lastId',

    // 👇 Nuevos parámetros
    bool usarUidActual = false,
    String? uidKey, // nombre del campo (ej: "uidEmpresa")
    bool generarNuevoUid = false,
  }) async {
    final Map<String, dynamic> subMap = {};

    if (data != null) {
      subMap.addAll(_sanitize(data));
    }

    if (nombreCampo != null) {
      subMap[nombreCampo] = valor;
    }

    // 👉 Usa el uid actual
    if (usarUidActual && uidKey != null) {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No autenticado');
      subMap[uidKey] = user.uid;
    }

    // 👉 Genera un uid nuevo
    if (generarNuevoUid && uidKey != null) {
      final newUid = _db.collection('_tmp').doc().id;
      subMap[uidKey] = newUid;
    }

    subMap['updatedAt'] = FieldValue.serverTimestamp();

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
        print(
          '✅ [NUBE] Actualizado en $mapName en $resolvedPath: ${subMap.keys}',
        );
      }
    } catch (e) {
      print('❌ [NUBE] Error: $e');
      rethrow;
    }
  }

  /// Convierte "taxista.datosLaborales" + {telefono:123} en:
  /// { taxista: { datosLaborales: { telefono:123 } } }
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

  /// reemplaza {uid} por el uid real del usuario actual
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

  // empresa{n+1} suma 1 al último id guardado en counterPath/counterField
  static Future<String> _resolvePathAsync(
    String path, {
    String? counterPath,
    String counterField = 'lastId',
  }) async {
    // Reemplazo {uid}
    final user = _auth.currentUser;
    if (user == null) throw Exception('No autenticado');
    path = path.replaceAll('{uid}', user.uid);

    // Reemplazar {uid} también en counterPath si existe
    if (counterPath != null) {
      counterPath = counterPath.replaceAll('{uid}', user.uid);
    }

    // Buscar {n+1}
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

    return path; // si no hay {n+1}, devuelve igual
  }
}

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
--- Crear un nuevo uid campo ---
await SaveDatosGenericos.guardarCampoEnMap(
  absoluteDocPath: 'empresas/{uid}',
  nombreMap: 'info',
  data: {
    'nombreEmpresa': _empresaController.text.trim(),
    'nombreRepresentante': _nameCtrl.text.trim(),
  },
  generarNuevoUid: true,
  uidKey: 'uidEmpresa', // 👈 genera y guarda un nuevo uid aquí
);
--- Usar uid actual como campo ---
await SaveDatosGenericos.guardarCampoEnMap(
  absoluteDocPath: 'empresas/{uid}',
  nombreMap: 'info',
  data: {
    'nombreEmpresa': _empresaController.text.trim(),
    'nombreRepresentante': _nameCtrl.text.trim(),
  },
  usarUidActual: true,
  uidKey: 'uidEmpresa',  // 👈 así lo guardas como campo
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
