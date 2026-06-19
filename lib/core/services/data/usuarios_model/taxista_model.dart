// taxista_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Taxista {
  final String uidTaxista;
  final String modo;
  final String empresa;
  final bool habilitado;
  final PerfilTaxista perfilTaxista;
  final DocumentosVehiculo documentosVehiculo;
  final double? promedioEstrellas;
  final int? numeroResenias;
  final int? totalPuntuacion;

  Taxista({
    required this.uidTaxista,
    required this.modo,
    required this.empresa,
    required this.habilitado,
    required this.perfilTaxista,
    required this.documentosVehiculo,
    this.promedioEstrellas,
    this.numeroResenias,
    this.totalPuntuacion,
  });

  factory Taxista.fromJson(Map<String, dynamic> json) {
    return Taxista(
      uidTaxista: json['uidTaxista'],
      modo: json['modo'],
      empresa: json['empresa'],
      habilitado: json['habilitado'] ?? false,
      perfilTaxista: PerfilTaxista.fromJson(json['perfilTaxista']),
      documentosVehiculo: DocumentosVehiculo.fromJson(
        json['documentosVehiculo'],
      ),
      promedioEstrellas: json['promedioEstrellas'],
      numeroResenias: json['numeroResenias'],
      totalPuntuacion: json['totalPuntuacion'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uidTaxista': uidTaxista,
      'modo': modo,
      'empresa': empresa,
      'habilitado': habilitado,
      'perfilTaxista': perfilTaxista.toJson(),
      'documentosVehiculo': documentosVehiculo.toJson(),
      'promedioEstrellas': promedioEstrellas,
      'numeroResenias': numeroResenias,
      'totalPuntuacion': totalPuntuacion,
    };
  }
}

class PerfilTaxista {
  final String nombre;
  final String genero;
  final String ci;
  final String ciNumero;
  final String ciComplemento;
  final String ciExtension;
  final String email;
  final String telefono;
  final DateTime fechaRegistro;
  final String fotoPerfil;
  final bool datosCompletos;
  final String tipoLicencia;
  final ContactoEmergencia contactoEmergencia;
  final String departamento;

  PerfilTaxista({
    required this.nombre,
    required this.genero,
    required this.ci,
    required this.ciNumero,
    required this.ciComplemento,
    required this.ciExtension,
    required this.email,
    required this.telefono,
    required this.fechaRegistro,
    required this.fotoPerfil,
    required this.datosCompletos,
    required this.tipoLicencia,
    required this.contactoEmergencia,
    required this.departamento,
  });

  factory PerfilTaxista.fromJson(Map<String, dynamic> json) {
    return PerfilTaxista(
      nombre: json['nombre'],
      genero: json['genero'],
      ci: json['ci'],
      ciNumero: json['ci_numero'],
      ciComplemento: json['ci_complemento'],
      ciExtension: json['ci_extension'],
      email: json['email'],
      telefono: json['telefono'],
      fechaRegistro: json['fechaRegistro'] is Timestamp
          ? (json['fechaRegistro'] as Timestamp).toDate()
          : DateTime.parse(json['fechaRegistro']),
      fotoPerfil: json['fotoPerfil'],
      datosCompletos: json['datosCompletos'] ?? false,
      tipoLicencia: json['tipoLicencia'],
      contactoEmergencia: ContactoEmergencia.fromJson(
        json['contactoEmergencia'],
      ),
      departamento: json['departamento'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'genero': genero,
      'ci': ci,
      'ci_numero': ciNumero,
      'ci_complemento': ciComplemento,
      'ci_extension': ciExtension,
      'email': email,
      'telefono': telefono,
      'fechaRegistro': fechaRegistro.toIso8601String(),
      'fotoPerfil': fotoPerfil,
      'datosCompletos': datosCompletos,
      'tipoLicencia': tipoLicencia,
      'contactoEmergencia': contactoEmergencia.toJson(),
      'departamento': departamento,
    };
  }
}

class ContactoEmergencia {
  final String nombre;
  final String telefono;

  ContactoEmergencia({required this.nombre, required this.telefono});

