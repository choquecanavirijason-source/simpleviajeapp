import 'package:flutter/widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UidColeccionDoc {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Map<String, dynamic>? _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v as Map);
    return null;
  }

  // Ref a users/<uid>
  static DocumentReference<Map<String, dynamic>> _userDocRef() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Usuario no autenticado');
    return _db.collection('users').doc(uid);
  }

  // ===================== NIVEL 1: users/<uid>/<subcollection>/<docId> =====================

  static Future<Map<String, dynamic>?> fetchSubdoc({
    required String subcollection,
    required String docId,
  }) async {
    final snap = await _userDocRef().collection(subcollection).doc(docId).get();
    if (!snap.exists) return null;
    final map = _asMap(snap.data());
    return map == null ? null : {'id': snap.id, ...map};
  }

  static Future<List<Map<String, dynamic>>> listSubcollection({
    required String subcollection,
    String? orderByField,
    bool descending = false,
    int? limit,
  }) async {
    Query<Map<String, dynamic>> q = _userDocRef().collection(subcollection);
    if (orderByField != null && orderByField.isNotEmpty) {
      q = q.orderBy(orderByField, descending: descending);
    }
    if (limit != null && limit > 0) q = q.limit(limit);
    final qs = await q.get();
    return qs.docs.map((d) => {'id': d.id, ...?_asMap(d.data())}).toList();
  }

  // ===================== NIVEL 2: users/<uid>/<parent>/<doc>/<child>/<doc> =====================

  static DocumentReference<Map<String, dynamic>> nestedDocRef({
    required String parentSubcollection, // ej. 'historial-saldo'
    required String parentDocId, // ej. '2025'
    required String childSubcollection, // ej. 'agosto'
    required String childDocId, // ej. '29-8-2025'
  }) {
    return _userDocRef()
        .collection(parentSubcollection)
        .doc(parentDocId)
        .collection(childSubcollection)
        .doc(childDocId);
  }

  static Future<Map<String, dynamic>?> fetchNestedSubdoc({
    required String parentSubcollection,
    required String parentDocId,
    required String childSubcollection,
    required String childDocId,
  }) async {
    final snap = await nestedDocRef(
      parentSubcollection: parentSubcollection,
      parentDocId: parentDocId,
      childSubcollection: childSubcollection,
      childDocId: childDocId,
    ).get();
    if (!snap.exists) return null;
    final map = _asMap(snap.data());
    return map == null ? null : {'id': snap.id, ...map};
  }

  static Future<List<Map<String, dynamic>>> listNestedSubcollection({
    required String parentSubcollection,
    required String parentDocId,
    required String childSubcollection,
    String? orderByField,
    bool descending = false,
    int? limit,
  }) async {
    Query<Map<String, dynamic>> q = _userDocRef()
        .collection(parentSubcollection)
        .doc(parentDocId)
        .collection(childSubcollection);
    if (orderByField != null && orderByField.isNotEmpty) {
      q = q.orderBy(orderByField, descending: descending);
    }
    if (limit != null && limit > 0) q = q.limit(limit);
    final qs = await q.get();
    return qs.docs.map((d) => {'id': d.id, ...?_asMap(d.data())}).toList();
  }

  // ===================== Ruta arbitraria (pares [col,id,...]) =====================

  // Construye referencia a un DOC a partir de segmentos: ['historial-saldo','2025', 'agosto','29-8-2025']
  static DocumentReference<Map<String, dynamic>> docAtPath(
    List<String> segments,
  ) {
    if (segments.length.isOdd) {
      throw ArgumentError('segments debe ser par: [col, id, col, id, ...]');
    }
    var ref = _userDocRef();
    for (var i = 0; i < segments.length; i += 2) {
      ref = ref.collection(segments[i]).doc(segments[i + 1]);
    }
    return ref;
  }

  // Lee un DOC arbitrario con segmentos (atajo a docAtPath(...).get())
  static Future<Map<String, dynamic>?> fetchAtPath(
    List<String> segments,
  ) async {
    final snap = await docAtPath(segments).get();
    if (!snap.exists) return null;
    final map = _asMap(snap.data());
    return map == null ? null : {'id': snap.id, ...map};
  }

  // --- Helpers de ruta (string) ---
  static List<String> _splitPath(String path) =>
      path.split('/').where((s) => s.isNotEmpty).toList();

  static Future<Map<String, dynamic>?> fetchPath(String path) async {
    final seg = _splitPath(path);
    if (seg.length.isOdd) {
      throw ArgumentError(
        'La ruta debe terminar en DOCUMENTO (número PAR de segmentos). '
        'Ej: "historial-saldo/2025/agosto/29-8-2025"',
      );
    }
    // Reutiliza tu fetchAtPath(List<String>)
    return fetchAtPath(seg);
  }

  static Future<List<Map<String, dynamic>>> listPath(
    String path, {
    String? orderByField,
    bool descending = false,
    int? limit,
  }) async {
    final seg = _splitPath(path);
    if (seg.length.isEven) {
      throw ArgumentError(
        'La ruta debe terminar en COLECCIÓN (número IMPAR de segmentos). '
        'Ej: "historial-saldo/2025/agosto"',
      );
    }

    // Camina hasta el último DOC y toma la colección final
    var ref = _userDocRef();
    for (var i = 0; i < seg.length - 1; i += 2) {
      ref = ref.collection(seg[i]).doc(seg[i + 1]);
    }
    Query<Map<String, dynamic>> q = ref.collection(seg.last);

    if (orderByField != null && orderByField.isNotEmpty) {
      q = q.orderBy(orderByField, descending: descending);
    }
    if (limit != null && limit > 0) q = q.limit(limit);

    final qs = await q.get();
    return qs.docs.map((d) => {'id': d.id, ...?d.data()}).toList();
  }

  // === PEGAR DENTRO DE UidColeccionDoc (no toques lo demás) ===

  // Reemplaza {uid} si lo usas en la ruta
  static String _resolveTokens(String path) {
    final uid = _auth.currentUser?.uid;
    return path.replaceAll('{uid}', uid ?? '');
  }

  // Construye ref de DOC desde raíz de Firestore: col/id/col/id...
  static DocumentReference<Map<String, dynamic>> _absDocRefFromSeg(
    List<String> seg,
  ) {
    if (seg.length.isOdd) {
      throw ArgumentError(
        'Ruta DOC absoluta inválida (segmentos deben ser PAR). Ej: "users/{uid}/historial-saldo/2025"',
      );
    }
    var ref = _db.collection(seg[0]).doc(seg[1]);
    for (var i = 2; i < seg.length; i += 2) {
      ref = ref.collection(seg[i]).doc(seg[i + 1]);
    }
    return ref;
  }

  /// Lee un DOC usando ruta ABSOLUTA (desde raíz). Soporta {uid}.
  /// Ej: 'users/{uid}/historial-saldo/2025'
  static Future<Map<String, dynamic>?> fetchAbsPath(
    String absoluteDocPath,
  ) async {
    final resolved = _resolveTokens(absoluteDocPath);
    final seg = _splitPath(resolved);
    final snap = await _absDocRefFromSeg(seg).get();
    if (!snap.exists) return null;
    final map = _asMap(snap.data());
    return map == null ? null : {'id': snap.id, ...map};
  }

  /// Lista una COLECCIÓN usando ruta ABSOLUTA. Soporta {uid}.
  /// Ej: 'empresas/abc123/historial-saldo'
  static Future<List<Map<String, dynamic>>> listAbsPath(
    String absoluteCollectionPath, {
    String? orderByField,
    bool descending = false,
    int? limit,
  }) async {
    final resolved = _resolveTokens(absoluteCollectionPath);
    final seg = _splitPath(resolved);
    if (seg.length.isEven) {
      throw ArgumentError(
        'Ruta COLECCIÓN absoluta inválida (segmentos deben ser IMPAR). Ej: "users/{uid}/historial-saldo"',
      );
    }
    var docRef = _db.collection(seg[0]).doc(seg[1]);
    for (var i = 2; i < seg.length - 1; i += 2) {
      docRef = docRef.collection(seg[i]).doc(seg[i + 1]);
    }
    Query<Map<String, dynamic>> q = docRef.collection(seg.last);
    if (orderByField != null && orderByField.isNotEmpty) {
      q = q.orderBy(orderByField, descending: descending);
    }
    if (limit != null && limit > 0) q = q.limit(limit);
    final qs = await q.get();
    return qs.docs.map((d) => {'id': d.id, ...?_asMap(d.data())}).toList();
  }

  // --- Helpers de depuración (para ver qué ruta realmente lees) ---
  static Future<void> debugAbsDoc(String absoluteDocPath) async {
    final resolved = _resolveTokens(absoluteDocPath);
    final seg = _splitPath(resolved);
    debugPrint(
      '[ABS DOC] raw="$absoluteDocPath" -> resolved="$resolved" seg=$seg',
    );
    try {
      final snap = await _absDocRefFromSeg(seg).get();
      debugPrint('[ABS DOC] exists=${snap.exists} data=${snap.data()}');
    } catch (e) {
      debugPrint('[ABS DOC] ERROR: $e');
    }
  }

  static Future<void> debugCampo(String campo) async {
    final uid = _auth.currentUser?.uid;
    final snap = await _db.collection('users').doc(uid).get();
    final data = _asMap(snap.data());
    final m = _asMap(data?[campo]);
    debugPrint('[CPO] keys(${campo}) = ${m?.keys.toList()}');
  }

  // --- Helpers para leer un campo puntual (soporta "dot path" como empresa.saldo) ---

  // Ahora soporta maps anidados y listas: a.b[0].c[2].d
  static dynamic _getByDotPath(Map<String, dynamic> map, String path) {
    dynamic cur = map;
    for (final t in _tokensFromPath(path)) {
      if (t is String) {
        if (cur is Map) {
          cur = (cur as Map)[t];
        } else {
          return null;
        }
      } else if (t is int) {
        if (cur is List && t >= 0 && t < cur.length) {
          cur = cur[t];
        } else {
          return null;
        }
      }
    }
    return cur;
  }

  static T? _coerce<T>(dynamic v) {
    if (v == null) return null;

    if (T == String) return v.toString() as T;

    if (T == int) {
      if (v is int) return v as T;
      if (v is num) return v.toInt() as T;
      if (v is String) {
        final n = num.tryParse(v.trim());
        if (n != null) return n.toInt() as T;
        throw StateError('No se puede convertir "$v" (String) a int');
      }
    }

    if (T == double) {
      if (v is double) return v as T;
      if (v is num) return v.toDouble() as T;
      if (v is String) {
        final n = num.tryParse(v.trim());
        if (n != null) return n.toDouble() as T;
        throw StateError('No se puede convertir "$v" (String) a double');
      }
    }

    if (T == num) {
      if (v is num) return v as T;
      if (v is String) {
        final n = num.tryParse(v.trim());
        if (n != null) return n as T;
        throw StateError('No se puede convertir "$v" (String) a num');
      }
    }

    if (T == Map<String, dynamic>) {
      final m = _asMap(v);
      return (m == null ? null : m) as T;
    }

    if (T == DateTime && v is Timestamp) return v.toDate() as T;

    if (v is T) return v;

    throw StateError('No se puede convertir $v (tipo ${v.runtimeType}) a $T');
  }

  static Future<Map<String, dynamic>?> sectionAbs(
    String absoluteDocPath,
    String section,
  ) {
    return fieldAbs<Map<String, dynamic>>(absoluteDocPath, section);
  }

  /// Lee un CAMPO de un DOC con **ruta ABSOLUTA** (p. ej. 'users/{uid}', 'empresa.saldo')
  static Future<T?> fieldAbs<T>(
    String absoluteDocPath,
    String fieldPath,
  ) async {
    final doc = await fetchAbsPath(absoluteDocPath);
    if (doc == null) return null;
    // 'doc' trae también 'id', pero no molesta si no lo pides
    final value = _getByDotPath(doc, fieldPath);
    return _coerce<T>(value);
  }

  /// (Opcional) Igual que arriba pero con **ruta relativa** a users/<uid>
  static Future<T?> fieldPath<T>(
    String relativeDocPath,
    String fieldPath,
  ) async {
    final doc = await fetchPath(relativeDocPath);
    if (doc == null) return null;
    final value = _getByDotPath(doc, fieldPath);
    return _coerce<T>(value);
  }

  /// (Opcional) Si quieres desde subcolección directa bajo la raíz users/<uid>
  static Future<T?> getFieldFromSubdoc<T>({
    required String subcollection,
    required String docId,
    required String fieldName, // admite 'a.b.c'
  }) async {
    final snap = await _userDocRef().collection(subcollection).doc(docId).get();
    if (!snap.exists) return null;
    final data = _asMap(snap.data());
    if (data == null) return null;
    final value = _getByDotPath(data, fieldName);
    return _coerce<T>(value);
  }

  // Mapas dentro de mapas
  // Parseador simple: soporta foo.bar[0].baz
  static List<dynamic> _tokensFromPath(String path) {
    final tokens = <dynamic>[];
    for (final part in path.split('.')) {
      final re = RegExp(r'([^\[\]]+)|\[(\d+)\]');
      for (final m in re.allMatches(part)) {
        if (m.group(1) != null) tokens.add(m.group(1)!); // clave de map
        if (m.group(2) != null)
          tokens.add(int.parse(m.group(2)!)); // índice de lista
      }
    }
    return tokens;
  }
}

