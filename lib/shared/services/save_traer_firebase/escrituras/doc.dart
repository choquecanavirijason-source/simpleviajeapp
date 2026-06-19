// import 'package:buses2/shared/services/save_traer_firebase/escrituras/doc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../reemplazar/reemplazar.dart';
import '../helpers/incrementar.dart' as inc;
import '../helpers/placeholders.dart';
export '../helpers/incrementar.dart' show incrementar, decrementar, Incrementar;

/* Asi funciona Firebase
*- doc.set(data) = Crea el doc si no existe, reemplaza todo si no usas SetOptions
   Con SetOptions(merge: true) actualiza solo los campos que envias, 1 escritura.
*- doc.update(data) = Actualiza campos especificos, falla si el doc no existe, 1 escritura.
*- doc.delete() = Borra el doc, 1 escritura.
/- collection.add(data) = Crea un doc con ID automatico, 1 escritura.
*/

/*✅ Resumen práctico (escrituras):
set → crear o reemplazar (con merge si quieres).
update → actualizar campos puntuales.
delete → eliminar doc completo.
add → crear doc con ID automático.
arrayUnion, arrayRemove, increment → modificadores atómicos.
batch / transaction → varias escrituras juntas (siguen costando 1 c/u).
*/

class DocSets {
  static final _db = FirebaseFirestore.instance;

  /// 🔹Set con merge: actualiza o crea el doc si no existe
  static Future<void> set({
    required List<String> absoluteDocPath, // siempre lista
    required List<String> nombreMap, // siempre lista
    required List<Map<String, dynamic>> data, // siempre lista
    Map<String, Map<String, String>> reglas = const {},
    bool autoCreatedAtForNewDocs = false,
    String createdAtFieldName = 'createdAt',
    List<bool>? createdAtFor,
  }) async {
    if (absoluteDocPath.length != nombreMap.length ||
        absoluteDocPath.length != data.length) {
      throw Exception(
        'Las listas absoluteDocPath, nombreMap y data deben tener la misma longitud.',
      );
    }
    if (createdAtFor != null && createdAtFor.length < data.length) {
      throw Exception(
        'createdAtFor debe tener longitud >= data.length si se proporciona.',
      );
    }

    final batch = _db.batch();
    final aliasPool = <String, String>{};
    final valoresResueltos = await Placeholders.resolverValores(reglas);

    for (int i = 0; i < absoluteDocPath.length; i++) {
      // 1) reemplazos declarados desde el page ({uid}, {empresaID}, etc.)
      final path1 = await Reemplazar.resolverRuta(
        absoluteDocPath[i],
        reglas: reglas,
      );
      // 2) generación/reuso de {new:alias}
      final resolvedPath = Reemplazar.rutaNewUIDConAlias(path1, aliasPool);
      final ref = _db.doc(resolvedPath);

      var mapName = nombreMap[i];

      // 2) Incrementar(...) → FieldValue.increment(...)
      Map<String, dynamic> transformed = Map<String, dynamic>.from(
        inc.transformarIncrementables(data[i]),
      ); // ✅

      // 4) *** NUEVO ***: combinar valores de reglas + alias:{NombreAlias}
      final valoresConAlias = <String, String>{
        ...valoresResueltos,
        // Esto permite usar {alias:Empresa} en data
        for (final e in aliasPool.entries) 'alias:${e.key}': e.value,
      };

      // 3) DATA: Reemplaza SIEMPRE {uid} y {empresaID}, etc.
      transformed = Placeholders.reemplazarEnMapaConValores(
        transformed,
        valores: valoresConAlias,
      );

      // 4) decidir si inyectar createdAt
      final isNewDoc = absoluteDocPath[i].contains('{newUID');
      final shouldInjectCreatedAt = (createdAtFor != null)
          ? (createdAtFor[i] == true) // control explícito por índice
          : (autoCreatedAtForNewDocs && isNewDoc); // modo auto por {newUID}

      if (shouldInjectCreatedAt) {
        transformed[createdAtFieldName] = FieldValue.serverTimestamp();
      }

      // 5) aplicar nesting si nombreMap usa guiones
      final setData = (mapName == '@root' || mapName.isEmpty)
          ? transformed
          : Reemplazar.guionMap(mapName, transformed);

      batch.set(ref, setData, SetOptions(merge: true));
    }

    await batch.commit();
  }
}

