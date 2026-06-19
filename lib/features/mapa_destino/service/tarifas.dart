import 'dart:collection';
import '../../../shared/services/save_traer_firebase/lecturas/docGet.dart';
import '../data/models/servicio_empresa_model.dart' as m;

class Tarifa {
  final double distanciaBase;
  final double horaPicoExtra;
  final double nocturno;
  final double porKm;
  final double porMin;
  final double tarifaBase;

  const Tarifa({
    required this.distanciaBase,
    required this.horaPicoExtra,
    required this.nocturno,
    required this.porKm,
    required this.porMin,
    required this.tarifaBase,
  });

  static double _d(Object? v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  factory Tarifa.fromTarifasMap(Map<String, dynamic>? t) => Tarifa(
    distanciaBase: _d(t?['distanciaBase']),
    horaPicoExtra: _d(t?['horaPicoExtra']),
    nocturno: _d(t?['nocturno']),
    porKm: _d(t?['porKm']),
    porMin: _d(t?['porMin']),
    tarifaBase: _d(t?['tarifaBase']),
  );
}

// -------- Se guarda la tarifa en caché por 5 minutos ----------
final _cacheTarifa = HashMap<String, Tarifa>();
final _tsTarifa = HashMap<String, DateTime>();
const _ttlTarifa = Duration(minutes: 3);
String _kTarifa(String empresaId, String departamento, String servicio) =>
    '$empresaId|$departamento|${servicio.toLowerCase().trim()}';

/// Normaliza el nombre de un servicio para comparar: minúsculas, sin acentos
/// y sin espacios ni guiones bajos. Así "Conductor Designado",
/// "conductor_designado" y "conductordesignado" matchean igual.
/// Público para que la UI matchee el servicio seleccionado igual que el backend.
String normalizarNombreServicio(String s) => _normServicio(s);

String _normServicio(String s) {
  const acentos = {
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n',
  };
  final lower = s.toLowerCase().trim();
  final buf = StringBuffer();
  for (final ch in lower.split('')) {
    buf.write(acentos[ch] ?? ch);
  }
  return buf.toString().replaceAll(RegExp(r'[\s_]+'), '');
}

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

    addId('${pRaw}__$depRaw');
    addId('${pTitle}__$depTitle');
    addId('${pRaw}__$depTitle');
    addId('${pTitle}__$depRaw');
    addId('${pLow}__$depLow');

    addId('${pRaw}_$depRaw');
    addId('${pTitle}_$depTitle');
    addId('${pRaw}_$depTitle');
    addId('${pTitle}_$depRaw');
    addId('${pLow}_$depLow');
  }

  addId(depRaw);
  addId(depLow);
  addId(depTitle);
  return out;
}

/// Obtiene la tarifa de un servicio específico en un departamento
Future<Tarifa?> tarifaDeServicioEnDepartamento({
  required String empresaId,
  required String departamento,
  String? pais,
  required String servicio,
}) async {
  final key =
      '${_kTarifa(empresaId, departamento, servicio)}|${(pais ?? '').trim().toLowerCase()}';
  final now = DateTime.now();

  final cached = _cacheTarifa[key];
  final ts = _tsTarifa[key];
  if (cached != null && ts != null && now.difference(ts) < _ttlTarifa) {
    return cached;
  }

  final docIds = _docIdCandidates(pais: pais, departamento: departamento);
  List<dynamic> res = const [];
  for (final docId in docIds) {
    final intento = await DocGet.documentosGet(
      rutas: ["empresas/$empresaId/tarifas/$docId"],
    );
    if (intento.isNotEmpty && intento.first['data'] != null) {
      res = intento;
      break;
    }
  }
  if (res.isEmpty) return null;

  final data = res.first['data'] as Map<String, dynamic>?;
  if (data == null) return null;

  final target = _normServicio(servicio);
  for (final entry in data.entries) {
    final v = entry.value;
    if (v is Map<String, dynamic>) {
      final byServicio = _normServicio((v['servicio'] as String?) ?? '');
      final byKey = _normServicio(entry.key);
      if (target.isNotEmpty && (byServicio == target || byKey == target)) {
        final tarifasMap = v['tarifas'] as Map<String, dynamic>?;
        final t = Tarifa.fromTarifasMap(tarifasMap);
        _cacheTarifa[key] = t;
        _tsTarifa[key] = now;
        return t;
      }
    }
  }
  return null;
}

// ================== HORAS PICO + COMBO (1 sola lectura) ==================

