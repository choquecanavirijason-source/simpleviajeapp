import 'package:cloud_firestore/cloud_firestore.dart';

class Rutas {
  // Construye una referencia a una colección a partir de una ruta
  // Ejemplo: "empresas/empresa123/taxistasRegistrados"
  // Debe terminar en colección
  static CollectionReference rutaCollection(String ruta) {
    final firestore = FirebaseFirestore.instance;
    final partes = LineSeparacion.separador(ruta);

    dynamic ref = firestore.collection(partes.first);

    for (int i = 1; i < partes.length; i++) {
      final segmento = partes[i];
      if (i.isOdd) {
        ref = ref.doc(segmento); // índices impares → documento
      } else {
        ref = ref.collection(segmento); // índices pares → colección
      }
    }

    if (ref is CollectionReference) {
      return ref;
    } else {
      throw ArgumentError("La ruta '$ruta' debe terminar en Coleccion.");
    }
  }

  // Construye una referencia a un documento a partir de una ruta
  // Ejemplo válido: "empresas/empresa123"
  // Debe terminar en documento
  static DocumentReference rutaDocumento(String ruta) {
    final firestore = FirebaseFirestore.instance;
    final partes = LineSeparacion.separador(ruta);

    dynamic ref = firestore.collection(partes.first);

    for (int i = 1; i < partes.length; i++) {
      final segmento = partes[i];
      if (i.isOdd) {
        ref = ref.doc(segmento); // índices impares → documento
      } else {
        ref = ref.collection(segmento); // índices pares → colección
      }
    }

    if (ref is DocumentReference) {
      return ref;
    } else {
      throw ArgumentError(
        "La ruta '$ruta' termina en una colección. Se esperaba un documento.",
      );
    }
  }
}

class LineSeparacion {
  /// Divide la ruta en segmentos
  /// Ejemplo: "empresas/empresa123/taxistasRegistrados"
  static List<String> separador(String ruta) {
    if (ruta.trim().isEmpty) {
      throw ArgumentError("La ruta no puede estar vacía");
    }
    return ruta.split('/').where((p) => p.isNotEmpty).toList();
  }
}
