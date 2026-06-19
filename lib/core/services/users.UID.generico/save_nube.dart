import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SaveBilleteraNube {
  SaveBilleteraNube._();

  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Guarda en: users/<uid> con el campo `<nombreCampo>`: { ...datos }
  /// Ej: nombreCampo: 'billetera'  -> users/<uid>.billetera = {...}
  ///     nombreCampo: 'suscripcion' -> users/<uid>.suscripcion = {...}
  static Future<void> guardar({
    required Map<String, dynamic> data,
    required String nombreCampo, // <-- lo decides desde la page
  }) async {
    print('⬆️ [NUBE] Guardando campo "$nombreCampo"...');
    final user = _auth.currentUser;
    if (user == null) {
      print('❌ [NUBE] Usuario no autenticado.');
      throw Exception('No autenticado. Inicia sesión para guardar.');
    }

    final sanitized = _sanitize(data)
      ..['updatedAt'] = FieldValue.serverTimestamp();

    try {
      await _db.collection('users').doc(user.uid).set({
        nombreCampo: sanitized,
      }, SetOptions(merge: true));
      print('✅ [NUBE] Campo "$nombreCampo" guardado correctamente.');
    } catch (e) {
      print('❌ [NUBE] Error al guardar campo "$nombreCampo": $e');
      rethrow;
    }
  }

  // Quita null/NaN para no ensuciar Firestore.
  static Map<String, dynamic> _sanitize(Map<String, dynamic> data) {
    final out = <String, dynamic>{};
    data.forEach((k, v) {
      if (v == null) return;
      if (v is num && v.isNaN) return;
      out[k] = v;
    });
    return out;
  }
}

/* Ejemplo de uso:
static const String sectionName = 'billetera'; // Nombre del campo en Firestore

  void _guardar() async {

    try {
      // Construye el mapa genérico desde los inputs
      final data = MapGenericoBuilder.fromControllers(_ctrls);

      // Guarda en <uid>.generico = { ... }
      await SaveBilleteraNube.guardar(
        data: data,
        nombreCampo: sectionName,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Billetera guardada')),
      );
    } catch (e) {
      print('❌ [NUBE] Error al guardar billetera: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    }

  }
*/
