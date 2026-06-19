import 'package:cloud_firestore/cloud_firestore.dart';
import '../helpers/rutas.dart';
import '../helpers/placeholders.dart';
import '../helpers/buscar_campo.dart';
import '../helpers/dibujar_datos.dart';

/// [V.1.2.0]

/* Asi funciona Firebase
*- doc.get() = lectura del doc 1 vez
*- doc.snapshots() = escucha el doc en tiempo real. 1 lectura +1 cada vez que cambia
/- coleccion.get() = lectura de todos los docs 1 vez. 1 lectura por cada doc
/- collection.where(...).get() = mira una colección y devuelve los docs que cumplen el filtro.
  1 lectura por cada doc que devuelve
/- collection.where(...).snapshots() = escucha en tiempo real los docs que cumplen el filtro
  1 lectura por cada doc que devuelve +1 cada vez que cambia alguno
*/
/*
✅ Resumen práctico:
*- doc.get() → una vez, rápido, startup/init.
*- doc.snapshots() → en vivo, se actualiza automáticamente.
/- collection.get() → trae todo (peligroso si hay muchos).
/- collection.where(...).get() → una vez, con filtro.
/- collection.where(...).snapshots() → en vivo, con filtro.
*/

class ColeccionGet {
  /// Lee **todas** las colecciones indicadas en `rutas` con `.get()` (sin filtros)
  /// y devuelve una lista plana con `{ id, data }` por cada documento encontrado.
  static Future<List<Map<String, dynamic>>> coleccionesGet({
    required List<String>
    rutas, // ej: ["empresas", "empresas/{empresaID}/taxistasRegistrados"]
    Map<String, Map<String, String>> reglas =
        const {}, // convierte {empresaID} en valor real
    List<int>? limites, // ej: [10, 5] opcional por ruta

    List<String>? buscaCampos, // ej: ['servicio','activo']  opcional
    Map<String, String>?
    mapSalida, // ej: {'titulo':'otroDato','activo':'activo'}  opcional
  }) async {
    final resultados = <Map<String, dynamic>>[];

    for (int i = 0; i < rutas.length; i++) {
      // 🔹 resolver placeholders (ej: {empresaID}, {uid}, etc.)
      final rutaResuelta = await Placeholders.resolverRuta(
        rutas[i],
        reglas: reglas,
      );
      final ref = Rutas.rutaCollection(
        rutaResuelta,
      ); // 👉 arma la referencia a la colección

      Query query = ref;

      // 👉 aplicar límite si existe
      if (limites != null && i < limites.length) {
        query = query.limit(limites[i]);
      }

      // 👉 leer TODOS los documentos de la colección (sin where)
      final snapshot = await query.get();
      print("📦 [${rutaResuelta}] docs encontrados: ${snapshot.docs.length}");

      for (final doc in snapshot.docs) {
        resultados.add({"id": doc.id, "data": doc.data()});

        // sigue imprimiendo para debug
        // print("📄 ID: ${doc.id}");
        // print("➡️ Data: ${doc.data()}");
      }
    }

    // 2) si NO piden campos → devuelvo los docs crudos
    if (buscaCampos == null || buscaCampos.isEmpty) {
      return resultados;
    }

    // 3) extraer campos en cualquier profundidad
    final nodos = BuscarCampo.extraerGrupos(resultados, buscaCampos);

    // 4) si NO piden mapeo → devuelvo nodos tal cual
    if (mapSalida == null || mapSalida.isEmpty) {
      return nodos;
    }

    // 5) mapear a llaves para la UI
    final items = AdaptadorDatos.construir(nodos, mapSalida: mapSalida);
    return items;
  }
}

/*
import 'package:buses2/shared/services/save_traer_firebase/lecturas/coleccion_get.dart';
...
List<Map<String, dynamic>> _items = [];
...
Future<void> _cargarDatos() async {
  print("⏳ Cargando datos (collection.get)...");
  final res = await ColeccionGet.coleccionesGet(
    rutas: [
      "empresas", // trae todas las empresas
      "empresas/{empresaID}/taxistasRegistrados", // trae todos los taxistas de tu empresa
    ],
    buscaCampos: ['servicio', 'activo'], // <— campo que quiero extraer
    mapSalida: {
      'activo': 'activo',
      'servicio': 'servicio', // por si también lo quieres a mano
    },
    reglas: {
      'empresaID': {
        'doc': 'pasajeros/{uid}', // 👈 de este doc saco el valor
        'field': 'uidEmpresa',    // 👈 este campo tiene el ID de la empresa
      },
    },
    //limites: [5, 10], // opcional, por ruta
  );

  setState(() {
    _items = valores;
  });

  // debug opcional
  for (final g in valores) {
    print('servicio: ${g['servicio']}  activo: ${g['activo']}');
  }

  print("✅ Datos cargados (collection.get)");
}

// UI
Text(
  _items.isEmpty
    ? 'Cargando...'
    : 'Servicios: ${_items.map((e) => e['servicio']).whereType<String>().join(', ')}',
)
*/
