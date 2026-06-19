// SOLO UI: rellena controllers a partir de un Empresa
// lib/features/home_empresa_features/datos_empresa/empresa_cache_remote/empresa_fill/empresa_fill.dart
import 'package:flutter/widgets.dart';
import 'package:buses2/core/services/user_empresa/empresa_model.dart';

class EmpresaFill {
  static void controllers(
    Empresa e, {
    required TextEditingController nombreCtrl,
    required TextEditingController propietarioCtrl,
    required TextEditingController celularCtrl,
    required TextEditingController emailCtrl,
  }) {
    nombreCtrl.text = e.nombreEmpresa ?? '';
    propietarioCtrl.text = e.representante ?? '';
    celularCtrl.text = e.telefono ?? '';
    emailCtrl.text = e.email ?? '';
  }
}

/* Se usa así:

import 'package:buses2/features/home_empresa_features/datos_empresa/empresa_cache_remote/empresa_cache_remote.dart';

// Rellenar controllers desde un objeto Empresa (cache o nube):
EmpresaFill.controllers(
  empresa, // Empresa no-nula
  nombreCtrl: _nameEmpresaCtrl,
  propietarioCtrl: _namePropietarioCtrl,
);

// (opcional) Limpiar:
_nameEmpresaCtrl.clear();
_namePropietarioCtrl.clear();
*/
