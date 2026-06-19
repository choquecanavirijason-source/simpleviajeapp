import 'package:flutter/material.dart';
import 'package:buses2/shared/widgets/app_bar/app_bar.dart';
import 'package:buses2/shared/widgets/cajas/caja_contenedora/caja_contenedora.dart';
import 'package:buses2/shared/widgets/inputs/input_text.dart';
import 'package:buses2/shared/widgets/botones/boton.dart';
import 'package:buses2/shared/widgets/cajas/caja_boton/caja_boton.dart';
import 'package:buses2/shared/widgets/botones/btn_fijo_abajo.dart';
import 'package:buses2/shared/utils/generar_widgets.dart';
import 'widgets/datos_generales.dart';
import 'widgets/pantalla_celular.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:buses2/shared/widgets/overlays/cargando.dart';
import 'package:buses2/shared/widgets/notificacion/notificacion.dart';
import 'package:buses2/shared/utils/limpiar_inputs.dart';
import 'package:buses2/shared/services/save_traer_firebase/escrituras/doc.dart';
import 'package:buses2/shared/services/save_traer_firebase/escrituras/n+1.dart';

class CrearDocPage extends StatefulWidget {
  const CrearDocPage({super.key});

  @override
  State<CrearDocPage> createState() => _CrearDocPageState();
}

class _CrearDocPageState extends State<CrearDocPage> {
  final List<TextEditingController> _camposControllers = [];
  final List<TextEditingController> _subirFotosControllers = [];

  // NUEVO: ids estables + contadores
  final List<String> _campoIds = [];
  final List<String> _fileIds = [];
  int _campoSeq = 0;
  int _fileSeq = 0;

  final _formKey = GlobalKey<FormState>();

  // ✅ Controladores separados para cada campo
  final _nombreBtnCtrl = TextEditingController();
  final _subtituloBtnCtrl = TextEditingController();
  final _tituloDocCtrl = TextEditingController();

  bool _guardando = false;

