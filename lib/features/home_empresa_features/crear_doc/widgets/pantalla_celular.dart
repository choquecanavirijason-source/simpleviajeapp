import 'package:flutter/material.dart';
import 'package:buses2/shared/widgets/app_bar/app_bar.dart';
import 'package:buses2/shared/widgets/inputs/input_text.dart';
import 'package:buses2/shared/widgets/cajas/caja_subir_foto/box_subir_foto.dart';
import 'package:buses2/shared/utils/generar_widgets.dart';

class PantallaCelular extends StatelessWidget {
  final TextEditingController tituloDocCtrl;
  final List<TextEditingController> camposControllers;
  final List<TextEditingController> subirFotosControllers;
  final VoidCallback onFileChanged; // callback para cuando cambie un archivo

  const PantallaCelular({
    super.key,
    required this.tituloDocCtrl,
    required this.camposControllers,
    required this.subirFotosControllers,
    required this.onFileChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 250, // ancho fijo como un celular
        height: 500, // alto fijo como un celular
        decoration: BoxDecoration(
          color: Colors.white, // Color pantalla
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.black87, width: 6),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: Column(
            children: [
              // 👉 AppBar simulado
              SizedBox(
                height: 56,
                child: AppBar1(
                  titulo: tituloDocCtrl.text.isEmpty
                      ? 'Vista previa'
                      : tituloDocCtrl.text,
                  titleSize: TitleSize.small,
                  leftAction: LeftAction.back,
                  iconoIzquierda: Icons.arrow_back,
                  iconoDerecha: Icons.more_vert,
                ),
              ),

              // 👉 Contenido simulado
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const SizedBox(height: 5),

                    // Campos dinámicos
                    ...GenerarWidgets.generar(
                      cantidad: camposControllers.length,
                      builder: (i) {
                        final controller = camposControllers[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ValueListenableBuilder<TextEditingValue>(
                            valueListenable: controller,
                            builder: (context, value, _) {
                              return TextInput2(
                                controller: controller,
                                label: value.text.isEmpty
                                    ? 'Nombre del campo'
                                    : value.text,
                                placeholder: value.text.isEmpty
                                    ? 'Nombre del campo'
                                    : value.text,
                                prefixIcon: Icons.text_fields,
                              );
                            },
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 10),

                    // Campos de archivos
                    ...GenerarWidgets.generar(
                      cantidad: subirFotosControllers.length,
                      builder: (i) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ValueListenableBuilder<TextEditingValue>(
                            valueListenable: subirFotosControllers[i],
                            builder: (context, value, _) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    value.text.isEmpty
                                        ? 'Nombre del campo de archivo'
                                        : value.text,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FileBox(
                                      icon: Icons.image,
                                      label: 'Subir Foto',
                                      //file: _selectedFile, // archivo local
                                      //imageUrl: _imageUrl, // URL remota (opcional)
                                      onChanged: (file) {
                                        /*
                                        setState(() {
                                          //_selectedFile = file; // Actualiza el estado con el nuevo archivo
                                        });
                                        */
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
