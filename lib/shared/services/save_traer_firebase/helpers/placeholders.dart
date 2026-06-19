// lib/shared/services/save_traer_firebase/helpers/placeholders.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Placeholders {
  static final _db = FirebaseFirestore.instance;

  /// 🔹 Reemplaza {uid} y placeholders personalizados solo en RUTAS
  static Future<String> resolverRuta(
    String path, {
    Map<String, Map<String, String>> reglas = const {},
  }) async {
    var result = UidHelper.reemplazarUid(path);
    final valores = await resolverValores(reglas);
    for (final entry in valores.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value);
    }
    return result;
  }

  /// ✅ Resuelve TODOS los placeholders definidos en `reglas` (una lectura por placeholder)
  static Future<Map<String, String>> resolverValores(
    Map<String, Map<String, String>> reglas,
  ) async {
    final out = <String, String>{};

    for (final entry in reglas.entries) {
      final placeholder = entry.key;
      final rule = entry.value;
      final docTemplate = rule['doc'] ?? '';
      final field = rule['field'] ?? '';
      final mapPath = rule['map'];

      if (docTemplate.isEmpty || field.isEmpty) {
        throw Exception(
          'Regla inválida para "{$placeholder}": faltan doc/field.',
        );
      }

      final docPath = UidHelper.reemplazarUid(docTemplate);
      final snap = await _db.doc(docPath).get();
      final data = (snap.data() ?? {}) as Map<String, dynamic>;

      if (mapPath != null && mapPath.isNotEmpty && mapPath != '@root') {
        final nested = GuionHelper.leer(mapPath, field, data);
        if (nested == null) {
          throw Exception('Campo "$field" no encontrado en mapa "$mapPath".');
        }
        out[placeholder] = nested.toString();
      } else {
        final valor = data[field];
        if (valor == null) {
          throw Exception(
            'Campo "$field" no encontrado en "$docPath" para "{$placeholder}".',
          );
        }
        out[placeholder] = valor.toString();
      }
    }

    return out;
  }

  /// ✅ Reemplaza {uid} y {$placeholder} dentro de cualquier Mapa/List de DATA
  static Future<Map<String, dynamic>> reemplazarEnMapa(
    Map<String, dynamic> input, {
    Map<String, Map<String, String>> reglas = const {},
  }) async {
    final valores = await resolverValores(reglas);
    return reemplazarEnMapaConValores(input, valores: valores);
  }

  /// ✅ Versión eficiente: usa valores ya resueltos (evita lecturas repetidas)
  static Map<String, dynamic> reemplazarEnMapaConValores(
    Map<String, dynamic> input, {
    required Map<String, String> valores,
  }) {
    dynamic walk(dynamic v) {
      if (v is String) {
        var s = UidHelper.reemplazarUid(v); // {uid}
        for (final entry in valores.entries) {
          s = s.replaceAll('{${entry.key}}', entry.value); // {empresaID}, etc.
        }
        return s;
      } else if (v is Map) {
        return v.map((k, val) => MapEntry(k.toString(), walk(val)));
      } else if (v is List) {
        return v.map(walk).toList();
      }
      return v;
    }

    return input.map((k, v) => MapEntry(k.toString(), walk(v)));
  }
}

class UidHelper {
  static final _auth = FirebaseAuth.instance;

  static String get uid {
    final user = _auth.currentUser;
    if (user == null) throw Exception("👤 No hay usuario autenticado");
    print("👤 UID actual: ${user.uid}");
    return user.uid;
  }

  static String reemplazarUid(String path) {
    return path.replaceAll('{uid}', uid);
  }
}

class GuionHelper {
  static Map<String, dynamic> construir(
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

  static dynamic leer(String path, String campo, Map<String, dynamic> data) {
    dynamic nested = data;
    for (final part in path.split('-')) {
      if (nested is Map<String, dynamic> && nested.containsKey(part)) {
        nested = nested[part];
      } else {
        return null;
      }
    }
    return nested is Map<String, dynamic> ? nested[campo] : null;
  }
}

/*
await ColeccionWhere.ejemploBasico(
  rutas: ["empresas/{empresaID}/taxistasRegistrados"],
  condiciones: [
    {'mapaCampo': 'perfil.uidEmpresa', '==': '{uid}'},
  ],
  reglas: {
    'empresaID': {
      'doc': 'pasajeros/{uid}', // 👈 de este doc saco el valor
      'field': 'uidEmpresa',    // 👈 este campo tiene el ID de la empresa
    },
  },
  limite: 3,
);
*/
