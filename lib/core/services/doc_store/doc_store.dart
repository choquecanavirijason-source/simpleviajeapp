// import 'package:buses2/core/services/doc_store/doc_store.dart';
export 'ports.dart';
export 'doc_store_service.dart';
export 'firebase_adapter.dart' show FirebaseDocumentSaverAdapter;
// export 'supabase_adapter.dart' show SupabaseDocumentSaverAdapter; // si lo agregas luego

/* Se usa asi:
app_module.dart:
import 'package:buses2/core/services/doc_store/doc_store.dart';
...
  // === Guardado de documentos (backend actual: Firebase) ===
  i.addSingleton<DocumentSaverPort>(FirebaseDocumentSaverAdapter.new);
  i.addSingleton<DocStoreService>(() => DocStoreService(i.get<DocumentSaverPort>()));

Boton nombre_archivo_usara.dart:
import 'package:buses2/core/services/doc_store/doc_store.dart';
...

  // ... haces el guardado aquí ...

}
*/
