/// devuelve todos los [campo: valor] que se pida desde el page, en cualquier profundidad del doc.
/// Si [todasCoincidencias] es true, devuelve todas las coincidencias (varios por campo).
/// campos: ej. ['info'] o ['info','detalles',...]
/// [V.1.0.0]

// lib/shared/services/save_traer_firebase/helpers/buscar_campo.dart
class BuscarCampo {
  static List<Map<String, dynamic>> extraerGrupos(
    List<Map<String, dynamic>> docs,
    List<String> campos, {
    bool requiereTodos = true,
  }) {
    final out = <Map<String, dynamic>>[];
    final seen = <String>{};

    String _keyOf(Map<String, dynamic> m) =>
        campos.map((c) => (m[c] == null) ? '∅' : m[c].toString()).join('||');

    void _visit(
      dynamic node,
      Map<String, dynamic> ctx,
      List<String> kpath,
      String docId,
    ) {
      if (node is Map) {
        // 1) acumular valores de este nodo sobre el contexto heredado
        final next = Map<String, dynamic>.from(ctx);
        for (final c in campos) {
          if (node.containsKey(c)) next[c] = node[c];
        }

        // 2) ¿cumple?
        final ok = requiereTodos
            ? campos.every((c) => next.containsKey(c))
            : campos.any((c) => next.containsKey(c));

        if (ok) {
          final hit = <String, dynamic>{};
          for (final c in campos) {
            if (next.containsKey(c)) hit[c] = next[c];
          }
          // metadatos para poder escribir luego
          hit['__docId'] = docId;
          hit['__path'] = kpath.join(
            '-',
          ); // ej. "taxi" ó "moto_taxi-servicios" si fuera más profundo

          final k = _keyOf(hit);
          if (!seen.contains(k)) {
            seen.add(k);
            out.add(hit);
          }
        }

        // 3) bajar
        node.forEach((k, v) {
          if (k is String) {
            _visit(v, next, [...kpath, k], docId);
          } else {
            _visit(v, next, kpath, docId);
          }
        });
      } else if (node is List) {
        for (final e in node) _visit(e, ctx, kpath, docId);
      }
    }

    for (final doc in docs) {
      final data = doc['data'];
      final id = (doc['id'] ?? '').toString();
      if (data != null) _visit(data, const {}, <String>[], id);
    }
    return out;
  }

  static List<Map<String, dynamic>> extraerNodosCon(
    List<Map<String, dynamic>> docs,
    List<String> campos, {
    bool requiereTodos = true,
  }) {
    return extraerGrupos(docs, campos, requiereTodos: requiereTodos);
  }
}
