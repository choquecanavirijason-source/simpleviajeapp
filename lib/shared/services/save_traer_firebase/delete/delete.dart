// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import '../helpers/rutas.dart';
import '../helpers/placeholders.dart';

/// [V.1.0.0] - Helper para eliminaciones en Firestore
///
/// Funciones:
///  - eliminarCampo(): borra un campo (admite rutas anidadas "a.b.c").
///  - eliminarCampos(): borra varios campos.
///  - eliminarDocumento(): borra todo el documento.
///  - eliminarServicioTarifa(): caso de uso específico de tarifas por departamento.
class DocDelete {
  /// Elimina **un campo** de un documento.
  ///
  /// - [rutaDoc] admite placeholders tipo `empresas/{empresaID}/config`
  /// - [clave] puede ser una ruta anidada `"a.b.c"` o una clave de nivel raíz `"taxi"`.
  /// - Si el `update(FieldValue.delete())` falla por la clave dada, cae a estrategia de
  ///   reescritura: lee el doc, quita la clave raíz si existe y hace `set(dataNueva)`.
  static Future<void> eliminarCampo({
    required String rutaDoc,
    required String clave,
    Map<String, Map<String, String>> reglas = const {},
  }) async {
    final rutaResuelta = await Placeholders.resolverRuta(
      rutaDoc,
      reglas: reglas,
    );
    final docRef = Rutas.rutaDocumento(rutaResuelta);

    // Intento 1: delete con update (soporta "a.b.c")
    try {
      await docRef.update({clave: FieldValue.delete()});
      print('🗑️  [OK] update(delete) $rutaResuelta :: $clave');
      return;
    } catch (e) {
      print('⚠️  update(delete) falló, intento fallback con set(): $e');
    }

    // Intento 2 (fallback): leer todo el documento, remover clave raíz y setear
    final snap = await docRef.get();
    if (!snap.exists) {
      print('ℹ️ Documento no existe: $rutaResuelta');
      return;
    }
    final data = Map<String, dynamic>.from(snap.data() as Map? ?? {});
    if (data.containsKey(clave)) {
      data.remove(clave);
      await docRef.set(data);
      print('🗑️  [OK] set() sin clave raíz $clave en $rutaResuelta');
    } else {
      print(
        'ℹ️  Clave "$clave" no encontrada en doc $rutaResuelta (nada que borrar).',
      );
    }
  }

  /// Elimina **varios campos** en una sola operación update().
  /// Si falla, hará fallback campo por campo con [eliminarCampo].
  static Future<void> eliminarCampos({
    required String rutaDoc,
    required List<String> claves,
    Map<String, Map<String, String>> reglas = const {},
  }) async {
    if (claves.isEmpty) return;

    final rutaResuelta = await Placeholders.resolverRuta(
      rutaDoc,
      reglas: reglas,
    );
    final docRef = Rutas.rutaDocumento(rutaResuelta);

    // Intento con update() de una
    try {
      final mapa = {for (final k in claves) k: FieldValue.delete()};
      await docRef.update(mapa);
      print(
        '🗑️  [OK] update(delete) múltiple $rutaResuelta :: ${claves.join(", ")}',
      );
      return;
    } catch (e) {
      print('⚠️  update múltiple falló, intento campo por campo: $e');
    }

    // Fallback: una por una
    for (final k in claves) {
      await eliminarCampo(rutaDoc: rutaDoc, clave: k, reglas: reglas);
    }
  }

  /// Elimina **todo el documento**.
  static Future<void> eliminarDocumento({
    required String rutaDoc,
    Map<String, Map<String, String>> reglas = const {},
  }) async {
    final rutaResuelta = await Placeholders.resolverRuta(
      rutaDoc,
      reglas: reglas,
    );
    final docRef = Rutas.rutaDocumento(rutaResuelta);
    await docRef.delete();
    print('🗑️  [OK] Documento borrado: $rutaResuelta');
  }

  // ---------------------------------------------------------------------------
  // 🎯 CASO ESPECÍFICO DE TU APP
  // Colección: empresas/mujeresalvolante/tarifas/{departamentoId}
  // Dentro del doc => clave del servicio: p. ej. "taxi", "moto_taxi"
  // ---------------------------------------------------------------------------

  /// Borra la **clave del servicio** de un documento de tarifas por departamento.
  ///
  /// Ejemplo:
  /// ```dart
  /// await DocDelete.eliminarServicioTarifa(
  ///   departamentoId: 'Cochabamba',
  ///   serviceKey: 'taxi',
  /// );
  /// ```
  static Future<void> eliminarServicioTarifa({
    required String departamentoId,
    required String serviceKey,
  }) async {
    final rutaDoc = 'empresas/mujeresalvolante/tarifas/$departamentoId';
    // Primero intentamos con update(FieldValue.delete()) (soporta anidado)
    try {
      final docRef = Rutas.rutaDocumento(rutaDoc);
      await docRef.update({serviceKey: FieldValue.delete()});
      print('🗑️  [OK] servicio "$serviceKey" borrado en $rutaDoc (update)');
      return;
    } catch (e) {
      print('⚠️  update(delete) falló en $rutaDoc → fallback con set(): $e');
    }

    // Fallback compatible: leer doc, quitar clave raíz y setear
    final docRef = Rutas.rutaDocumento(rutaDoc);
    final snap = await docRef.get();
    if (!snap.exists) {
      print('ℹ️ Documento no existe: $rutaDoc');
      return;
    }
    final data = Map<String, dynamic>.from(snap.data() as Map? ?? {});
    if (!data.containsKey(serviceKey)) {
      print('ℹ️ Clave "$serviceKey" no existe en $rutaDoc (nada que borrar).');
      return;
    }
    data.remove(serviceKey);
    await docRef.set(data);
    print(
      '🗑️  [OK] servicio "$serviceKey" borrado en $rutaDoc (set fallback)',
    );
  }
}
