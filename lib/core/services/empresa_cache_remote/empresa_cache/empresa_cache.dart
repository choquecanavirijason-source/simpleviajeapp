// SOLO caché: guardado/lectura/borrado + serialización segura
// lib/features/home_empresa_features/datos_empresa/empresa_cache_remote/empresa_cache/empresa_cache.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:buses2/core/services/user_empresa/empresa_model.dart';

class EmpresaCache {
  static const _prefix = 'empresa_cache';
  static String _key(String uid) => '$_prefix:$uid';

  /// --- Serialización segura (DateTime/Timestamp → ISO) ---
  static dynamic _toJsonSafe(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toIso8601String();
    // Evita importar firestore aquí: detectamos por nombre de tipo
    if (value.runtimeType.toString() == 'Timestamp') {
      try {
        return (value as dynamic).toDate().toIso8601String();
      } catch (_) {}
    }
    return value;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is num) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt());
      } catch (_) {}
    }
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {}
    }
    if (value.runtimeType.toString() == 'Timestamp') {
      try {
        return (value as dynamic).toDate();
      } catch (_) {}
    }
    return null;
  }

  static Map<String, dynamic> _mapToJsonSafe(Map<String, dynamic> map) {
    final out = <String, dynamic>{};
    map.forEach((k, v) {
      if (v is Map<String, dynamic>) {
        out[k] = _mapToJsonSafe(v);
      } else if (v is List) {
        out[k] = v
            .map(
              (e) => e is Map<String, dynamic>
                  ? _mapToJsonSafe(e)
                  : _toJsonSafe(e),
            )
            .toList();
      } else {
        out[k] = _toJsonSafe(v);
      }
    });
    return out;
  }

  static Map<String, dynamic> _normalizeForModel(Map<String, dynamic> map) {
    final out = Map<String, dynamic>.from(map);
    for (final key in const ['createdAt', 'updatedAt', 'deletedAt']) {
      if (out.containsKey(key)) {
        final dt = _parseDate(out[key]);
        if (dt != null) out[key] = dt;
      }
    }
    return out;
  }

  /// Guarda TODO el objeto o solo un subset de campos (si [fields] no es null/empty).
  static Future<void> save(
    String uid,
    Empresa? empresa, {
    Set<String>? fields,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (empresa == null) {
        await prefs.remove(_key(uid));
        debugPrint('🗑️ Empresa cache borrada para $uid');
        return;
      }
      final fullSafe = _mapToJsonSafe(empresa.toMap());
      final data = (fields == null || fields.isEmpty)
          ? fullSafe
          : Map<String, dynamic>.fromEntries(
              fullSafe.entries.where((e) => fields.contains(e.key)),
            );

      await prefs.setString(_key(uid), jsonEncode(data));
      debugPrint(
        '✅ Empresa cache guardada para $uid (campos=${data.keys.toList()})',
      );
    } catch (e, st) {
      debugPrint('❌ Error guardando Empresa cache: $e\n$st');
    }
  }

  static Future<Empresa?> read(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_key(uid));
      if (jsonStr == null) return null;
      final Map<String, dynamic> map = jsonDecode(jsonStr);
      final normalized = _normalizeForModel(map);
      return Empresa.fromMap(normalized);
    } catch (e, st) {
      debugPrint('❌ Error leyendo Empresa cache: $e\n$st');
      return null;
    }
  }

  static Future<void> clear(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(uid));
    } catch (e) {
      debugPrint('❌ Error limpiando Empresa cache: $e');
    }
  }
}

/* Se usa así:

import 'package:buses2/features/home_empresa_features/datos_empresa/empresa_cache_remote/empresa_cache_remote.dart';

// Guardar (subset opcional):
await EmpresaCache.save(uid, empresa, fields: {'email','nombreEmpresa','representante','telefono','logoUrl'});
// (si omitís "fields", guarda TODO el objeto)

// Leer:
final Empresa? e = await EmpresaCache.read(uid);

// Borrar:
await EmpresaCache.clear(uid);
// (equivalente: await EmpresaCache.save(uid, null);)
*/
