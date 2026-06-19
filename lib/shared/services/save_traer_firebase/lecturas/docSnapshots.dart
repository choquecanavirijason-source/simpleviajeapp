// lib/shared/services/save_traer_firebase/lecturas/docSnapshots.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../helpers/placeholders.dart';
import 'package:flutter/foundation.dart';

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

class DocSnapshots {
  /// 🔹 Escucha documentos en tiempo real
  static Stream<List<Map<String, dynamic>>> documentosSnapshots({
    required List<String>
    rutas, // ej: ["empresas/empresa123", "clientes/cliente456"]
    Map<String, Map<String, String>> reglas =
        const {}, // convierte {empresaID} en valor real
    List<String?>? nombreMapas,
    List<List<String>>? nombreCampos,
  }) async* {
    for (int i = 0; i < rutas.length; i++) {
      // 1️⃣ Resolver placeholders (ej: {empresaID}, {uid}, etc.)
      final rutaResuelta = await Placeholders.resolverRuta(
        rutas[i],
        reglas: reglas,
      );
      final ref = FirebaseFirestore.instance.doc(rutaResuelta);

      // 2️⃣ Escuchar el documento en tiempo real
      yield* ref.snapshots().map((snap) {
        debugPrint(
          "📡 [doc.snapshots()] Actualización recibida de '$rutaResuelta'",
        );

        if (!snap.exists) {
          return [
            {
              "path": rutaResuelta,
              "id": ref.id,
              "data": null, // no existe
            },
          ];
        }

        final raw = snap.data() as Map<String, dynamic>?;

        // 1️⃣ Base por mapa (guiones) o doc completo
        final selectorMapa = (nombreMapas != null && i < nombreMapas.length)
            ? nombreMapas[i]
            : null;
        final base = CampoUtils.extraerMapaPorGuion(raw, selectorMapa);

        // 2️⃣ Filtrado por campos top-level (si se piden)
        final campos = (nombreCampos != null && i < nombreCampos.length)
            ? nombreCampos[i]
            : null;
        final contenido = CampoCampos.filtrar(base, campos);

        return [
          {"path": rutaResuelta, "id": snap.id, "data": contenido},
        ];
      });
    }
  }
}

/* Ejemplo de uso:
import 'package:buses2/shared/services/save_traer_firebase/lecturas/docSnapshots.dart';
...
@override
void initState() {
  super.initState();

  // 👇 Escucha cambios en tiempo real
  DocSnapshots.documentosSnapshots(
    rutas: ["empresas/{empresaID}"],
    reglas: {
      'empresaID': {
        'doc': 'pasajeros/{uid}',
        'field': 'uidEmpresa',
      },
    },
  ).listen((docs) {
    final empresa = docs.first;
    print("🏢 Empresa actualizada: ${empresa['data']}");
  });
}
*/

class CampoUtils {
  /// Si path es null/'' => devuelve el doc completo.
  /// Si path = 'a-b-c' => devuelve raw['a']['b']['c'].
  /// No trata el último segmento como "campo": TODO es parte del mapa.
  static dynamic extraerMapaPorGuion(Map<String, dynamic>? raw, String? path) {
    if (raw == null) return null;
    if (path == null || path.trim().isEmpty) return raw;

    dynamic current = raw;
    for (final seg in path.split('-')) {
      if (current is Map<String, dynamic> && current.containsKey(seg)) {
        current = current[seg];
      } else {
        return null;
      }
    }
    return current; // Map, List o valor escalar
  }
}

class CampoCampos {
  /// Si [campos] es null o vacío => devuelve [base] tal cual.
  /// Si [base] es Map => devuelve solo las claves indicadas (si no existen, se omiten).
  /// Si [base] NO es Map (p.ej. List/num/String) y pides campos => devuelve null.
  static dynamic filtrar(dynamic base, List<String>? campos) {
    if (campos == null || campos.isEmpty) return base;
    if (base is! Map<String, dynamic>) return null;

    final out = <String, dynamic>{};
    for (final c in campos) {
      if (c.isEmpty) continue;
      if (base.containsKey(c)) out[c] = base[c];
    }
    return out;
  }
}
