/// 📦 Archivo centralizado para tokens y API keys.
/// Reemplaza los valores con tus propias keys. Nunca subas keys reales al repo.
/// Usa un archivo .env local (excluido del repo) o un gestor seguro en producción.
class ApiKeys {
  // 🔹 MAPBOX — reemplaza con tu token de https://account.mapbox.com
  static const String mapbox = 'TU_MAPBOX_TOKEN_AQUI';

  // 🔹 GOOGLE MAPS — reemplaza con tu key de https://console.cloud.google.com
  static const String googleMaps = 'TU_GOOGLE_MAPS_KEY_AQUI';

  // 🔹 Otros servicios (ejemplo)
}

/* Ejemplo de uso: [ApiKeys.mapbox] // .mapbox | .googleMaps
import 'package:buses2/core/services/config/api_keys.dart';
...
  final url = Uri.parse(
    'https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json?access_token=${ApiKeys.mapbox}&language=es',
  );
*/