class HoraPicoFranja {
  final Duration desde; // ej. "07:00" -> Duration(hours: 7)
  final Duration hasta; // ej. "09:00" -> Duration(hours: 9)
  const HoraPicoFranja({required this.desde, required this.hasta});
}

class HorasPico {
  final List<HoraPicoFranja> franjas;
  const HorasPico(this.franjas);
}

class TarifaYHorasPico {
  final Tarifa tarifa;
  final HorasPico horasPico;
  const TarifaYHorasPico({required this.tarifa, required this.horasPico});
}

Duration _parseHHmm(Object? v) {
  if (v == null) return const Duration();
  final s = v.toString().trim();
  if (s.isEmpty) return const Duration();
  final parts = s.split(':');
  int h = 0, m = 0;
  try {
    if (parts.isNotEmpty) h = int.parse(parts[0]);
    if (parts.length > 1) m = int.parse(parts[1]);
  } catch (_) {
    return const Duration();
  }
  h = h.clamp(0, 23);
  m = m.clamp(0, 59);
  return Duration(hours: h, minutes: m);
}

// --- cache combinado (tarifa + horas pico) ---
final _cacheTarifaHP = HashMap<String, TarifaYHorasPico>();
final _tsTarifaHP = HashMap<String, DateTime>();
const _ttlTarifaHP = Duration(minutes: 3);
String _kTarifaHP(String empresaId, String ciudad, String servicio) =>
    '$empresaId|$ciudad|${servicio.toLowerCase().trim()}';

/// UNA SOLA LECTURA al doc /empresas/{empresaId}/tarifas/{ciudad}
/// Devuelve: Tarifa (submapa 'tarifas') + Horas Pico (submapa 'Horas_pico')
Future<TarifaYHorasPico?> tarifaYHorasPicoDeServicioEnCiudad({
  required String empresaId,
  required String ciudad,
  required String servicio,
}) async {
  final key = _kTarifaHP(empresaId, ciudad, servicio);
  final now = DateTime.now();

  final cached = _cacheTarifaHP[key];
  final ts = _tsTarifaHP[key];
  if (cached != null && ts != null && now.difference(ts) < _ttlTarifaHP) {
    return cached;
  }

  // === 1 sola lectura ===
  final res = await DocGet.documentosGet(
    rutas: ["empresas/$empresaId/tarifas/$ciudad"],
  );
  if (res.isEmpty) return null;

  final data = res.first['data'] as Map<String, dynamic>?;
  if (data == null) return null;

  final target = _normServicio(servicio);
  Tarifa? t;
  final franjas = <HoraPicoFranja>[];

  for (final entry in data.entries) {
    final v = entry.value;
    if (v is Map<String, dynamic>) {
      final byServicio = _normServicio((v['servicio'] as String?) ?? '');
      final byKey = _normServicio(entry.key);
      if (target.isNotEmpty && (byServicio == target || byKey == target)) {
        // tarifas
        final tarifasMap = v['tarifas'] as Map<String, dynamic>?;
        t = Tarifa.fromTarifasMap(tarifasMap);

        // horas pico
        final hp = v['Horas_pico'] as Map<String, dynamic>?;
        final list = hp?['franjas'];
        if (list is List) {
          for (final f in list) {
            if (f is Map<String, dynamic>) {
              franjas.add(
                HoraPicoFranja(
                  desde: _parseHHmm(f['desde']),
                  hasta: _parseHHmm(f['hasta']),
                ),
              );
            }
          }
        }
        break;
      }
    }
  }

  if (t == null) return null;

  final combo = TarifaYHorasPico(tarifa: t, horasPico: HorasPico(franjas));
  _cacheTarifaHP[key] = combo;
  _tsTarifaHP[key] = now;
  return combo;
}

/// Helper por si luego quieres saber si AHORA cae en alguna franja pico.
/// Maneja rangos que cruzan medianoche (ej: 22:00-05:30).
bool esHoraPicoAhora(HorasPico hp, DateTime momento) {
  final t = Duration(hours: momento.hour, minutes: momento.minute);

  bool dentro(Duration ini, Duration fin) {
    if (ini <= fin) {
      return t >= ini && t <= fin;
    }
    // cruza medianoche
    return t >= ini || t <= fin;
  }

  for (final fr in hp.franjas) {
    if (dentro(fr.desde, fr.hasta)) return true;
  }
  return false;
}

// ================== AEROPUERTO + (Tarifa + Horas Pico) EN 1 LECTURA ==================

