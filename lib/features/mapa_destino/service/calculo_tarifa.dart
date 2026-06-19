// lib/features/mapa_destino/service/calculo_tarifa.dart
import './tarifas.dart'; // Aquí tienes Tarifa, HorasPico, Aeropuerto y helpers

/// Realiza el calculo de la Tarifa.
/// Si recibe 2km base por 10bs base. los primeros 2.50km
/// para abajo son 10bs. y si son 2.51km contara 1km extra y se
/// sumara el valor recibido por km extra. si es 1bs entonces
/// nos dara 11bs. y si minutos recibe Bs. 0.10 se le sumara
/// 0.70 (7 minutos) y el total sera 11.70bs. y asi sucesivamente.
/// Si es aeropuerto se ignoran los km y minutos y se cobra
/// segun la tabla de aeropuerto.
/// Si es hora pico se le suma el porcentaje recibido. Ejemplo
/// si es 10% se le suma 1.17 y el total sera 12.87. los valores
/// 0.87 se redondea a 0.90. si es 0.06 para arriba sera 0.10
/// y si es 0.05 para abajo se redondea a 0.00
/// Si es nocturno se le suma el valor recibido. Ejemplo 2bs
/// el recargo nocturno solo se aplica si es aeropuerto.
/// Si es aeropuerto y nocturno se le suma el valor recibido
/// de nocturno. Ejemplo 2bs y el total sera 12.90

class CalculoTarifaResult {
  final bool esAeropuerto;
  final bool aplicoHoraPico;
  final bool aplicoNocturno;

  final double distanciaKm;
  final int minutos;

  final double base;
  final int kmExtraCobrar;
  final double cargoDistancia;
  final double cargoTiempo;
  final double
  recargoHoraPico; // monto sumado por hora pico (post multiplicador)
  final double
  recargoNocturno; // monto fijo sumado si aplica (SOLO en aeropuerto, igual a tu ejemplo)
  final double total;

  const CalculoTarifaResult({
    required this.esAeropuerto,
    required this.aplicoHoraPico,
    required this.aplicoNocturno,
    required this.distanciaKm,
    required this.minutos,
    required this.base,
    required this.kmExtraCobrar,
    required this.cargoDistancia,
    required this.cargoTiempo,
    required this.recargoHoraPico,
    required this.recargoNocturno,
    required this.total,
  });
}

