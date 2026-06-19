// lib/shared/services/codigos/codigos_service.dart
//
// Servicio para validar y aplicar códigos de la colección `codigos/`:
//   - 'referido_taxista'  → usado al registrar un nuevo taxista
//   - 'cupon_pasajero'    → usado por pasajero para reducir precio del viaje
//
// El ID del documento Firestore ES el código en MAYÚSCULAS.
// Todas las validaciones críticas (incrementar usosActuales) se hacen
// dentro de transacciones Firestore para evitar condiciones de carrera.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Códigos de error normalizados que la UI puede traducir.
class CodigoErrorCodes {
  static const noExiste = 'CODIGO_NO_EXISTE';
  static const inactivo = 'CODIGO_INACTIVO';
  static const aunNoVigente = 'CODIGO_AUN_NO_VIGENTE';
  static const expirado = 'CODIGO_EXPIRADO';
  static const agotado = 'CODIGO_AGOTADO';
  static const tipoIncorrecto = 'CODIGO_TIPO_INCORRECTO';
  static const cuponMontoMinimo = 'CUPON_MONTO_MINIMO_NO_ALCANZADO';
  static const cuponYaUsado = 'CUPON_YA_USADO_POR_USUARIO';
  static const referidoAutoaplicado = 'REFERIDO_AUTOAPLICADO';
  static const cuponTipoDesconocido = 'CUPON_TIPO_DESCONOCIDO';

  /// Devuelve un mensaje legible para el usuario.
  static String mensaje(String code) {
    switch (code) {
      case noExiste:
        return 'El código no es válido';
      case inactivo:
        return 'Este código fue desactivado';
      case aunNoVigente:
        return 'Este código aún no está disponible';
      case expirado:
        return 'Este código ha expirado';
      case agotado:
        return 'Este código alcanzó su límite de usos';
      case tipoIncorrecto:
        return 'Este código no aplica aquí';
      case cuponMontoMinimo:
        return 'No alcanzas el monto mínimo del cupón';
      case cuponYaUsado:
        return 'Ya usaste este cupón';
      case referidoAutoaplicado:
        return 'No puedes usar tu propio código';
      case cuponTipoDesconocido:
        return 'Tipo de descuento desconocido';
      default:
        return 'Error al validar código';
    }
  }
}

/// Resultado de validar un cupón (sin aún consumirlo).
class CuponValidacion {
  final String codigoId;
  final double descuento;
  final double precioFinal;
  const CuponValidacion({
    required this.codigoId,
    required this.descuento,
    required this.precioFinal,
  });
}

class CodigosService {
  CodigosService._();
  static final CodigosService instance = CodigosService._();

  static const _coleccion = 'codigos';

  // ============================================================
  // CUPÓN PASAJERO
  // ============================================================

  /// Valida un cupón SIN consumirlo (no escribe nada). Útil para mostrar
  /// previa del descuento mientras el pasajero termina de configurar su viaje.
  /// Lanza un string de [CodigoErrorCodes] si no es válido.
  Future<CuponValidacion> validarCupon({
    required String codigoIngresado,
    required double montoViaje,
  }) async {
    final db = FirebaseFirestore.instance;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) throw CodigoErrorCodes.noExiste;

    final codigoId = _normalizar(codigoIngresado);
    final snap = await db.collection(_coleccion).doc(codigoId).get();

    if (!snap.exists) throw CodigoErrorCodes.noExiste;
    final data = snap.data()!;

    _validarComunes(data, esperandoTipo: 'cupon_pasajero');

    // Control por usuario (sin transacción, es solo previa).
    final usosPorUsuario = (data['usosPorUsuario'] as num?)?.toInt() ?? 1;
    final usoUsuarioSnap = await db
        .collection(_coleccion)
        .doc(codigoId)
        .collection('usos')
        .doc(uid)
        .get();
    final usosDeEsteUsuario = usoUsuarioSnap.exists
        ? (usoUsuarioSnap.data()!['veces'] as num?)?.toInt() ?? 0
        : 0;
    if (usosDeEsteUsuario >= usosPorUsuario) {
      throw CodigoErrorCodes.cuponYaUsado;
    }

