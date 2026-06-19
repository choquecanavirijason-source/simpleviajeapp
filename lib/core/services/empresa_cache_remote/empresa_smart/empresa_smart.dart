// Orquestador: cache → (opcional) nube → cache + (opcional) fill controllers
// lib/features/home_empresa_features/datos_empresa/empresa_cache_remote/empresa_smart/empresa_smart.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:buses2/core/services/user_empresa/empresa_model.dart';
import 'package:buses2/shared/services/cuenta_user/cuenta_user.dart';

import '../empresa_cache/empresa_cache.dart';
import '../empresa_fill/empresa_fill.dart';
import '../empresa_remote/empresa_remote.dart';

class EmpresaLoadResult {
  final Empresa? empresa;
  final bool fromCache;
  const EmpresaLoadResult({required this.empresa, required this.fromCache});
}

class EmpresaSmart {
  /// Campos por defecto a cachear (podés sobreescribir con [fields]).
  static const Set<String> defaultFields = {
    'email',
    'nombreEmpresa',
    'representante',
    'telefono',
    'logoUrl',
  };

  /// Carga Empresa con este flujo:
  /// 1) Si [preferCache] es true: intenta cache; si hay, devuelve (y opcionalmente rellena controllers).
  /// 2) Si no hay cache (o preferCache==false): va a la nube, guarda subset ([fields]) y devuelve (y opcionalmente rellena).
  ///
  /// Si [fillControllers] es true, debés pasar los controllers correspondientes.
  static Future<EmpresaLoadResult> load({
    Set<String> fields = EmpresaSmart.defaultFields,
    bool preferCache = true,
    bool fillControllers = false,
    TextEditingController? nombreCtrl,
    TextEditingController? propietarioCtrl,
    TextEditingController? celularCtrl,
    TextEditingController? emailCtrl,
    String? uidOverride,
  }) async {
    try {
      // Resolver UID
      String uid = '';
      if (uidOverride != null && uidOverride.isNotEmpty) {
        uid = uidOverride;
      } else {
        final accountSvc = Modular.get<UserAccountService>();
        final acc = await accountSvc.current();
        uid = acc?.uid ?? '';
      }
      if (uid.isEmpty) {
        debugPrint('⚠️ EmpresaSmart.load: UID vacío');
        return const EmpresaLoadResult(empresa: null, fromCache: false);
      }

      // 1) Intentar cache
      if (preferCache) {
        final cached = await EmpresaCache.read(uid);
        if (cached != null) {
          if (fillControllers) {
            if (nombreCtrl == null ||
                propietarioCtrl == null ||
                celularCtrl == null ||
                emailCtrl == null) {
              debugPrint(
                '⚠️ EmpresaSmart.load: fillControllers=true pero faltan controllers',
              );
            } else {
              EmpresaFill.controllers(
                cached,
                nombreCtrl: nombreCtrl,
                propietarioCtrl: propietarioCtrl,
                celularCtrl: celularCtrl,
                emailCtrl: emailCtrl,
              );
            }
          }
          debugPrint('🟢 EmpresaSmart: devuelvo cache para $uid');
          return EmpresaLoadResult(empresa: cached, fromCache: true);
        }
      }

      // 2) Nube → guardar subset → (opcional) fill
      final remote = await EmpresaRemote.fetch(uidOverride: uid);
      if (remote != null) {
        await EmpresaCache.save(uid, remote, fields: fields);

        if (fillControllers) {
          if (nombreCtrl == null ||
              propietarioCtrl == null ||
              celularCtrl == null ||
              emailCtrl == null) {
            debugPrint(
              '⚠️ EmpresaSmart.load: fillControllers=true pero faltan controllers',
            );
          } else {
            EmpresaFill.controllers(
              remote,
              nombreCtrl: nombreCtrl,
              propietarioCtrl: propietarioCtrl,
              celularCtrl: celularCtrl,
              emailCtrl: emailCtrl,
            );
          }
        }
      } else {
        debugPrint('🟡 EmpresaSmart: remoto vacío para $uid');
      }

      return EmpresaLoadResult(empresa: remote, fromCache: false);
    } catch (e, st) {
      debugPrint('❌ EmpresaSmart.load error: $e\n$st');
      return const EmpresaLoadResult(empresa: null, fromCache: false);
    }
  }
}

/* Se puede usar así:
import 'dart:io';
import 'package:buses2/features/home_empresa_features/datos_empresa/empresa_cache_remote/empresa_cache_remote.dart';
...
File? _logoFile; // Subir foto
...
Future<void> _cargarEmpresa() async {
  final res = await EmpresaSmart.load(
    fields: {'email','nombreEmpresa','representante','telefono','logoUrl'},//Se guarda en la cache
    preferCache: true,// si es true primero cache, si es false va a la nube
    fillControllers: true,// si es true rellena los controllers, si es false no los toca
    nombreCtrl: _nameEmpresaCtrl,
    propietarioCtrl: _namePropietarioCtrl,
    celularCtrl: _nameCelularCtrl,
    emailCtrl: _nameEmailCtrl,
  );
  if (!mounted) return;
  setState(() {
    _empresa = res.empresa;
    _cargando = false;
  });
}

// Subir foto y datos
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
// UI Subir foto
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
  onPressed: _actualizarEmpresa, // UI Subir foto y datos
),
*/