  factory ContactoEmergencia.fromJson(Map<String, dynamic> json) {
    return ContactoEmergencia(
      nombre: json['nombre'],
      telefono: json['telefono'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'nombre': nombre, 'telefono': telefono};
  }
}

class DocumentosVehiculo {
  final String color;
  final String marca;
  final String modelo;
  final String placa;
  final String numeroAsientos;
  final String numeroLicencia;
  final String servicioSeleccionado;
  final DateTime fechaRegistro;
  final DateTime fechaActualizacion;
  final String fotoConductor;
  final String fotoLicenciaConducirAnverso;
  final String fotoLicenciaConducirReverso;
  final String fotoCarneIdentidadAnverso;
  final String fotoCarneIdentidadReverso;
  final String fotoAntecedentesPenales;
  final String fotoSoat;
  final String fotoPermisoCirculacion;
  final String fotoRevisionTecnica;
  final String fotoVehiculo1;
  final String fotoVehiculo2;
  final bool verificadoFotoAntecedentesPenales;
  final bool verificadoFotoCarneIdentidadAnverso;
  final bool verificadoFotoCarneIdentidadReverso;
  final bool verificadoFotoConductor;
  final bool verificadoFotoLicenciaConducirAnverso;
  final bool verificadoFotoLicenciaConducirReverso;
  final bool verificadoFotoPermisoCirculacion;
  final bool verificadoFotoRevisionTecnica;
  final bool verificadoFotoSoat;
  final bool verificadoFotoVehiculo1;
  final bool verificadoFotoVehiculo2;

  DocumentosVehiculo({
    required this.color,
    required this.marca,
    required this.modelo,
    required this.placa,
    required this.numeroAsientos,
    required this.numeroLicencia,
    required this.servicioSeleccionado,
    required this.fechaRegistro,
    required this.fechaActualizacion,
    required this.fotoConductor,
    required this.fotoLicenciaConducirAnverso,
    required this.fotoLicenciaConducirReverso,
    required this.fotoCarneIdentidadAnverso,
    required this.fotoCarneIdentidadReverso,
    required this.fotoAntecedentesPenales,
    required this.fotoSoat,
    required this.fotoPermisoCirculacion,
    required this.fotoRevisionTecnica,
    required this.fotoVehiculo1,
    required this.fotoVehiculo2,
    required this.verificadoFotoAntecedentesPenales,
    required this.verificadoFotoCarneIdentidadAnverso,
    required this.verificadoFotoCarneIdentidadReverso,
    required this.verificadoFotoConductor,
    required this.verificadoFotoLicenciaConducirAnverso,
    required this.verificadoFotoLicenciaConducirReverso,
    required this.verificadoFotoPermisoCirculacion,
    required this.verificadoFotoRevisionTecnica,
    required this.verificadoFotoSoat,
    required this.verificadoFotoVehiculo1,
    required this.verificadoFotoVehiculo2,
  });

