import 'package:cloud_firestore/cloud_firestore.dart';
import '../reemplazar/reemplazar.dart';

/* Asi funciona Firebase
*- doc.get() = lectura del doc 1 vez
*- doc.snapshots() = escucha el doc en tiempo real. 1 lectura +1 cada vez que cambia
/- coleccion.get() = lectura de todos los docs 1 vez. 1 lectura por cada doc
/- collection.where(...).get() = mira una colección y devuelve los docs que cumplen el filtro.
  1 lectura por cada doc que devuelve
/- collection.where(...).snapshots() = escucha en tiempo real los docs que cumplen el filtro
  1 lectura por cada doc que devuelve +1 cada vez que cambia alguno
/+ collectionGroup.get() = consulta todas las subcolecciones con un mismo nombre 1 vez.
  1 lectura por cada doc que devuelve
/+ collectionGroup.where(...).get() = consulta todas las subcolecciones con un mismo nombre y devuelve los docs que cumplen el filtro.
  1 lectura por cada doc que devuelve
/+ collectionGroup.where(...).snapshots() = escucha en vivo todas las subcolecciones con un mismo nombre que cumplen el filtro.
  1 lectura por cada doc que devuelve +1 cada vez que cambia alguno
*/
/*
✅ Resumen práctico:
*- doc.get() → una vez, rápido, startup/init.
*- doc.snapshots() → en vivo, se actualiza automáticamente.
/- collection.get() → trae todo (peligroso si hay muchos).
/- collection.where(...).get() → una vez, con filtro.
/- collection.where(...).snapshots() → en vivo, con filtro.
/+ collectionGroup.get() → trae todo de subcolecciones con mismo nombre (peligroso si hay muchos).
/+ collectionGroup.where(...).get() → una vez, con filtro, de subcolecciones con mismo nombre.
/+ collectionGroup.where(...).snapshots() → en vivo, con filtro, de subcolecciones con mismo nombre.
*/

class DocGets {
  static final _db = FirebaseFirestore.instance;

  // Helpers mínimos
  static Future<DocumentSnapshot<Map<String, dynamic>>> _snap(String ruta) =>
      _db.doc(ruta).get();

  static Object? _pick(Map<String, dynamic>? root, String rutaGuion) {
    if (root == null) return null;
    if (rutaGuion.isEmpty || rutaGuion == '@root') return root;
    Object? cur = root;
    for (final p in rutaGuion.split('-')) {
      if (cur is Map<String, dynamic> && cur.containsKey(p)) {
        cur = cur[p];
      } else {
        return null;
      }
    }
    return cur;
  }

  static String _rutaCompuesta(String nombreMap, String nombreCampo) {
    if (nombreMap == '@root' || nombreMap.isEmpty) return nombreCampo;
    if (nombreCampo.isEmpty) return nombreMap;
    return '$nombreMap-$nombreCampo';
  }

  static Map<String, dynamic>? _filtrarCampos(
    Map<String, dynamic>? base,
    Set<String>? campos,
  ) {
    if (base == null) return null;
    if (campos == null) return base;
    final out = <String, dynamic>{};
    for (final c in campos) {
      final v = base[c];
      out[c] = (v != null && v is! Map) ? v : null;
    }
    return out;
  }

  // 🔹 GET simple
  static Future<List<Map<String, dynamic>?>> get({
    required List<String> absoluteDocPath,
    required List<String> nombreMap,
    List<Set<String>>? nombreCampo,
    Map<String, Map<String, String>> reglas = const {},
  }) async {
    if (absoluteDocPath.length != nombreMap.length) {
      throw Exception(
        'absoluteDocPath y nombreMap deben tener la misma longitud.',
      );
    }
    if (nombreCampo != null && absoluteDocPath.length != nombreCampo.length) {
      throw Exception(
        'Si pasas nombreCampo, su longitud debe coincidir con absoluteDocPath y nombreMap.',
      );
    }

    // 1) Resolver placeholders (empresaID, uid, etc.)
    final rutas = await Future.wait(
      absoluteDocPath.map((r) => Reemplazar.resolverRuta(r, reglas: reglas)),
    );

    // 2) Un solo get por doc
    final snaps = await Future.wait(rutas.map(_snap));

    // 3) Armar salida
    final out = <Map<String, dynamic>?>[];
    for (int i = 0; i < snaps.length; i++) {
      final data = snaps[i].data();
      final mapPath = nombreMap[i];
      final camposPed = nombreCampo == null ? null : nombreCampo[i];

      final base = _pick(data, mapPath);
      final pieza = _filtrarCampos(
        base is Map<String, dynamic> ? base : null,
        camposPed,
      );

      out.add(pieza);
    }
    return out;
  }

