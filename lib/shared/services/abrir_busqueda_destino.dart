import 'package:flutter/material.dart';
import 'package:buses2/core/services/ubicacion_usuario/ubicacion_user.dart';
import 'package:buses2/core/utils/particionarDireccion.dart';
import 'package:buses2/features/home/widgets/modal_inferior_AyB.dart';

/// Abre directamente el modal "¿A dónde vamos?" (selección de origen y
/// destino), igual que al tocar la barra de búsqueda del home — sin
/// depender de que esa pantalla esté montada ni de navegar hacia ella.
Future<void> abrirBusquedaDestino(
  BuildContext context,
  TextEditingController destinoController,
) async {
  final ubicacion = UbicacionUsuario();

  double? lat;
  double? lng;
  String calle = '';
  String ciudad = '';
  String departamento = '';
  String pais = '';

  final coords = await ubicacion.coordenadasUser();
  if (coords != null) {
    final direccionCompleta = await ubicacion.obtenerDireccionDesdeCoordenadas(
      coords['lat']!,
      coords['lng']!,
    );
    if (direccionCompleta != null) {
      final partes = direccionPorPartes(direccionCompleta);
      lat = coords['lat'];
      lng = coords['lng'];
      calle = partes['calle'] ?? '';
      ciudad = partes['ciudad'] ?? '';
      departamento = partes['departamento'] ?? '';
      pais = partes['pais'] ?? '';
    }
  }

  if (!context.mounted) return;
  await ModalInferiorAyB.mostrar(
    context: context,
    destinoController: destinoController,
    lat: lat,
    lng: lng,
    calle: calle,
    ciudad: ciudad,
    pais: pais,
    departamento: departamento,
  );
}