/* Ejemplo de uso:
  void initState() {
    super.initState();
    // Trae los datos después del primer frame para no bloquear el build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarYLoguear();
    });
  }
Future<void> _cargarYLoguear() async {
  try {
    await UidColeccionDoc.debugAbsDoc('users/{uid}/coleccion/documento'); // depura la ruta
    // accede al documento completo
    final doc1 = await UidColeccionDoc.fetchAbsPath('users/{uid}/coleccion/documento');
    // accede a un campo específico dentro del documento
    final phoneNum = await UidColeccionDoc.fieldAbs<num>('users/{uid}', 'phone');
    // accede a un mapa completo
    final empresa = await UidColeccionDoc.fieldAbs<Map<String,dynamic>>('users/{uid}', 'empresa');
    // accede a un mapa dentro de otro mapa de fornma indefinida
    final tema = await UidColeccionDoc.fieldAbs<String>('users/{uid}', 'empresa.holaMap');
    // accede a un campo dentro de un mapa dentro de otro mapa;
    final campo = await UidColeccionDoc.fieldAbs<String>('users/{uid}', 'empresa.holaMap.hola2');
    debugPrint('👉 phone (num): $campo');
  } catch (e, st) {
    debugPrint('❌ Error: $e');
    debugPrint('$st');
  }
}
*/

