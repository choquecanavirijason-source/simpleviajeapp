import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/taxista_wallet_models.dart';

/// Servicio para manejar el saldo y recargas del taxista
class TaxistaWalletService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// Ruta base: taxistas/{taxistaId}/billetera
  String? get _taxistaId => _auth.currentUser?.uid;

  CollectionReference get _billeteraRef {
    if (_taxistaId == null) {
      throw Exception('Usuario no autenticado');
    }
    return _firestore
        .collection('taxistas')
        .doc(_taxistaId)
        .collection('billetera');
  }

  // ==================== SALDO ====================

  /// Obtener el saldo actual del taxista
  Future<TaxistaSaldo> obtenerSaldo() async {
    if (_taxistaId == null) {
      throw Exception('Usuario no autenticado');
    }

    final doc = await _billeteraRef.doc('saldo').get();

    if (!doc.exists) {
      // Si no existe, crear con saldo inicial 0
      final nuevoSaldo = TaxistaSaldo(
        taxistaId: _taxistaId!,
        saldo: 0.0,
        ultimaActualizacion: DateTime.now(),
      );
      await _billeteraRef.doc('saldo').set(nuevoSaldo.toFirestore());
      return nuevoSaldo;
    }

    return TaxistaSaldo.fromFirestore(doc);
  }

  /// Stream del saldo en tiempo real
  Stream<TaxistaSaldo> streamSaldo() {
    if (_taxistaId == null) {
      throw Exception('Usuario no autenticado');
    }

    return _billeteraRef.doc('saldo').snapshots().map((doc) {
      if (!doc.exists) {
        return TaxistaSaldo(
          taxistaId: _taxistaId!,
          saldo: 0.0,
          ultimaActualizacion: DateTime.now(),
        );
      }
      return TaxistaSaldo.fromFirestore(doc);
    });
  }

  /// Actualizar saldo (usado internamente por el sistema)
  Future<void> actualizarSaldo(double nuevoSaldo) async {
    await _billeteraRef.doc('saldo').set({
      'saldo': nuevoSaldo,
      'ultimaActualizacion': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ==================== RECARGAS ====================

  /// Registrar una nueva recarga
  Future<String> registrarRecarga({
    required double monto,
    required String metodoPago,
    String estado = 'completado',
    String? referencia,
    String? notas,
  }) async {
    final recarga = RecargaHistorial(
      id: '',
      monto: monto,
      fecha: DateTime.now(),
      metodoPago: metodoPago,
      estado: estado,
      referencia: referencia,
      notas: notas,
    );

    final docRef = await _billeteraRef
        .doc('historial')
        .collection('recargas')
        .add(recarga.toFirestore());

    // Si la recarga es completada, actualizar el saldo
    if (estado == 'completado') {
      final saldoActual = await obtenerSaldo();
      await actualizarSaldo(saldoActual.saldo + monto);
    }

    return docRef.id;
  }

  /// Obtener historial de recargas (últimas 50)
  Future<List<RecargaHistorial>> obtenerHistorialRecargas({
    int limite = 50,
  }) async {
    final querySnapshot = await _billeteraRef
        .doc('historial')
        .collection('recargas')
        .orderBy('fecha', descending: true)
        .limit(limite)
        .get();

    return querySnapshot.docs
        .map((doc) => RecargaHistorial.fromFirestore(doc))
        .toList();
  }

  /// Stream del historial de recargas en tiempo real
  Stream<List<RecargaHistorial>> streamHistorialRecargas({int limite = 50}) {
    return _billeteraRef
        .doc('historial')
        .collection('recargas')
        .orderBy('fecha', descending: true)
        .limit(limite)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RecargaHistorial.fromFirestore(doc))
              .toList(),
        );
  }

  /// Obtener una recarga específica por ID
  Future<RecargaHistorial?> obtenerRecarga(String recargaId) async {
    final doc = await _billeteraRef
        .doc('historial')
        .collection('recargas')
        .doc(recargaId)
        .get();

    if (!doc.exists) return null;
    return RecargaHistorial.fromFirestore(doc);
  }

  /// Actualizar estado de una recarga (útil para recargas pendientes)
  Future<void> actualizarEstadoRecarga(
    String recargaId,
    String nuevoEstado,
  ) async {
    final recarga = await obtenerRecarga(recargaId);
    if (recarga == null) throw Exception('Recarga no encontrada');

    await _billeteraRef
        .doc('historial')
        .collection('recargas')
        .doc(recargaId)
        .update({'estado': nuevoEstado});

    // Si cambió a completado, actualizar saldo
    if (nuevoEstado == 'completado' && recarga.estado != 'completado') {
      final saldoActual = await obtenerSaldo();
      await actualizarSaldo(saldoActual.saldo + recarga.monto);
    }
  }

  // ==================== COMISIONES ====================

  /// Verificar si el saldo es suficiente para cubrir la comisión
  /// Retorna true si hay saldo suficiente, false si no
  Future<Map<String, dynamic>> verificarSaldoParaViaje({
    required double montoViaje,
    required double porcentajeComision,
  }) async {
    if (_taxistaId == null) {
      return {
        'suficiente': false,
        'mensaje': 'Usuario no autenticado',
        'saldoActual': 0.0,
        'montoComision': 0.0,
      };
    }

    final saldoActual = await obtenerSaldo();
    final montoComision = montoViaje * (porcentajeComision / 100);

    print('🔍 Verificando saldo para viaje');
    print('   Saldo actual: ${saldoActual.saldo}');
    print('   Monto viaje: $montoViaje');
    print('   Comisión ($porcentajeComision%): $montoComision');

    final suficiente = saldoActual.saldo >= montoComision;

    return {
      'suficiente': suficiente,
      'saldoActual': saldoActual.saldo,
      'montoComision': montoComision,
      'mensaje': suficiente
          ? 'Saldo suficiente'
          : 'Saldo insuficiente. Necesitas recargar al menos Bs. ${(montoComision - saldoActual.saldo).toStringAsFixed(2)}',
    };
  }

  /// Registrar comisión al finalizar un viaje
  /// Este método se llama automáticamente al terminar un viaje
  Future<String> registrarComision({
    required double montoViaje,
    required double porcentajeComision,
    required String viajeId,
    required String servicio,
    String? pasajeroId,
    String? pasajeroNombre,
  }) async {
    if (_taxistaId == null) {
      throw Exception('Usuario no autenticado');
    }

    print('🔹 TaxistaWalletService.registrarComision');
    print('   TaxistaId: $_taxistaId');
    print('   MontoViaje: $montoViaje');
    print('   Porcentaje: $porcentajeComision%');

    final montoComision = montoViaje * (porcentajeComision / 100);
    final montoNeto = montoViaje - montoComision;

    print('   MontoComision: $montoComision');
    print('   MontoNeto: $montoNeto');

    final comision = ComisionHistorial(
      id: '',
      montoViaje: montoViaje,
      porcentajeComision: porcentajeComision,
      montoComision: montoComision,
      montoNeto: montoNeto,
      fecha: DateTime.now(),
      viajeId: viajeId,
      servicio: servicio,
      pasajeroId: pasajeroId,
      pasajeroNombre: pasajeroNombre,
    );

    print(
      '   Guardando en: taxistas/$_taxistaId/billetera/historial/comisiones/',
    );

    final docRef = await _billeteraRef
        .doc('historial')
        .collection('comisiones')
        .add(comision.toFirestore());

    print('   ✅ Comisión guardada con ID: ${docRef.id}');

    // Actualizar saldo: restar la comisión (deuda del taxista a la empresa)
    // El taxista recibe el dinero del viaje en efectivo del pasajero
    final saldoActual = await obtenerSaldo();
    print('   Saldo actual: ${saldoActual.saldo}');
    print('   Nuevo saldo: ${saldoActual.saldo - montoComision}');

    await actualizarSaldo(saldoActual.saldo - montoComision);

    print('   ✅ Saldo actualizado');

    return docRef.id;
  }

  /// Obtener historial de comisiones (últimas 50)
  Future<List<ComisionHistorial>> obtenerHistorialComisiones({
    int limite = 50,
  }) async {
    final querySnapshot = await _billeteraRef
        .doc('historial')
        .collection('comisiones')
        .orderBy('fecha', descending: true)
        .limit(limite)
        .get();

    return querySnapshot.docs
        .map((doc) => ComisionHistorial.fromFirestore(doc))
        .toList();
  }

  /// Stream del historial de comisiones en tiempo real
  Stream<List<ComisionHistorial>> streamHistorialComisiones({int limite = 50}) {
    return _billeteraRef
        .doc('historial')
        .collection('comisiones')
        .orderBy('fecha', descending: true)
        .limit(limite)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ComisionHistorial.fromFirestore(doc))
              .toList(),
        );
  }

  // ==================== CONFIGURACIÓN QR ====================

  /// Obtener la configuración del QR de recarga
  /// Este QR es compartido por todos los conductores y es configurado desde el admin
  Future<ConfiguracionQR> obtenerConfiguracionQR() async {
    try {
      final doc = await _firestore.collection('qr_recarga').doc('activo').get();

      if (!doc.exists || doc.data() == null) {
        return ConfiguracionQR(
          qrImageUrl: '',
          descripcion: 'QR no configurado',
        );
      }

      return ConfiguracionQR.fromFirestore(doc.data()!);
    } catch (e) {
      return ConfiguracionQR(
        qrImageUrl: '',
        descripcion: 'Error al cargar QR: $e',
      );
    }
  }

  /// Stream de la configuración del QR en tiempo real
  Stream<ConfiguracionQR> streamConfiguracionQR() {
    return _firestore.collection('qr_recarga').doc('activo').snapshots().map((
      doc,
    ) {
      if (!doc.exists || doc.data() == null) {
        return ConfiguracionQR(
          qrImageUrl: '',
          descripcion: 'QR no configurado',
        );
      }
      return ConfiguracionQR.fromFirestore(doc.data()!);
    });
  }

  /// Actualizar configuración del QR (solo para admin)
  /// Este método debería ser llamado desde el panel de administración
  Future<void> actualizarConfiguracionQR({
    required String qrImageUrl,
    String? descripcion,
  }) async {
    final config = ConfiguracionQR(
      qrImageUrl: qrImageUrl,
      descripcion: descripcion,
    );

    await _firestore
        .collection('qr_recarga')
        .doc('activo')
        .set(config.toFirestore(), SetOptions(merge: true));
  }
}
