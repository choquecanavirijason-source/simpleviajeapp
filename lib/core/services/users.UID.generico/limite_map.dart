// /lib/core/services/users.UID.generico/limite_map.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:buses2/core/services/users.UID.generico/carga_datos_genericos.dart';

class LimiteMapService {
  LimiteMapService._();

  // Helpers internos
  static Map<String, dynamic>? _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  static DateTime _parseFechaFlexible(dynamic v, {String? fallbackKey}) {
    // 1) Timestamp de Firestore
    if (v is Timestamp) return v.toDate();

    // 2) String estilo "d-m-yyyy" o "d-m-yyyy H:m:s"
    if (v is String) {
      final parts = v.trim().split(RegExp(r'\s+'));
      final fecha = parts.isNotEmpty ? parts[0] : null;
      final hora = parts.length > 1 ? parts[1] : null;

      DateTime? dt;

      // fecha: d-m-yyyy
      if (fecha != null) {
        final f = fecha.split('-');
        if (f.length == 3) {
          final d = int.tryParse(f[0]);
          final m = int.tryParse(f[1]);
          final y = int.tryParse(f[2]);

          int hh = 0, mm = 0, ss = 0;
          if (hora != null) {
            final h = hora.split(':');
            if (h.isNotEmpty) hh = int.tryParse(h[0]) ?? 0;
            if (h.length > 1) mm = int.tryParse(h[1]) ?? 0;
            if (h.length > 2) ss = int.tryParse(h[2]) ?? 0;
          }
          if (y != null && m != null && d != null) {
            dt = DateTime(y, m, d, hh, mm, ss);
          }
        }
      }
      if (dt != null) return dt;
    }

    // 3) Si no hubo 'fecha' válido, tratar de usar el 'fallbackKey' (ej. la key del map)
    if (fallbackKey != null) {
      return _parseFechaFlexible(fallbackKey);
    }

    // 4) Último recurso: Epoch
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Lee un documento en `absoluteDocPath` cuyo `data` es un MAP de MAPs
  /// (ej.: keys "29-8-2025 11:16:46" -> {fecha, monto, estado, ...})
  ///
  /// Devuelve SOLO `limit` entradas, ordenadas por `fecha` (si existe) o por la key.
  /// `includeKeyFieldName`: si no es null, se inserta la key original bajo ese nombre.
  static Future<List<Map<String, dynamic>>> fetchLimitedAbs(
    String absoluteDocPath, {
    int limit = 3,
    bool descending = true,
    String? includeKeyFieldName = '__key',
    String innerFechaField = 'fecha',
  }) async {
    final doc = await UidColeccionDoc.fetchAbsPath(absoluteDocPath);
    if (doc == null || doc.isEmpty) return <Map<String, dynamic>>[];

    // Ignorar la key 'id' del doc y quedarnos con los mapas válidos
    final entries = <MapEntry<String, Map<String, dynamic>>>[];

    for (final e in doc.entries) {
      final k = e.key;
      if (k == 'id') continue;
      final m = _asMap(e.value);
      if (m == null) continue;
      entries.add(MapEntry(k, m));
    }

    // Ordenar por 'fecha' (si existe); fallback: por la key
    entries.sort((a, b) {
      final fa = _parseFechaFlexible(
        a.value[innerFechaField],
        fallbackKey: a.key,
      );
      final fb = _parseFechaFlexible(
        b.value[innerFechaField],
        fallbackKey: b.key,
      );
      final cmp = fa.compareTo(fb);
      return descending ? -cmp : cmp;
    });

    // Limitar
    final sliced = entries.take(limit);

    // Devolver como lista de mapas (opcionalmente incluyendo la key original)
    final out = <Map<String, dynamic>>[];
    for (final e in sliced) {
      final m = Map<String, dynamic>.from(e.value);
      if (includeKeyFieldName != null && includeKeyFieldName.isNotEmpty) {
        m[includeKeyFieldName] = e.key;
      }
      out.add(m);
    }
    return out;
  }
}

/* ejemplo de uso:
void initState() {
  super.initState();
  // Ejecuta después del primer frame para no bloquear el build
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _cargarYLoguear();
  });
}

Future<void> _cargarYLoguear() async {
  try {

    // === Rutas de las colecciones y doc ===
    final rutaDoc = 'users/{uid}';

    await UidColeccionDoc.debugAbsDoc(rutaDoc);
    final doc = await UidColeccionDoc.fetchAbsPath(rutaDoc);
    debugPrint('👉 DOC ($rutaDoc): $doc');
    
    // === Limite Map ===
    const cuantos = 1; // cuántos mapas quieres
    final ultimos = await LimiteMapService.fetchLimitedAbs(
      rutaDoc,
      limit: cuantos,
      descending: true,            // más recientes primero
      includeKeyFieldName: '__key' // opcional: guarda la key original
    );
    debugPrint('👉 ULTIMOS ($cuantos): $ultimos');
    
    // Ejemplo: si quieres solo mostrar campos específicos de los maps
    for (final item in ultimos) {
      debugPrint('• ${item['estado']} | ${item['monto']} | fecha=${item['fecha']} | key=${item['__key']}');
    }
    // === Limite Map ===

  } catch (e, st) {
    debugPrint('❌ Error: $e');
    debugPrint('$st');
  }
}
*/
