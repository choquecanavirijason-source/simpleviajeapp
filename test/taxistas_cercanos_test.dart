import 'package:buses2/features/home/services/taxistas_cercanos_service.dart';
import 'package:buses2/features/mapa_destino/widgets/radar_buscando.dart';
import 'package:flutter_test/flutter_test.dart';

// Pasajero en la plaza principal de Cochabamba.
const double cLat = -17.3895;
const double cLng = -66.1568;
const int ahora = 1800000000000;

Map<String, Object?> taxi(
  double lat,
  double lng, {
  String servicio = 'Taxi',
  int? t = ahora,
}) =>
    {
      'lat': lat,
      'lng': lng,
      'servicio': servicio,
      if (t != null) 't': t,
    };

List<TaxistaOnline> seleccionar(
  Map raw, {
  String? servicio,
  List<double> radios = TaxistasCercanosService.radiosPorDefectoKm,
}) =>
    TaxistasCercanosService.seleccionarCercanos(
      raw: raw,
      centerLat: cLat,
      centerLng: cLng,
      servicio: servicio,
      radiosKm: radios,
      nowMs: ahora,
    );

void main() {
  group('haversineKm', () {
    test('mismo punto es 0', () {
      expect(TaxistasCercanosService.haversineKm(cLat, cLng, cLat, cLng), 0);
    });

    test('0.01° de latitud son ~1.11 km', () {
      final d =
          TaxistasCercanosService.haversineKm(cLat, cLng, cLat + 0.01, cLng);
      expect(d, closeTo(1.112, 0.005));
    });
  });

  group('rumboGrados', () {
    test('puntos cardinales', () {
      double r(double lat, double lng) =>
          TaxistasCercanosService.rumboGrados(cLat, cLng, lat, lng);
      expect(r(cLat + 0.01, cLng), closeTo(0, 0.5)); // norte
      expect(r(cLat, cLng + 0.01), closeTo(90, 0.5)); // este
      expect(r(cLat - 0.01, cLng), closeTo(180, 0.5)); // sur
      expect(r(cLat, cLng - 0.01), closeTo(270, 0.5)); // oeste
    });
  });

  group('seleccionarCercanos', () {
    test('ordena del más cercano al más lejano', () {
      final res = seleccionar({
        'lejos': taxi(cLat + 0.03, cLng), // ~3.3 km
        'cerca': taxi(cLat + 0.005, cLng), // ~0.55 km
        'medio': taxi(cLat + 0.015, cLng), // ~1.7 km
      });
      expect(res.map((t) => t.uid), ['cerca', 'medio', 'lejos']);
      expect(res.first.distanciaKm, closeTo(0.556, 0.01));
    });

    test('usa el primer radio con resultados (5 km)', () {
      final res = seleccionar({
        'a': taxi(cLat + 0.02, cLng), // ~2.2 km
        'b': taxi(cLat + 0.08, cLng), // ~8.9 km, fuera de 5 km
      });
      expect(res.map((t) => t.uid), ['a']);
    });

    test('amplía el radio si no hay nadie en 5 km', () {
      final res = seleccionar({
        'b': taxi(cLat + 0.08, cLng), // ~8.9 km
        'c': taxi(cLat + 0.15, cLng), // ~16.7 km
      });
      expect(res.map((t) => t.uid), ['b']);
    });

    test('llega hasta 20 km y no más', () {
      expect(seleccionar({'c': taxi(cLat + 0.15, cLng)}).single.uid, 'c');
      expect(seleccionar({'x': taxi(cLat + 0.3, cLng)}), isEmpty); // ~33 km
    });

    test('descarta ubicaciones viejas', () {
      final viejo = ahora - const Duration(minutes: 4).inMilliseconds;
      final reciente = ahora - const Duration(minutes: 2).inMilliseconds;
      final res = seleccionar({
        'fantasma': taxi(cLat + 0.001, cLng, t: viejo),
        'activo': taxi(cLat + 0.01, cLng, t: reciente),
      });
      expect(res.map((t) => t.uid), ['activo']);
    });

    test('acepta nodos sin timestamp (formato antiguo)', () {
      expect(seleccionar({'a': taxi(cLat + 0.01, cLng, t: null)}), hasLength(1));
    });

    test('filtra por servicio sin importar mayúsculas', () {
      final res = seleccionar({
        'taxi': taxi(cLat + 0.001, cLng, servicio: 'Taxi'),
        'moto': taxi(cLat + 0.01, cLng, servicio: 'Moto Taxi'),
      }, servicio: 'moto taxi');
      expect(res.map((t) => t.uid), ['moto']);
    });

    test('ignora nodos inválidos', () {
      final res = seleccionar({
        'sinLat': {'lng': cLng},
        'noEsMapa': 'basura',
        'ok': taxi(cLat + 0.01, cLng),
      });
      expect(res.map((t) => t.uid), ['ok']);
    });

    test('sin taxistas devuelve lista vacía', () {
      expect(seleccionar({}), isEmpty);
    });
  });

  group('RadarTaxiCercano.distanciaTexto', () {
    test('metros bajo 1 km, km con un decimal desde 1 km', () {
      String txt(double km) =>
          RadarTaxiCercano(distanciaKm: km, rumboGrados: 0).distanciaTexto;
      expect(txt(0.35), '350 m');
      expect(txt(1.24), '1.2 km');
      expect(txt(12), '12.0 km');
    });
  });
}
