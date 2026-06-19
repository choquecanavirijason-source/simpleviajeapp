import 'package:cloud_firestore/cloud_firestore.dart';
import '../helpers/placeholders.dart';

class Condiciones {
  static Query aplicar(Query query, List<Map<String, dynamic>> condiciones) {
    for (final cond in condiciones) {
      final campo = cond['mapaCampo'] as String;

      // 🔑 buscamos la clave que no sea "mapaCampo"
      final operador = cond.keys.firstWhere((k) => k != 'mapaCampo');
      var valor = cond[operador];

      // 🚀 Resolver placeholder {uid}
      if (valor is String && valor.contains('{uid}')) {
        valor = UidHelper.uid;
      }

      switch (operador) {
        case '==':
          query = query.where(campo, isEqualTo: valor);
          break;
        case '!=':
          query = query.where(campo, isNotEqualTo: valor);
          break;
        case '>':
          query = query.where(campo, isGreaterThan: valor);
          break;
        case '>=':
          query = query.where(campo, isGreaterThanOrEqualTo: valor);
          break;
        case '<':
          query = query.where(campo, isLessThan: valor);
          break;
        case '<=':
          query = query.where(campo, isLessThanOrEqualTo: valor);
          break;
        case 'array-contiene': // Busca un valor dentro de un array
          query = query.where(campo, arrayContains: valor);
          break;
        case 'array-contiene-cualquiera': // Busca cualquiera de varios valores dentro de un array
          query = query.where(campo, arrayContainsAny: valor);
          break;
        case 'in': // Busca si un valor está en una lista de posibles valores
          query = query.where(campo, whereIn: valor);
          break;
        case 'not-in': // Busca si un valor no está en una lista
          query = query.where(campo, whereNotIn: valor);
          break;
        default:
          throw ArgumentError("Operador no soportado: $operador");
      }
    }
    return query;
  }
}

/* Ejemplo de uso:
import 'package:buses2/shared/services/save_traer_firebase/lecturas/coleccionWhere.dart';
await ColeccionWhere.ejemploBasico(
  rutas: ["empresas/empresa123/taxistasRegistrados"],
  condiciones: [
    {'mapaCampo': 'perfil.uidEmpresa', '==': 'empresa123'},
  ],
);
*/