    final desc = Map<String, dynamic>.from(data['descuento'] as Map);
    final descuento = _calcularDescuento(
      descuento: desc,
      montoOriginal: montoViaje,
    );
    return CuponValidacion(
      codigoId: codigoId,
      descuento: descuento,
      precioFinal: (montoViaje - descuento).clamp(0, montoViaje),
    );
  }

  /// Valida Y consume un cupón atomicamente (transacción).
  /// Llamar al momento de confirmar la operación (pedir taxi).
  Future<CuponValidacion> consumirCupon({
    required String codigoIngresado,
    required double montoViaje,
  }) async {
    final db = FirebaseFirestore.instance;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) throw CodigoErrorCodes.noExiste;

    final codigoId = _normalizar(codigoIngresado);

    return await db.runTransaction<CuponValidacion>((tx) async {
      final ref = db.collection(_coleccion).doc(codigoId);
      final snap = await tx.get(ref);
      if (!snap.exists) throw CodigoErrorCodes.noExiste;
      final data = snap.data()!;

      _validarComunes(data, esperandoTipo: 'cupon_pasajero');

      final usosPorUsuario = (data['usosPorUsuario'] as num?)?.toInt() ?? 1;
      final usoUsuarioRef = ref.collection('usos').doc(uid);
      final usoUsuarioSnap = await tx.get(usoUsuarioRef);
      final usosDeEsteUsuario = usoUsuarioSnap.exists
          ? (usoUsuarioSnap.data()!['veces'] as num?)?.toInt() ?? 0
          : 0;
      if (usosDeEsteUsuario >= usosPorUsuario) {
        throw CodigoErrorCodes.cuponYaUsado;
      }

      final desc = Map<String, dynamic>.from(data['descuento'] as Map);
      final descuento = _calcularDescuento(
        descuento: desc,
        montoOriginal: montoViaje,
      );
      final total = (montoViaje - descuento).clamp(0, montoViaje);

      tx.update(ref, {
        'usosActuales': FieldValue.increment(1),
        'ultimaActualizacion': FieldValue.serverTimestamp(),
      });
      tx.set(
        usoUsuarioRef,
        {
          'veces': FieldValue.increment(1),
          'ultimoMonto': descuento,
          'ultimoUso': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      return CuponValidacion(
        codigoId: codigoId,
        descuento: descuento,
        precioFinal: total.toDouble(),
      );
    });
  }

  // ============================================================
  // REFERIDO TAXISTA
  // ============================================================

  /// Aplica un código de referido durante el registro de un taxista.
  /// Acredita recompensa al referente (si lo hay) y al nuevo taxista.
  /// Lanza un código de [CodigoErrorCodes] si no es válido.
  Future<void> aplicarCodigoReferido({
    required String codigoIngresado,
    required String uidNuevoTaxista,
  }) async {
    final db = FirebaseFirestore.instance;
    final codigoId = _normalizar(codigoIngresado);

    await db.runTransaction((tx) async {
      final ref = db.collection(_coleccion).doc(codigoId);
      final snap = await tx.get(ref);
      if (!snap.exists) throw CodigoErrorCodes.noExiste;
      final data = snap.data()!;

      _validarComunes(data, esperandoTipo: 'referido_taxista');

      final propietario = (data['taxistaPropietarioUid'] as String?)?.trim();
      if (propietario != null &&
          propietario.isNotEmpty &&
          propietario == uidNuevoTaxista) {
        throw CodigoErrorCodes.referidoAutoaplicado;
      }

      final recRef = (data['recompensaReferente'] is Map)
          ? Map<String, dynamic>.from(data['recompensaReferente'] as Map)
          : const <String, dynamic>{};
      final recNew = (data['recompensaReferido'] is Map)
          ? Map<String, dynamic>.from(data['recompensaReferido'] as Map)
          : const <String, dynamic>{};

      // 1) Recompensa al taxista nuevo
      if (recNew['tipo'] == 'saldo') {
        final monto = (recNew['monto'] as num?)?.toDouble() ?? 0;
        if (monto > 0) {
          final saldoRef = db.doc('taxistas/$uidNuevoTaxista/billetera/saldo');
          tx.set(
            saldoRef,
            {
              'saldo': FieldValue.increment(monto),
              'ultimaActualizacion': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      }

      // 2) Recompensa al referente (solo si hay dueño)
      if (propietario != null &&
          propietario.isNotEmpty &&
          recRef['tipo'] == 'saldo') {
        final monto = (recRef['monto'] as num?)?.toDouble() ?? 0;
        if (monto > 0) {
          final saldoRef = db.doc('taxistas/$propietario/billetera/saldo');
          tx.set(
            saldoRef,
            {
              'saldo': FieldValue.increment(monto),
              'ultimaActualizacion': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      }

      // 3) Incrementar contador del código
      tx.update(ref, {
        'usosActuales': FieldValue.increment(1),
        'ultimaActualizacion': FieldValue.serverTimestamp(),
      });

      // 4) Log de uso (autoId)
      final logRef = ref.collection('usos').doc();
      tx.set(logRef, {
        'uidUsado': uidNuevoTaxista,
        'fecha': FieldValue.serverTimestamp(),
        'recompensaReferente': recRef,
        'recompensaReferido': recNew,
      });

      // 5) Marcar el doc del taxista nuevo con su referente
      final taxistaRef = db.doc('taxistas/$uidNuevoTaxista');
      tx.set(
        taxistaRef,
        {
          'referidoPor': propietario,
          'codigoReferidoUsado': codigoId,
        },
        SetOptions(merge: true),
      );
    });
  }

  // ============================================================
  // Helpers internos
  // ============================================================

  String _normalizar(String s) => s.trim().toUpperCase();

  /// Valida campos comunes de un documento de código.
  /// Lanza un código de [CodigoErrorCodes] si algo falla.
  void _validarComunes(
    Map<String, dynamic> data, {
    required String esperandoTipo,
  }) {
    if (data['tipo'] != esperandoTipo) {
      throw CodigoErrorCodes.tipoIncorrecto;
    }
    if (data['activo'] != true) throw CodigoErrorCodes.inactivo;

    final now = Timestamp.now();
    final fi = data['fechaInicio'];
    final fe = data['fechaExpiracion'];
    if (fi is Timestamp && fi.compareTo(now) > 0) {
      throw CodigoErrorCodes.aunNoVigente;
    }
    if (fe is Timestamp && fe.compareTo(now) <= 0) {
      throw CodigoErrorCodes.expirado;
    }

    final usosMaximos = (data['usosMaximos'] as num?)?.toInt();
    final usosActuales = (data['usosActuales'] as num?)?.toInt() ?? 0;
    if (usosMaximos != null && usosActuales >= usosMaximos) {
      throw CodigoErrorCodes.agotado;
    }
  }

  double _calcularDescuento({
    required Map<String, dynamic> descuento,
    required double montoOriginal,
  }) {
    final tipo = descuento['tipo']?.toString();
    final valor = (descuento['valor'] as num?)?.toDouble() ?? 0;
    final montoMinimo =
        (descuento['montoMinimo'] as num?)?.toDouble() ?? 0;
    final descuentoMaximo =
        (descuento['descuentoMaximo'] as num?)?.toDouble() ?? 0;

    if (montoOriginal < montoMinimo) {
      throw CodigoErrorCodes.cuponMontoMinimo;
    }

    double calc;
    if (tipo == 'porcentaje') {
      calc = montoOriginal * (valor / 100);
      if (descuentoMaximo > 0 && calc > descuentoMaximo) {
        calc = descuentoMaximo;
      }
    } else if (tipo == 'monto_fijo') {
      calc = valor;
    } else {
      throw CodigoErrorCodes.cuponTipoDesconocido;
    }

    if (calc > montoOriginal) calc = montoOriginal;
    if (kDebugMode) {
      debugPrint(
        '🎟️ cupón: original=$montoOriginal tipo=$tipo valor=$valor descuento=$calc',
      );
    }
    return calc;
  }
}