/* Ejemplo de uso:

final reglas = {
  'empresaID': { // placeholder {empresaID}
    'doc': 'pasajeros/{uid}', // doc donde está el campo que queremos leer
    'field': 'uidEmpresa' // campo que contiene el id de la empresa. se puede anidar con 'a-b-c'
  },
};

/// Set con merge: actualiza o crea el doc si no existe
await DocSets.set(
  absoluteDocPath: [
    'users/{uid}/prestamos/{newUID:Alias1}', // newUID:Alias1 si no tiene alias genera id nuevo
    'pasajeros/{uid}/perfilEmpresa/{newUID:Alias2}', // el alias hace que se comparta el mismo uid
    'pasajeros/{uid}/perfilEmpresa/{newUID:Alias2}',
  ],
  nombreMap: [
    'info-detalles',
    '@root',
    'info-adicional',
  ],
  data: [
    { 'nombre': _nameCtrl.text.trim(), },
    { 'valor': 'hola', 'actorUid': '{uid}', 'aliasId': '{alias:Alias2}'},
    { 'monto': incrementar(monto) }, // 👈 +v al campo
  ],
  reglas: reglas, // 👈 usar placeholder {empresaID}
  autoCreatedAtForNewDocs: true, // Automatico por cada newUID
  createdAtFieldName: 'createdAt', // nombre del campo
  createdAtFor: [false, true], // solo para el 2º ítem
);
*/

/// update + batch
class DocUpdates {
  static final _db = FirebaseFirestore.instance;

  /// 🔹Update: actualiza campos específicos; falla si el doc no existe
  static Future<void> update({
    required List<String> absoluteDocPath, // siempre lista
    required List<String> nombreMap, // siempre lista
    required List<Map<String, dynamic>> data, // siempre lista
    Map<String, Map<String, String>> reglas = const {},
  }) async {
    if (absoluteDocPath.length != nombreMap.length ||
        absoluteDocPath.length != data.length) {
      throw Exception(
        'Las listas absoluteDocPath, nombreMap y data deben tener la misma longitud.',
      );
    }

    final batch = _db.batch();
    final aliasPool = <String, String>{};

    for (int i = 0; i < absoluteDocPath.length; i++) {
      // 👇 misma resolución que en DocSets.set
      final path1 = await Reemplazar.resolverRuta(absoluteDocPath[i]);
      final resolvedPath = Reemplazar.rutaNewUIDConAlias(path1, aliasPool);
      final ref = _db.doc(resolvedPath);

      final mapName = nombreMap[i];
      final d = data[i];

      // 👇 mismo modelado de mapa anidado
      final updateData = (mapName == '@root' || mapName.isEmpty)
          ? d
          : Reemplazar.guionMap(mapName, d);

      // 👇 update (falla si el doc no existe)
      batch.update(ref, updateData);
    }

    await batch.commit();
  }
}

/* Ejemplo de uso:
/// Actualizar varios campos específicos, si no existe el doc falla

await DocUpdates.update(
  absoluteDocPath: [
    'users/{uid}/prestamos/{newUID:Alias1}', // newUID:Alias1 si no tiene alias genera id nuevo
    'pasajeros/{uid}/perfilEmpresa/{newUID:Alias2}', // el alias hace que se comparta el mismo uid
    'pasajeros/{uid}/perfilEmpresa/{newUID:Alias2}',
  ],
  nombreMap: [
    'info-detalles',
    '@root',
    'info-adicional',
  ],
  data: [
    { 'nombre': _nameCtrl.text.trim(), },
    { 'valor': 'hola' },
    { 'activo': true, },
  ],
);
*/
