import 'package:cloud_firestore/cloud_firestore.dart';
import '../helpers/rutas.dart';
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

class ColeccionWhere {
  static Future<List<Map<String, dynamic>>> coleccionesWhere({
    required List<String>
    rutas, // ej: ["empresas/empresa123/taxistasRegistrados", "otra/ruta"],
    List<List<Map<String, dynamic>>> condiciones = const [],
    Map<String, Map<String, String>> reglas =
        const {}, // convierte {empresaID} en valor real
    List<int>? limites, // ej: [2, 5] opcional
  }) async {
    final resultados = <Map<String, dynamic>>[];

    for (int i = 0; i < rutas.length; i++) {
      // 🔹 resolver placeholders (ej: {empresaID}, {uid}, etc.)
      final rutaResuelta = await Placeholders.resolverRuta(
        rutas[i],
        reglas: reglas,
      );
      final ref = Rutas.rutaCollection(rutaResuelta); // 👉 arma la ruta

      // 👉 condiciones específicas por ruta
      final condicionesRuta = (i < condiciones.length)
          ? condiciones[i]
          : <Map<String, dynamic>>[];
      Query query = Condiciones.aplicar(ref, condicionesRuta);

      // 👉 aplicar límite si existe
      if (limites != null && i < limites.length) {
        query = query.limit(limites[i]);
      }

      final snapshot = await query.get();
      //.collection
      //.doc(nameDoc) // documento dinamico
      //.collection(subCollection)
      //.where("perfil.uidEmpresa", isEqualTo: "empresa123")
      //.limit(2)
      //.get();
      print("📦 Cantidad de docs encontrados: ${snapshot.docs.length}");

      for (var doc in snapshot.docs) {
        resultados.add({"id": doc.id, "data": doc.data()});

        // sigue imprimiendo para debug
        //print("📄 ID: ${doc.id}");
        //print("➡️ Data: ${doc.data()}");
      }
    }
    return resultados;
  }
}

/*
import 'package:buses2/shared/services/save_traer_firebase/lecturas/coleccionWhere.dart';
...
Future<void> _cargarDatos() async {
  print("⏳ Cargando datos...");
  final empresas = await ColeccionWhere.coleccionesWhere(
    rutas: [
      "empresas",
      "empresas/empresa456/taxistasRegistrados",
    ],
    condiciones: [
      [ {'mapaCampo': 'estado', '==': 'activo'} ], // condiciones para clientes
      [ {'mapaCampo': 'estado', '==': 'activo'} ], // condiciones para prestamos
    ],
    reglas: { // busca en  pasajeros/{uid} el campo uidEmpresa, y usa su valor
      'empresaID': {
        'doc': 'pasajeros/{uid}', // 👈 de este doc saco el valor
        'field': 'uidEmpresa',    // 👈 este campo tiene el UID de la empresa
      },
    },
    //limites: [1, 5],
  );
  print("🏢 Empresa encontrada: $empresas[0]");
  if (empresas.isNotEmpty) {
    final uidEmpresa = empresas[0]["id"];
    print("🏢 uidEmpresa encontrado: $uidEmpresa");
    final empresaData = empresas[0]["data"];
    print("🏢 Datos de la empresa: $empresaData");

    // ✅ aquí ya puedes usarlo en tu lógica
    // Ejemplo: navegar, guardar en provider, etc.
  }

  print("✅ Datos cargados");
}

/* Ejemplos especiales:
// Buscar un varios valores dentro de un array
{'mapaCampo': 'roles', 'array-contiene-cualquiera': ['admin', 'editor']},
// Busca un valor dentro de un campo
{'mapaCampo': 'estado', 'in': ['aprobado', 'pendiente']},
// Busca que el valor del campo no exista
{'mapaCampo': 'estado', 'not-in': ['rechazado', 'suspendido']},
*/
*/
