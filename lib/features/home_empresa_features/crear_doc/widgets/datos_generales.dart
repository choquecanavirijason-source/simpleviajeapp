import 'package:flutter/material.dart';
import 'package:buses2/shared/widgets/cajas/caja_contenedora/caja_contenedora.dart';
import 'package:buses2/shared/widgets/inputs/input_text.dart';

class DatosGenerales extends StatelessWidget {
  final TextEditingController nombreBtnCtrl;
  final TextEditingController subtituloBtnCtrl;
  final TextEditingController tituloDocCtrl;

  const DatosGenerales({
    super.key,
    required this.nombreBtnCtrl,
    required this.subtituloBtnCtrl,
    required this.tituloDocCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return CajaContenedora(
      titulo: 'Datos Generales',
      iconoTitulo: Icons.local_taxi,
      tituloAlign: TituloAlign.center,
      iconoDerecha: Icons.local_taxi,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextInput2(
            controller: nombreBtnCtrl,
            label: 'Nombre del Botón',
            placeholder: 'Ej: Carnet de Conducir',
            prefixIcon: Icons.local_taxi,
            validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 10),
          TextInput2(
            controller: subtituloBtnCtrl,
            label: 'Subtítulo del Botón',
            placeholder: 'Ej: Válido hasta 2026',
            prefixIcon: Icons.subtitles,
            validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 10),
          TextInput2(
            controller: tituloDocCtrl,
            label: 'Título del Documento',
            placeholder: 'Ej: Carnet de Conducir',
            prefixIcon: Icons.title,
            validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
          ),
        ],
      ),
    );
  }
}
