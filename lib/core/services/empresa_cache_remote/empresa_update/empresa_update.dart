//
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:buses2/core/services/user_empresa/empresa_model.dart';
import 'package:buses2/shared/services/cuenta_user/cuenta_user.dart';

import '../empresa_cache/empresa_cache.dart';

class EmpresaUpdate {
  /// Sube logo a Firebase Storage y devuelve la URL pública.
  static Future<String?> _uploadLogo({
    required String uid,
    File? file,
    Uint8List? bytes,
    String? fileName, // para inferir extensión
  }) async {
    if (file == null && bytes == null) return null;

    final ts = DateTime.now().millisecondsSinceEpoch;
    final ext =
        _inferExt(fileName) ?? (file != null ? _extFromPath(file.path) : 'jpg');
    final path = 'users/$uid/empresa/logo_$ts.$ext';

    final ref = FirebaseStorage.instance.ref().child(path);
    UploadTask task;

    if (file != null) {
      task = ref.putFile(
        file,
        SettableMetadata(contentType: _mimeFromExt(ext)),
      );
    } else {
      task = ref.putData(
        bytes!,
        SettableMetadata(contentType: _mimeFromExt(ext)),
      );
    }

    final snap = await task;
    return await snap.ref.getDownloadURL();
  }

  static String? _inferExt(String? name) {
    if (name == null) return null;
    final i = name.lastIndexOf('.');
    if (i == -1) return null;
    return name.substring(i + 1).toLowerCase();
  }

  static String _extFromPath(String p) {
    final i = p.lastIndexOf('.');
    return i == -1 ? 'jpg' : p.substring(i + 1).toLowerCase();
  }

  static String? _mimeFromExt(String ext) {
    switch (ext.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      default:
        return null;
    }
  }

  /// Guarda TODO desde los controllers. Si pasás logo (file/bytes), lo sube.
  /// Luego actualiza Firestore y actualiza la caché con [cacheFields].
  static Future<bool> saveFromUI({
    required TextEditingController nombreCtrl,
    required TextEditingController propietarioCtrl,
    required TextEditingController celularCtrl,
    required TextEditingController emailCtrl,
    File? logoFile, // opción A (File)
    Uint8List? logoBytes, // opción B (bytes)
    String? logoFileName, // para inferir extensión si usas bytes
    Set<String> cacheFields = const {
      'email',
      'nombreEmpresa',
      'representante',
      'telefono',
      'logoUrl',
    },
  }) async {
    try {
      final accountSvc = Modular.get<UserAccountService>();
      final acc = await accountSvc.current();
      final uid = acc?.uid ?? '';
      if (uid.isEmpty) {
        debugPrint('⚠️ EmpresaUpdate: UID vacío');
        return false;
      }

      // 1) Subir logo (si hay)
      String? logoUrl;
      if (logoFile != null || logoBytes != null) {
        logoUrl = await _uploadLogo(
          uid: uid,
          file: logoFile,
          bytes: logoBytes,
          fileName: logoFileName,
        );
      }

      // 2) Actualizar Firestore con dot-notation (no pisa todo el objeto empresa)
      final updates = <String, dynamic>{
        'empresa.nombreEmpresa': nombreCtrl.text.trim(),
        'empresa.representante': propietarioCtrl.text.trim(),
        'empresa.telefono': celularCtrl.text.trim(),
        'empresa.email': emailCtrl.text.trim(),
        'empresa.updatedAt': FieldValue.serverTimestamp(),
      };
      if (logoUrl != null) updates['empresa.logoUrl'] = logoUrl;

      final doc = FirebaseFirestore.instance.collection('users').doc(uid);
      try {
        await doc.update(updates);
      } catch (_) {
        // Si 'empresa' no existiera, hacemos set inicial
        await doc.set({
          'empresa': {
            'nombreEmpresa': nombreCtrl.text.trim(),
            'representante': propietarioCtrl.text.trim(),
            'telefono': celularCtrl.text.trim(),
            'email': emailCtrl.text.trim(),
            if (logoUrl != null) 'logoUrl': logoUrl,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        }, SetOptions(merge: true));
      }

      // 3) Actualizar caché (preservar logo previo si no subiste uno nuevo)
      final prev = await EmpresaCache.read(uid);
      final empresaToCache = Empresa(
        nombreEmpresa: nombreCtrl.text.trim(),
        representante: propietarioCtrl.text.trim(),
        telefono: celularCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        logoUrl: logoUrl ?? prev?.logoUrl,
      );
      await EmpresaCache.save(uid, empresaToCache, fields: cacheFields);

      debugPrint('✅ EmpresaUpdate: datos actualizados para $uid');
      return true;
    } catch (e, st) {
      debugPrint('❌ EmpresaUpdate.saveFromUI error: $e\n$st');
      return false;
    }
  }
}

/* Se usa así:
import 'dart:io';
...
  File? _logoFile;
  ...
  Future<void> _actualizarEmpresa() async {
    Cargando.show(context, message: "Guardando...");
    final ok = await EmpresaUpdate.saveFromUI(
      nombreCtrl: _nameEmpresaCtrl,
      propietarioCtrl: _namePropietarioCtrl,
      celularCtrl: _nameCelularCtrl,
      emailCtrl: _nameEmailCtrl,
      // si _logoFile es null, no cambia el logo en la nube
      logoFile: _logoFile,
      // no hace falta pasar logoBytes ni logoFileName cuando usas File
      cacheFields: const {'email', 'nombreEmpresa', 'representante', 'telefono', 'logoUrl'},
    );
    Cargando.hide();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Datos actualizados' : 'Error al actualizar')),
    );

    // Refresca desde cache para reflejar logoUrl, etc.
    if (ok) {
      final res = await EmpresaSmart.load(
        preferCache: true,
        fillControllers: true,
        nombreCtrl: _nameEmpresaCtrl,
        propietarioCtrl: _namePropietarioCtrl,
        celularCtrl: _nameCelularCtrl,
        emailCtrl: _nameEmailCtrl,
      );
      if (!mounted) return;
      setState(() {
        _empresa = res.empresa;
        // Si querés, limpia el file local seleccionado
        // _logoFile = null;
      });
    }
  }
  ...
  // UI
  SubirFotoWidget(
    icono: Icons.upload,
    texto: 'Subir logo',
    initialUrl: _empresa?.logoUrl,   // ⬅️ aquí va la url remota (NUBE)
    // Usamos tu callback existente
    onPicked: (file) {
      setState(() {
        _logoFile = file; // guardamos el File para subirlo luego
      });
    },
  ),
  ...
  btnFijoAbajo: Boton1(
    label: 'Actulizar Datos',
    color: BotonColor.color1,
    borde: BotonBorde.borde1,
    iconoIzquierdo: Icons.save,
    iconoDerecho: Icons.save,
    onPressed: _actualizarEmpresa,
  ),
*/
