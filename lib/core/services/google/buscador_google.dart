import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'coordenadas_place_id.dart';
import 'package:buses2/core/utils/particionarDireccion.dart';

class GooglePlacesService {
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/place/autocomplete/json';

  // 🔹 Debouncer interno (500ms para respuesta más rápida)
  Timer? _debounceTimer;
  final int debounceMilliseconds = 500;

  Future<List<Map<String, String>>> buscarLugares(
    String input, {
    String countryCode = 'bo',
    double? lat,
    double? lng,
    int radiusMeters = 50000, // 50km por defecto
  }) async {
    _debounceTimer?.cancel();

    // Esperamos 500ms desde la última letra escrita
    final completer = Completer<List<Map<String, String>>>();
    _debounceTimer = Timer(Duration(milliseconds: debounceMilliseconds), () async {
      if (input.isEmpty) {
        print('🔵 GooglePlaces: Input vacío, retornando lista vacía');
        completer.complete([]);
        return;
      }

      final apiKey = dotenv.env['GOOGLE_API_KEY']?.trim();
      if (apiKey == null || apiKey.isEmpty) {
        debugPrint('❌ GooglePlaces: GOOGLE_API_KEY no encontrado en .env');
        completer.complete([]);
        return;
      }

      print('🔍 GooglePlaces: Buscando "$input"...');

      try {
        // Construir URL con parámetros mejorados para búsqueda más amplia
        // Si hay ubicación, agregar location y radius para priorizar resultados cercanos
        String urlString =
            '$_baseUrl?input=${Uri.encodeQueryComponent(input)}&key=$apiKey&language=es&components=country:$countryCode';

        if (lat != null && lng != null) {
          urlString += '&location=$lat,$lng&radius=$radiusMeters';
          print(
            '📍 GooglePlaces: Usando ubicación ($lat, $lng) con radio ${radiusMeters}m',
          );
        }

        final Uri url = Uri.parse(urlString);

        final safeUrl = url.toString().replaceAll(
          RegExp(r'key=[^&]+'),
          'key=***',
        );
        print('🌐 GooglePlaces: URL: $safeUrl');

        final response = await http.get(url);

        print('📡 GooglePlaces: Status code: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final status = data['status'];
          print('✅ GooglePlaces: API Status: $status');

          if (status != 'OK' && status != 'ZERO_RESULTS') {
            print('❌ GooglePlaces: Error de API: $status');
            if (data['error_message'] != null) {
              print('❌ GooglePlaces: Mensaje: ${data['error_message']}');
            }
            completer.complete([]);
            return;
          }

          final List predictions = data['predictions'] ?? [];
          print(
            '📊 GooglePlaces: ${predictions.length} resultados encontrados',
          );

          // 🔹 Procesamos los resultados y separamos título / subtítulo
          final resultados = predictions.map<Map<String, String>>((p) {
            final description = p['description'].toString();
            final partes = direccionPorPartes(description);
            return {
              'titulo': partes['titulo']!,
              'subtitulo': partes['subtitulo']!,
              'place_id':
                  p['place_id'] ??
                  '', // Guardamos el place_id, para optimizar búsquedas futuras
            };
          }).toList();

          print('✅ GooglePlaces: ${resultados.length} lugares procesados');
          for (var i = 0; i < resultados.length && i < 3; i++) {
            print(
              '  📍 ${i + 1}. ${resultados[i]['titulo']} - ${resultados[i]['subtitulo']}',
            );
          }

          completer.complete(resultados);
        } else {
          print('❌ GooglePlaces: Error HTTP ${response.statusCode}');
          print('❌ GooglePlaces: Body: ${response.body}');
          completer.complete([]);
        }
      } catch (e, stackTrace) {
        print('⚠️ GooglePlaces: Error al buscar lugares: $e');
        print('⚠️ GooglePlaces: StackTrace: $stackTrace');
        completer.complete([]);
      }
    });

    return completer.future;
  }

  /// 🔹 Método auxiliar:
  /// Usa el `CoordenadasPlaceId` para obtener lat/lng del `place_id`.
  Future<Map<String, double>?> obtenerCoordenadas(String placeId) async {
    final coordenadasService = CoordenadasPlaceId();
    return await coordenadasService.obtenerCoordenadas(placeId);
  }

