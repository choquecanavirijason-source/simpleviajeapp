// lib/features/home_empresa_features/servicios/page/widgets/modal_inferior_departamentos.dart
// Utilidad para mostrar un modal inferior con la lista de departamentos.
// Incluye un caché simple en memoria para evitar lecturas repetidas.
//
// Uso:
// final seleccionado = await mostrarPickerDepartamentos(
//   context: context,
//   fetchDepartamentos: _traerDepartamentos, // tu función que devuelve Future<List<String>>
// );
// if (seleccionado != null && context.mounted) {
//   setState(() => _departamentoSeleccionado = seleccionado);
// }

import 'package:flutter/material.dart';

// Caché en memoria (a nivel de librería)
List<String> _cacheDepartamentos = [];

// Permite limpiar el caché manualmente si fuese necesario
void limpiarCacheDepartamentos() {
  _cacheDepartamentos = [];
}

/// Muestra un bottom sheet para seleccionar un departamento.
/// - Si hay datos en caché, los usa; si no, llama a [fetchDepartamentos] y guarda en caché.
/// - Devuelve el departamento seleccionado o null si se cancela.
Future<String?> mostrarPickerDepartamentos({
  required BuildContext context,
  required Future<List<String>> Function() fetchDepartamentos,
  String emptyMessage = 'No hay departamentos disponibles',
}) async {
  // 1) Usa caché si ya existe; caso contrario, trae y cachea
  final departamentos = _cacheDepartamentos.isNotEmpty
      ? _cacheDepartamentos
      : await fetchDepartamentos();
  if (_cacheDepartamentos.isEmpty) _cacheDepartamentos = departamentos;

  // 2) Si no hay data, avisa y retorna
  if (departamentos.isEmpty) {
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
        itemCount: departamentos.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final item = departamentos[i];
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
