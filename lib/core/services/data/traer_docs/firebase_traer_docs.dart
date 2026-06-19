import 'package:cloud_firestore/cloud_firestore.dart';
import 'traer_docs.dart';

class FirebaseTraerDocs implements TraerDocs {
  final FirebaseFirestore _db;
  final String collection;
  FirebaseTraerDocs({FirebaseFirestore? db, this.collection = 'documentos'})
    : _db = db ?? FirebaseFirestore.instance;

  @override
  Future<DocumentoRemoto?> getDocumento({
    required String uid,
    required String templateId,
  }) async {
    // Ajusta la ruta a tu esquema real
    final ref = _db
        .collection(collection)
        .doc(uid)
        .collection('templates')
        .doc(templateId);
    final snap = await ref.get();
    if (!snap.exists) return null;
    final data = snap.data()!;
    return DocumentoRemoto(
      campos: (data['campos'] as Map?)?.cast<String, String>(),
      urls: (data['urls'] as Map?)?.cast<String, String>(),
    );
  }
}
