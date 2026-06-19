// Modelo para los documentos del vehículo y del conductor
class DocumentosVehiculo {
  // Datos del vehículo
  final String? marca;
  final String? color;
  final String? numeroAsientos;

  // Datos de la licencia
  final String? numeroLicencia;

  // URLs de los documentos subidos
  final String? fotoAntecedentesPenales;
  final String? fotoConductor;
  final String? fotoCarneIdentidadAnverso;
  final String? fotoCarneIdentidadReverso;
  final String? fotoLicenciaConducirAnverso;
  final String? fotoLicenciaConducirReverso;
  final String? fotoSoat;
  final String? fotoPermisoCirculacion;
  final String? fotoRevisionTecnica;
  final String? fotoVehiculo1;
  final String? fotoVehiculo2;

  // Estados de verificación para cada documento
  final bool verificadoFotoAntecedentesPenales;
  final bool verificadoFotoConductor;
  final bool verificadoFotoCarneIdentidadAnverso;
  final bool verificadoFotoCarneIdentidadReverso;
  final bool verificadoFotoLicenciaConducirAnverso;
  final bool verificadoFotoLicenciaConducirReverso;
  final bool verificadoFotoSoat;
  final bool verificadoFotoPermisoCirculacion;
  final bool verificadoFotoRevisionTecnica;
  final bool verificadoFotoVehiculo1;
  final bool verificadoFotoVehiculo2;

  // Marca de tiempo
  final DateTime? fechaRegistro;
  final DateTime? fechaActualizacion;

  DocumentosVehiculo({
    this.marca,
    this.color,
    this.numeroAsientos,
    this.numeroLicencia,
    this.fotoAntecedentesPenales,
    this.fotoConductor,
    this.fotoCarneIdentidadAnverso,
    this.fotoCarneIdentidadReverso,
    this.fotoLicenciaConducirAnverso,
    this.fotoLicenciaConducirReverso,
    this.fotoSoat,
    this.fotoPermisoCirculacion,
    this.fotoRevisionTecnica,
    this.fotoVehiculo1,
    this.fotoVehiculo2,
    this.verificadoFotoAntecedentesPenales = false,
    this.verificadoFotoConductor = false,
    this.verificadoFotoCarneIdentidadAnverso = false,
    this.verificadoFotoCarneIdentidadReverso = false,
    this.verificadoFotoLicenciaConducirAnverso = false,
    this.verificadoFotoLicenciaConducirReverso = false,
    this.verificadoFotoSoat = false,
    this.verificadoFotoPermisoCirculacion = false,
    this.verificadoFotoRevisionTecnica = false,
    this.verificadoFotoVehiculo1 = false,
    this.verificadoFotoVehiculo2 = false,
    this.fechaRegistro,
    this.fechaActualizacion,
  });