  @override
  void initState() {
    super.initState();

    // Cuando cambie el título del documento → refresca
    _tituloDocCtrl.addListener(() {
      setState(() {});
    });

    // Cuando cambie el nombre del botón → refresca
    _nombreBtnCtrl.addListener(() {
      setState(() {});
    });

    // Cuando cambie el subtítulo → refresca
    _subtituloBtnCtrl.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    // ✅ Liberar los controladores
    _nombreBtnCtrl.dispose();
    _subtituloBtnCtrl.dispose();
    _tituloDocCtrl.dispose();

    // NUEVO: dinámicos
    for (final c in _camposControllers) c.dispose();
    for (final c in _subirFotosControllers) c.dispose();

    super.dispose();
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    // Construir mapas por id para campos dinámicos
    final Map<String, dynamic> camposTextoMap = {};
    for (var i = 0; i < _camposControllers.length; i++) {
      final id = _campoIds[i];
      final etiqueta = _camposControllers[i].text.trim();
      if (etiqueta.isEmpty) continue;
      camposTextoMap[id] = {'etiqueta': etiqueta, 'tipo': 'texto', 'orden': i};
    }

    final Map<String, dynamic> camposArchivoMap = {};
    for (var i = 0; i < _subirFotosControllers.length; i++) {
      final id = _fileIds[i];
      final etiqueta = _subirFotosControllers[i].text.trim();
      if (etiqueta.isEmpty) continue;
      camposArchivoMap[id] = {
        'etiqueta': etiqueta,
        'tipo': 'archivo',
        'orden': i,
      };
    }

    // 👇 Mostrar overlay ANTES de la operación async
    Cargando.show(context, message: 'Guardando...');

    bool ok = false;
    Object? errorGuardado;

    try {
      // 2) Si NMasUno.resolver usa rutas con placeholders, pásale reglas
      final nombreGenerado = await NMasUno.resolver(
        //doc_1
        absoluteDocPath: 'empresas/mujeresalvolante',
        nombreMapContador: 'documentos', // 👈 map anidado
        nombreCampoContador: 'contadorDocumentos',
      );
      await DocSets.set(
        absoluteDocPath: ['empresas/mujeresalvolante'],
        nombreMap: ['documentos-$nombreGenerado'],
        data: [
          {
            'nombreDoc': nombreGenerado,
            'nombreBtn': _nombreBtnCtrl.text.trim(),
            'subtituloBtn': _subtituloBtnCtrl.text.trim(),
            'tituloDoc': _tituloDocCtrl.text.trim(),
            'camposTexto': camposTextoMap,
            'camposArchivo': camposArchivoMap,
            'orden': int.parse(nombreGenerado.split('_').last),
          },
        ],
      );

      ok = true;
    } catch (e) {
      errorGuardado = e;
      print("🔴 Error al guardar: $errorGuardado");
    } finally {
      try {
        Cargando.hide(); //
      } catch (_) {
        // por si hide poppea cuando no hay diálogo
      }
    }

    if (!mounted) return;

    if (ok) {
      notificacion(
        context,
        title: 'Guardado exitoso',
        seconds: 6,
        icon: Icons.check_rounded,
        color: Colors.green,
      );

      clearFormInputs(
        formKey: _formKey,
        fixed: [_nombreBtnCtrl, _subtituloBtnCtrl, _tituloDocCtrl],
        dynamicLists: [_camposControllers, _subirFotosControllers],
        disposeDynamic: true,
      );
    } else {
      notificacion(
        context,
        title: 'Error al guardar',
        // Si quieres mostrar el mensaje:
        // subtitle: '$errorGuardado',
        seconds: 6,
        icon: Icons.error_rounded,
        color: Colors.red,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    //return Scaffold(
    return ScaffoldConBottom(
      appBar: AppBar1(
        titulo: 'Crear documento',
        titleSize: TitleSize.big,
        leftAction: LeftAction.back,
        iconoIzquierda: Icons.arrow_back,
        iconoDerecha: Icons.upload_file,
        onTapDerecha: () {
          Modular.to.pushNamed('/ver-documento');
        },
      ),
      //scrollBody: true, // 👈 activa scroll
      body: Form(
        key: _formKey,
        child: ListView(
          clipBehavior: Clip.none, // 👈 esto es lo que evita el corte
          padding: const EdgeInsets.all(16), // padding global
          children: [
            // ================== Caja 1 ==================
            DatosGenerales(
              nombreBtnCtrl: _nombreBtnCtrl,
              subtituloBtnCtrl: _subtituloBtnCtrl,
              tituloDocCtrl: _tituloDocCtrl,
            ),

            const SizedBox(height: 10),

            // ================== Caja 2 ==================
            CajaContenedora(
              titulo: 'Campos de Datos',
              iconoTitulo: Icons.local_taxi,
              tituloAlign: TituloAlign.center,
              iconoDerecha: Icons.local_taxi,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 👇 Aquí se pintan todos los campos creados
                  ...GenerarWidgets.generar(
                    cantidad: _camposControllers.length,
                    builder: (i) {
                      final controller = _camposControllers[i];
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
                  Boton1(
                    label: 'Crear Campo',
                    color: BotonColor.color2,
                    borde: BotonBorde.borde1,
                    iconoIzquierdo: Icons.upload_file,
                    iconoDerecho: Icons.upload_file,
                    onPressed: () {
                      setState(() {
                        _camposControllers.add(TextEditingController());
                        _campoIds.add(
                          'campo_${_campoSeq.toString().padLeft(3, '0')}',
                        );
                        _campoSeq++;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // ================== Caja 3 ==================
            CajaContenedora(
              titulo: 'Campos de Archivos',
              iconoTitulo: Icons.local_taxi,
              tituloAlign: TituloAlign.center,
              iconoDerecha: Icons.local_taxi,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...GenerarWidgets.generar(
                    cantidad: _subirFotosControllers.length,
                    builder: (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextInput2(
                          // Cualquier widget
                          controller: _subirFotosControllers[i],
                          label: 'Campo ${i + 1}',
                          placeholder: 'Ingresa valor',
                          prefixIcon: Icons.text_fields,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Boton1(
                    label: 'Crear Campo de Archivo',
                    color: BotonColor.color2,
                    borde: BotonBorde.borde1,
                    iconoIzquierdo: Icons.upload_file,
                    iconoDerecho: Icons.upload_file,
                    onPressed: () {
                      setState(() {
                        _subirFotosControllers.add(TextEditingController());
                        _fileIds.add(
                          'file_${_fileSeq.toString().padLeft(3, '0')}',
                        );
                        _fileSeq++;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: Colors.grey.shade400,
                    thickness: 1.5,
                    endIndent: 10,
                  ),
                ),
                Text(
                  "Vista previa",
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: Colors.grey.shade400,
                    thickness: 1.5,
                    indent: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // ================== Vista previa del botón ==================
            CajaBoton(
              title: _nombreBtnCtrl.text.isEmpty
                  ? 'Ttitulo Boton'
                  : _nombreBtnCtrl.text,
              subtitle: _subtituloBtnCtrl.text.isEmpty
                  ? 'Descripcion'
                  : _subtituloBtnCtrl.text,
              rightIcon: Icons.check_circle,
              rightIconColor: Colors.green,
              textAlign: TextAlign.start,
              columnAlignment: CrossAxisAlignment.start,
              //estado: "Pendiente o en revisión",
              onTap: () {},
            ),
            const SizedBox(height: 20),
            // ================== Simulación del Celular ==================
            PantallaCelular(
              tituloDocCtrl: _tituloDocCtrl,
              camposControllers: _camposControllers,
              subirFotosControllers: _subirFotosControllers,
              onFileChanged: () {
                setState(() {}); // refresca cuando se suba un archivo
              },
            ),
          ],
        ),
      ),
      btnFijoAbajo: Boton1(
        label: 'Crear Documento',
        color: BotonColor.color1,
        borde: BotonBorde.borde1,
        iconoIzquierdo: Icons.save,
        iconoDerecho: Icons.save,
        onPressed: _guardar,
      ),
    );
  }
}
