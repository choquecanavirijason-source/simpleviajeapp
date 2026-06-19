// LÓGICA PURA (sin imports de UI)
class AdaptadorDatos {
  /// Mapea nodos -> llaves de salida según [mapSalida]
  /// Ej: mapSalida: { 'titulo': 'otroDato', 'activo': 'activo' }
  static List<Map<String, dynamic>> construir(
    List<Map<String, dynamic>> nodos, {
    required Map<String, String> mapSalida,
  }) {
    final items = <Map<String, dynamic>>[];

    for (final nodo in nodos) {
      final item = <String, dynamic>{};
      mapSalida.forEach((llaveSalida, llaveEntrada) {
        item[llaveSalida] = nodo[llaveEntrada];
      });
      items.add(item);
    }

    return items;
  }
}
