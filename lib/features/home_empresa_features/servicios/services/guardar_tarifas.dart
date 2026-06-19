import 'package:flutter/material.dart';
import 'package:buses2/shared/services/save_traer_firebase/escrituras/doc.dart';

/// Guarda/actualiza un servicio de tarifas dentro del doc:
///   empresas/mujeresalvolante/tarifas/{departamento}
///
/// Escribe:
///  - {departamento} en la raíz del doc
///  - Dentro del mapa {servicioKey} (normalizado):
///      { servicio, activo, (logo/fotos opcional), tarifas:{...},
///        Tarifas_Aeropuerto:{tramos:[]}, Horas_pico:{franjas:[]} }
///
/// NOTA:
/// - Solo se incluyen números no-nulos en 'tarifas' (mergea por clave, no borra otros).
/// - Tramos se reemplaza como lista (esperado).
/// - Si extraFields incluye 'logo' o 'fotos', los escribe; si no, no los toca.
Future<void> guardarTarifas({
  required String servicio, 
  required String departamento, // Ej: "Cochabamba"
  required bool activo,

  double? tarifaBase,
  double? distanciaBase,
  double? porKm,
  double? porMin,
  double? horaPicoExtra,
  double? nocturno,
  double? comision,

  required List<(String left, String right)> tramosAero,
  required List<({TimeOfDay desde, TimeOfDay hasta})> franjasHoras,

  Map<String, dynamic>?
  extraFields, // {'logo': 'https://...', 'fotos': [ ... ]}
}) async {
  String _mapKey(String s) => s
      .trim()
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'[^\w\-]'), '')
      .toLowerCase();

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  double _toNum(String s) =>
      double.tryParse(s.trim().replaceAll(',', '.')) ?? 0.0;

  String _cleanNum(String s) => s.replaceAll(RegExp(r'[^0-9,.\-]'), '');

  // --- tramos aeropuerto ---
  final tramos = <Map<String, num>>[];
  for (final r in tramosAero) {
    final l = _cleanNum(r.$1), rr = _cleanNum(r.$2);
    if (l.isEmpty || rr.isEmpty) continue;
    final desdeKm = _toNum(l), precio = _toNum(rr);
    if (desdeKm <= 0 || precio <= 0) continue;
    tramos.add({'desdeKm': desdeKm, 'precio': precio});
  }
  tramos.sort((a, b) => (a['desdeKm'] as num).compareTo(b['desdeKm'] as num));

  // --- franjas pico ---
  final franjas = <Map<String, String>>[
    for (final f in franjasHoras)
      {'desde': _fmtTime(f.desde), 'hasta': _fmtTime(f.hasta)},
  ];

  // --- tarifas (solo números no-nulos) ---
  final tarifas = <String, num>{};
  if (tarifaBase != null) tarifas['tarifaBase'] = tarifaBase;
  if (distanciaBase != null) tarifas['distanciaBase'] = distanciaBase;
  if (porKm != null) tarifas['porKm'] = porKm;
  if (porMin != null) tarifas['porMin'] = porMin;
  if (horaPicoExtra != null) tarifas['horaPicoExtra'] = horaPicoExtra;
  if (nocturno != null) tarifas['nocturno'] = nocturno;
  if (comision != null) tarifas['comision'] = comision;

  final servicioKey = _mapKey(servicio);

  final dataServicio = <String, dynamic>{
    'servicio': servicio,
    'activo': activo,
    if (tarifas.isNotEmpty) 'tarifas': tarifas,
    'Tarifas_Aeropuerto': {'tramos': tramos},
    'Horas_pico': {'franjas': franjas},
    if (extraFields != null &&
        extraFields['logo'] is String &&
        (extraFields['logo'] as String).isNotEmpty)
      'logo': extraFields['logo'],
    if (extraFields != null &&
        extraFields['fotos'] is List &&
        (extraFields['fotos'] as List).isNotEmpty)
      'fotos': extraFields['fotos'],
  };

  // Escribimos en dos pasos, mismo doc (merge interno por claves):
  await DocSets.set(
    absoluteDocPath: [
      'empresas/mujeresalvolante/tarifas/$departamento', // raíz del doc
      'empresas/mujeresalvolante/tarifas/$departamento', // mapa del servicio
    ],
    nombreMap: [
      '@root', // → { departamento: ... } (no borra otros campos)
      servicioKey, // → merge dentro de {servicioKey}
    ],
    data: [
      {'departamento': departamento},
      dataServicio,
    ],
  );
}
