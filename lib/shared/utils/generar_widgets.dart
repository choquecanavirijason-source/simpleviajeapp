import 'package:flutter/material.dart';

class GenerarWidgets {
  /// Genera una lista de widgets dinámicos a partir de un builder genérico.
  ///
  /// [cantidad] → cuántos widgets generar.
  /// [builder] → función que construye cada widget recibiendo el índice.
  static List<Widget> generar({
    required int cantidad,
    required Widget Function(int index) builder,
  }) {
    return List.generate(cantidad, (index) => builder(index));
  }
}

/*  EJEMPLO DE USO:
 final List<TextEditingController> _camposControllers = [];
  ...
  onPressed: () {
    setState(() {
      _camposControllers.add(TextEditingController());
    });
  },
  ...GenerarWidgets.generar(
    cantidad: _camposControllers.length,
    builder: (i) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextInput2( // Cualquier widget
          controller: _camposControllers[i],
          label: 'Campo ${i + 1}',
          placeholder: 'Ingresa valor',
          prefixIcon: Icons.text_fields,
        ),
      );
    },
  ),
*/