  factory DocumentosVehiculo.fromJson(Map<String, dynamic> json) {
    return DocumentosVehiculo(
      color: json['color'] ?? '',
      marca: json['marca'] ?? '',
      modelo: json['modelo'] ?? '',
      placa: json['numeroPlaca'] ?? '',
      // convertir entero a cadena
      numeroAsientos: json['numeroAsientos']?.toString() ?? '',
      numeroLicencia: json['numeroLicencia'] ?? '',
      servicioSeleccionado: json['servicioSeleccionado'] ?? '',
      fechaRegistro: json['fechaRegistro'] is Timestamp
          ? (json['fechaRegistro'] as Timestamp).toDate()
          : DateTime.parse(json['fechaRegistro']),
      fechaActualizacion: json['fechaActualizacion'] is Timestamp
          ? (json['fechaActualizacion'] as Timestamp).toDate()
          : DateTime.parse(json['fechaActualizacion']),
      fotoConductor: json['fotoConductor'] ?? '',
      fotoLicenciaConducirAnverso: json['fotoLicenciaConducirAnverso'] ?? '',
      fotoLicenciaConducirReverso: json['fotoLicenciaConducirReverso'] ?? '',
      fotoCarneIdentidadAnverso: json['fotoCarneIdentidadAnverso'] ?? '',
      fotoCarneIdentidadReverso: json['fotoCarneIdentidadReverso'] ?? '',
      fotoAntecedentesPenales: json['fotoAntecedentesPenales'] ?? '',
      fotoSoat: json['fotoSoat'] ?? '',
      fotoPermisoCirculacion: json['fotoPermisoCirculacion'] ?? '',
      fotoRevisionTecnica: json['fotoRevisionTecnica'] ?? '',
      fotoVehiculo1: json['fotoVehiculo1'] ?? '',
      fotoVehiculo2: json['fotoVehiculo2'] ?? '',
      verificadoFotoAntecedentesPenales:
          json['verificadoFotoAntecedentesPenales'] ?? false,
      verificadoFotoCarneIdentidadAnverso:
          json['verificadoFotoCarneIdentidadAnverso'] ?? false,
      verificadoFotoCarneIdentidadReverso:
          json['verificadoFotoCarneIdentidadReverso'] ?? false,
      verificadoFotoConductor: json['verificadoFotoConductor'] ?? false,
      verificadoFotoLicenciaConducirAnverso:
          json['verificadoFotoLicenciaConducirAnverso'] ?? false,
      verificadoFotoLicenciaConducirReverso:
          json['verificadoFotoLicenciaConducirReverso'] ?? false,
      verificadoFotoPermisoCirculacion:
          json['verificadoFotoPermisoCirculacion'] ?? false,
      verificadoFotoRevisionTecnica:
          json['verificadoFotoRevisionTecnica'] ?? false,
      verificadoFotoSoat: json['verificadoFotoSoat'] ?? false,
      verificadoFotoVehiculo1: json['verificadoFotoVehiculo1'] ?? false,
      verificadoFotoVehiculo2: json['verificadoFotoVehiculo2'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'color': color,
      'marca': marca,
      'modelo': modelo,
      'numeroPlaca': placa,
      'numeroAsientos': numeroAsientos,
      'numeroLicencia': numeroLicencia,
      'servicioSeleccionado': servicioSeleccionado,
      'fechaRegistro': fechaRegistro.toIso8601String(),
      'fechaActualizacion': fechaActualizacion.toIso8601String(),
      'fotoConductor': fotoConductor,
      'fotoLicenciaConducirAnverso': fotoLicenciaConducirAnverso,
      'fotoLicenciaConducirReverso': fotoLicenciaConducirReverso,
      'fotoCarneIdentidadAnverso': fotoCarneIdentidadAnverso,
      'fotoCarneIdentidadReverso': fotoCarneIdentidadReverso,
      'fotoAntecedentesPenales': fotoAntecedentesPenales,
      'fotoSoat': fotoSoat,
      'fotoPermisoCirculacion': fotoPermisoCirculacion,
      'fotoRevisionTecnica': fotoRevisionTecnica,
      'fotoVehiculo1': fotoVehiculo1,
      'fotoVehiculo2': fotoVehiculo2,
      'verificadoFotoAntecedentesPenales': verificadoFotoAntecedentesPenales,
      'verificadoFotoCarneIdentidadAnverso':
          verificadoFotoCarneIdentidadAnverso,
      'verificadoFotoCarneIdentidadReverso':
          verificadoFotoCarneIdentidadReverso,
      'verificadoFotoConductor': verificadoFotoConductor,
      'verificadoFotoLicenciaConducirAnverso':
          verificadoFotoLicenciaConducirAnverso,
      'verificadoFotoLicenciaConducirReverso':
          verificadoFotoLicenciaConducirReverso,
      'verificadoFotoPermisoCirculacion': verificadoFotoPermisoCirculacion,
      'verificadoFotoRevisionTecnica': verificadoFotoRevisionTecnica,
      'verificadoFotoSoat': verificadoFotoSoat,
      'verificadoFotoVehiculo1': verificadoFotoVehiculo1,
      'verificadoFotoVehiculo2': verificadoFotoVehiculo2,
    };
  }
}
