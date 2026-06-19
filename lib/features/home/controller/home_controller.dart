import 'package:flutter/material.dart';
import 'package:buses2/core/services/ubicacion_usuario/ubicacion_usuario.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeController {
  final TextEditingController locationController = TextEditingController();

  void dispose() {
    locationController.dispose(); // Liberar recursos
  }

  // Borrar ubicacion guardada
  Future<void> borrarUbicacionGuardada() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('lat_guardada');
    await prefs.remove('lng_guardada');
    await prefs.remove('direccion_guardada');
    await prefs.remove('departamento_guardado');
    await prefs.remove('pais_guardado');
  }
}
