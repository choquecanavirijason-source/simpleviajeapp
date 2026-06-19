import '../../mapa_destino.dart';

/// Entidades y modelos relacionados a los servicios de empresa

class HorasPicoFranja {
  final String desde;
  final String hasta;

  const HorasPicoFranja({required this.desde, required this.hasta});

  factory HorasPicoFranja.fromMap(Map<String, dynamic> map) {
    return HorasPicoFranja(
      desde: (map['desde'] ?? '').toString(),
      hasta: (map['hasta'] ?? '').toString(),
    );
  }
}

class HorasPico {
  final List<HorasPicoFranja> franjas;

  const HorasPico({required this.franjas});

  factory HorasPico.fromMap(Map<String, dynamic> map) {
    final raw = map['franjas'];
    final list = <HorasPicoFranja>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          list.add(HorasPicoFranja.fromMap(item));
        }
      }
    }
    return HorasPico(franjas: List.unmodifiable(list));
  }
}

class TramoAeropuerto {
  final String desdeKm;
  final num precio;

  const TramoAeropuerto({required this.desdeKm, required this.precio});

  factory TramoAeropuerto.fromMap(Map<String, dynamic> map) {
    return TramoAeropuerto(
      desdeKm: (map['desdeKm'] ?? '').toString(),
      precio: (map['precio'] is num) ? map['precio'] as num : 0,
    );
  }
}

class TarifasAeropuerto {
  final List<TramoAeropuerto> tramos;

  const TarifasAeropuerto({required this.tramos});

  factory TarifasAeropuerto.fromMap(Map<String, dynamic> map) {
    final raw = map['tramos'];
    final list = <TramoAeropuerto>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          list.add(TramoAeropuerto.fromMap(item));
        }
      }
    }
    return TarifasAeropuerto(tramos: List.unmodifiable(list));
  }
}

class TarifasServicio {
  final num comision;
  final num distanciaBase;
  final num horaPicoExtra;
  final num nocturno;
  final num porKm;
  final num porMin;
  final num tarifaBase;

  const TarifasServicio({
    required this.comision,
    required this.distanciaBase,
    required this.horaPicoExtra,
    required this.nocturno,
    required this.porKm,
    required this.porMin,
    required this.tarifaBase,
  });

  factory TarifasServicio.fromMap(Map<String, dynamic> map) {
    num _n(dynamic v) => v is num ? v : 0;

    return TarifasServicio(
      comision: _n(map['comision']),
      distanciaBase: _n(map['distanciaBase']),
      horaPicoExtra: _n(map['horaPicoExtra']),
      nocturno: _n(map['nocturno']),
      porKm: _n(map['porKm']),
      porMin: _n(map['porMin']),
      tarifaBase: _n(map['tarifaBase']),
    );
  }
}

class ServicioEmpresa {
  final String id; // clave en el documento: ej. "conductor_designado"
  final String servicio; // nombre visible
  final String? icono;
  final String? logo;
  final bool activo;
  final String? departamento;
  final HorasPico? horasPico;
  final TarifasServicio? tarifas;
  final TarifasAeropuerto? tarifasAeropuerto;

  const ServicioEmpresa({
    required this.id,
    required this.servicio,
    this.icono,
    this.logo,
    required this.activo,
    this.departamento,
    this.horasPico,
    this.tarifas,
    this.tarifasAeropuerto,
  });

  String get label => servicio;

  factory ServicioEmpresa.fromEntry({
    required String id,
    required Map<String, dynamic> raw,
  }) {
    final String? servicioNombre = (raw['servicio'] as String?)?.trim();
    final String nombreFinal =
        (servicioNombre == null || servicioNombre.isEmpty)
        ? id.replaceAll('_', ' ').trim()
        : servicioNombre;

    final horasPicoMap = raw['Horas_pico'];
    final tarifasMap = raw['tarifas'];
    final tarifasAeropuertoMap = raw['Tarifas_Aeropuerto'];

    return ServicioEmpresa(
      id: id,
      servicio: nombreFinal,
      icono: (raw['icono'] as String?)?.trim(),
      logo: (raw['logo'] as String?)?.trim(),
      activo: raw['activo'] is bool ? raw['activo'] as bool : true,
      departamento: (raw['departamento'] as String?)?.trim(),
      horasPico: (horasPicoMap is Map<String, dynamic>)
          ? HorasPico.fromMap(horasPicoMap)
          : null,
      tarifas: (tarifasMap is Map<String, dynamic>)
          ? TarifasServicio.fromMap(tarifasMap)
          : null,
      tarifasAeropuerto: (tarifasAeropuertoMap is Map<String, dynamic>)
          ? TarifasAeropuerto.fromMap(tarifasAeropuertoMap)
          : null,
    );
  }
}
