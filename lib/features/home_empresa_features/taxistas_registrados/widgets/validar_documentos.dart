import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:buses2/shared/widgets/slider/image_slider.dart';
import 'package:buses2/shared/widgets/inputs/input_display.dart';
import 'package:buses2/shared/widgets/inputs/input_multilinea.dart';
import 'package:buses2/shared/widgets/cajas/caja_estado/selector_estado.dart';
import 'package:buses2/shared/widgets/app_bar/app_bar.dart';
import 'package:buses2/shared/widgets/botones/btn_fijo_abajo.dart';
import 'package:buses2/shared/widgets/botones/boton.dart';
import '../data/estado_taxista.dart';
import 'package:buses2/shared/widgets/etiquetas/etiqueta_estado.dart';

class ValidarDocumentosPage extends StatefulWidget {
  const ValidarDocumentosPage({super.key});

  @override
  State<ValidarDocumentosPage> createState() => _ValidarDocumentosPageState();
}

class _ValidarDocumentosPageState extends State<ValidarDocumentosPage> {
  String _estadoActual = 'en_revision';
  final TextEditingController _notaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarEstadoInicial();
  }

  Future<void> _cargarEstadoInicial() async {
    final args = Modular.args.data as Map?;
    final uidEmpresa = args?['empresa']?.uidPropietario; // o el campo correcto
    final taxistaId = args?['taxista']?.id;
    final docNombre = args?['docNombre'];

    // ✅ Permitir continuar aunque falten datos (usar valores por defecto)
    if (uidEmpresa == null || taxistaId == null || docNombre == null) {
      debugPrint('⚠️ Faltan datos iniciales, usando valores por defecto');
      return;
    }

    final estado = await LeerEstadoTaxistaService.traerEstado(
      taxistaId: taxistaId,
      docNombre: docNombre,
    );

    if (estado != null && mounted) {
      setState(() => _estadoActual = estado);
      debugPrint('🟢 Estado leído de Firebase: $_estadoActual');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 👇 Recuperar argumentos enviados con Modular.to.pushNamed(...)
    final args = Modular.args.data as Map?;
    final taxista = args?['taxista'];
    final empresa = args?['empresa'];
    final documentoPlantilla = args?['documentoPlantilla'];
    final documentoTaxista = args?['documentoTaxista'];
    final documentoEmpresa = args?['documentoEmpresa'] ?? {};
    final docNombre = args?['docNombre'] ?? '';

    // =====================================
    // 🧩 Buscar el documento correspondiente ej: "doc_1", "doc_6", etc.
    // =====================================
    final String docKey =
        documentoTaxista?['id'] ?? documentoTaxista?['key'] ?? '';
    final Map<String, dynamic> docTaxistaMap =
        (taxista?.misDocumentos ?? {}) as Map<String, dynamic>;
    // si no se encuentra, usa el primero disponible o mapa vacío
    final Map<String, dynamic> docTaxista =
        docKey.isNotEmpty && docTaxistaMap.containsKey(docKey)
        ? (docTaxistaMap[docKey] as Map<String, dynamic>)
        : (docTaxistaMap.values.isNotEmpty
              ? (docTaxistaMap.values.first as Map<String, dynamic>)
              : <String, dynamic>{});
    print('🧾 misDocumentos del taxista: ${taxista?.misDocumentos}');

    // ===============================
    // 🖼️ Reunir imágenes del documento
    // ===============================
    final List<String> imagenes = [];
    docTaxista.forEach((key, value) {
      if (key.startsWith('campoArchivo_') &&
          value is String &&
          value.startsWith('http')) {
        imagenes.add(value);
      }
    });
    if (imagenes.isEmpty) {
      imagenes.add('https://via.placeholder.com/800x500?text=Sin+imagen');
    }

    // ===============================
    // 📝 Reunir campos de texto dinámicos
    // ===============================
    final Map<String, String> camposTexto = {};
    documentoTaxista.forEach((key, value) {
      if (key.startsWith('campoTexto_') && value is String) {
        camposTexto[key] = value;
      }
    });

    // Ordenar por número (campoTexto_1, campoTexto_2, ...)
    final sortedKeys = camposTexto.keys.toList()
      ..sort((a, b) {
        final numA = int.tryParse(a.split('_').last) ?? 0;
        final numB = int.tryParse(b.split('_').last) ?? 0;
        return numA.compareTo(numB);
      });

    // ===============================
    // 🎨 UI
    // ===============================
    return ScaffoldConBottom(
      appBar: AppBar1(
        titleSize: TitleSize.big,
        titulo: 'Validar Documento',
        backgroundColor: const Color(0xFFFFFFFF),
        textColor: Colors.black,
        hasShadow: false,
        leftAction: LeftAction.back,
        iconoIzquierda: Icons.arrow_back,
        iconoDerecha: Icons.settings,
        onTapDerecha: () => debugPrint('Ajustes'),
      ),

      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 🔷 Encabezado
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    documentoEmpresa['tituloDoc'] ??
                        'Documento sin título', // ✅ viene de empresa
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Taxista: ${taxista?.nombre ?? "Sin nombre"}',
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  Text(
                    'Empresa: ${empresa?.nombreEmpresa ?? "Sin empresa"}',
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            // 🟨 Selector de estado
            EtiquetaEstado(
              _estadoActual.isNotEmpty ? _estadoActual : 'pendiente',
              opciones: const ['pendiente', 'aprobado', 'rechazado'],
              onEstadoCambiado: (nuevoEstado) {
                setState(() => _estadoActual = nuevoEstado.toLowerCase());
                debugPrint('🟢 Estado seleccionado: $_estadoActual');
              },
            ),

            const SizedBox(height: 12),

            // 🧾 Mostrar el campo solo si el estado es "rechazado"
            if (_estadoActual == 'rechazado') ...[
              Multilinea2(
                controller: _notaController,
                label: 'Detalle del rechazo (opcional)',
                placeholder: 'Ej: La fotografía no es clara...',
                minLines: 1,
                maxLines: 5,
              ),
              const SizedBox(height: 12),
            ],

            // 🖼️ Slider de imágenes del documento
            ImageSlider(
              images: imagenes,
              height: 220,
              showDots: true,
              showArrows: true,
              infinite: false,
              autoPlay: false,
              openOnTap: true,
            ),

            const SizedBox(height: 16),

            // 🔤 Campos de texto dinámicos
            if (sortedKeys.isEmpty)
              const Text(
                'El usuario no ha completado campos de texto para este documento.',
                style: TextStyle(color: Colors.black54),
              )
            else
              ...sortedKeys.map((key) {
                final value = camposTexto[key] ?? '';
                final numero = key.split('_').last;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextDisplay2(
                    controller: TextEditingController(text: value),
                    label: 'Campo texto #$numero',
                    prefixIcon: Icons.badge_outlined,
                  ),
                );
              }),

            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  color: Colors.black54,
                  size: 18,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Revisa las imágenes y confirma si el documento es válido.',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),

      // 🔘 Botones inferiores
      btnFijoAbajo: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Boton1(
            label: 'Guardar Cambios',
            color: BotonColor.color1,
            borde: BotonBorde.borde1,
            iconoIzquierdo: Icons.save_rounded,
            onPressed: () async {
              final uidEmpresa = taxista?.uidEmpresa;
              final taxistaId = taxista?.id;

              if (uidEmpresa == null || taxistaId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error: faltan datos de empresa o taxista'),
                  ),
                );
                return;
              }

              try {
                await ActualizarEstadoTaxistaService.actualizarEstado(
                  uidEmpresa: uidEmpresa,
                  taxistaId: taxistaId,
                  docNombre: docNombre,
                  nuevoEstado: _estadoActual,
                  motivo: _estadoActual == 'rechazado'
                      ? _notaController.text
                      : null,
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Estado actualizado correctamente ($_estadoActual)',
                    ),
                  ),
                );

                Modular.to.pop(_estadoActual); // opcional: cerrar la página
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
              }
            },
          ),
        ],
      ),

      backgroundGradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFFFFF), Color(0xFFEBEBEB)],
      ),
      colorFondo: const Color(0xFFEBEBEB),
    );
  }
}
