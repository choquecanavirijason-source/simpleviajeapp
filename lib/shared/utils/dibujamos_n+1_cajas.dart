import 'package:flutter/widgets.dart';

/*
  - Cuando recibimos una lista de datos, podemos crear o
    dibujar n+1 cajas con un separador entre ellas.
*/
typedef ItemWidgetBuilder<T> = Widget Function(T item, int index);

List<Widget> buildSeparated<T>(
  List<T> items, {
  required ItemWidgetBuilder<T> itemBuilder,
  double gap = 6.0,
}) {
  final out = <Widget>[];
  for (var i = 0; i < items.length; i++) {
    out.add(itemBuilder(items[i], i));
    if (i != items.length - 1) out.add(SizedBox(height: gap));
  }
  return out;
}

/* ===========================
   MERGE POR docId (genérico)
   =========================== */

/// Fuente de datos a mergear por docId.
/// - `data`: mapa del tipo { docId: {campo: valor, ...} }
/// - `fields`: qué campos copiar de esta ruta (los null se ignoran)
class DocRoute {
  final Map<String, dynamic>? data;
  final Set<String> fields;
  const DocRoute({required this.data, required this.fields});
}

/// Mezcla N rutas por `docId` y devuelve una lista para la UI.
/// - `routes`: lista de fuentes (DocRoute)
/// - `idKey`: nombre de la clave id que se colocará en cada ítem
/// - `orderKey`: si existe y es numérico, se usa para ordenar asc (los que no tengan van al final)
List<Map<String, dynamic>> mergeByDocId({
  required List<DocRoute> routes,
  String idKey = 'id',
  String orderKey = 'orden',
}) {
  final acc = <String, Map<String, dynamic>>{};

  for (final r in routes) {
    (r.data ?? {}).forEach((docId, src) {
      if (src is! Map<String, dynamic>) return;
      final dst = acc.putIfAbsent(docId, () => {idKey: docId});
      for (final k in r.fields) {
        final v = src[k];
        if (v != null) dst[k] = v;
      }
    });
  }

  final list = acc.values.toList();

  // Orden opcional por 'orden'
  list.sort((a, b) {
    final ao = (a[orderKey] is num) ? (a[orderKey] as num).toInt() : 0x7fffffff;
    final bo = (b[orderKey] is num) ? (b[orderKey] as num).toInt() : 0x7fffffff;
    return ao.compareTo(bo);
  });

  return list;
}

/* Ejemplo de uso:
final List<Map<String, dynamic>> _items = [];
...

...
// Dentro del UI
children: buildSeparated<Map<String, dynamic>>(
  _items,
  gap: 9,
  itemBuilder: (m, i) => CajaBoton(
    title: m['nombreBtn'] ?? '',
    subtitle: m['subtituloBtn'] ?? '',
    rightIcon: Icons.hourglass_top,
    rightIconColor: Colors.orange,
    textAlign: TextAlign.start,
    columnAlignment: CrossAxisAlignment.start,
    onTap: () {
      final titulo = m['tituloDoc'] ?? '';
      final etiquetas = {'docId': m['id']}; // lo que necesites pasar
      Modular.to.pushNamed(
        '/page-generica-taxi',
        arguments: {
          'tituloDoc': titulo,
          'etiqueta': etiquetas,
        },
      );
    },
  ),
),
*/
