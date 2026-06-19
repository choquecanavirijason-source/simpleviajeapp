import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

/// Helper para lecturas de colecciones en Firestore
class CollectionGet {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionGet({FirebaseFirestore? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  /// 🔹 Lee todos los documentos de una colección (1 lectura por cada doc).
  /// Soporta `{uid}` en el path.
  Future<List<Map<String, dynamic>>> getAllDocs({
    required String absoluteCollectionPath,
  }) async {
    // reemplazar {uid}
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('No autenticado');
    final resolvedPath = absoluteCollectionPath.replaceAll('{uid}', uid);

    final snap = await _db.collection(resolvedPath).get();

    return snap.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id; // muy útil tener el ID
      return data;
    }).toList();
  }
}

/* Ejemplo de uso:
// Trae todos los documentos de una colección
final coleccion = CollectionGet();
final empresas = await coleccion.getAllDocs(
  absoluteCollectionPath: 'empresas', // 'pasajeros/{uid}/taxis',
);
*/
