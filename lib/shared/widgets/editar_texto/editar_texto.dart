/*
import 'package:buses2/shared/widgets/casillas/casillas.dart';
import 'package:buses2/shared/widgets/modal/modal.dart';
import 'package:buses2/shared/widgets/botones/boton_small.dart';
import 'package:buses2/shared/widgets/inputs/input_text.dart';
...
String _name = 'Nombre del Conductor';

Future<void> _editarNombre() async {
  final _nameCtrl = TextEditingController(text: _name);
  showAppModal(
    context,
    title: 'Editar nombre',
    body: Column(
      children: [
        TextInput2(
          controller: _nameCtrl,
          //label: 'Número de teléfono',
          placeholder: 'Ingresa tu nombre',
          prefixIcon: Icons.person,
          //validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
        ),
      ],
    ),
    showCancel: false, // muestra botón Cancelar
    footerButtons: [
      BotonSmall(
        label: 'Guardar',
        onPressed: () {
          setState(() {
            _name = _nameCtrl.text.trim();
          });
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Guardado')),
          );
        },
      ),
    ],
  );
}
...
Casillas(
  title: 'Nombre',
  subtitle: _name,
  leading: Casillas.blueCircleIcon(Icons.phone), // círculo azul + icono
  trailing: const Icon(Icons.edit, size: 18),
  onTap: _editarNombre,
  showTopDivider: true, // línea arriba
  showBottomDivider: false, // sin línea abajo
),
*/