  // Convertir a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'marca': marca,
      'color': color,
      'numeroAsientos': numeroAsientos,
      'numeroLicencia': numeroLicencia,
      'fotoAntecedentesPenales': fotoAntecedentesPenales,
      'fotoConductor': fotoConductor,
      'fotoCarneIdentidadAnverso': fotoCarneIdentidadAnverso,
      'fotoCarneIdentidadReverso': fotoCarneIdentidadReverso,
      'fotoLicenciaConducirAnverso': fotoLicenciaConducirAnverso,
      'fotoLicenciaConducirReverso': fotoLicenciaConducirReverso,
      'fotoSoat': fotoSoat,
      'fotoPermisoCirculacion': fotoPermisoCirculacion,
      'fotoRevisionTecnica': fotoRevisionTecnica,
      'fotoVehiculo1': fotoVehiculo1,
      'fotoVehiculo2': fotoVehiculo2,
      'verificadoFotoAntecedentesPenales': verificadoFotoAntecedentesPenales,
      'verificadoFotoConductor': verificadoFotoConductor,
      'verificadoFotoCarneIdentidadAnverso':
          verificadoFotoCarneIdentidadAnverso,
      'verificadoFotoCarneIdentidadReverso':
          verificadoFotoCarneIdentidadReverso,
      'verificadoFotoLicenciaConducirAnverso':
          verificadoFotoLicenciaConducirAnverso,
      'verificadoFotoLicenciaConducirReverso':
          verificadoFotoLicenciaConducirReverso,
      'verificadoFotoSoat': verificadoFotoSoat,
      'verificadoFotoPermisoCirculacion': verificadoFotoPermisoCirculacion,
      'verificadoFotoRevisionTecnica': verificadoFotoRevisionTecnica,
      'verificadoFotoVehiculo1': verificadoFotoVehiculo1,
      'verificadoFotoVehiculo2': verificadoFotoVehiculo2,
      'fechaRegistro': fechaRegistro?.toIso8601String(),
      'fechaActualizacion': fechaActualizacion?.toIso8601String(),
    };
  }

  // Crear desde Map (desde Firestore)
  factory DocumentosVehiculo.fromMap(Map<String, dynamic> map) {
    return DocumentosVehiculo(
      marca: map['marca'],
      color: map['color'],
      numeroAsientos: map['numeroAsientos'],
      numeroLicencia: map['numeroLicencia'],
      fotoAntecedentesPenales: map['fotoAntecedentesPenales'],
      fotoConductor: map['fotoConductor'],
      fotoCarneIdentidadAnverso: map['fotoCarneIdentidadAnverso'],
      fotoCarneIdentidadReverso: map['fotoCarneIdentidadReverso'],
      fotoLicenciaConducirAnverso: map['fotoLicenciaConducirAnverso'],
      fotoLicenciaConducirReverso: map['fotoLicenciaConducirReverso'],
      fotoSoat: map['fotoSoat'],
      fotoPermisoCirculacion: map['fotoPermisoCirculacion'],
      fotoRevisionTecnica: map['fotoRevisionTecnica'],
      fotoVehiculo1: map['fotoVehiculo1'],
      fotoVehiculo2: map['fotoVehiculo2'],
      verificadoFotoAntecedentesPenales:
          map['verificadoFotoAntecedentesPenales'] ?? false,
      verificadoFotoConductor: map['verificadoFotoConductor'] ?? false,
      verificadoFotoCarneIdentidadAnverso:
          map['verificadoFotoCarneIdentidadAnverso'] ?? false,
      verificadoFotoCarneIdentidadReverso:
          map['verificadoFotoCarneIdentidadReverso'] ?? false,
      verificadoFotoLicenciaConducirAnverso:
          map['verificadoFotoLicenciaConducirAnverso'] ?? false,
      verificadoFotoLicenciaConducirReverso:
          map['verificadoFotoLicenciaConducirReverso'] ?? false,
      verificadoFotoSoat: map['verificadoFotoSoat'] ?? false,
      verificadoFotoPermisoCirculacion:
          map['verificadoFotoPermisoCirculacion'] ?? false,
      verificadoFotoRevisionTecnica:
          map['verificadoFotoRevisionTecnica'] ?? false,
      verificadoFotoVehiculo1: map['verificadoFotoVehiculo1'] ?? false,
      verificadoFotoVehiculo2: map['verificadoFotoVehiculo2'] ?? false,
      fechaRegistro: map['fechaRegistro'] != null
          ? DateTime.parse(map['fechaRegistro'])
          : null,
      fechaActualizacion: map['fechaActualizacion'] != null
          ? DateTime.parse(map['fechaActualizacion'])
          : null,
    );
  }

  /// Método para verificar si todos los documentos obligatorios están subidos
  /// fotoVehiculo2 es OPCIONAL
  bool get todosDocumentosSubidos {
    return numeroLicencia != null &&
        marca != null &&
        color != null &&
        numeroAsientos != null &&
        fotoAntecedentesPenales != null &&
        fotoConductor != null &&
        fotoCarneIdentidadAnverso != null &&
        fotoCarneIdentidadReverso != null &&
        fotoLicenciaConducirAnverso != null &&
        fotoLicenciaConducirReverso != null &&
        fotoSoat != null &&
        fotoPermisoCirculacion != null &&
        fotoRevisionTecnica != null &&
        fotoVehiculo1 != null;
    // fotoVehiculo2 NO es obligatorio
  }
}
