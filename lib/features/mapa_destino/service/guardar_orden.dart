import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:buses2/shared/services/save_traer_firebase/escrituras/doc.dart';

/// Escribe en: ordenesPasajeros/{uid}/ordenes/{newUID:Orden}
Future<void> guardarOrdenPasajero({
  required Map<String, dynamic> payload,
}) async {
  await DocSets.set(
    absoluteDocPath: const ['ordenesPasajeros/{uid}/ordenes/{newUID:Orden}'],
    nombreMap: const ['@root'], // guarda el mapa tal cual
    data: [payload],
    autoCreatedAtForNewDocs: true,
    createdAtFieldName: 'createdAt',
    createdAtFor: const [true],
  );
}

/// Guarda ORDEN NORMAL. Devuelve true/false.
Future<bool> pedirTaxiYGuardar({
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

  // Destino (Punto B fijo)
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

  // Opcional: descuento de un cupón ya validado/consumido.
  // Si se provee, se guarda dentro de `tarifa` y se ajusta `total`.
  Map<String, dynamic>? descuentoInfo,
}) async {
  try {
    // Validaciones mínimas
    if (precioEstimado == null || ultimoKm == null || ultimosMin == null) {
      if (kDebugMode)
        debugPrint('🟥 pedirTaxiYGuardar: faltan métricas/precio');
      return false;
    }
    if (puntoALat == null || puntoALng == null) {
      if (kDebugMode) debugPrint('🟥 pedirTaxiYGuardar: Punto A inválido');
      return false;
    }
    if (bFixLat == null || bFixLng == null) {
      if (kDebugMode) debugPrint('🟥 pedirTaxiYGuardar: Punto B inválido');
      return false;
    }

    // UID del pasajero (logueado)
    final String? uidPasajero = FirebaseAuth.instance.currentUser?.uid;

    // Precio final (si no tocó el input, usa recomendado)
    final num precioOfrecido = tarifa ?? precioEstimado;

    // Descuento del cupón (si existe).
    final double montoDescuento = descuentoInfo == null
        ? 0
        : (descuentoInfo['monto'] as num?)?.toDouble() ?? 0;
    final num totalBase = (desgloseTotal ?? precioEstimado);
    final num totalFinal = (totalBase - montoDescuento).clamp(0, totalBase);

    final Map<String, dynamic> payload = {
      'tipo': 'normal',
      'servicio': servicioSel,
      'estado': 'pedido',

      // 👇 UID pasajero
      'uidPasajero': uidPasajero,

      'tarifa': {
        'precioRecomendado': precioEstimado,
        'precioOfrecido': precioOfrecido,
        'km': ultimoKm,
        'min': ultimosMin,
        'total': totalFinal,
        if (descuentoInfo != null) ...{
          'descuento': {
            'codigo': descuentoInfo['codigo'],
            'monto': montoDescuento,
            'totalSinDescuento': totalBase,
          },
        },
      },

      'origen': {
        'lat': puntoALat,
        'lng': puntoALng,
        'calle': puntoACalle,
        'ciudad': puntoACiudad,
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
      'rutaDoc': 'ordenesPasajeros/{uid}/ordenes/{alias:Orden}',
      'timestampLocal': DateTime.now().toIso8601String(),
    };

    if (kDebugMode)
      debugPrint('📝 pedirTaxiYGuardar → guardando en ordenes...');
    await guardarOrdenPasajero(payload: payload);
    if (kDebugMode) debugPrint('✅ pedirTaxiYGuardar OK');
    return true;
  } catch (e, st) {
    if (kDebugMode) debugPrint('🟥 pedirTaxiYGuardar ERROR: $e\n$st');
    return false;
  }
}
