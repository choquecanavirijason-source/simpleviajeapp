// lib/shared/widgets/buscadores/logica_buscar.dart

// v. 1.0.0

/// Normaliza: minúsculas + quita tildes/diacríticos comunes (español)
String normalize(String s) {
  final lower = s.toLowerCase();
  return lower
      .replaceAll(RegExp(r'[áàäâã]'), 'a')
      .replaceAll(RegExp(r'[éèëê]'), 'e')
      .replaceAll(RegExp(r'[íìïî]'), 'i')
      .replaceAll(RegExp(r'[óòöôõ]'), 'o')
      .replaceAll(RegExp(r'[úùüû]'), 'u')
      .replaceAll('ñ', 'n');
}

/// Filtra una lista de mapas buscando en los campos indicados.
List<Map<String, dynamic>> filtrarMapasPorCampos(
  List<Map<String, dynamic>> data,
  String query, {
  required List<String> campos,
  bool matchAllTerms = false,
}) {
  final q = normalize(query.trim());
  if (q.isEmpty) return data;

  final terms = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

  bool itemMatches(Map<String, dynamic> it, String term) {
    for (final campo in campos) {
      final valor = normalize((it[campo] ?? '').toString());
      if (valor.contains(term)) return true;
    }
    return false;
  }

  return data.where((it) {
    if (matchAllTerms) {
      return terms.every((t) => itemMatches(it, t));
    } else {
      return terms.any((t) => itemMatches(it, t));
    }
  }).toList();
}

/// Versión genérica para listas tipadas.
List<T> filtrarListaGenerica<T>(
  List<T> data,
  String query, {
  required List<String Function(T)> getters,
  bool matchAllTerms = false,
}) {
  final q = normalize(query.trim());
  if (q.isEmpty) return data;

  final terms = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

  bool itemMatches(T it, String term) {
    for (final g in getters) {
      final valor = normalize(g(it));
      if (valor.contains(term)) return true;
    }
    return false;
  }

  return data.where((it) {
    if (matchAllTerms) {
      return terms.every((t) => itemMatches(it, t));
    } else {
      return terms.any((t) => itemMatches(it, t));
    }
  }).toList();
}
