// lib/features/home_empresa_features/taxistas_registrados/data/taxistas_registrados_data.dart

import 'package:flutter/foundation.dart';
import 'package:buses2/features/home_empresa_features/taxistas_registrados/data/guardar_variable.dart';
import 'package:buses2/shared/services/save_traer_firebase/lecturas/coleccionWhere.dart';

/// Empresa estática (sin campo uidEmpresa)
const String kEmpresaId = 'mujeresalvolante';

/// ======================================================
/// 🟩 MODELO ÚNICO: Taxista Registrado (todo en uno)
/// ======================================================
class TaxistaRegistrado {
  final String id;

  // Campos (nivel raíz)
  final String? estado; // ej: "aprovado"
  final String? taxistaLibre; // ej: "ocupado" | "disponible"
  final String? uidTaxista; // (si existe en el doc)
  final String? empresa; // (opcional, si mantienes un campo 'empresa')

  // PERFIL (perfilTaxista)
  final String? nombre;
  final String? correo;
  final String? telefono;
  final String? fotoPerfil;

  // DOCUMENTOS variables (misDocumentos → { "doc_1": {...}, "doc_2": {...} })
  final Map<String, Map<String, dynamic>> misDocumentos;

  const TaxistaRegistrado({
    required this.id,
    required this.estado,
    required this.taxistaLibre,
    required this.uidTaxista,
    required this.empresa,
    required this.nombre,
    required this.correo,
    required this.telefono,
    required this.fotoPerfil,
    required this.misDocumentos,
  });

  factory TaxistaRegistrado.fromMap(Map<String, dynamic> data, String docId) {
    final perfilAny = data['perfilTaxista'];
    final Map<String, dynamic> perfil = (perfilAny is Map)
        ? Map<String, dynamic>.from(perfilAny as Map)
        : const <String, dynamic>{};

    final mdAny = data['misDocumentos'];
    final Map<String, Map<String, dynamic>> documentos = {};
    if (mdAny is Map) {
      mdAny.forEach((k, v) {
        if (v is Map) {
          documentos[k.toString()] = Map<String, dynamic>.from(v as Map);
        }
      });
    }

    return TaxistaRegistrado(
      id: docId,
      estado: data['estado']?.toString(),
      taxistaLibre: data['taxistaLibre']?.toString(),
      uidTaxista: data['uidTaxista']?.toString(),
      empresa: data['empresa']?.toString(), // opcional
      nombre: perfil['nombre']?.toString(),
      correo: perfil['correo']?.toString(),
      telefono: perfil['telefono']?.toString(),
      fotoPerfil: perfil['fotoPerfil']?.toString(),
      misDocumentos: documentos,
    );
  }
}

/// ======================================================
/// 🟦 REPO: Lecturas para "Taxistas Registrados"
/// ======================================================
class TaxistasRegistradosRepo {
  /// 🔹 Health check: lee primeros N taxistas desde la ruta estática
  static Future<List<Map<String, dynamic>>> debugLeerSubcoleccion() async {
    final raw = await ColeccionWhere.coleccionesWhere(
      rutas: ['empresas', kEmpresaId, 'taxistas'], // <— ruta estática
      condiciones: [
        [
          // sin filtros
        ],
      ],
      limites: [20],
    );

    if (kDebugMode) {
      debugPrint(
        'DEBUG taxistas (${raw.length}) en empresas/$kEmpresaId/taxistas:',
      );
      for (final e in raw) {
        debugPrint(' - id=${e['id']} data=${e['data']}');
      }
    }
    return raw;
  }

  /// ✅ Trae TODOS los taxistas de la empresa estática (subcolección directa)
  static Future<List<TaxistaRegistrado>> traerDeEmpresaEstatica() async {
    final raw = await ColeccionWhere.coleccionesWhere(
      rutas: ['empresas', kEmpresaId, 'taxistas'], // <— importante
      condiciones: [
        [
          // {'mapaCampo': 'estado', '==': 'aprovado'}, // opcional
        ],
      ],
      // limites: [100],
    );

    return _mapear(raw);
  }

  /// 🔹 Solo los uidTaxista de esa subcolección
  static Future<List<String>> traerUidsTaxistasDeEmpresaEstatica() async {
    final raw = await ColeccionWhere.coleccionesWhere(
      rutas: ['empresas', kEmpresaId, 'taxistas'],
      condiciones: [
        [
          // sin filtros
        ],
      ],
      // limites: [200],
    );

    final uids = <String>[];
    for (final e in raw) {
      final dataAny = e['data'];
      final Map<String, dynamic> data = (dataAny is Map)
          ? Map<String, dynamic>.from(dataAny as Map)
          : const <String, dynamic>{};
      final uidTaxista = data['uidTaxista']?.toString();
      if (uidTaxista != null && uidTaxista.isNotEmpty) {
        uids.add(uidTaxista);
      } else if (kDebugMode) {
        debugPrint('WARN: doc ${e['id']} no tiene uidTaxista en raíz.');
      }
    }
    return uids;
  }

  /// 🔸 Guarda el primer uidTaxista de la empresa estática y lo retorna
  static Future<String?> guardarPrimerUidTaxistaDeEmpresaEstatica() async {
    final uids = await traerUidsTaxistasDeEmpresaEstatica();
    final uid = uids.isNotEmpty ? uids.first : null;
    GuardarVariable.instance.setUidTaxista(uid);
    if (kDebugMode) debugPrint('setUidTaxista("$uid")');
    return uid;
  }

  /// 🔹 Traer por uidTaxista guardado
  static Future<List<TaxistaRegistrado>> traerPorTaxistaGuardado() async {
    final uidTaxista = GuardarVariable.instance.uidTaxista;
    if (uidTaxista == null || uidTaxista.isEmpty) return [];
    return _traerPorUidTaxista(uidTaxista);
  }

  /// 🔸 Traer por uidTaxista específico (sigue en la MISMA subcolección)
  static Future<List<TaxistaRegistrado>> _traerPorUidTaxista(
    String uidTaxista,
  ) async {
    final raw = await ColeccionWhere.coleccionesWhere(
      rutas: ['empresas', kEmpresaId, 'taxistas'],
      condiciones: [
        [
          {'mapaCampo': 'uidTaxista', '==': uidTaxista},
        ],
      ],
      // limites: [50],
    );
    return _mapear(raw);
  }

  /// 🔁 Fallback si SIGUES en raíz (no recomendado, pero útil si tu data aún no migró):
  /// Busca en 'taxistas' donde campo 'empresa' == 'mujeresalvolante'
  static Future<List<TaxistaRegistrado>>
  traerDesdeRaizPorCampoEmpresaFallback() async {
    final raw = await ColeccionWhere.coleccionesWhere(
      rutas: ['taxistas'],
      condiciones: [
        [
          {
            'mapaCampo': 'empresa',
            '==': kEmpresaId,
          }, // requiere CAMPO 'empresa'
        ],
      ],
      // limites: [100],
    );
    return _mapear(raw);
  }

  /// Utilitario: mapea `raw` a lista de modelo
  static List<TaxistaRegistrado> _mapear(List<dynamic> raw) {
    final lista = <TaxistaRegistrado>[];
    for (final e in raw) {
      final id = (e['id'] ?? '').toString();
      if (id.isEmpty) continue;

      final dataAny = e['data'];
      final Map<String, dynamic> data = (dataAny is Map)
          ? Map<String, dynamic>.from(dataAny as Map)
          : const <String, dynamic>{};

      lista.add(TaxistaRegistrado.fromMap(data, id));
    }
    return lista;
  }
}
