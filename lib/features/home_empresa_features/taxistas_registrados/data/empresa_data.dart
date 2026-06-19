import 'package:flutter/foundation.dart';
import 'package:buses2/shared/services/save_traer_firebase/lecturas/docGet.dart';
import 'package:buses2/shared/services/save_traer_firebase/escrituras/doc.dart';

/// ======================================================
/// 🟩 MODELO DE TRABAJADOR DENTRO DE EMPRESA
/// ======================================================
class TrabajadorEmpresa {
  final double saldo;
  final String? estadoTaxista;
  final Map<String, dynamic> documentos;

  TrabajadorEmpresa({
    required this.saldo,
    required this.estadoTaxista,
    required this.documentos,
  });

  /// 🧩 Método para clonar con cambios
  TrabajadorEmpresa copyWith({
    double? saldo,
    String? estadoTaxista,
    Map<String, dynamic>? documentos,
  }) {
    return TrabajadorEmpresa(
      saldo: saldo ?? this.saldo,
      estadoTaxista: estadoTaxista ?? this.estadoTaxista,
      documentos: documentos ?? this.documentos,
    );
  }

  /// ✅ Crea una instancia desde un mapa Firestore
  factory TrabajadorEmpresa.fromMap(Map<String, dynamic> data) {
    final documentos = (data['documentos'] ?? {}) as Map<String, dynamic>;
    return TrabajadorEmpresa(
      saldo: (data['saldo'] is num) ? (data['saldo'] as num).toDouble() : 0.0,
      estadoTaxista: documentos['estadoTaxista']?.toString(),
      documentos: (data['documentos'] ?? {}) as Map<String, dynamic>,
    );
  }
}

/// ======================================================
/// 🟩 MODELO DE EMPRESA
/// ======================================================
class Empresa {
  // ====== CAMPOS DE NIVEL RAÍZ ======
  final String codigoAcceso;
  final String estado;
  final String estadoEmpresa;
  final String uidPropietario;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ====== MAPA PERFIL EMPRESA ======
  final String nombreEmpresa;
  final String representanteLegal;
  final String telefono;
  final String correo;

  // ====== MAPA UBICACIÓN PRINCIPAL ======
  final String calle;
  final String ciudad;
  final String pais;
  final double lat;
  final double lng;

  // ====== MAPA DOCUMENTOS ======
  final int contadorDocumentos;
  final Map<String, dynamic> documentos;

  Empresa({
    required this.codigoAcceso,
    required this.estado,
    required this.estadoEmpresa,
    required this.uidPropietario,
    required this.createdAt,
    required this.updatedAt,
    required this.nombreEmpresa,
    required this.representanteLegal,
    required this.telefono,
    required this.correo,
    required this.calle,
    required this.ciudad,
    required this.pais,
    required this.lat,
    required this.lng,
    required this.contadorDocumentos,
    required this.documentos,
  });

  /// ✅ Crea una empresa a partir de un Map de Firestore
  factory Empresa.fromMap(Map<String, dynamic> data) {
    // Fechas seguras (coverts timestamps de Firestore)
    DateTime? parseFecha(dynamic raw) {
      if (raw == null) return null;
      if (raw is DateTime) return raw;
      if (raw is Map && raw['_seconds'] != null) {
        return DateTime.fromMillisecondsSinceEpoch(
          (raw['_seconds'] as int) * 1000,
        );
      }
      if (raw.toString().contains('seconds=')) {
        final match = RegExp(r'seconds=(\\d+)').firstMatch(raw.toString());
        if (match != null) {
          final seconds = int.parse(match.group(1)!);
          return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
        }
      }
      return null;
    }

    // Submapas
    final perfil = (data['perfilEmpresa'] ?? {}) as Map<String, dynamic>;
    final ubicaciones = (data['mis_ubicaciones'] ?? {}) as Map<String, dynamic>;
    final ubicacion1 =
        (ubicaciones['ubicacion1'] ?? {}) as Map<String, dynamic>;
    final documentos = (data['documentos'] ?? {}) as Map<String, dynamic>;

    // Lista de propietarios
    final uidProp =
        (data['uidPropietarios'] is List && data['uidPropietarios'].isNotEmpty)
        ? data['uidPropietarios'][0]
        : '';

    return Empresa(
      codigoAcceso: data['codigoAcceso'] ?? '',
      estado: data['estado'] ?? '',
      estadoEmpresa: data['estadoEmpresa'] ?? '',
      uidPropietario: uidProp,
      createdAt: parseFecha(data['createdAt']),
      updatedAt: parseFecha(data['updatedAt']),
      nombreEmpresa: perfil['nombreEmpresa'] ?? '',
      representanteLegal: perfil['representanteLegal'] ?? '',
      telefono: perfil['telefono'] ?? '',
      correo: perfil['correo'] ?? '',
      calle: ubicacion1['calle'] ?? '',
      ciudad: ubicacion1['ciudad'] ?? '',
      pais: ubicacion1['pais'] ?? '',
      lat: (ubicacion1['lat'] ?? 0).toDouble(),
      lng: (ubicacion1['lng'] ?? 0).toDouble(),
      contadorDocumentos: (documentos['contadorDocumentos'] ?? 0).toInt(),
      documentos: documentos,
    );
  }
}