// --- Aeropuerto ---
class AeropuertoTramo {
  final double desdeKm; // umbral (<= desdeKm)
  final double precio; // precio fijo
  const AeropuertoTramo({required this.desdeKm, required this.precio});
}

class AeropuertoTarifas {
  final List<AeropuertoTramo> tramos; // lista dinámica por empresa
  const AeropuertoTarifas(this.tramos);
}

// --- Ya definidos arriba: Tarifa, HoraPicoFranja, HorasPico ---
// Combinamos TODO en un solo DTO:
class TarifaHorasPicoAeropuerto {
  final Tarifa tarifa;
  final HorasPico horasPico;
  final AeropuertoTarifas aeropuerto;
  const TarifaHorasPicoAeropuerto({
    required this.tarifa,
    required this.horasPico,
    required this.aeropuerto,
  });
}

// --- Cache para el combo ---
final _cacheTHPA = HashMap<String, TarifaHorasPicoAeropuerto>();
final _tsTHPA = HashMap<String, DateTime>();
const _ttlTHPA = Duration(minutes: 3);
String _kTHPA(String empresaId, String departamento, String servicio) =>
    '$empresaId|$departamento|${servicio.toLowerCase().trim()}';

/// UNA SOLA LECTURA al doc /empresas/{empresaId}/tarifas/{departamento}
/// Devuelve: Tarifa (submapa 'tarifas') + Horas Pico (submapa 'Horas_pico')
///           + Aeropuerto (submapa 'Tarifas_Aeropuerto' -> 'tramos')
Future<TarifaHorasPicoAeropuerto?>
tarifaHorasPicoAeropuertoDeServicioEnDepartamento({
  required String empresaId,
  required String departamento,
  String? pais,
  required String servicio,
}) async {
  final key =
      '${_kTHPA(empresaId, departamento, servicio)}|${(pais ?? '').trim().toLowerCase()}';
  final now = DateTime.now();

  final cached = _cacheTHPA[key];
  final ts = _tsTHPA[key];
  if (cached != null && ts != null && now.difference(ts) < _ttlTHPA) {
    return cached;
  }

  // === 1 SOLA LECTURA ===
  final docIds = _docIdCandidates(pais: pais, departamento: departamento);
  List<dynamic> res = const [];
  for (final docId in docIds) {
    final intento = await DocGet.documentosGet(
      rutas: ["empresas/$empresaId/tarifas/$docId"],
    );
    if (intento.isNotEmpty && intento.first['data'] != null) {
      res = intento;
      break;
    }
  }
  if (res.isEmpty) return null;

  final data = res.first['data'] as Map<String, dynamic>?;
  if (data == null) return null;

  final target = _normServicio(servicio);
  Tarifa? t;
  final franjas = <HoraPicoFranja>[];
  final tramos = <AeropuertoTramo>[];

  // ✅ Matchea por el campo `servicio` O por la CLAVE de la entrada, de forma
  // tolerante (sin espacios/guiones bajos/acentos). Esto evita que servicios
  // cuyo `label` proviene de la clave (sin campo `servicio`) o con nombre
  // ligeramente distinto se queden sin tarifa.
  for (final entry in data.entries) {
    final v = entry.value;
    if (v is Map<String, dynamic>) {
      final byServicio = _normServicio((v['servicio'] as String?) ?? '');
      final byKey = _normServicio(entry.key);
      if (target.isNotEmpty && (byServicio == target || byKey == target)) {
        // ----- tarifas -----
        final tarifasMap = v['tarifas'] as Map<String, dynamic>?;
        t = Tarifa.fromTarifasMap(tarifasMap);

        // ----- horas pico -----
        final hp = v['Horas_pico'] as Map<String, dynamic>?;
        final listHP = hp?['franjas'];
        if (listHP is List) {
          for (final f in listHP) {
            if (f is Map<String, dynamic>) {
              franjas.add(
                HoraPicoFranja(
                  desde: _parseHHmm(f['desde']),
                  hasta: _parseHHmm(f['hasta']),
                ),
              );
            }
          }
        }

        // ----- aeropuerto -----
        final ap = v['Tarifas_Aeropuerto'] as Map<String, dynamic>?;
        final listAP = ap?['tramos'];
        if (listAP is List) {
          for (final f in listAP) {
            if (f is Map<String, dynamic>) {
              final dk = (f['desdeKm'] is num)
                  ? (f['desdeKm'] as num).toDouble()
                  : (f['desdeKm'] is String
                        ? double.tryParse(f['desdeKm']) ?? 0.0
                        : 0.0);
              final p = (f['precio'] is num)
                  ? (f['precio'] as num).toDouble()
                  : (f['precio'] is String
                        ? double.tryParse(f['precio']) ?? 0.0
                        : 0.0);
              tramos.add(AeropuertoTramo(desdeKm: dk, precio: p));
            }
          }
        }
        break;
      }
    }
  }

  if (t == null) return null;

  // Ordena tramos por umbral (ascendente) para búsquedas predecibles
  tramos.sort((a, b) => a.desdeKm.compareTo(b.desdeKm));

  final combo = TarifaHorasPicoAeropuerto(
    tarifa: t,
    horasPico: HorasPico(franjas),
    aeropuerto: AeropuertoTarifas(tramos),
  );
  _cacheTHPA[key] = combo;
  _tsTHPA[key] = now;
  return combo;
}

