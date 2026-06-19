// lib/core/services/users.UID.generico/carga_img_local.dart
//
// Carga SOLO la imagen desde almacenamiento LOCAL usando la ruta guardada
// en SharedPreferences (users.<uid>.<sectionName> → { 'logoLocalPath': '<ruta>' }).
// Si no hay ruta o el archivo no existe, retorna null.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CargaImgLocal {
  CargaImgLocal._();

  static final _auth = FirebaseAuth.instance;

  /// Lee la ruta (String) guardada en local para la imagen. Si no existe, null.
  static Future<String?> loadPath({
    required String sectionName,
    String fieldName = 'logoLocalPath',
  }) async {
    print(
      '📥 [IMG-LOCAL] Leyendo ruta → sección "$sectionName", campo "$fieldName"...',
    );

    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      print('🚫 [IMG-LOCAL] No autenticado; no se puede leer local.');
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final key = 'users.$uid.$sectionName';
    final str = prefs.getString(key);
    if (str == null) {
      print('⚠️ [IMG-LOCAL] No hay mapa para "$key".');
      return null;
    }

    try {
      final decoded = jsonDecode(str);
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        final path = map[fieldName] as String?;
        if (path == null || path.trim().isEmpty) {
          print('⚠️ [IMG-LOCAL] "$fieldName" no está definido.');
          return null;
        }
        print('✅ [IMG-LOCAL] Ruta encontrada: $path');
        return path;
      }
    } catch (e) {
      debugPrint('💥 [IMG-LOCAL] Error decodificando JSON: $e');
    }
    return null;
  }

  /// Devuelve el File si la ruta guardada existe; si no, null.
  static Future<File?> loadFile({
    required String sectionName,
    String fieldName = 'logoLocalPath',
  }) async {
    final path = await loadPath(sectionName: sectionName, fieldName: fieldName);
    if (path == null) return null;

    final f = File(path);
    final exists = await f.exists();
    if (!exists) {
      print('🟡 [IMG-LOCAL] Archivo no existe en disco: $path');
      return null;
    }

    print('🟢 [IMG-LOCAL] Archivo listo: $path');
    return f;
  }
}

/* Ejemplo de uso:
File? _imgFile;
...
void initState() {
  super.initState();
  _baseFareCtrl = NumberEditingController(allowDecimal: true, decimalPlaces: 2);
  _baseKmCtrl   = NumberEditingController(allowDecimal: true, decimalPlaces: 2);

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final f = await CargaImgLocal.loadFile(sectionName: sectionName); // 'billetera'
    if (!mounted) return;
    if (f != null) {
      setState(() => _imgFile = f); // muestra la imagen si existe
    }
  });
}
*/