/// ======================================================
/// 🟪 MODELO COMBINADO: EMPRESA + TRABAJADOR
/// ======================================================
class EmpresaYTrabajador {
  final Empresa empresa;
  final TrabajadorEmpresa trabajador;

  EmpresaYTrabajador({required this.empresa, required this.trabajador});
}

/// ======================================================
/// 🟦 FUNCIÓN PARA TRAER EMPRESA POR UID ACTUAL
/// ======================================================
Future<EmpresaYTrabajador?> traerEmpresaYTrabajador({
  required String uidTaxista,
}) async {
  try {
    print('🚕 Trayendo empresa y trabajador $uidTaxista...');

    final docs = await DocGet.documentosGet(
      rutas: [
        'empresas/mujeresalvolante',
        'empresas/mujeresalvolante/trabajadores/$uidTaxista',
      ],

      nombreMapas: ['', ''],
    );

    if (docs.length < 2 || docs[0]['data'] == null || docs[1]['data'] == null) {
      debugPrint('⚠️ Empresa o trabajador no encontrados');
      return null;
    }

    final empresa = Empresa.fromMap(docs[0]['data'] as Map<String, dynamic>);
    final trabajador = TrabajadorEmpresa.fromMap(
      docs[1]['data'] as Map<String, dynamic>,
    );

    debugPrint('✅ Empresa: ${empresa.nombreEmpresa}');
    debugPrint('💰 Saldo: ${trabajador.saldo}');
    debugPrint('estadoTaxista: ${trabajador.estadoTaxista}');
    debugPrint('📑 Docs trabajador: ${trabajador.documentos.keys.join(", ")}');

    return EmpresaYTrabajador(empresa: empresa, trabajador: trabajador);
  } catch (e) {
    debugPrint('❌ Error al traer empresa y trabajador: $e');
    return null;
  }
}

/// ======================================================
/// 🟪 CLASE: Actualiza el estado del taxista dentro de su empresa
/// ======================================================
class ActualizarEstadoTaxista {
  /// 🔹 Actualiza el campo documentos.estadoTaxista en la empresa del taxista
  static Future<void> actualizar({
    required String uidTaxista,
    required String nuevoEstado,
  }) async {
    try {
      await DocSets.set(
        absoluteDocPath: ['empresas/mujeresalvolante/trabajadores/$uidTaxista'],
        nombreMap: [
          'documentos', // ✅ esto indica que se actualizará dentro del mapa "documentos"
        ],
        data: [
          {
            'estadoTaxista': nuevoEstado, // ✅ valor a guardar
          },
        ],
      );
    } catch (e, st) {
      debugPrint('❌ [ACTUALIZAR] Error al actualizar estadoTaxista: $e');
      debugPrint('📍 Stacktrace: $st');
      rethrow;
    }
  }
}

/// ======================================================
/// 🟩 Actualiza el saldo del taxista dentro de su empresa
/// ======================================================
class ActualizarSaldoTaxista {
  /// 🔹 Actualiza el campo `saldo` en `empresas/mujeresalvolante/trabajadores/{uidTaxista}`
  static Future<void> actualizar({
    required String uidTaxista,
    required double nuevoSaldo,
  }) async {
    try {
      await DocSets.set(
        absoluteDocPath: ['empresas/mujeresalvolante/trabajadores/$uidTaxista'],
        nombreMap: [
          '', // <- vacío porque el campo `saldo` está en la raíz del documento del trabajador
        ],
        data: [
          {
            'saldo': nuevoSaldo, // ✅ actualiza el campo saldo
          },
        ],
      );

      debugPrint(
        '💾 [ACTUALIZAR] Saldo actualizado correctamente: $nuevoSaldo',
      );
    } catch (e, st) {
      debugPrint('❌ [ACTUALIZAR] Error al actualizar saldo: $e');
      debugPrint('📍 Stacktrace: $st');
      rethrow;
    }
  }
}