/// ✅ Construye el combo (Tarifa + Horas pico + Aeropuerto) DIRECTAMENTE desde
/// un `ServicioEmpresa` ya cargado (misma lectura que llenó la lista de
/// servicios). Evita una segunda lectura a Firestore y el re-match por nombre,
/// que fallaba cuando el servicio no tenía campo `servicio` (nombre derivado de
/// la clave) o difería en mayúsculas/acentos/guiones bajos.
TarifaHorasPicoAeropuerto comboDesdeServicioEmpresa(m.ServicioEmpresa s) {
  final t = s.tarifas;
  final tarifa = Tarifa(
    distanciaBase: (t?.distanciaBase ?? 0).toDouble(),
    horaPicoExtra: (t?.horaPicoExtra ?? 0).toDouble(),
    nocturno: (t?.nocturno ?? 0).toDouble(),
    porKm: (t?.porKm ?? 0).toDouble(),
    porMin: (t?.porMin ?? 0).toDouble(),
    tarifaBase: (t?.tarifaBase ?? 0).toDouble(),
  );

  final franjas = <HoraPicoFranja>[];
  for (final f in s.horasPico?.franjas ?? const <m.HorasPicoFranja>[]) {
    franjas.add(
      HoraPicoFranja(desde: _parseHHmm(f.desde), hasta: _parseHHmm(f.hasta)),
    );
  }

  final tramos = <AeropuertoTramo>[];
  for (final tr in s.tarifasAeropuerto?.tramos ?? const <m.TramoAeropuerto>[]) {
    tramos.add(
      AeropuertoTramo(
        desdeKm: double.tryParse(tr.desdeKm) ?? 0.0,
        precio: tr.precio.toDouble(),
      ),
    );
  }
  tramos.sort((a, b) => a.desdeKm.compareTo(b.desdeKm));

  return TarifaHorasPicoAeropuerto(
    tarifa: tarifa,
    horasPico: HorasPico(franjas),
    aeropuerto: AeropuertoTarifas(tramos),
  );
}

/// Dado un set de tramos de aeropuerto y la distancia, retorna el precio fijo.
/// Regla: toma el PRIMER tramo cuyo `distanciaKm <= desdeKm`.
/// Si no cae en ninguno, devuelve el precio del ÚLTIMO tramo (el mayor).
double precioAeropuertoPorDistancia(AeropuertoTarifas ap, double distanciaKm) {
  if (ap.tramos.isEmpty) return 0.0;
  for (final t in ap.tramos) {
    if (distanciaKm <= t.desdeKm) return t.precio;
  }
  return ap.tramos.last.precio;
}

/*
import '../service/tarifas.dart'; // mismo archivo

final combo = await tarifaYHorasPicoDeServicioEnCiudad(
  empresaId: empresaId,
  ciudad: 'Cochabamba',
  servicio: 'Taxi',
);

if (combo != null) {
  final t = combo.tarifa;
  final hp = combo.horasPico;

  // Variables de tarifa
  final base        = t.tarifaBase;
  final porKm       = t.porKm;
  final porMin      = t.porMin;
  final distBase    = t.distanciaBase;
  final nocturnoBs  = t.nocturno;
  final horaPicoPct = t.horaPicoExtra;

  // Franjas dinámicas de hora pico (0..N)
  final List<HoraPicoFranja> franjas = hp.franjas;

  // (si quieres saber si ahora es pico)
  // final bool ahoraPico = esHoraPicoAhora(hp, DateTime.now());
}
*/
