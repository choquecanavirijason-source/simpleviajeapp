import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo para lugares guardados del usuario (Casa, Trabajo, Favoritos)
class LugarGuardado {
  final String? id;
  final String tipo; // 'casa', 'trabajo', 'favorito'
  final String nombre; // Para favoritos, el usuario puede dar un nombre
  final double lat;
  final double lng;
  final String? texto;
  final String? calle;
  final String? ciudad;
  final String? departamento;
  final String? pais;
  final DateTime? fechaCreacion;

  LugarGuardado({
    this.id,
    required this.tipo,
    required this.nombre,
    required this.lat,
    required this.lng,
    this.texto,
    this.calle,
    this.ciudad,
    this.departamento,
    this.pais,
    this.fechaCreacion,
  });

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  factory LugarGuardado.fromMap(Map<String, dynamic> map, {String? docId}) {
    return LugarGuardado(
      id: docId,
      tipo: map['tipo']?.toString() ?? '',
      nombre: map['nombre']?.toString() ?? '',
      lat: _toDouble(map['lat']) ?? 0.0,
      lng: _toDouble(map['lng']) ?? 0.0,
      texto: map['texto']?.toString(),
      calle: map['calle']?.toString(),
      ciudad: map['ciudad']?.toString(),
      departamento: map['departamento']?.toString(),
      pais: map['pais']?.toString(),
      fechaCreacion: map['fechaCreacion'] != null
          ? (map['fechaCreacion'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tipo': tipo,
      'nombre': nombre,
      'lat': lat,
      'lng': lng,
      if (texto != null) 'texto': texto,
      if (calle != null) 'calle': calle,
      if (ciudad != null) 'ciudad': ciudad,
      if (departamento != null) 'departamento': departamento,
      if (pais != null) 'pais': pais,
      'fechaCreacion': fechaCreacion ?? FieldValue.serverTimestamp(),
    };
  }
}

/// Repositorio para gestionar lugares guardados
class LugaresGuardadosRepo {
  static final _db = FirebaseFirestore.instance;

  /// Obtener un lugar específico (casa o trabajo)
  static Future<LugarGuardado?> obtenerLugar({
    required String uid,
    required String tipo, // 'casa' o 'trabajo'
  }) async {
    try {
      final doc = await _db
          .collection('usuarios')
          .doc(uid)
          .collection('lugares')
          .doc(tipo)
          .get();

      if (!doc.exists) return null;
      return LugarGuardado.fromMap(doc.data()!, docId: doc.id);
    } catch (e) {
      print('Error al obtener lugar $tipo: $e');
      return null;
    }
  }

  /// Guardar casa o trabajo
  static Future<bool> guardarLugar({
    required String uid,
    required LugarGuardado lugar,
  }) async {
    try {
      // Para casa y trabajo, usamos el tipo como ID del documento
      if (lugar.tipo == 'casa' || lugar.tipo == 'trabajo') {
        await _db
            .collection('usuarios')
            .doc(uid)
            .collection('lugares')
            .doc(lugar.tipo)
            .set(lugar.toMap(), SetOptions(merge: true));
        return true;
      }
      return false;
    } catch (e) {
      print('Error al guardar lugar: $e');
      return false;
    }
  }

  /// Eliminar casa o trabajo
  static Future<bool> eliminarLugar({
    required String uid,
    required String tipo,
  }) async {
    try {
      await _db
          .collection('usuarios')
          .doc(uid)
          .collection('lugares')
          .doc(tipo)
          .delete();
      return true;
    } catch (e) {
      print('Error al eliminar lugar: $e');
      return false;
    }
  }

  /// Obtener todos los favoritos
  static Future<List<LugarGuardado>> obtenerFavoritos({
    required String uid,
  }) async {
    try {
      final snapshot = await _db
          .collection('usuarios')
          .doc(uid)
          .collection('favoritos')
          .orderBy('fechaCreacion', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => LugarGuardado.fromMap(doc.data(), docId: doc.id))
          .toList();
    } catch (e) {
      print('Error al obtener favoritos: $e');
      return [];
    }
  }

  /// Agregar a favoritos
  static Future<String?> agregarFavorito({
    required String uid,
    required LugarGuardado lugar,
  }) async {
    try {
      final docRef = await _db
          .collection('usuarios')
          .doc(uid)
          .collection('favoritos')
          .add(lugar.toMap());
      return docRef.id;
    } catch (e) {
      print('Error al agregar favorito: $e');
      return null;
    }
  }

  /// Eliminar favorito
  static Future<bool> eliminarFavorito({
    required String uid,
    required String favoritoId,
  }) async {
    try {
      await _db
          .collection('usuarios')
          .doc(uid)
          .collection('favoritos')
          .doc(favoritoId)
          .delete();
      return true;
    } catch (e) {
      print('Error al eliminar favorito: $e');
      return false;
    }
  }

  /// Stream de casa y trabajo
  static Stream<Map<String, LugarGuardado?>> streamLugares({
    required String uid,
  }) {
    return _db
        .collection('usuarios')
        .doc(uid)
        .collection('lugares')
        .snapshots()
        .map((snapshot) {
          final Map<String, LugarGuardado?> lugares = {
            'casa': null,
            'trabajo': null,
          };

          for (final doc in snapshot.docs) {
            if (doc.id == 'casa' || doc.id == 'trabajo') {
              lugares[doc.id] = LugarGuardado.fromMap(
                doc.data(),
                docId: doc.id,
              );
            }
          }

          return lugares;
        });
  }

  /// Stream de favoritos
  static Stream<List<LugarGuardado>> streamFavoritos({required String uid}) {
    return _db
        .collection('usuarios')
        .doc(uid)
        .collection('favoritos')
        .orderBy('fechaCreacion', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => LugarGuardado.fromMap(doc.data(), docId: doc.id))
              .toList(),
        );
  }
}
