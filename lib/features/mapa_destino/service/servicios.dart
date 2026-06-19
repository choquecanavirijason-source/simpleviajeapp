import 'dart:collection';
import '../../../shared/services/save_traer_firebase/lecturas/docGet.dart';
import '../data/models/servicio_empresa_model.dart';

final _cacheServicios = HashMap<String, List<ServicioEmpresa>>();
final _tsServicios = HashMap<String, DateTime>();
const _ttlServicios = Duration(minutes: 0);

// Empresa fija
const _empresaFija = 'mujeresalvolante';

String _kServicios(String departamento) =>
    '$_empresaFija|${departamento.trim().toLowerCase()}';

String _titleCaseSimple(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .toList();
  return parts
      .map(
        (w) => w.length <= 1
            ? w.toUpperCase()
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
      )
      .join(' ');
}

List<String> _docIdCandidates({String? pais, required String departamento}) {
  final depRaw = departamento.trim();
  final depLow = depRaw.toLowerCase();
  final depTitle = _titleCaseSimple(depRaw);
  final out = <String>[];

  void addId(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty || out.contains(s)) return;
    out.add(s);
  }

  final pRaw = (pais ?? '').trim();
  if (pRaw.isNotEmpty) {
    final pLow = pRaw.toLowerCase();
    final pTitle = _titleCaseSimple(pRaw);

    // Formato solicitado: {pais}__{departamento}
    addId('${pRaw}__$depRaw');
    addId('${pTitle}__$depTitle');
    addId('${pRaw}__$depTitle');
    addId('${pTitle}__$depRaw');
    addId('${pLow}__$depLow');

    // Formato nuevo esperado: {pais}_{departamento}
    addId('${pRaw}_$depRaw');
    addId('${pTitle}_$depTitle');
    addId('${pRaw}_$depTitle');
    addId('${pTitle}_$depRaw');
    addId('${pLow}_$depLow');
  }

  // Compatibilidad con formato anterior (solo departamento)
  addId(depRaw);
  addId(depLow);
  addId(depTitle);

  return out;
}

/// Obtiene los servicios disponibles en un departamento específico
Future<List<ServicioEmpresa>> serviciosDeEmpresaEnDepartamento({
  required String departamento,
  String? pais,
}) async {
  final deptoNormalizado = departamento.trim().toLowerCase();
  final docIds = _docIdCandidates(pais: pais, departamento: departamento);
  print('🔍 [Servicios] departamento recibido: "$departamento"');
  print('🔍 [Servicios] pais recibido: "${(pais ?? '').trim()}"');
  print('🔍 [Servicios] departamento normalizado: "$deptoNormalizado"');
  print('🔍 [Servicios] candidatos docId: $docIds');
  final key =
      '${_kServicios(departamento)}|${(pais ?? '').trim().toLowerCase()}';
  final now = DateTime.now();

  final cached = _cacheServicios[key];
  final ts = _tsServicios[key];
  if (cached != null && ts != null && now.difference(ts) < _ttlServicios) {
    print(
      '✅ [Servicios] desde caché (${cached.length}): ${cached.map((s) => s.servicio).toList()}',
    );
    return cached;
  }

  List<dynamic> res = const [];
  String? docUsado;
  for (final docId in docIds) {
    final ruta = 'empresas/$_empresaFija/tarifas/$docId';
    print('🔍 [Servicios] intentando ruta: $ruta');
    final intento = await DocGet.documentosGet(rutas: [ruta]);
    if (intento.isNotEmpty && intento.first['data'] != null) {
      res = intento;
      docUsado = docId;
      break;
    }
  }

  print('📦 [Servicios] respuesta de Firebase: ${res.length} documento(s)');
  if (docUsado != null) {
    print('✅ [Servicios] documento usado: $docUsado');
  } else {
    print(
      '⚠️ [Servicios] no se encontró documento para los candidatos: $docIds',
    );
  }

  final out = <ServicioEmpresa>[];
  if (res.isNotEmpty) {
    final data = res.first['data'] as Map<String, dynamic>?;
    print('📄 [Servicios] keys del documento: ${data?.keys.toList()}');

    if (data != null) {
      for (final entry in data.entries) {
        final raw = entry.value;
        if (raw is! Map<String, dynamic>) continue;
        final servicio = ServicioEmpresa.fromEntry(id: entry.key, raw: raw);

        print(
          '🧩 [Servicios] evaluando "${entry.key}": servicio="${servicio.servicio}", activo=${servicio.activo}, deptoModel="${servicio.departamento}", icono="${servicio.icono}", logo="${servicio.logo}"',
        );

        // Respeta el flag "activo" (por defecto true)
        if (!servicio.activo) {
          print(
            '⏭️ [Servicios] omitido por activo=false: ${servicio.servicio}',
          );
          continue;
        }

        // Si en el mapa viene un campo "departamento", debe coincidir
        final deptoMap = servicio.departamento;
        if (deptoMap != null && deptoMap.isNotEmpty) {
          if (deptoMap.toLowerCase() != deptoNormalizado) {
            print(
              '⏭️ [Servicios] omitido por depto no coincide: "${servicio.servicio}" => "$deptoMap" != "$deptoNormalizado"',
            );
            continue;
          }
        }

        print('✅ [Servicios] agregado: ${servicio.servicio}');
        out.add(servicio);
      }
    }
  }

  final list = List<ServicioEmpresa>.unmodifiable(out);
  print(
    '✅ [Servicios] encontrados (${list.length}): ${list.map((s) => s.servicio).toList()}',
  );
  _cacheServicios[key] = list;
  _tsServicios[key] = now;
  return list;
}

Future<List<ServicioEmpresa>> tarifasDeEmpresaEnDepartamento({
  required String departamento,
  String? pais,
}) async {
  final docIds = _docIdCandidates(pais: pais, departamento: departamento);
  List<dynamic> response = const [];
  for (final docId in docIds) {
    final intento = await DocGet.documentosGet(
      rutas: ["empresas/$_empresaFija/tarifas/$docId"],
    );
    if (intento.isNotEmpty && intento.first['data'] != null) {
      response = intento;
      break;
    }
  }

  if (response.isEmpty || response.first['data'] == null) {
    return [];
  }

  final data = response.first['data'] as Map<String, dynamic>;
  final listaDeServicios = <ServicioEmpresa>[];

  data.forEach((key, value) {
    if (value is! Map<String, dynamic>) return;

    final bool estaActivo = value['activo'] == true;
    final String? nombreServicio = value['servicio']?.toString();

    if (estaActivo && nombreServicio != null) {
      listaDeServicios.add(ServicioEmpresa.fromEntry(id: key, raw: value));
    }
  });

  return listaDeServicios;
}