/*
    await UidColeccionDoc.debugAbsDoc('raiz/documento/coleccion/documento'); // depura la ruta
    // accede al documento completo
    final doc1 = await UidColeccionDoc.fetchAbsPath('raiz/documento/coleccion/documento');
    debugPrint('👉 phone (num): $doc1');
*/

/* Acceder a un campo especifico dentro de un map dentro de otro map:
// 1) Campo string
final nombre = await UidColeccionDoc.fieldAbs<String>(
  'users/{uid}', 
  'empresa.holaMap.nombre',
);
debugPrint('nombre: $nombre');

// 2) Campo numérico
final saldo = await UidColeccionDoc.fieldAbs<num>(
  'users/{uid}', 
  'empresa.holaMap.saldo',
);
debugPrint('saldo: $saldo');

// 3) Timestamp dentro de un map (lo convierte a DateTime)
final creado = await UidColeccionDoc.fieldAbs<DateTime>(
  'users/{uid}', 
  'empresa.holaMap.createdAt',
);
debugPrint('createdAt: $creado');

// 4) Con listas en el medio (índice entre corchetes)
final calle = await UidColeccionDoc.fieldAbs<String>(
  'users/{uid}', 
  'empresa.sucursales[0].direccion.calle',
);
debugPrint('calle: $calle');
*/
