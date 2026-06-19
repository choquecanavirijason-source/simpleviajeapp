import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Este archivo nos sirve para obtener las coordenadas, usamos
/// el [place_id] obtenido en la búsqueda.
class CoordenadasPlaceId {
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/place/details/json';

  /// Obtiene las coordenadas, usamos el [place_id] obtenido en la búsqueda.
  Future<Map<String, double>?> obtenerCoordenadas(String placeId) async {
    if (placeId.isEmpty) {
      print('⚠️ El place_id está vacío.');
      return null;
    }

    final apiKey = dotenv.env['GOOGLE_API_KEY']?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      print('❌ CoordenadasPlaceId: GOOGLE_API_KEY no encontrado en .env');
      return null;
    }

    try {
      final Uri url = Uri.parse(
        '$_baseUrl?place_id=${Uri.encodeQueryComponent(placeId)}&fields=geometry/location&key=$apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final location = data['result']['geometry']['location'];
          final lat = location['lat']?.toDouble();
          final lng = location['lng']?.toDouble();

          return {'lat': lat, 'lng': lng};
        } else {
          print('❌ Error de Google API: ${data['status']}');
          return null;
        }
      } else {
        print('❌ Error HTTP: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('⚠️ Error al obtener coordenadas: $e');
      return null;
    }
  }
}

/* Ejemplo de uso: UI
import 'package:buses2/core/services/google/coordenadas_place_id.dart';
...
onUpdate: (r) async {
  final placeId = r.placeId ?? '';
  final coordenadas = await _googleService.obtenerCoordenadas(placeId);

  if (coordenadas != null) {
    print('📍 Coordenadas DESTINO: ${coordenadas['lat']}, ${coordenadas['lng']}');
  }
},
*/
