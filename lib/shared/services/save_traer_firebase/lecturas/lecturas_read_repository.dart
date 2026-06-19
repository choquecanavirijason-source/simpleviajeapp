import 'dart:async';
import 'package:buses2/shared/services/save_traer_firebase/lecturas/doc.dart'
    as ds;
import 'parsear_map.dart'
    as gp; // 👈 IMPORT necesario para usar gp.ParseOptions y gp.extraerComoMap

// 👇 La page podrá usar ParseOptions y ChildParseOptions importando SOLO el repo
export 'parsear_map.dart' show ParseOptions, ChildParseOptions;

abstract class ILecturasReadRepository {
  Future<List<Map<String, dynamic>?>> getRaw({
    required List<String> absoluteDocPath,
    required List<String> nombreMap,
    List<Set<String>>? nombreCampo,
    Map<String, Map<String, String>> reglas,
  });

  Future<List<Map<String, dynamic>>> getAndParse({
    required List<String> absoluteDocPath,
    required List<String> nombreMap,
    List<Set<String>>? nombreCampo,
    Map<String, Map<String, String>> reglas,
    required gp.ParseOptions parse, // la PAGE manda el parse
  });
}

class LecturasReadRepository implements ILecturasReadRepository {
  const LecturasReadRepository();

  @override
  Future<List<Map<String, dynamic>?>> getRaw({
    required List<String> absoluteDocPath,
    required List<String> nombreMap,
    List<Set<String>>? nombreCampo,
    Map<String, Map<String, String>> reglas = const {},
  }) {
    return ds.DocGets.get(
      absoluteDocPath: absoluteDocPath,
      nombreMap: nombreMap,
      nombreCampo: nombreCampo,
      reglas: reglas,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getAndParse({
    required List<String> absoluteDocPath,
    required List<String> nombreMap,
    List<Set<String>>? nombreCampo,
    Map<String, Map<String, String>> reglas = const {},
    required gp.ParseOptions parse,
  }) async {
    final resRaw = await ds.DocGets.get(
      absoluteDocPath: absoluteDocPath,
      nombreMap: nombreMap,
      nombreCampo: nombreCampo,
      reglas: reglas,
    );
    return gp.extraerComoMap(resRaw: resRaw, options: parse);
  }
}

/*
import 'package:buses2/shared/services/save_traer_firebase/lecturas/lecturas_read_repository.dart';
import 'dart:convert'; 
...
  List<Map<String, dynamic>> _items = [];
  late final ILecturasReadRepository _repo;
  @override
  void initState() {
    super.initState();
    _repo = const LecturasReadRepository();
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
