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
/// Operadores soportados (mapea a Firestore .where(...))
enum Operador {
  isEqualTo,
  arrayContains,
  arrayContainsAny,
  whereIn,
  isGreaterThan,
  isGreaterThanOrEqualTo,
  isLessThan,
  isLessThanOrEqualTo,
  isNotEqualTo,
}

/// Un filtro genérico para componer queries.
class Filtro {
  final String campo; // admite notación con puntos: 'info.uidPropietarios'
  final Operador op;
  final dynamic valor;

  const Filtro._(this.campo, this.op, this.valor);

  // Fábricas legibles (sin defaults de dominio)
  factory Filtro.arrayContiene(String campo, dynamic valor) =>
      Filtro._(campo, Operador.arrayContains, valor);

  factory Filtro.arrayContieneV1oV2(String campo, List<dynamic> valores) =>
      Filtro._(campo, Operador.arrayContainsAny, valores);

  factory Filtro.campoIgualAO(String campo, List<dynamic> valores) =>
      Filtro._(campo, Operador.whereIn, valores);

  factory Filtro.operadores(String campo, String operador, dynamic valor) {
    switch (operador.trim()) {
      case '==':
        return Filtro._(campo, Operador.isEqualTo, valor);
      case '!=':
        return Filtro._(campo, Operador.isNotEqualTo, valor);
      case '>':
        return Filtro._(campo, Operador.isGreaterThan, valor);
      case '>=':
        return Filtro._(campo, Operador.isGreaterThanOrEqualTo, valor);
      case '<':
        return Filtro._(campo, Operador.isLessThan, valor);
      case '<=':
        return Filtro._(campo, Operador.isLessThanOrEqualTo, valor);
      default:
        throw ArgumentError(
          "Operador inválido para Filtro.operadores: '$operador'. Usa uno de: "
          "==, !=, >, >=, <, <=",
        );
    }
  }
}

class GetQueriesFiltro {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  GetQueriesFiltro({FirebaseFirestore? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  // --- NUEVO: resolver placeholders (p.ej. '{uid}') ---
  dynamic _resolveValor(dynamic v) {
    if (v is String && v == '{uid}') return _auth.currentUser?.uid;
    return v;
  }

  //// true si hay 1 o mas docs que cumplen los filtros
  Future<bool> existeDoc({
    required String coleccion,
    required List<Filtro> filtros,
  }) async {
    // Si algún filtro requiere uid y no hay usuario, no hay match
    for (final f in filtros) {
      final needsUid = f.valor is String && f.valor == '{uid}';
      if (needsUid && _auth.currentUser?.uid == null) return false;
    }

    var q = _db.collection(coleccion) as Query<Map<String, dynamic>>;
    for (final f in filtros) {
      // usar el valor resuelto
      final fResuelto = Filtro._(f.campo, f.op, _resolveValor(f.valor));
      q = _aplicarFiltro(q, fResuelto);
    }
    final snap = await q.get();
    return snap.docs.isNotEmpty;
  }

  //// id del primer doc que cumple los filtros, o null
  Future<String?> idPrimero({
    required String coleccion,
    required List<Filtro> filtros,
  }) async {
    for (final f in filtros) {
      final needsUid = f.valor is String && f.valor == '{uid}';
      if (needsUid && _auth.currentUser?.uid == null) return null;
    }
    var q = _db.collection(coleccion) as Query<Map<String, dynamic>>;
    for (final f in filtros) {
      final fResuelto = Filtro._(f.campo, f.op, _resolveValor(f.valor));
      q = _aplicarFiltro(q, fResuelto);
    }
    final snap = await q.get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }

  Query<Map<String, dynamic>> _aplicarFiltro(
    Query<Map<String, dynamic>> q,
    Filtro f,
  ) {
    switch (f.op) {
      case Operador.isEqualTo:
        return q.where(f.campo, isEqualTo: f.valor);
      case Operador.arrayContains:
        return q.where(f.campo, arrayContains: f.valor);
      case Operador.arrayContainsAny:
        return q.where(f.campo, arrayContainsAny: (f.valor as List));
      case Operador.whereIn:
        return q.where(f.campo, whereIn: (f.valor as List));
      case Operador.isGreaterThan:
        return q.where(f.campo, isGreaterThan: f.valor);
      case Operador.isGreaterThanOrEqualTo:
        return q.where(f.campo, isGreaterThanOrEqualTo: f.valor);
      case Operador.isLessThan:
        return q.where(f.campo, isLessThan: f.valor);
      case Operador.isLessThanOrEqualTo:
        return q.where(f.campo, isLessThanOrEqualTo: f.valor);
      case Operador.isNotEqualTo:
        return q.where(f.campo, isNotEqualTo: f.valor);
    }
  }
}

/* Reglas
- se puede anidar los array. 'info.uidPropietarios'
- valores que se pueden usar. '{uid}' o 'hola mundo'

// Pon este bind en app_module.dart
i.addSingleton<GetQueriesFiltro>(GetQueriesFiltro.new); // Queries con filtros
Nota: evita usar GetQueriesFiltro() porque estamos usando BInd.
*/

/* Sirve para:
existeDoc(...)  // true si hay 1 o mas docs que cumplen los filtros
idPrimero(...) // id del primer doc que cumple los filtros, o null
*/

/* Ejemplo de uso:

import 'package:buses2/shared/services/save_traer_firebase/get_queries_filtro.dart';
...

void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) => _decidirRuta());
}
// El array contiene <nameArray> == {uid}
final queries = Modular.get<GetQueriesFiltro>();
final existe = await queries.existeDoc(
  coleccion: 'empresas',
  filtros: [ Filtro.arrayContiene('uidPropietarios', '{uid}') ],
);

// El array <nameArray> contiene {uid}
filtros: [ Filtro.arrayContiene('uidPropietarios', '{uid}') ],

// El array <roles> contiene 'admin' o 'manager'
Filtro.arrayContieneV1oV2('roles', ['admin', 'manager']),

// valor del campo == v1 OR campo == v2 OR ...
filtros: [ Filtro.campoIgualAO('estado', ['activa', 'pendiente']) ],

// valor del campo 'estado' es igual a 'activo'
filtros: [ Filtro.operadores('estado', '==', 'activo') ],

*/
