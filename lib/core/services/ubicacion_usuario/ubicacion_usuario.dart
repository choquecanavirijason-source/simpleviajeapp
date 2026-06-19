// import 'package:buses2/core/services/ubicacion_usuario/ubicacion_usuario.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:buses2/core/services/config/api_keys.dart';

class UbicacionUsuario {
  final String _accessToken = ApiKeys.mapbox;

  // Convertir coordenadas a dirección legible TEXTO
  Future<Map<String, String>?> obtenerDireccionLegible(
    double lat,
    double lng,
  ) async {
    print('🌐 Solicitando dirección legible para: $lat, $lng');

    final url = Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json?access_token=$_accessToken&language=es',
    );

    try {
      final response = await http.get(url);
      print('🛰️ Respuesta de Mapbox: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final placeName = data['features'][0]['place_name'];

        // Dividir la dirección por comas y tomar solo la primera parte
        final partes = placeName
            .toString()
            .split(',')
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .toList();
        final direccionCorta = partes.isNotEmpty ? partes.first : placeName;

        final String pais = partes.isNotEmpty ? partes.last : 'Desconocido';

        // Buscar departamento (region)
        String? departamento;

        // Obtener departamento de la direccion completa
        for (var parte in partes) {
          if (parte.contains('Departamento de')) {
            departamento = parte.replaceAll('Departamento de', '').trim();
            break;
          }
          if (parte.contains('Provincia de')) {
            departamento = parte.replaceAll('Provincia de', '').trim();
            break;
          }
        }
        print(
          '✅ Dirección legible obtenida: $direccionCorta, Departamento: ${departamento ?? "Desconocido"}, País: $pais',
        );

        return {
          'direccion': direccionCorta,
          'departamento': departamento ?? 'Desconocido',
          'pais': pais,
        };
      } else {
        print('❌ Error en geocodificación inversa: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error al hacer petición a Mapbox: $e');
    }
    return null;
  }

