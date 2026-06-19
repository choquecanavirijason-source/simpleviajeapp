// lib/core/services/users.UID.generico/save_local.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Guarda mapas por usuario y sección en el almacenamiento local.
/// Key: users.<uid>.<sectionName>  → JSON del mapa
class SaveLocalGenerico {
  SaveLocalGenerico._();

  static final _auth = FirebaseAuth.instance;

  /// Guarda el [map] bajo la sección [sectionName] para el usuario actual.
  /// Por defecto hace merge con lo existente y agrega updatedAt (local).
  static Future<bool> saveSectionMap({
    required String sectionName,
    required Map<String, dynamic> map,
    bool merge = true,
  }) async {
    print('💾 [LOCAL] Guardando sección "$sectionName"...');

    final uid = _requireUid();
    final prefs = await SharedPreferences.getInstance();
    final key = 'users.$uid.$sectionName';

    Map<String, dynamic> data = _sanitize(map)
      ..['updatedAt'] = DateTime.now().toIso8601String();

    if (merge) {
      final existingStr = prefs.getString(key);
      if (existingStr != null) {
        final existingDecoded = jsonDecode(existingStr);
        if (existingDecoded is Map) {
          final existing = Map<String, dynamic>.from(existingDecoded);
          // los nuevos valores pisan a los anteriores
          data = {...existing, ...data};
          print('↔️  [LOCAL] Merge con datos existentes para "$sectionName".');
        }
      }
    }

    final ok = await prefs.setString(key, jsonEncode(data));
    if (ok) {
      print(
        '✅ [LOCAL] Sección "$sectionName" guardada correctamente. Key: $key',
      );
    } else {
      print('❌ [LOCAL] Error al guardar sección "$sectionName".');
    }
    return ok;
  }

  // ----------------- helpers -----------------
  static String _requireUid() {
    final u = _auth.currentUser;
    if (u == null) {
      throw Exception('No autenticado. Inicia sesión para guardar localmente.');
    }
    return u.uid;
  }

  static Map<String, dynamic> _sanitize(Map<String, dynamic> map) {
    final out = <String, dynamic>{};
    map.forEach((k, v) {
      if (v == null) return;
      if (v is num && v.isNaN) return;
      out[k] = v;
    });
    return out;
  }
}

/* Ejemplo de uso:

  void _guardar() async {

    try {
      // Construye el mapa genérico desde los inputs
      final data = MapGenericoBuilder.fromControllers(_ctrls);

      // Guarda LOCAL (celular)
      await SaveLocalGenerico.saveSectionMap(
        sectionName: sectionName, // 'billetera' (la page manda)
        map: data,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Billetera guardada')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    }

  }
*/
