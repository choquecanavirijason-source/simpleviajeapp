// lib/core/services/users.UID.generico/carga_img_local_nube.dart
//
// Orquestador: intenta cargar la imagen PRIMERO de LOCAL (ruta guardada en prefs),
// si no existe, la carga desde la NUBE (Firestore: users/<uid>.<section>.<field>).
//
// Usa:
//  - CargaImgLocal.loadFile(sectionName, fieldName)
//  - CargaImgNube.loadUrl(sectionName, fieldName)

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:buses2/core/services/users.UID.generico/carga_img_local.dart';
import 'package:buses2/core/services/users.UID.generico/carga_img_nube.dart';

class CargaImgLocalNubeResult {
  final File? file; // Imagen encontrada en local (si existe)
  final String? url; // URL de nube (si local no estaba)
  const CargaImgLocalNubeResult({this.file, this.url});

  bool get hasLocal => file != null;
  bool get hasCloud => url != null;
}

class CargaImgLocalNube {
  CargaImgLocalNube._();

  /// Intenta LOCAL primero; si no hay, NUBE.
  /// [localFieldName] = clave del path en prefs (default: 'logoLocalPath')
  /// [cloudFieldName] = clave del url en nube (default: 'logoUrl')
  static Future<CargaImgLocalNubeResult> load({
    required String sectionName,
    String localFieldName = 'logoLocalPath',
    String cloudFieldName = 'logoUrl',
  }) async {
    debugPrint('🖼️ [IMG-L→N] Cargando imagen para sección "$sectionName"...');

    // 1) LOCAL
    final localFile = await CargaImgLocal.loadFile(
      sectionName: sectionName,
      fieldName: localFieldName,
    );
    if (localFile != null) {
      debugPrint('✅ [IMG-L→N] Encontrada en LOCAL: ${localFile.path}');
      return CargaImgLocalNubeResult(file: localFile);
    }
    debugPrint('↪️ [IMG-L→N] No hay imagen local. Probando NUBE...');

    // 2) NUBE
    final url = await CargaImgNube.loadUrl(
      sectionName: sectionName,
      fieldName: cloudFieldName,
    );
    if (url != null) {
      debugPrint('✅ [IMG-L→N] URL de NUBE: $url');
      return CargaImgLocalNubeResult(url: url);
    }

    debugPrint('⚠️ [IMG-L→N] No se encontró imagen ni en LOCAL ni en NUBE.');
    return const CargaImgLocalNubeResult();
  }
}

/* Ejemplo de uso:
File? _imgFile;
String? _imgUrl;
...
void initState() {
  super.initState();
  _baseFareCtrl = NumberEditingController(allowDecimal: true, decimalPlaces: 2);
  _baseKmCtrl   = NumberEditingController(allowDecimal: true, decimalPlaces: 2);

  _ctrls = {
    'baseFare': _baseFareCtrl,
    'baseKm'  : _baseKmCtrl,
    // 👉 mañana agregas: 'waitingFee': _waitingFeeCtrl,
  };

  // Carga img LOCAL -> si no hay, NUBE
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final res = await CargaImgLocalNube.load(
      sectionName: sectionName,    // 'billetera'
      // localFieldName: 'logoLocalPath', // si usas otra clave en prefs
      // cloudFieldName: 'logoUrl',       // si usas otra clave en Firestore
    );
    if (!mounted) return;
    setState(() {
      _imgFile = res.file; // si viene de local
      _imgUrl  = res.url;  // si viene de nube
    });
  });
}
...
// (opcional) preview local si existe
if (_imgFile != null) ...[
  ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Image.file(
      _imgFile!,
      height: 120,
      width: double.infinity,
      fit: BoxFit.cover,
    ),
  ),
  const SizedBox(height: 12),
],

SubirFotoWidget(
  icono: Icons.upload,
  texto: "Subir Logo",
  initialFile: _imgFile, // <- img local
  initialUrl: _imgUrl,   // <- img nube
  onPicked: (file) {
    setState(() {
      _imgFile = file;   // se verá de inmediato dentro del propio widget
      _imgUrl  = null;   // opcional: si elegiste local, limpia la url
    });
  },
),
*/
