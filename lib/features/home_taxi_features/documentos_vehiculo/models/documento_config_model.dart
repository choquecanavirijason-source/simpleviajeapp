/// Modelo para la configuración de documentos cargada desde Firestore
class DocumentoConfig {
  final String id;
  final String nombre;
  final String categoria;
  final int paso;
  final String tipo; // 'foto', 'texto', 'numero', 'seleccion'
  final bool requerido;
  final int orden;
  final String? descripcion;
  final bool activo;
  final bool esBase;
  final String? fechaCreacion;
  final List<String>? opciones; // Para tipo 'seleccion'

  DocumentoConfig({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.paso,
    required this.tipo,
    required this.requerido,
    required this.orden,
    this.descripcion,
    required this.activo,
    required this.esBase,
    this.fechaCreacion,
    this.opciones,
  });

  /// Crea una instancia desde un Map de Firestore
  factory DocumentoConfig.fromMap(Map<String, dynamic> map) {
    return DocumentoConfig(
      id: map['id'] as String? ?? '',
      nombre: map['nombre'] as String? ?? '',
      categoria: map['categoria'] as String? ?? '',
      paso: map['paso'] as int? ?? 0,
      tipo: map['tipo'] as String? ?? 'foto',
      requerido: map['requerido'] as bool? ?? false,
      orden: map['orden'] as int? ?? 0,
      descripcion: map['descripcion'] as String?,
      activo: map['activo'] as bool? ?? true,
      esBase: map['esBase'] as bool? ?? false,
      fechaCreacion: map['fechaCreacion'] as String?,
      opciones: map['opciones'] != null
          ? List<String>.from(map['opciones'] as List)
          : null,
    );
  }

  /// Convierte a Map para guardar en Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'categoria': categoria,
      'paso': paso,
      'tipo': tipo,
      'requerido': requerido,
      'orden': orden,
      'descripcion': descripcion,
      'activo': activo,
      'esBase': esBase,
      'fechaCreacion': fechaCreacion,
      if (opciones != null) 'opciones': opciones,
    };
  }

  @override
  String toString() {
    return 'DocumentoConfig(id: $id, nombre: $nombre, paso: $paso, tipo: $tipo, requerido: $requerido)';
  }
}

/// Configuración completa de documentos desde Firestore
class ConfiguracionDocumentos {
  final List<DocumentoConfig> documentos;
  final String version;
  final String ultimaModificacion;
  final String? modificadoPor;

  ConfiguracionDocumentos({
    required this.documentos,
    required this.version,
    required this.ultimaModificacion,
    this.modificadoPor,
  });

  /// Crea una instancia desde un Map de Firestore
  factory ConfiguracionDocumentos.fromMap(Map<String, dynamic> map) {
    final docsRaw = map['documentos'] as List<dynamic>? ?? [];
    final documentos = docsRaw
        .map((doc) => DocumentoConfig.fromMap(doc as Map<String, dynamic>))
        .toList();

    return ConfiguracionDocumentos(
      documentos: documentos,
      version: map['version'] as String? ?? '1.0',
      ultimaModificacion: map['ultimaModificacion'] as String? ?? '',
      modificadoPor: map['modificadoPorNombre'] as String?,
    );
  }

  /// Obtiene documentos de un paso específico ordenados
  List<DocumentoConfig> getDocumentosPorPaso(int paso) {
    return documentos.where((doc) => doc.paso == paso && doc.activo).toList()
      ..sort((a, b) => a.orden.compareTo(b.orden));
  }

  /// Obtiene todos los documentos requeridos
  List<DocumentoConfig> getDocumentosRequeridos() {
    return documentos.where((doc) => doc.requerido && doc.activo).toList();
  }

  /// Verifica si un documento específico existe en la configuración
  bool tieneDocumento(String id) {
    return documentos.any((doc) => doc.id == id && doc.activo);
  }

  @override
  String toString() {
    return 'ConfiguracionDocumentos(documentos: ${documentos.length}, version: $version)';
  }
}