  // 🔹 EXISTE simple
  static Future<List<bool>> existe({
    required List<String> absoluteDocPath,
    required List<String> nombreMap,
    List<Set<String>>? nombreCampo,
    Map<String, Map<String, String>> reglas = const {},
  }) async {
    if (absoluteDocPath.length != nombreMap.length) {
      throw Exception(
        'absoluteDocPath y nombreMap deben tener la misma longitud.',
      );
    }
    if (nombreCampo != null && absoluteDocPath.length != nombreCampo.length) {
      throw Exception(
        'Si pasas nombreCampo, su longitud debe coincidir con absoluteDocPath y nombreMap.',
      );
    }

    final rutas = await Future.wait(
      absoluteDocPath.map((r) => Reemplazar.resolverRuta(r, reglas: reglas)),
    );
    final snaps = await Future.wait(rutas.map(_snap));

    final res = <bool>[];
    for (int i = 0; i < snaps.length; i++) {
      final snap = snaps[i];
      final data = snap.data();

      if (nombreCampo == null) {
        if (nombreMap[i] == '@root') {
          res.add(snap.exists);
        } else {
          final base = _pick(data, nombreMap[i]);
          res.add(base is Map<String, dynamic>);
        }
        continue;
      }

      bool allExist = true;
      for (final c in nombreCampo[i]) {
        final ruta = _rutaCompuesta(nombreMap[i], c);
        final v = _pick(data, ruta);
        final ok = (v != null && v is! Map);
        allExist &= ok;
        if (!allExist) break;
      }
      res.add(allExist);
    }
    return res;
  }
}

/*
import 'package:buses2/shared/services/save_traer_firebase/lecturas/lecturas_read_repository.dart';
...
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final reglas = {
      'empresaID': {'doc': 'pasajeros/{uid}', 'field': 'uidEmpresa'},
    };

    final docs = await _repo.getAndParse(
      absoluteDocPath: ['empresas/{empresaID}'],
      nombreMap: ['documentos'],
      reglas: reglas,
      parse: ParseOptions( // ← la PAGE define el parse
        nombreMapPadre: 'documentos',
        prefijoClaveHija: 'doc_',
        campoOrden: 'orden',
        idKey: 'id',
        campos: {
          'nombreBtn': 'nombreBtn',
          'subtituloBtn': 'subtituloBtn',
          'tituloDoc': 'tituloDoc',
          'orden': 'orden',
        },
        children: [
          ChildParseOptions(
            nombreMapHijo: 'camposTexto',
            outputKey: 'textos',          // <- cómo quieres llamarlo en el resultado
            prefijoClaveHijo: 'campo_',
            campoOrden: 'orden',
            idKey: 'id',
            campos: {
              'etiqueta': 'etiqueta',
              'tipo': 'tipo',
              'orden': 'orden',
            },
          ),
          ChildParseOptions(
            nombreMapHijo: 'camposArchivo',
            outputKey: 'archivos',
            prefijoClaveHijo: 'file_',
            campoOrden: 'orden',
            idKey: 'id',
            campos: {
              'etiqueta': 'etiqueta',
              'tipo': 'tipo',
              'orden': 'orden',
            },
          ),
        ],
      ),
    );

    debugPrint('📦 docs: ${jsonEncode(docs)}');
    // esto solo 
    if (!mounted) return;
    setState(() => _items = docs);
  }

*/