CalculoTarifaResult calcularPrecioTotal({
  required TarifaHorasPicoAeropuerto combo,
  required double distanciaKm,
  required int minutos,
  String? destinoNombre,
  bool? aplicaNocturno, // ⬅️ ahora nullable
  DateTime? ahora,
  Duration nocturnoStart = const Duration(hours: 22), // ⬅️ nuevo
  Duration nocturnoEnd = const Duration(hours: 6), // ⬅️ nuevo
}) {
  final t = combo.tarifa;
  final hp = combo.horasPico;
  final ap = combo.aeropuerto;

  final dt = (ahora ?? DateTime.now()).toLocal(); // ⬅️ usar un solo “ahora”
  final aplicaNocturnoFinal = // ⬅️ decidir aquí
      aplicaNocturno ??
      esNocturnoAhoraDur(ahora: dt, start: nocturnoStart, end: nocturnoEnd);

  final String dest = (destinoNombre ?? '').toLowerCase();
  final esAeropuerto = dest.contains('aeropuerto') || dest.contains('airport');
  double total;
  int kmExtraCobrar = 0;
  double cargoDistancia = 0.0;
  double cargoTiempo = 0.0;
  double recargoHP = 0.0;
  double recargoNoc = 0.0;

  if (esAeropuerto) {
    // === LÓGICA AEROPUERTO (tarifa fija por tramos) ===
    total = precioAeropuertoPorDistancia(ap, distanciaKm);

    // SOLO aquí se suma nocturno (si aplica)
    if (aplicaNocturnoFinal && t.nocturno > 0) {
      // ⬅️ usamos aplicaNocturnoFinal
      recargoNoc = t.nocturno;
      total += recargoNoc;
    }
    total = _redondearDecimaConUmbral(total);

    return CalculoTarifaResult(
      esAeropuerto: true,
      aplicoHoraPico: false,
      aplicoNocturno: aplicaNocturnoFinal && t.nocturno > 0, // ⬅️
      distanciaKm: distanciaKm,
      minutos: minutos,
      base: 0.0,
      kmExtraCobrar: 0,
      cargoDistancia: 0.0,
      cargoTiempo: 0.0,
      recargoHoraPico: 0.0,
      recargoNocturno: recargoNoc,
      total: total,
    );
  }

  // === LÓGICA NORMAL ===
  // Distancia: base + extra con regla 0.51
  if (distanciaKm > t.distanciaBase) {
    final kmExtra = distanciaKm - t.distanciaBase;
    final kmExtraEntero = kmExtra.floor();
    final tieneDecimalAlto = (kmExtra - kmExtraEntero) >= 0.51;
    kmExtraCobrar = kmExtraEntero + (tieneDecimalAlto ? 1 : 0);
    cargoDistancia = kmExtraCobrar * t.porKm;
  }

  // Tiempo
  cargoTiempo = minutos * t.porMin;
  total = t.tarifaBase + cargoDistancia + cargoTiempo;

  // Hora pico (porcentaje) con franjas DINÁMICAS (de la empresa/servicio)
  final esPico = esHoraPicoAhora(hp, dt); // ⬅️ reusar dt
  if (esPico && t.horaPicoExtra > 0) {
    final double pct = (t.horaPicoExtra >= 1.0)
        ? (t.horaPicoExtra / 100.0)
        : t.horaPicoExtra;
    final antes = total;
    total *= (1 + pct);
    recargoHP = total - antes;
  }

  // 👉 aplicar redondeo de 0.06 a 0.10 y de 0.05 a 0.00
  total = _redondearDecimaConUmbral(total);

  // Igual que tu ejemplo: en la rama NORMAL NO sumas nocturno.
  return CalculoTarifaResult(
    esAeropuerto: false,
    aplicoHoraPico: esPico && t.horaPicoExtra > 0,
    aplicoNocturno: false,
    distanciaKm: distanciaKm,
    minutos: minutos,
    base: t.tarifaBase,
    kmExtraCobrar: kmExtraCobrar,
    cargoDistancia: cargoDistancia,
    cargoTiempo: cargoTiempo,
    recargoHoraPico: recargoHP,
    recargoNocturno: 0.0,
    total: total,
  );
}

// Helper: redondea a múltiplos de 0.10 con umbral 0.06
double _redondearDecimaConUmbral(double x) {
  // decima inferior
  final lower = (x * 10).floor() / 10.0;
  final rem = x - lower;
  // 0.00–0.05 -> lower ; 0.06–0.09 -> lower + 0.10
  return rem < 0.06 ? lower : (lower + 0.10);
}

/*
import '../service/tarifas.dart';         // donde obtienes Tarifa desde la nube
import '../service/calculo_tarifa.dart';  // este archivo

final t = tarifa; // Tarifa traída de la nube (tarifaBase, porKm, porMin, distanciaBase)
final res = calcularTarifaBasica(
  tarifa: t,
  distanciaKm: 2.49,
  minutos: 7, // por ejemplo
);

// res.total → el precio final
// res.kmExtraCobrar/cargoDistancia/cargoTiempo para mostrar desglose
*/

/// Devuelve true si `ahora` cae dentro del horario nocturno.
/// Maneja correctamente rangos que cruzan medianoche (ej.: 22:00–06:00).
bool esNocturnoAhoraDur({
  DateTime? ahora,
  Duration start = const Duration(hours: 22), // 22:00
  Duration end = const Duration(hours: 6), // 06:00 (exclusivo)
}) {
  final dt = (ahora ?? DateTime.now()).toLocal();
  final nowDur = Duration(hours: dt.hour, minutes: dt.minute);

  final cruzaMedianoche = start >= end;
  if (!cruzaMedianoche) {
    return nowDur >= start && nowDur < end;
  } else {
    return nowDur >= start || nowDur < end;
  }
}