  /// 🔹 Lugares populares cerca de (lat, lng) usando Google Places "Nearby
  /// Search" con `rankby=prominence`.
  ///
  /// Devuelve una lista de hasta [maxResultados] puntos con:
  ///   - 'titulo'    → nombre del lugar
  ///   - 'subtitulo' → dirección corta (vicinity)
  ///   - 'place_id'  → id de Google Places
  ///   - 'lat' / 'lng' (double) → coordenadas exactas del lugar
  ///   - 'tipo'      → primer tipo reportado por Google (ej. 'tourist_attraction')
  ///
  /// Si falla la API o no hay resultados, devuelve `[]`.
  Future<List<Map<String, dynamic>>> obtenerLugaresPopulares({
    required double lat,
    required double lng,
    int radiusMeters = 8000,
    int maxResultados = 6,
    String type = 'tourist_attraction',
  }) async {
    final apiKey = dotenv.env['GOOGLE_API_KEY']?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('❌ GooglePlaces(populares): GOOGLE_API_KEY no encontrado');
      return [];
    }

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
      '?location=$lat,$lng'
      '&radius=$radiusMeters'
      '&type=$type'
      '&language=es'
      '&key=$apiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) {
        debugPrint(
          '❌ GooglePlaces(populares): HTTP ${response.statusCode}',
        );
        return [];
      }
      final data = json.decode(response.body);
      final status = data['status'];
      if (status != 'OK' && status != 'ZERO_RESULTS') {
        debugPrint('❌ GooglePlaces(populares): status=$status');
        return [];
      }

      final List results = data['results'] ?? [];
      return results.take(maxResultados).map<Map<String, dynamic>>((r) {
        final loc = r['geometry']?['location'];
        final types = (r['types'] is List) ? r['types'] as List : const [];
        return {
          'titulo': (r['name'] ?? '').toString(),
          'subtitulo': (r['vicinity'] ?? '').toString(),
          'place_id': (r['place_id'] ?? '').toString(),
          'lat': (loc?['lat'] as num?)?.toDouble(),
          'lng': (loc?['lng'] as num?)?.toDouble(),
          'tipo': types.isNotEmpty ? types.first.toString() : '',
        };
      }).toList();
    } catch (e) {
      debugPrint('⚠️ GooglePlaces(populares): $e');
      return [];
    }
  }
}

/// Espera que el usuario deje de escribir (por defecto 2 segundos)
class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({this.milliseconds = 2000}); // ⏱ Espera 2 segundos por defecto

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  /// Cancela el temporizador manualmente si se necesita.
  void cancel() {
    _timer?.cancel();
  }
}

/*
final direccion = 'Avenida Daniel Salamanca 675, Cochabamba, Departamento de Cochabamba, Bolivia';
final partes = splitDireccionDetallada(direccion);

print('🧭 Título: ${partes['titulo']}');
print('🏙️ Subtítulo: ${partes['subtitulo']}');
print('📍 Calle: ${partes['calle']}');
print('🏢 Ciudad: ${partes['ciudad']}');
print('🗺️ Departamento: ${partes['departamento']}');
print('🌎 País: ${partes['pais']}');

// EN CONSOLA
🧭 Título: Avenida Daniel Salamanca 675
🏙️ Subtítulo: Cochabamba, Departamento de Cochabamba, Bolivia
📍 Calle: Avenida Daniel Salamanca 675
🏢 Ciudad: Cochabamba
🗺️ Departamento: Departamento de Cochabamba
🌎 País: Bolivia
*/

/* Ejemplo de uso: Solo consola
import 'package:buses2/core/services/google/buscador_google.dart';
...
final GooglePlacesService _googleService = GooglePlacesService();
...
onChanged: (valor) async {
  final resultados =
      await _googleService.buscarLugares(valor);

  print('🗺️ Resultados de Google Places:');
  for (final r in resultados) {
    print('👉 ${r['titulo']} - ${r['subtitulo']} (ID: ${r['place_id']})');
  }
},
*/

/* Ejemplo de uso: UI
import 'package:buses2/shared/widgets/cajas/sugerencias_busqueda/sugerencias_busqueda.dart';
import 'package:buses2/core/services/google/buscador_google.dart';
...
final GooglePlacesService _googleService = GooglePlacesService();
List<Map<String, String>> _resultadosBusqueda = [];
bool _cargando = false;
...
onChanged: (valor) async {
  setModalState(() => _cargando = true);

  final resultados =
      await _googleService.buscarLugares(valor);

  print('🗺️ Resultados de Google Places:');
  for (final r in resultados) {
    print('👉 ${r['titulo']} - ${r['subtitulo']} (ID: ${r['place_id']})');
  }

  setModalState(() {
    _resultadosBusqueda = resultados;
    _cargando = false;
  });
},
...
// 🔹 Lista dinámica de resultados
if (_cargando)
  const Center(child: CircularProgressIndicator())
else if (_resultadosBusqueda.isEmpty)
  const Text('Sin resultados')
else
  SugerenciasBusqueda(
    controller: _destinoController,
    onUpdate: (r) async {
      final placeId = r.placeId ?? '';
      final coordenadas = await _googleService.obtenerCoordenadas(placeId);

      if (coordenadas != null) {
        print('📍 Coordenadas DESTINO: ${coordenadas['lat']}, ${coordenadas['lng']}');
      }
    },
    items: _resultadosBusqueda
        .map(
          (r) => SugerenciaEntry(
            titulo: r['titulo'] ?? '',
            subtitulo: r['subtitulo'] ?? '',
            placeId: r['place_id'],
            leadingIcon: Icons.location_on,
            trailingIcon: Icons.north_east,
          ),
        )
        .toList(),
    mostrarSubtitulo: true,
    dense: false,
    showDivider: true,
    iconSize: 24,
    itemVerticalPadding: 10,
    leadingGap: 10,
    trailingGap: 6,
    defaultLeadingColor: Colors.red,
  ),
*/
