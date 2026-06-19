import 'package:cloud_firestore/cloud_firestore.dart';
import '../reemplazar/reemplazar.dart';

class NMasUno {
  static final _db = FirebaseFirestore.instance;

  static Future<String> resolver({
    required String absoluteDocPath,
    required String nombreCampoContador,
    String? nombreMapContador,
    Map<String, Map<String, String>> reglas = const {},
  }) async {
    final path1 = await Reemplazar.resolverRuta(
      absoluteDocPath,
      reglas: reglas,
    );
    final ref = _db.doc(path1);

    final snap = await ref.get();
    final data = snap.data() as Map<String, dynamic>? ?? {};

    int current = 0;
    if (nombreMapContador != null && nombreMapContador.isNotEmpty) {
      final raw = Reemplazar.leerGuionMap(
        nombreMapContador,
        nombreCampoContador,
        data,
      );
      current = raw ?? 0;
    } else {
      final raw = data[nombreCampoContador];
      current = (raw is int) ? raw : 0;
    }

    final next = current + 1;

    if (nombreMapContador != null && nombreMapContador.isNotEmpty) {
      await ref.set(
        Reemplazar.guionMap(nombreMapContador, {nombreCampoContador: next}),
        SetOptions(merge: true),
      );
    } else {
      await ref.set({nombreCampoContador: next}, SetOptions(merge: true));
    }

    return 'doc_$next'; // <-- SOLO el nombre del doc
  }
}

/* Ejemplo de uso:
  try {
    final nombreGenerado = await NMasUno.resolver( //doc_1
      absoluteDocPath: 'empresas/{empresaID}',
      //nombreMapContador: 'contadorDocumentos', // 👈 map anidado
      nombreCampoContador: 'contadorDocumentos',
    );
    await DocSets.set(
      absoluteDocPath: ['empresas/{empresaID}'],
      nombreMap: ['documentos-$nombreGenerado'],
      data: [
        {
          'nombreBtn': _nombreBtnCtrl.text.trim(),
          'subtituloBtn': _subtituloBtnCtrl.text.trim(),
          'tituloDoc': _tituloDocCtrl.text.trim(),
          'camposTexto': camposTextoMap,
          'camposArchivo': camposArchivoMap,
          'orden' : int.parse(nombreGenerado.split('_').last), // 👈 orden numérico
        },
      ],
    );
*/
