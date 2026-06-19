import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo del saldo del taxista
class TaxistaSaldo {
  final String taxistaId;
  final double saldo;
  final DateTime ultimaActualizacion;

  TaxistaSaldo({
    required this.taxistaId,
    required this.saldo,
    required this.ultimaActualizacion,
  });

  factory TaxistaSaldo.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TaxistaSaldo(
      taxistaId: doc.id,
      saldo: (data['saldo'] as num?)?.toDouble() ?? 0.0,
      ultimaActualizacion:
          (data['ultimaActualizacion'] as Timestamp?)?.toDate() ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'saldo': saldo,
      'ultimaActualizacion': FieldValue.serverTimestamp(),
    };
  }
}

/// Modelo del historial de recargas
class RecargaHistorial {
  final String id;
  final double monto;
  final DateTime fecha;
  final String metodoPago; // 'efectivo', 'transferencia', 'tarjeta'
  final String estado; // 'completado', 'pendiente', 'fallido'
  final String? referencia; // Número de referencia o comprobante
  final String? notas;

  RecargaHistorial({
    required this.id,
    required this.monto,
    required this.fecha,
    required this.metodoPago,
    required this.estado,
    this.referencia,
    this.notas,
  });

  factory RecargaHistorial.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return RecargaHistorial(
      id: doc.id,
      monto: (data['monto'] as num?)?.toDouble() ?? 0.0,
      fecha: (data['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metodoPago: data['metodoPago'] as String? ?? 'efectivo',
      estado: data['estado'] as String? ?? 'completado',
      referencia: data['referencia'] as String?,
      notas: data['notas'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'monto': monto,
      'fecha': FieldValue.serverTimestamp(),
      'metodoPago': metodoPago,
      'estado': estado,
      if (referencia != null) 'referencia': referencia,
      if (notas != null) 'notas': notas,
    };
  }
}

/// Modelo del historial de comisiones descontadas
class ComisionHistorial {
  final String id;
  final double montoViaje; // Monto total del viaje
  final double porcentajeComision; // Porcentaje aplicado (ej: 10.0 para 10%)
  final double montoComision; // Monto descontado
  final double
  montoNeto; // Lo que recibió el taxista (montoViaje - montoComision)
  final DateTime fecha;
  final String viajeId; // ID del viaje asociado
  final String servicio; 
  final String? pasajeroId;
  final String? pasajeroNombre;

  ComisionHistorial({
    required this.id,
    required this.montoViaje,
    required this.porcentajeComision,
    required this.montoComision,
    required this.montoNeto,
    required this.fecha,
    required this.viajeId,
    required this.servicio,
    this.pasajeroId,
    this.pasajeroNombre,
  });

  factory ComisionHistorial.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ComisionHistorial(
      id: doc.id,
      montoViaje: (data['montoViaje'] as num?)?.toDouble() ?? 0.0,
      porcentajeComision:
          (data['porcentajeComision'] as num?)?.toDouble() ?? 0.0,
      montoComision: (data['montoComision'] as num?)?.toDouble() ?? 0.0,
      montoNeto: (data['montoNeto'] as num?)?.toDouble() ?? 0.0,
      fecha: (data['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
      viajeId: data['viajeId'] as String? ?? '',
      servicio: data['servicio'] as String? ?? '',
      pasajeroId: data['pasajeroId'] as String?,
      pasajeroNombre: data['pasajeroNombre'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'montoViaje': montoViaje,
      'porcentajeComision': porcentajeComision,
      'montoComision': montoComision,
      'montoNeto': montoNeto,
      'fecha': FieldValue.serverTimestamp(),
      'viajeId': viajeId,
      'servicio': servicio,
      if (pasajeroId != null) 'pasajeroId': pasajeroId,
      if (pasajeroNombre != null) 'pasajeroNombre': pasajeroNombre,
    };
  }
}

/// Modelo de configuración de QR para recargas
/// Este QR es proporcionado por el admin y es compartido por todos los conductores
class ConfiguracionQR {
  final String qrImageUrl; // URL de la imagen del QR
  final String? descripcion; // Descripción o instrucciones
  final DateTime? ultimaActualizacion;

  ConfiguracionQR({
    required this.qrImageUrl,
    this.descripcion,
    this.ultimaActualizacion,
  });

  factory ConfiguracionQR.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) {
      return ConfiguracionQR(
        qrImageUrl: '',
        descripcion: 'QR no configurado',
        ultimaActualizacion: null,
      );
    }

    return ConfiguracionQR(
      // Mapear 'imageUrl' de Firestore a 'qrImageUrl' del modelo
      qrImageUrl:
          data['imageUrl'] as String? ?? data['qrImageUrl'] as String? ?? '',
      descripcion: data['descripcion'] as String?,
      ultimaActualizacion:
          (data['fechaActualizacion'] as Timestamp?)?.toDate() ??
          (data['ultimaActualizacion'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'imageUrl': qrImageUrl, // Guardar como 'imageUrl' en Firestore
      if (descripcion != null) 'descripcion': descripcion,
      'fechaActualizacion': FieldValue.serverTimestamp(),
    };
  }
}
