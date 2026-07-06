import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';

class UbicacionUsuario {
  /// Obtiene las coordenadas del usuario en formato `{ 'lat': 0.0, 'lng': 0.0 }`.
  Future<Map<String, double>?> coordenadasUser() async {
    try {
      // Verifica si los servicios de ubicación están habilitados
      final servicioHabilitado = await Geolocator.isLocationServiceEnabled();
      if (!servicioHabilitado) {
        print('⚠️ Los servicios de ubicación están deshabilitados.');
        return null;
      }

      // Verifica permisos
      LocationPermission permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
        if (permiso == LocationPermission.denied) {
          print('🚫 Permiso de ubicación denegado.');
          return null;
        }
      }

      if (permiso == LocationPermission.deniedForever) {
        print('🚫 Permiso de ubicación denegado permanentemente.');
        return null;
      }

      // Obtiene la posición actual
      final Position posicion = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return {'lat': posicion.latitude, 'lng': posicion.longitude};
    } catch (e) {
      print('❌ Error al obtener ubicación del usuario: $e');
      return null;
    }
  }
  /* Ejemplo de uso:
import 'package:buses2/core/services/ubicacion_usuario/ubicacion_user.dart';
...
final ubicacion = UbicacionUsuario();
...
Future<void> obtenerSoloCoordenadas() async {
  final coords = await ubicacion.coordenadasUser();

  if (coords != null) {
    print('🛰 Coordenadas actuales:');
    print('Latitud: ${coords['lat']}');
    print('Longitud: ${coords['lng']}');
  } else {
    print('❌ No se pudo obtener la ubicación.');
  }
}
*/

  /// Retorna un `Stream` de la ubicación en tiempo real.
  /// Ideal para rastrear movimiento del usuario (por ejemplo, conductor).
  Stream<Map<String, double>> escucharUbicacion() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10, // mínimo 10 metros de diferencia
      ),
    ).map(
      (Position posicion) => {
        'lat': posicion.latitude,
        'lng': posicion.longitude,
      },
    );
  }

  /// Convierte coordenadas (lat, lng) en una dirección legible.
  /// Ej: (lat, lng) → "Plaza Bolivar, Bolivia."
  Future<String?> obtenerDireccionDesdeCoordenadas(
    double lat,
    double lng,
  ) async {
    final token = dotenv.env['MAPBOX_TOKEN'] ?? '';
    if (token.isEmpty) {
      print('❌ MAPBOX_TOKEN no configurado en .env');
      return null;
    }
    try {
      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json?access_token=$token&language=es&limit=1',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['features'] != null && data['features'].isNotEmpty) {
          return data['features'][0]['place_name'];
        } else {
          print('⚠️ No se encontraron resultados para esas coordenadas.');
          return null;
        }
      } else {
        print('❌ Error HTTP ${response.statusCode} al obtener dirección.');
        return null;
      }
    } catch (e) {
      print('⚠️ Error al obtener dirección con Mapbox: $e');
      return null;
    }
  }

  /* Ejemplo de uso:
import 'package:buses2/core/services/ubicacion_usuario/ubicacion_user.dart';
...
final UbicacionUsuario ubicacion = UbicacionUsuario();
...
Future<void> mostrarUbicacionUsuario() async {
  // 1️⃣ Obtener coordenadas actuales
  final coords = await ubicacion.coordenadasUser();

  if (coords != null) {
    // 2️⃣ Obtener dirección legible (solo si se necesita)
    final direccion = await ubicacion.obtenerDireccionDesdeCoordenadas(
      coords['lat']!,
      coords['lng']!,
    );

    print('📍 Coordenadas: ${coords['lat']}, ${coords['lng']}');
    print('🏠 Dirección: $direccion');
  } else {
    print('❌ No se pudo determinar la ubicación.');
  }
}
...
onPressed: () async {
    await mostrarUbicacionUsuario();
  }
*/
}
