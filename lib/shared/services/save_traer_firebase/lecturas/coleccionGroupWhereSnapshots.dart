// 📄 lib/shared/services/save_traer_firebase/lecturas/coleccionGroupWhereSnapshots.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../helpers/condiciones.dart';
import '../helpers/placeholders.dart';

/* ==========================================================
  🔥 Firebase: MODO TIEMPO REAL (snapshots)
==============================================================
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
============================================================== */

class ColeccionGroupWhereSnapshots {
  /// 🔹 Escucha en tiempo real subcolecciones con mismo nombre (como "ordenes")
  static Stream<List<Map<String, dynamic>>> coleccionesGroupStream({
    /// Ej: ['ordenes']
    required List<String> subcolecciones,

    /// Ej: [ [ {'mapaCampo':'empresa.empresaId', '==':'{empresaID}'} ] ]
    List<List<Map<String, dynamic>>> condiciones = const [],

    /// Ej:
    /// {
    ///   'empresaID': {'doc':'pasajeros/{uid}', 'field':'uidEmpresa'}
    /// }
    Map<String, Map<String, String>> reglas = const {},

    /// Límite opcional (una lista para permitir varios subniveles)
    List<int>? limites,
  }) async* {
    // ⚠️ Solo procesamos la primera subcolección (normalmente "ordenes")
    if (subcolecciones.isEmpty) {
      yield [];
      return;
    }

    final nombreResuelto = await Placeholders.resolverRuta(
      subcolecciones.first,
      reglas: reglas,
    );

    // 🔹 Inicializamos query base
    Query query = FirebaseFirestore.instance.collectionGroup(nombreResuelto);

    // 🔹 Aplicamos condiciones y límites
    final condicionesRuta = (condiciones.isNotEmpty)
        ? condiciones.first
        : <Map<String, dynamic>>[];
    query = Condiciones.aplicar(query, condicionesRuta);

    if (limites != null && limites.isNotEmpty) {
      query = query.limit(limites.first);
    }

    // 🔹 Escucha en tiempo real con snapshots
    yield* query.snapshots().map((snapshot) {
      print(
        "📡 [stream:$nombreResuelto] Actualización (${snapshot.docs.length} docs)",
      );

      // 🔹 Convertimos cada doc a Map como en la versión .get()
      return snapshot.docs
          .map(
            (doc) => {
              "id": doc.id,
              "data": doc.data(),
              // opcional: "path": doc.reference.path,
            },
          )
          .toList();
    });
  }
}

/* ==========================================================
💡 Ejemplo de uso (idéntico al de .get, pero con stream):
==============================================================

Stream<List<Map<String, dynamic>>> stream = 
    ColeccionGroupWhereSnapshots.coleccionesGroupStream(
      subcolecciones: ['ordenes'],
      condiciones: [
        [
          {'mapaCampo': 'empresa.empresaId', '==': '{empresaID}'},
          {'mapaCampo': 'estado', '==': 'pedido'},
        ],
      ],
      reglas: {
        'empresaID': {
          'doc': 'pasajeros/{uid}',
          'field': 'uidEmpresa',
        },
      },
      limites: [100],
    );

stream.listen((ordenes) {
  print('🔄 Stream actualizado: ${ordenes.length} órdenes.');
});
============================================================== */
