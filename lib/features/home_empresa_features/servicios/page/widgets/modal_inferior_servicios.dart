// lib/features/home_empresa_features/servicios/page/widgets/modal_inferior_servicios.dart
// Utilidad para mostrar un modal inferior con la lista de servicios.
// Incluye un caché simple en memoria para evitar lecturas repetidas.
//
// Uso:
// final seleccionado = await mostrarPickerServicios(
//   context: context,
//   fetchServicios: _traerServicios, // tu función que devuelve Future<List<String>>
// );
// if (seleccionado != null && context.mounted) {
//   setState(() => _servicioSeleccionado = seleccionado);
// }

import 'package:flutter/material.dart';

// Caché en memoria (a nivel de librería)
List<String> _cacheServicios = [];

// Permite limpiar el caché manualmente si fuese necesario
void limpiarCacheServicios() {
  _cacheServicios = [];
}

/// Muestra un bottom sheet para seleccionar un servicio.
/// - Si hay datos en caché, los usa; si no, llama a [fetchServicios] y guarda en caché.
/// - Devuelve el servicio seleccionado o null si se cancela.
Future<String?> mostrarPickerServicios({
  required BuildContext context,
  required Future<List<String>> Function() fetchServicios,
  String emptyMessage = 'No hay servicios disponibles',
}) async {
  // 1) Usa caché si ya existe; caso contrario, trae y cachea
  final servicios = _cacheServicios.isNotEmpty
      ? _cacheServicios
      : await fetchServicios();
  if (_cacheServicios.isEmpty) _cacheServicios = servicios;

  // 2) Si no hay data, avisa y retorna
  if (servicios.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(emptyMessage)));
    }
    return null;
  }

  // 3) Mostrar Modal
  if (!context.mounted) return null;

  final seleccionado = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: servicios.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final item = servicios[i];
          return ListTile(
            title: Text(item),
            onTap: () => Navigator.of(ctx).pop(item),
          );
        },
      ),
    ),
  );

  return seleccionado;
}