  /// Lee coordenadas y dirección guardadas en SharedPreferences.
  Future<Map<String, dynamic>?> obtenerCoordenadasGuardadas() async {
    print('📦 Buscando coordenadas guardadas...');
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('lat_guardada');
    final lng = prefs.getDouble('lng_guardada');
    final direccion = prefs.getString('direccion_guardada');
    final departamento = prefs.getString('departamento_guardado');
    final pais = prefs.getString('pais_guardado');

    if (lat != null && lng != null) {
      print('✅ Coordenadas encontradas: $lat, $lng');
      final pos = Position(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
      return {
        'position': pos,
        'direccion': direccion ?? 'Sin dirección guardada',
        'departamento': departamento,
        'pais': pais,
      };
    }
    print('⚠️ No hay coordenadas guardadas');
    return null;
  }

  // Obtener nuevas coordenadas cada 40 metros.
  Future<Map<String, dynamic>?> obtenerUbicacion40mtrs({
    double umbralDistancia = 40.0,
  }) async {
    print('📍 Calculando ubicación óptima con umbral $umbralDistancia metros');
    final datosGuardados = await obtenerCoordenadasGuardadas();
    Position? nuevaPosicion;
    String? direccion;

    if (datosGuardados != null) {
      final posGuardada = datosGuardados['position'] as Position;
      final posicionActual = await obtenerUbicacionActual();

      if (posicionActual != null) {
        final distancia = Geolocator.distanceBetween(
          posGuardada.latitude,
          posGuardada.longitude,
          posicionActual.latitude,
          posicionActual.longitude,
        );

        print(
          '📏 Distancia entre posiciones: ${distancia.toStringAsFixed(2)} m',
        );

        if (distancia < umbralDistancia) {
          print('✅ Distancia menor al umbral. Usando coordenadas guardadas.');
          return datosGuardados;
        } else {
          print('🔄 Distancia mayor al umbral. Se actualizará la ubicación.');
          nuevaPosicion = posicionActual;
        }
      } else {
        print('⚠️ No se pudo obtener nueva posición. Usando guardada.');
        return datosGuardados;
      }
    } else {
      print('🆕 No hay coordenadas previas. Obteniendo nuevas...');
      nuevaPosicion = await obtenerUbicacionActual();
    }

    if (nuevaPosicion != null) {
      final info = await obtenerDireccionLegible(
        nuevaPosicion.latitude,
        nuevaPosicion.longitude,
      );
      direccion = info?['direccion'];

      await guardarCoordenadas(nuevaPosicion, info: info);

      return {
        'position': nuevaPosicion,
        'direccion': direccion ?? 'Sin dirección',
        'departamento': info?['departamento'],
        'pais': info?['pais'],
      };
    }
    print('❌ No se pudo obtener ubicación óptima');
    return null;
  }
  /* Ejemplo de uso:
  - crea la instancia:
  final ubicacion = UbicacionUsuario();
  - Llama la funcion:
  final resultado = await ubicacion.obtenerUbicacion40mtrs();
  print('📍 Resultado: $resultado');

    Ejemplo mas completo:
  onPressed: () async {
    final resultado = await ubicacionUsuario.obtenerUbicacion40mtrs();

    if (resultado != null) {
      print('📍 Ubicación óptima: ${resultado['position'].latitude}, ${resultado['position'].longitude}');
      print('📍 Dirección: ${resultado['direccion']}');
      //🡇Cuando se obtiene la Dir... actualiza la UI para que aparesca.
      setState(() {
        direccionGuardada = resultado['direccion'] ?? 'Sin dirección'; // <-- Esto es lo que actualiza el título del AppBar
      });

      Modular.to.pushNamed('/mapa', arguments: {
        'lat': resultado['position'].latitude,
        'lng': resultado['position'].longitude,
        'direccion': resultado['direccion'],
      });
    } else {
      print('❌ No se obtuvo permisos para obtener la ubicacion');
    }
  }

  🔵Recibir la direccion en otra pantalla.
  final nuevaDireccion = args['direccion'] as String?;
  direccionGuardada = nuevaDireccion ?? 'Sin dirección';
  label: direccionGuardada,
  */

  // Obtener la ubicación actual como Position
  Future<Position?> obtenerUbicacionActual() async {
    print('📍 Iniciando obtención de ubicación actual...');
    try {
      bool servicioActivo = await Geolocator.isLocationServiceEnabled();
      print('🛰️ Servicio de ubicación activo: $servicioActivo');
      if (!servicioActivo) {
        print('⚠️ Servicios de ubicación desactivados');
        return null;
      }

      LocationPermission permiso = await Geolocator.checkPermission();
      print('🔐 Permiso actual: $permiso');

      if (permiso == LocationPermission.denied) {
        print('⚠️ Permiso denegado, solicitando...');
        permiso = await Geolocator.requestPermission();
        print('🔐 Permiso después de solicitud: $permiso');

        if (permiso == LocationPermission.denied) {
          print('❌ Permiso de ubicación denegado');
          return null;
        }
      }
      if (permiso == LocationPermission.deniedForever) {
        print('❌ Permiso de ubicación denegado permanentemente');
        return null;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      print(
        '✅ Ubicación obtenida: ${position.latitude}, ${position.longitude}',
      );
      return position;
    } catch (e) {
      print('❌ Error al obtener ubicación: $e');
      return null;
    }
  }

  /// Guarda coordenadas y dirección en SharedPreferences.
  ///
  /// Si ya tienes el resultado de geocodificación inversa, pásalo en `info`
  /// para evitar una petición duplicada a Mapbox.
  Future<void> guardarCoordenadas(
    Position position, {
    Map<String, String>? info,
  }) async {
    print(
      '💾 Guardando coordenadas: ${position.latitude}, ${position.longitude}',
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('lat_guardada', position.latitude);
    await prefs.setDouble('lng_guardada', position.longitude);

    final resolvedInfo =
        info ??
        await obtenerDireccionLegible(position.latitude, position.longitude);
    if (resolvedInfo != null) {
      await prefs.setString('direccion_guardada', resolvedInfo['direccion']!);
      await prefs.setString(
        'departamento_guardado',
        resolvedInfo['departamento']!,
      );
      await prefs.setString('pais_guardado', resolvedInfo['pais']!);
      print('📍 Dirección guardada: ${resolvedInfo['direccion']}');
      print('🏛️ Departamento guardado: ${resolvedInfo['departamento']}');
      print('🌎 País guardado: ${resolvedInfo['pais']}');
    }

    print('Coordenadas guardadas: ${position.latitude}, ${position.longitude}');
  }

  /// Retorna el departamento guardado en SharedPreferences.
  Future<String?> obtenerDepartamentoGuardado() async {
    print('📦 Obteniendo departamento guardado...');
    final prefs = await SharedPreferences.getInstance();
    final depto = prefs.getString('departamento_guardado');
    print('🏛️ Departamento encontrado: ${depto ?? "No guardado"}');
    return depto;
  }

  /// Retorna el país guardado en SharedPreferences.
  Future<String?> obtenerPaisGuardado() async {
    print('📦 Obteniendo país guardado...');
    final prefs = await SharedPreferences.getInstance();
    final pais = prefs.getString('pais_guardado');
    print('🌎 País encontrado: ${pais ?? "No guardado"}');
    return pais;
  }
}
