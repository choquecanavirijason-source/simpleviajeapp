import 'package:flutter/foundation.dart';
import 'package:buses2/shared/services/save_traer_firebase/escrituras/doc.dart';
import 'package:buses2/shared/services/save_traer_firebase/lecturas/docGet.dart';

/// ======================================================
/// 🟢 Servicio para actualizar el estado del taxista
/// ======================================================
///
/// Este servicio usa la API `DocSets.set()`
/// para escribir el campo `estadoTaxista` en:
/// 🔹 empresas/{uidEmpresa}/trabajadores/{taxistaId}
///
/// Si el estado es "rechazado", también guarda `motivoRechazo`.
///
/// Se actualiza sin sobrescribir el resto del documento (merge:true)
///
class ActualizarEstadoTaxistaService {
  /// 🔹 Actualiza el estado de un documento específico dentro del mapa "documentos"
  static Future<void> actualizarEstado({
    required String uidEmpresa,
    required String taxistaId,
    required String docNombre, // ej: "doc_1"
    required String nuevoEstado,
    String? motivo,
  }) async {
    // Este es el contenido del mapa doc_?
    final data = {
      'estado': nuevoEstado,
      if (motivo != null && motivo.trim().isNotEmpty)
        'motivoRechazo': motivo.trim(),
    };

    // ✅ Usa nombreMap para anidar dentro de documentos.doc_1
    await DocSets.set(
      absoluteDocPath: ['empresas/$uidEmpresa/trabajadores/$taxistaId'],
      nombreMap: [
        'documentos-$docNombre', // 👈 esto crea documentos.doc_1.{estado, motivoRechazo}
      ],
      data: [data],
    );
  }
}

class LeerEstadoTaxistaService {
  /// 🔹 Lee el estado actual de un documento dentro del mapa "documentos"
  /// usando la regla para obtener el `uidEmpresa` desde pasajeros/{uid}.uidEmpresa
  static Future<String?> traerEstado({
    required String taxistaId,
    required String docNombre, // ej: "doc_1"
  }) async {
    try {
      debugPrint(
        '📍 Solicitando estado para taxistaId: $taxistaId / doc: $docNombre',
      );

      final docs = await DocGet.documentosGet(
        rutas: ['empresas/mujeresalvolante/trabajadores/$taxistaId'],

        nombreMapas: [
          '', // devuelve el documento completo
        ],
      );

      // 🔍 Ver la ruta final que se resolvió y el resultado crudo
      debugPrint('📄 Ruta resuelta final: ${docs.first['path']}');
      debugPrint('📦 Data obtenida: ${docs.first['data']}');

      final raw = docs.first['data'] as Map<String, dynamic>?;
      if (raw == null) {
        debugPrint('⚠️ No se encontró el documento del trabajador.');
        return null;
      }

      final documentos = raw['documentos'] as Map<String, dynamic>?;
      if (documentos == null) {
        debugPrint('⚠️ El campo "documentos" no existe en el documento.');
        return null;
      }

      final docSeleccionado = documentos[docNombre] as Map<String, dynamic>?;
      if (docSeleccionado == null) {
        debugPrint('⚠️ No existe "$docNombre" dentro de "documentos".');
        return null;
      }

      final estado = docSeleccionado['estado']?.toString() ?? 'pendiente';
      debugPrint('🟢 Estado leído correctamente: $estado');
      return estado;
    } catch (e, st) {
      debugPrint('❌ Error al traer estado del documento: $e');
      debugPrint('📍 Stacktrace: $st');
      return null;
    }
  }
}
