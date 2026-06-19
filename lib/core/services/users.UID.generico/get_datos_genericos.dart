import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GetDatosGenericos {
  GetDatosGenericos._();

  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Obtiene un documento completo y lo devuelve como Map<String, dynamic>
  static Future<Map<String, dynamic>?> traerDoc({
    required String absoluteDocPath, // ej: users/{uid}
  }) async {
    final resolvedPath = _resolvePath(absoluteDocPath);
    final snap = await _db.doc(resolvedPath).get();
    return snap.data();
  }

  /// Obtiene uno o varios mapas dentro de documentos.
  /// - Si absoluteDocPath y nombreMap son String → devuelve un solo Map.
  /// - Si ambos son List → devuelve una lista de Maps en orden.
  static Future<dynamic> traerMap({
    required dynamic absoluteDocPath, // String o List<String>
    required dynamic nombreMap, // String o List<String>
  }) async {
    // Normalizar rutas
    final rutas = absoluteDocPath is String
        ? [absoluteDocPath]
        : (absoluteDocPath as List<String>);

    // Normalizar maps
    final maps = nombreMap is String
        ? List.filled(rutas.length, nombreMap)
        : (nombreMap as List<String>);

    if (rutas.length != maps.length) {
      throw Exception(
        'El número de rutas (${rutas.length}) no coincide con el número de maps (${maps.length})',
      );
    }

    final results = <Map<String, dynamic>?>[];

    for (var i = 0; i < rutas.length; i++) {
      final resolvedPath = _resolvePath(rutas[i]);
      final snap = await _db.doc(resolvedPath).get();
      final data = snap.data();
      if (data == null) {
        results.add(null);
        continue;
      }

      final parts = maps[i].split('.');
      dynamic current = data;
      for (final p in parts) {
        if (current is Map<String, dynamic> && current.containsKey(p)) {
          current = current[p];
        } else {
          current = null;
          break;
        }
      }

      results.add(
        current is Map<String, dynamic>
            ? Map<String, dynamic>.from(current)
            : null,
      );
    }

    // Si era solo un string, devolvemos un solo map en vez de lista
    return absoluteDocPath is String ? results.first : results;
  }

  /// Obtiene un campo puntual dentro de un mapa
  /// ej: traerCampo(absoluteDocPath:'users/{uid}', nombreMap:'taxista.datosTaxi', nombreCampo:'placa')
  static Future<T?> traerCampo<T>({
    required String absoluteDocPath,
    required String nombreMap,
    required String nombreCampo,
  }) async {
    final map = await traerMap(
      absoluteDocPath: absoluteDocPath,
      nombreMap: nombreMap,
    );
    if (map == null) return null;
    return map[nombreCampo] as T?;
  }

  /// reemplaza {uid} por el uid real del usuario actual
  static String _resolvePath(String path) {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No autenticado');
    return path.replaceAll('{uid}', user.uid);
  }

  /// Lee TODOS los documentos de una colección y devuelve
  /// una lista de maps (incluye el id del doc).
  static Future<List<Map<String, dynamic>>> traerDocsDeColeccion({
    required String absoluteCollectionPath, // ej: empresas/{uid}/documentos
  }) async {
    final resolved = _resolvePath(absoluteCollectionPath);
    final qs = await _db.collection(resolved).get();
    return qs.docs.map((d) {
      final data = d.data();
      return {'id': d.id, ...data};
    }).toList();
  }

  /// Lee de cada documento de una colección un CAMPO dentro de un mapa.
  /// Ej: nombreMap: 'documentos', nombreCampo: 'tituloDoc'
  static Future<List<T?>> traerCampoDeColeccion<T>({
    required String absoluteCollectionPath,
    required String nombreMap,
    required String nombreCampo,
  }) async {
    final resolved = _resolvePath(absoluteCollectionPath);
    final qs = await _db.collection(resolved).get();

    return qs.docs.map((doc) {
      final data = doc.data();
      // Navega dentro del map (p.ej. 'documentos' o 'a.b.c')
      dynamic current = data;
      for (final p in nombreMap.split('.')) {
        if (current is Map<String, dynamic> && current.containsKey(p)) {
          current = current[p];
        } else {
          current = null;
          break;
        }
      }
      if (current is Map<String, dynamic>) {
        return current[nombreCampo] as T?;
      }
      return null;
    }).toList();
  }
}

