import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CargaImgNube {
  CargaImgNube._();

  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static Map<String, dynamic>? _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  /// Devuelve la URL (String) o null si no existe.
  static Future<String?> loadUrl({
    required String sectionName, // ej: 'billetera'
    String fieldName = 'logoUrl', // clave donde guardaste el URL
  }) async {
    debugPrint(
      '☁️ [IMG-NUBE] Cargando "$sectionName.$fieldName" desde Firestore...',
    );
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      debugPrint('🚫 [IMG-NUBE] No autenticado.');
      return null;
    }

    final snap = await _db.collection('users').doc(uid).get();
    final data = _asMap(snap.data());
    final section = _asMap(data?[sectionName]);
    final url = section?[fieldName];

    if (url is String && url.trim().isNotEmpty) {
      debugPrint('✅ [IMG-NUBE] URL encontrada: $url');
      return url;
    }

    debugPrint(
      '⚠️ [IMG-NUBE] No se encontró URL en "$sectionName.$fieldName".',
    );
    return null;
  }
}

/* Ejemplo de uso:
String? _imgUrl;
...
@override
void initState() {
  super.initState();
  _baseFareCtrl = NumberEditingController(allowDecimal: true, decimalPlaces: 2);
  _baseKmCtrl   = NumberEditingController(allowDecimal: true, decimalPlaces: 2);

  _ctrls = {
    'baseFare': _baseFareCtrl,
    'baseKm'  : _baseKmCtrl,
    // 👉 mañana agregas: 'waitingFee': _waitingFeeCtrl,
  };

  // Carga la url de la nube
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final url = await CargaImgNube.loadUrl(
      sectionName: sectionName, // 'billetera'
      // fieldName: 'logoUrl',   // si usas otro nombre, cámbialo aquí
    );
    if (!mounted) return;
    if (url != null) {
      setState(() => _imgUrl = url);
    }
  });
}
...
SubirFotoWidget(
  icono: Icons.upload,
  texto: "Subir Logo",
  initialUrl: _imgUrl, // <-- ahora viene de la nube
  onPicked: (file) {
    setState(() {
      _imgFile = file; // preview inmediata si el widget lo soporta
    });
  },
),
*/
