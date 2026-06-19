/// Opciones de parseo genéricas para cualquier mapa con hijos.
class ParseOptions {
  final String? nombreMapPadre;
  final String prefijoClaveHija;
  final String idKey;
  final Map<String, String> campos;
  final String? campoOrden;
  final bool requierenTodosLosCampos;
  final List<ChildParseOptions> children;

  const ParseOptions({
    this.nombreMapPadre,
    this.prefijoClaveHija = '',
    this.idKey = 'id',
    required this.campos,
    this.campoOrden,
    this.requierenTodosLosCampos = true,
    this.children = const [],
  });
}

class ChildParseOptions {
  final String nombreMapHijo;
  final String prefijoClaveHijo;
  final Map<String, String> campos;
  final String? campoOrden;
  final String idKey;
  final String outputKey;
  final bool requierenTodosLosCampos;

  const ChildParseOptions({
    required this.nombreMapHijo,
    required this.outputKey,
    this.prefijoClaveHijo = '',
    required this.campos,
    this.campoOrden,
    this.idKey = 'id',
    this.requierenTodosLosCampos = true,
  });
}

List<Map<String, dynamic>> extraerComoMap({
  required dynamic resRaw,
  required ParseOptions options,
}) {
  final lista = resRaw is List ? resRaw : [resRaw]; // asegura que sea lista[]
  final salida =
      <
        Map<String, dynamic>
      >[]; // guarda los maps que estan dentro del map padre, pero lo guarda en objetos.

  // Iterar el map recibido
  for (var item in lista) {
    dynamic mapAExplorar = item;
    if (options.nombreMapPadre != null &&
        mapAExplorar is Map &&
        mapAExplorar[options.nombreMapPadre] is Map) {
      mapAExplorar = mapAExplorar[options.nombreMapPadre];
    }
    if (mapAExplorar is! Map) continue;

    (mapAExplorar as Map).forEach((k, v) {
      if (v is! Map) return;
      if (options.prefijoClaveHija.isNotEmpty &&
          !k.toString().startsWith(options.prefijoClaveHija))
        return;

      final hijoDoc = v as Map;
      final normalizado = <String, dynamic>{options.idKey: k.toString()};

      bool faltante = false;
      options.campos.forEach((salidaKey, entradaKey) {
        final valor = hijoDoc[entradaKey];
        if (valor == null && options.requierenTodosLosCampos) {
          faltante = true;
          return;
        }
        normalizado[salidaKey] = valor;
      });
      if (faltante) return;

      // ---- Procesar hijos anidados (si hay) ----
      for (final child in options.children) {
        final origen = hijoDoc[child.nombreMapHijo];
        final listaHijos = <Map<String, dynamic>>[];

        if (origen is Map) {
          origen.forEach((ck, cv) {
            if (cv is! Map) return;
            if (child.prefijoClaveHijo.isNotEmpty &&
                !ck.toString().startsWith(child.prefijoClaveHijo))
              return;

            final m = cv as Map;
            final out = <String, dynamic>{child.idKey: ck.toString()};

            bool faltanteChild = false;
            child.campos.forEach((outKey, inKey) {
              final val = m[inKey];
              if (val == null && child.requierenTodosLosCampos) {
                faltanteChild = true;
                return;
              }
              out[outKey] = val;
            });
            if (!faltanteChild) listaHijos.add(out);
          });

          // Orden de los hijos (si aplica)
          if (child.campoOrden != null) {
            int toInt(dynamic x) {
              if (x is num) return x.toInt();
              return int.tryParse(x?.toString() ?? '') ?? (1 << 30);
            }

            listaHijos.sort(
              (a, b) => toInt(
                a[child.campoOrden],
              ).compareTo(toInt(b[child.campoOrden])),
            );
          }
        }

        normalizado[child.outputKey] = listaHijos;
      }
      // ------------------------------------------

      salida.add(normalizado);
    });
  }

  // Orden. ordenar si se indicó campoOrden
  if (options.campoOrden != null) {
    int toInt(dynamic x) {
      if (x is num) return x.toInt();
      return int.tryParse(x?.toString() ?? '') ?? (1 << 30);
    }

    salida.sort(
      (a, b) =>
          toInt(a[options.campoOrden]).compareTo(toInt(b[options.campoOrden])),
    );
  }

  return salida;
}

/* Ejemplo de uso:
final items = extraerComoMap(
  resRaw: resRaw,
  options: const ParseOptions(
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

setState(() {
  _items = items;
});
*/
