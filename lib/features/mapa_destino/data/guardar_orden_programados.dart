import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:buses2/features/mapa_destino/modal_programar_viaje/calendar_es_modal.dart';
import 'package:buses2/shared/services/save_traer_firebase/escrituras/doc.dart';

/// Guarda en: ordenesPasajeros/{uid}/ordenesProgramados/{newUID:Orden}
Future<void> guardarOrdenPasajeroProgramado({
  required Map<String, dynamic> payload,
}) async {
  await DocSets.set(
    absoluteDocPath: const [
      'ordenesPasajeros/{uid}/ordenesProgramados/{newUID:Orden}',
    ],
    nombreMap: const ['@root'],
    data: [payload],
    autoCreatedAtForNewDocs: true,
    createdAtFieldName: 'createdAt',
    createdAtFor: const [true],
  );
}

/// Lógica de pedir/guardar ORDEN PROGRAMADA
Future<bool> pedirTaxiYGuardarProgramado({
  // ====== estado necesario ======
  required Map<String, dynamic>? comboSelNullable,
  required double? precioEstimado,
  required double? ultimoKm,
  required int? ultimosMin,

  required Map<String, dynamic>? desgloseMap, // placeholder no usado
  required double? desgloseTotal,

  // Origen (Punto A)
  required double? puntoALat,
  required double? puntoALng,
  required String? puntoACalle,
  required String? puntoACiudad,
  required String? puntoAPais,
  String? puntoADepartamento,

  // Destino fijo (Punto B)
  required double? bFixLat,
  required double? bFixLng,
  required String? fixCalle,
  required String? fixCiudad,
  required String? fixPais,
  required String? bFixDireccion,

  // Destino “en vivo” (fallback)
  required String? puntoBCalle,
  required String? puntoBCiudad,
  required String? puntoBPais,

  required num? tarifa, // valor editado por el usuario
  required String? servicioSel, // nombre del servicio
  // Programación
  ProgramacionSeleccion? programacion,
  DateTime? scheduledAtLocal, // fecha/hora local efectiva (día + hora)
}) async {
  try {
    // Validaciones mínimas
    if (precioEstimado == null || ultimoKm == null || ultimosMin == null) {
      if (kDebugMode)
        debugPrint('🟥 pedirTaxiYGuardarProgramado: faltan métricas/precio');
      return false;
    }
    if (puntoALat == null || puntoALng == null) {
      if (kDebugMode)
        debugPrint('🟥 pedirTaxiYGuardarProgramado: Punto A inválido');
      return false;
    }
    if (bFixLat == null || bFixLng == null) {
      if (kDebugMode)
        debugPrint('🟥 pedirTaxiYGuardarProgramado: Punto B inválido');
      return false;
    }

    // UID del pasajero (logueado)
    final String? uidPasajero = FirebaseAuth.instance.currentUser?.uid;

    // Precio final (si no tocó el input, usa recomendado)
    final num precioOfrecido = tarifa ?? precioEstimado;

    final Map<String, dynamic> payload = {
      'tipo': 'programado',
      'servicio': servicioSel,
      'estado': 'pedido',

      // 👇 UID pasajero
      'uidPasajero': uidPasajero,

      'tarifa': {
        'precioRecomendado': precioEstimado,
        'precioOfrecido': precioOfrecido,
        'km': ultimoKm,
        'min': ultimosMin,
        'total': (desgloseTotal ?? precioEstimado),
      },

      if (puntoADepartamento != null) 'departamento': puntoADepartamento,
      if (puntoAPais != null) 'pais': puntoAPais,

      'origen': {
        'lat': puntoALat,
        'lng': puntoALng,
        'calle': puntoACalle,
        'ciudad': puntoACiudad,
        if (puntoADepartamento != null) 'departamento': puntoADepartamento,
        'pais': puntoAPais,
      },

      'destino': {
        'lat': bFixLat,
        'lng': bFixLng,
        'calle': fixCalle ?? puntoBCalle,
        'ciudad': fixCiudad ?? puntoBCiudad,
        'pais': fixPais ?? puntoBPais,
        'texto':
            bFixDireccion ??
            [
              if (puntoBCalle != null) puntoBCalle,
              if (puntoBCiudad != null) puntoBCiudad,
              if (puntoBPais != null) puntoBPais,
            ].whereType<String>().join(', '),
      },

      // Metadatos / rutas
      'ordenId': '{alias:Orden}',
      'rutaDoc': 'ordenesPasajeros/{uid}/ordenesProgramados/{alias:Orden}',
      'timestampLocal': DateTime.now().toIso8601String(),
      'scheduledAtLocal': scheduledAtLocal?.toIso8601String(),
    };

    if (programacion != null) {
      payload['programacion'] = programacion.toJson();
    }

    if (kDebugMode)
      debugPrint(
        '📝 pedirTaxiYGuardarProgramado → guardando en ordenesProgramados...',
      );
    await guardarOrdenPasajeroProgramado(payload: payload);
    if (kDebugMode) debugPrint('✅ pedirTaxiYGuardarProgramado OK');
    return true;
  } catch (e, st) {
    if (kDebugMode) debugPrint('🟥 pedirTaxiYGuardarProgramado ERROR: $e\n$st');
    return false;
  }
}
