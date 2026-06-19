import 'package:flutter/material.dart';

/// Modelo genérico para una opción del modal inferior.
/// Solo define el ícono, el texto y una acción opcional.
class ModalOpcion {
  final IconData icono;
  final String titulo;
  final VoidCallback? onTap;

  ModalOpcion({required this.icono, required this.titulo, this.onTap});
}

class ModalInferior {
  /// Muestra un modal inferior genérico con opciones.
  /// [titulo] es el encabezado del modal.
  static Future<ModalOpcion?> mostrar(
    BuildContext context, {
    required List<ModalOpcion> opciones,
    String titulo = 'Selecciona una opción',
  }) {
    return showModalBottomSheet<ModalOpcion>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Divider(height: 1, thickness: 1),

                ListTileTheme(
                  data: const ListTileThemeData(
                    dense: true,
                    minLeadingWidth: 0,
                    horizontalTitleGap: 8,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: opciones.map((opcion) {
                      return ListTile(
                        leading: Icon(opcion.icono, size: 28),
                        title: Text(
                          opcion.titulo,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        minVerticalPadding: 0,
                        visualDensity: const VisualDensity(
                          vertical: 0,
                          horizontal: 2,
                        ),
                        onTap: () {
                          Navigator.pop(ctx, opcion);
                          opcion.onTap?.call();
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/* Uso:
String? _valorSeleccionado;
...
CajaInput(
  texto: _valorSeleccionado ?? 'Selecciona una Empresa',
  icono: Icons.chevron_right,
  onTap: () async {
    final seleccion = await ModalInferior.mostrar(
      context,
      titulo: 'Selecciona una Empresa', // aquí puedes poner "Conductor", "Taxi", etc.
      opciones: [
        ModalOpcion(
          icono: Icons.business,
          titulo: 'Empresa A',
          onTap: () => debugPrint('Acción Empresa A'),
        ),
        ModalOpcion(
          icono: Icons.business,
          titulo: 'Empresa B',
          onTap: () => debugPrint('Acción Empresa B'),
        ),
        ModalOpcion(
          icono: Icons.business,
          titulo: 'Empresa C',
          onTap: () => debugPrint('Abrir perfil Empresa C'),
        ),
      ],
    );

    if (!mounted) return;
    if (seleccion != null) {
      setState(() => _valorSeleccionado = seleccion.titulo);
      debugPrint('Seleccionada ${seleccion.titulo}');
    }
  },
),         
*/
