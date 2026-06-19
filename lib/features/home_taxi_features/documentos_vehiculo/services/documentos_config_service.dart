import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/documento_config_model.dart';

/// Servicio para cargar la configuración de documentos desde Firestore
class DocumentosConfigService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Carga la configuración de documentos desde Firestore
  /// Retorna null si no existe o hay error
  static Future<ConfiguracionDocumentos?> cargarConfiguracion() async {
    try {
      final docSnapshot = await _firestore
          .collection('configuracion')
          .doc('documentosRegistro')
          .get();

      if (!docSnapshot.exists) {
        print('⚠️ No existe configuración de documentos en Firestore');
        return null;
      }

      final data = docSnapshot.data();
      if (data == null) {
        print('⚠️ Configuración de documentos vacía');
        return null;
      }

      final config = ConfiguracionDocumentos.fromMap(data);
      print(
        '✅ Configuración de documentos cargada: ${config.documentos.length} documentos',
      );
      return config;
    } catch (e) {
      print('❌ Error al cargar configuración de documentos: $e');
      return null;
    }
  }

  /// Obtiene la configuración por defecto si no existe en Firestore
  /// Esta es la configuración hardcodeada original con los 11 documentos base
  static ConfiguracionDocumentos getConfiguracionPorDefecto() {
    final documentosBase = [
      // Paso 1: Documentos Personales
      DocumentoConfig(
        id: 'fotoAntecedentesPenales',
        nombre: 'Antecedentes Penales',
        categoria: 'Documentos Personales',
        paso: 1,
        tipo: 'foto',
        requerido: true,
        orden: 1,
        descripcion: 'Certificado de antecedentes penales vigente',
        activo: true,
        esBase: true,
      ),
      DocumentoConfig(
        id: 'fotoConductor',
        nombre: 'Foto del Conductor',
        categoria: 'Documentos Personales',
        paso: 1,
        tipo: 'foto',
        requerido: true,
        orden: 2,
        descripcion: 'Fotografía reciente del conductor',
        activo: true,
        esBase: true,
      ),
      DocumentoConfig(
        id: 'fotoCarneIdentidadAnverso',
        nombre: 'Carné de Identidad (Anverso)',
        categoria: 'Documentos Personales',
        paso: 1,
        tipo: 'foto',
        requerido: true,
        orden: 3,
        descripcion: 'Parte frontal del carné de identidad',
        activo: true,
        esBase: true,
      ),
      DocumentoConfig(
        id: 'fotoCarneIdentidadReverso',
        nombre: 'Carné de Identidad (Reverso)',
        categoria: 'Documentos Personales',
        paso: 1,
        tipo: 'foto',
        requerido: true,
        orden: 4,
        descripcion: 'Parte posterior del carné de identidad',
        activo: true,
        esBase: true,
      ),
      DocumentoConfig(
        id: 'fotoLicenciaConducirAnverso',
        nombre: 'Licencia de Conducir (Anverso)',
        categoria: 'Documentos Personales',
        paso: 1,
        tipo: 'foto',
        requerido: true,
        orden: 5,
        descripcion: 'Parte frontal de la licencia de conducir',
        activo: true,
        esBase: true,
      ),
      DocumentoConfig(
        id: 'fotoLicenciaConducirReverso',
        nombre: 'Licencia de Conducir (Reverso)',
        categoria: 'Documentos Personales',
        paso: 1,
        tipo: 'foto',
        requerido: true,
        orden: 6,
        descripcion: 'Parte posterior de la licencia de conducir',
        activo: true,
        esBase: true,
      ),

      // Paso 2: Documentos del Vehículo
      DocumentoConfig(
        id: 'fotoSoat',
        nombre: 'SOAT',
        categoria: 'Documentos Vehículo',
        paso: 2,
        tipo: 'foto',
        requerido: true,
        orden: 1,
        descripcion: 'Seguro Obligatorio de Accidentes de Tránsito vigente',
        activo: true,
        esBase: true,
      ),
      DocumentoConfig(
        id: 'fotoPermisoCirculacion',
        nombre: 'Permiso de Circulación',
        categoria: 'Documentos Vehículo',
        paso: 2,
        tipo: 'foto',
        requerido: true,
        orden: 2,
        descripcion: 'Permiso de circulación vigente del vehículo',
        activo: true,
        esBase: true,
      ),
      DocumentoConfig(
        id: 'fotoRevisionTecnica',
        nombre: 'Revisión Técnica',
        categoria: 'Documentos Vehículo',
        paso: 2,
        tipo: 'foto',
        requerido: true,
        orden: 3,
        descripcion: 'Certificado de revisión técnica vehicular vigente',
        activo: true,
        esBase: true,
      ),

      // Paso 3: Fotografías del Vehículo
      DocumentoConfig(
        id: 'fotoVehiculo1',
        nombre: 'Fotografía del Vehículo 1',
        categoria: 'Fotografías Vehículo',
        paso: 3,
        tipo: 'foto',
        requerido: true,
        orden: 1,
        descripcion: 'Foto principal del vehículo (vista frontal)',
        activo: true,
        esBase: true,
      ),
      DocumentoConfig(
        id: 'fotoVehiculo2',
        nombre: 'Fotografía del Vehículo 2',
        categoria: 'Fotografías Vehículo',
        paso: 3,
        tipo: 'foto',
        requerido: false,
        orden: 2,
        descripcion: 'Foto adicional del vehículo (vista lateral - opcional)',
        activo: true,
        esBase: true,
      ),
    ];

    return ConfiguracionDocumentos(
      documentos: documentosBase,
      version: '1.0',
      ultimaModificacion: DateTime.now().toIso8601String(),
      modificadoPor: 'Sistema (Configuración por defecto)',
    );
  }

  /// Carga la configuración con fallback a la configuración por defecto
  static Future<ConfiguracionDocumentos>
  cargarConfiguracionConFallback() async {
    final config = await cargarConfiguracion();
    if (config != null) {
      return config;
    }

    print('📋 Usando configuración de documentos por defecto');
    return getConfiguracionPorDefecto();
  }

  /// Compara la configuración activa con los documentos del conductor
  /// y retorna la lista de documentos requeridos que faltan
  static List<DocumentoConfig> obtenerDocumentosFaltantes({
    required ConfiguracionDocumentos configuracion,
    required Map<String, dynamic> documentosUsuario,
  }) {
    final documentosFaltantes = <DocumentoConfig>[];

    for (final doc in configuracion.documentos) {
      // Solo verificar documentos activos y requeridos
      if (!doc.activo || !doc.requerido) continue;

      // Verificar si el documento tiene datos
      final valor = documentosUsuario[doc.id];

      if (doc.tipo == 'foto') {
        // Para fotos, verificar que exista URL
        if (valor == null || valor.toString().isEmpty) {
          documentosFaltantes.add(doc);
        }
      } else {
        // Para otros tipos, verificar que exista valor
        if (valor == null || valor.toString().isEmpty) {
          documentosFaltantes.add(doc);
        }
      }
    }

    return documentosFaltantes;
  }

  /// Verifica si el conductor tiene todos los documentos requeridos
  static bool tieneDocumentosCompletos({
    required ConfiguracionDocumentos configuracion,
    required Map<String, dynamic> documentosUsuario,
  }) {
    final faltantes = obtenerDocumentosFaltantes(
      configuracion: configuracion,
      documentosUsuario: documentosUsuario,
    );
    return faltantes.isEmpty;
  }
}
