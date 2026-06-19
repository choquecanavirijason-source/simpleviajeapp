import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Reemplazar {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  /// Reemplaza {uid} en la ruta por el UID del usuario actual
  static String rutaUID(String path) {
    final user = _auth.currentUser;
    if (user == null) throw Exception("No hay usuario autenticado");
    return path.replaceAll("{uid}", user.uid);
  }

  /// Reemplaza {newUID} y {newUID:alias} en la ruta.
  static String rutaNewUIDConAlias(String path, Map<String, String> aliasPool) {
    if (!path.contains("{newUID")) return path;

    final parts = path.split("/");
    final regex = RegExp(r'^\{newUID(?::([A-Za-z0-9_\-]+))?\}$');

    for (int i = 0; i < parts.length; i++) {
      final m = regex.firstMatch(parts[i]);
      if (m == null) continue;

      // Validar posición de documento (índice impar)
      if (i % 2 == 0) {
        throw Exception(
          "La marca {newUID[:alias]} debe ir en posición de documento. Path: $path",
        );
      }

      final alias = m.group(1); // puede ser null
      final collectionPath = parts.sublist(0, i).join("/");

      if (alias == null) {
        // Sin alias => id nuevo SIEMPRE
        final id = _db.collection(collectionPath).doc().id;
        parts[i] = id;
      } else {
        // Con alias => reusar si existe, sino generar y guardar
        final existing = aliasPool[alias];
        if (existing != null) {
          parts[i] = existing;
        } else {
          final id = _db.collection(collectionPath).doc().id;
          aliasPool[alias] = id;
          parts[i] = id;
        }
      }
    }

    return parts.join("/");
  }

  /// construye el (-) ejemplo "info-detalles"
  static Map<String, dynamic> guionMap(
    String path,
    Map<String, dynamic> value,
  ) {
    final parts = path.split('-');
    Map<String, dynamic> result = value;
    for (final part in parts.reversed) {
      result = {part: result};
    }
    return result;
  }

  /// lee el (-) ejemplo "info-detalles"
  static int? leerGuionMap(
    String path,
    String campo,
    Map<String, dynamic> data,
  ) {
    dynamic nested = data;
    for (final part in path.split('-')) {
      if (nested is Map<String, dynamic> && nested.containsKey(part)) {
        nested = nested[part];
      } else {
        return null;
      }
    }
    if (nested is Map<String, dynamic> && nested[campo] is int) {
      return nested[campo] as int;
    }
    return null;
  }

  /// Crea placeholders personalizados {empresaID}, {taxistaID}, etc.
  static Future<String> resolverRuta(
    String path, {
    Map<String, Map<String, String>> reglas = const {},
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No hay usuario autenticado');

    // 1) Reemplazo básico de {uid}
    var result = path.replaceAll('{uid}', user.uid);

    // 2) Para cada placeholder declarado en reglas, si aparece en el path, lo resolvemos
    for (final entry in reglas.entries) {
      final placeholder = entry.key; // p.ej. 'empresaID'
      if (!result.contains('{$placeholder}')) continue;

      final rule = entry.value;
      final docTemplate = rule['doc'] ?? '';
      final field = rule['field'] ?? '';
      final mapDash = rule['map']; // opcional: 'a-b-c' => data[a][b][c]

      if (docTemplate.isEmpty || field.isEmpty) {
        throw Exception(
          'Regla inválida para "{$placeholder}": faltan doc/field.',
        );
      }

      // La ruta del doc puede incluir {uid} u otros ya resueltos
      final docPath = _aplicarValoresBasicos(docTemplate, user.uid);

      final snap = await _db.doc(docPath).get();
      final data = (snap.data() as Map<String, dynamic>?) ?? {};

      Map<String, dynamic> fuente = data;
      if (mapDash != null && mapDash.isNotEmpty && mapDash != '@root') {
        for (final k in mapDash.split('-')) {
          final next = fuente[k];
          if (next is Map<String, dynamic>) {
            fuente = next;
          } else {
            throw Exception('Mapa "$mapDash" no encontrado en "$docPath".');
          }
        }
      }

      final valor = fuente[field];
      if (valor == null) {
        throw Exception('Campo "$field" no encontrado en "$docPath".');
      }

      result = result.replaceAll('{$placeholder}', valor.toString());
    }

    return result;
  }

  static String _aplicarValoresBasicos(String s, String uid) {
    // Por ahora solo {uid}. (Si luego quieres permitir más, se agregan aquí.)
    return s.replaceAll('{uid}', uid);
  }

  /*
  /// === AÑADIDO: helpers para {todo} en rutas de MAPAS (con guiones) ===
  // === Helpers de path con guiones y {todo} ===
  static bool tieneTodoEnGuion(String mapPath) {
    if (mapPath.isEmpty || mapPath == '@root') return false;
    return mapPath.split('-').contains('{todo}');
  }

  static List<String> partesDeGuion(String mapPath) {
    if (mapPath.isEmpty || mapPath == '@root') return const [];
    final s = mapPath.startsWith('@root-') ? mapPath.substring(6) : mapPath;
    return s.split('-');
  }

  /// Expansor genérico de {todo} en cualquier posición.
  /// `procesarHoja` define qué hacer con el Map hoja (filtrar, transformar, etc.).
  static Map<String, dynamic>? expandirTodos(
    Object? node,
    List<String> parts,
    int idx,
    Map<String, dynamic>? Function(Map<String, dynamic>?) procesarHoja,
  ) {
    if (idx >= parts.length) {
      return procesarHoja(node is Map<String, dynamic> ? node : null);
    }
    final p = parts[idx];
    if (p == '{todo}') {
      if (node is! Map<String, dynamic>) return null;
      final out = <String, dynamic>{};
      node.forEach((k, v) {
        final child = expandirTodos(v, parts, idx + 1, procesarHoja);
        if (child != null) out[k] = child;
      });
      return out.isEmpty ? null : out;
    } else {
      if (node is! Map<String, dynamic>) return null;
      final next = node[p];
      return expandirTodos(next, parts, idx + 1, procesarHoja);
    }
  }
  */
}
