// lib/shared/services/save_traer_firebase/lecturas/ColeccionGroupWhereGet.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../helpers/condiciones.dart';
import '../helpers/placeholders.dart';

/* Asi funciona Firebase
*- doc.get() = lectura del doc 1 vez
*- doc.snapshots() = escucha el doc en tiempo real. 1 lectura +1 cada vez que cambia
/- coleccion.get() = lectura de todos los docs 1 vez. 1 lectura por cada doc
/- collection.where(...).get() = mira una colección y devuelve los docs que cumplen el filtro.
  1 lectura por cada doc que devuelve
/- collection.where(...).snapshots() = escucha en tiempo real los docs que cumplen el filtro
  1 lectura por cada doc que devuelve +1 cada vez que cambia alguno
/+ collectionGroup.get() = consulta todas las subcolecciones con un mismo nombre 1 vez.
  1 lectura por cada doc que devuelve
/+ collectionGroup.where(...).get() = consulta todas las subcolecciones con un mismo nombre y devuelve los docs que cumplen el filtro.
  1 lectura por cada doc que devuelve
/+ collectionGroup.where(...).snapshots() = escucha en vivo todas las subcolecciones con un mismo nombre que cumplen el filtro.
  1 lectura por cada doc que devuelve +1 cada vez que cambia alguno
*/
/*
✅ Resumen práctico:
*- doc.get() → una vez, rápido, startup/init.
*- doc.snapshots() → en vivo, se actualiza automáticamente.
/- collection.get() → trae todo (peligroso si hay muchos).
/- collection.where(...).get() → una vez, con filtro.
/- collection.where(...).snapshots() → en vivo, con filtro.
/+ collectionGroup.get() → trae todo de subcolecciones con mismo nombre (peligroso si hay muchos).
/+ collectionGroup.where(...).get() → una vez, con filtro, de subcolecciones con mismo nombre.
/+ collectionGroup.where(...).snapshots() → en vivo, con filtro, de subcolecciones con mismo nombre.
*/

class ColeccionGroupWhereGet {
  static Future<List<Map<String, dynamic>>> coleccionesGroup({
    /// Nombres de subcolección a consultar con collectionGroup, ej: ['ordenes', 'items']
    required List<String> subcolecciones,

    /// Condiciones por cada subcolección (mismo formato que en tu API)
    /// ej: [ [ {'mapaCampo':'empresa.empresaId', '==':'{empresaID}'} ] ]
    List<List<Map<String, dynamic>>> condiciones = const [],

    /// Reglas para placeholders como {uid}, {empresaID}, etc. (igual que en tu API)
    /// ej:
    /// {
    ///   'empresaID': {'doc':'pasajeros/{uid}', 'field':'uidEmpresa'}
    /// }
    Map<String, Map<String, String>> reglas = const {},

    /// Límite opcional por cada subcolección
    List<int>? limites,
  }) async {
    final resultados = <Map<String, dynamic>>[];

    for (int i = 0; i < subcolecciones.length; i++) {
      // 🔹 Resolver placeholders si pones algo como '{empresaID}' en el nombre (normalmente es literal)
      final nombreResuelto = await Placeholders.resolverRuta(
        subcolecciones[i],
        reglas: reglas,
      );

      // 👉 collectionGroup sobre el NOMBRE de la subcolección
      Query query = FirebaseFirestore.instance.collectionGroup(nombreResuelto);

      // 👉 aplicar condiciones específicas por subcolección
      final condicionesRuta = (i < condiciones.length)
          ? condiciones[i]
          : <Map<String, dynamic>>[];
      query = Condiciones.aplicar(query, condicionesRuta);

      // 👉 aplicar límite si existe
      if (limites != null && i < limites.length) {
        query = query.limit(limites[i]);
      }

      final snapshot = await query.get();
      print(
        "📦[group:$nombreResuelto] Cantidad de docs encontrados: ${snapshot.docs.length}",
      );

      for (var doc in snapshot.docs) {
        resultados.add({
          "id": doc.id, // id del doc dentro de la subcolección
          "data": doc.data(), // mapa de datos
          // Si te sirve para debug, puedes descomentar:
          // "path": doc.reference.path,
          // "parent": doc.reference.parent.parent?.path,
        });
      }
    }

    print("📦 Total docs (collectionGroup): ${resultados.length}");
    return resultados;
  }
}

/*
USO EJEMPLO (igual estilo que tu API):

final ordenes = await ColeccionGroupWhereGet.coleccionesGroup(
  subcolecciones: ['ordenes'],
  condiciones: [
    [
      {'mapaCampo': 'empresa.empresaId', '==': '{empresaID}'},
    ],
  ],
  reglas: {
    'empresaID': {
      'doc': 'pasajeros/{uid}', // de este doc saco el valor
      'field': 'uidEmpresa',    // este campo tiene el ID de la empresa
    },
  },
  // limites: [50],
);
print('✅ Total órdenes encontradas: ${ordenes.length}');
*/
