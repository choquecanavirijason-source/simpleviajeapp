import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DeleteDatosGenericos {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// reemplaza {uid} por el uid real del usuario actual
  static String _resolvePath(String path) {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No autenticado');
    return path.replaceAll('{uid}', user.uid);
  }

  /// Borra documentos filtrando por un campo
  static Future<void> eliminarDocumentoPorTitulo({
    required String absoluteCollectionPath,
    required String nombreCampo,
    required String valorCampo,
  }) async {
    final resolved = _resolvePath(absoluteCollectionPath);

    final snapshot = await _db
        .collection(resolved)
        .where(nombreCampo, isEqualTo: valorCampo)
        .get();

    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  /// Borra un documento directamente por ID
  static Future<void> eliminarDocumentoPorId({
    required String absoluteCollectionPath,
    required String docId,
  }) async {
    final resolved = _resolvePath(absoluteCollectionPath);
    await _db.collection(resolved).doc(docId).delete();
  }
}

/* Ejemplo de uso:
import 'package:buses2/core/services/users.UID.generico/delete_datos_genericos.dart';
...
  Future<void> _eliminar(String titulo) async {
    try {
      Cargando.show(context, message: 'Eliminando...');
      await DeleteDatosGenericos.eliminarDocumentoPorTitulo(
        absoluteCollectionPath: 'empresas/{uid}/documentos',
        nombreCampo: 'tituloDoc',
        valorCampo: titulo,
      );

      if (!mounted) return;
      setState(() {
        _titulos.remove(titulo);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Documento eliminado')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    } finally {
      Cargando.hide();
    }
  }
  ...
  onDelete: () => _eliminar(titulo),
*/
