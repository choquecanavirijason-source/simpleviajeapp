abstract class TraerDocs {
  Future<DocumentoRemoto?> getDocumento({
    required String uid,
    required String templateId,
  });
}

class DocumentoRemoto {
  final Map<String, String>? campos;
  final Map<String, String>? urls;
  DocumentoRemoto({this.campos, this.urls});
}