/* Uso, Rellenar inputs:
import 'package:buses2/core/services/users.UID.generico/get_datos_genericos.dart';
...
  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final data = await GetDatosGenericos.traerMap(
        absoluteDocPath: 'users/{uid}', // coleccion/documento infinito.
        nombreMap: 'taxista.datosTaxi', // map dentro de map infinito
      );

      if (data != null) {
        _marcaCtrl.text = data['marca'] ?? '';
        _modeloCtrl.text = data['modelo'] ?? '';
        _placaCtrl.text = data['placa'] ?? '';
        _colorCtrl.text = data['color'] ?? '';
      }
    } catch (e) {
      debugPrint('Error al cargar datos: $e');
    }
  }
*/

/* Rellenar inputs, de diferentes rutas:
Future<void> _cargarDatos() async {
  try {
    final results = await GetDatosGenericos.traerMap(
      absoluteDocPath: [
        'users/{uid}', // coleccion/documento infinito.
        'users/{uid}/backup/doc', // coleccion/documento infinito.
      ],
      nombreMap: [
        'taxista.datosTaxi', // map dentro de map infinito
        'empresa.detalles', // map dentro de map infinito
      ],
    );

    final datosTaxi = results[0]; // Rellena inputs con la 1ra ruta
    final datosEmpresa = results[1]; // Rellena inputs con la 2da ruta
    // Datos traidos con la 1ra ruta
    if (datosTaxi != null) {
      _marcaCtrl.text = datosTaxi['marca'] ?? '';
      _modeloCtrl.text = datosTaxi['modelo'] ?? '';
      _placaCtrl.text = datosTaxi['placa'] ?? '';
      _colorCtrl.text = datosTaxi['color'] ?? '';
    }
    // Datos traidos con la 2da ruta
    if (datosEmpresa != null) {
      _marcaCtrl.text = datosEmpresa['marca'] ?? '';
      _modeloCtrl.text = datosEmpresa['modelo'] ?? '';
      _placaCtrl.text = datosEmpresa['placa'] ?? '';
      _colorCtrl.text = datosEmpresa['color'] ?? '';
    }

    if (datosEmpresa != null) {
      debugPrint("Empresa: ${datosEmpresa['nombre']}");
    }
  } catch (e) {
    debugPrint('Error al cargar datos: $e');
  }
}
*/

/* Ejemplo de uso con un campo especifico, dentro de un input:
  Future<void> _cargarDatos() async {
    try {
      final placa = await GetDatosGenericos.traerCampo<String>(
        absoluteDocPath: 'users/{uid}',
        nombreMap: 'taxista.datosTaxi',
        nombreCampo: 'placa', // Trae un campo específico dentro
      );

      if (placa != null) {
        _placaCtrl.text = placa; // 👈 Asignar al input controlador
      }
    } catch (e) {
      debugPrint('Error al cargar datos: $e');
    }
  }
  ... Para que el valor aparesca en un texto ...
  Text('Placa: ${_placaCtrl.text.isEmpty ? '---' : _placaCtrl.text}',),
  ...
  TextInput2(
    controller: _placaCtrl, // controlador del input
    ...otros parametros
  ),
*/

/* Reemplaza un texto fijo por un valor real
Future<void> _cargarDatos() async {
  try {
    final placa = await GetDatosGenericos.traerCampo<String>(
      absoluteDocPath: 'users/{uid}',
      nombreMap: 'taxista.datosTaxi',
      nombreCampo: 'placa', // Trae un campo específico dentro
    );
  
    if (!mounted) return;
    setState(() {
      _placa = placa;
    });
  } catch (e) {
    debugPrint('Error al cargar datos: $e');
  }
}
...
Text(
  'PLaca: ${_placa ?? '---'}',
),
*/

/* Trer todos los documentos de una colección
  Future<void> _cargarDatos() async {
    try {
      final titulos = await GetDatosGenericos.traerCampoDeColeccion<String>(
        absoluteCollectionPath: 'empresas/{uid}/documentos',
        nombreMap: 'documentos',
        nombreCampo: 'tituloDoc',
      );

      if (!mounted) return;
      setState(() {
        _titulos = titulos.whereType<String>().toList();
      });
    } catch (e) {
      debugPrint('Error al cargar datos: $e');
    }
  }
*/
