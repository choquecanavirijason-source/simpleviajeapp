import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:buses2/shared/widgets/app_bar/app_bar.dart';
import 'package:buses2/shared/widgets/overlays/cargando.dart';
import 'package:buses2/core/services/users.UID.generico/save_img_nube.dart';
import 'models/documento_config_model.dart';
import 'services/documentos_config_service.dart';
import 'widgets/documento_upload_widget.dart';
import 'widgets/campo_dinamico_widget.dart';

/// Página para cargar solo los documentos faltantes
/// sin tener que refill todo el formulario de registro
class DocumentosNuevosPage extends StatefulWidget {
  const DocumentosNuevosPage({super.key});

  @override
  State<DocumentosNuevosPage> createState() => _DocumentosNuevosPageState();
}

class _DocumentosNuevosPageState extends State<DocumentosNuevosPage> {
  final _formKey = GlobalKey<FormState>();

  ConfiguracionDocumentos? _configuracion;
  Map<String, dynamic>? _documentosExistentes;
  List<DocumentoConfig> _documentosFaltantes = [];
  bool _cargando = true;
  bool _guardando = false;

  // Mapa dinámico para archivos nuevos
  final Map<String, File?> _nuevosArchivos = {};
  final Map<String, String?> _nuevosValoresTexto = {};

  @override
  void initState() {
    super.initState();
    _cargarDocumentosFaltantes();
  }

  Future<void> _cargarDocumentosFaltantes() async {
    setState(() => _cargando = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        throw Exception('Usuario no autenticado');
      }

      // Cargar configuración
      final config =
          await DocumentosConfigService.cargarConfiguracionConFallback();

      // Cargar documentos existentes del conductor
      final docSnapshot = await FirebaseFirestore.instance
          .collection('taxistas')
          .doc(uid)
          .get();

      final documentosExistentes =
          docSnapshot.data()?['documentosVehiculo'] as Map<String, dynamic>? ??
          {};

      // Obtener lista de documentos faltantes
      final faltantes = DocumentosConfigService.obtenerDocumentosFaltantes(
        configuracion: config,
        documentosUsuario: documentosExistentes,
      );

      setState(() {
        _configuracion = config;
        _documentosExistentes = documentosExistentes;
        _documentosFaltantes = faltantes;
        _cargando = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar documentos: $e')),
        );
        setState(() => _cargando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar1(titulo: 'Documentos Requeridos'),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _documentosFaltantes.isEmpty
          ? _buildNoDocumentos()
          : _buildFormulario(),
    );
  }

  Widget _buildNoDocumentos() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Colors.green.shade400,
            ),
            const SizedBox(height: 24),
            const Text(
              '¡Todos los documentos completos!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Tienes todos los documentos requeridos al día.',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Modular.to.pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Volver al inicio'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormulario() {
    // Calcular documentos completados
    final todosDocumentos =
        _configuracion?.documentos
            .where((doc) => doc.activo && doc.requerido)
            .toList() ??
        [];
    final completados = todosDocumentos.length - _documentosFaltantes.length;
    final total = todosDocumentos.length;

    return Column(
      children: [
        // Banner informativo con progreso
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Se han agregado nuevos documentos requeridos. Por favor, carga los siguientes:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Barra de progreso
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: completados / total,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.green.shade600,
                  ),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$completados de $total documentos completados',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // Lista de documentos faltantes
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ..._documentosFaltantes.map((doc) => _buildCampoDocumento(doc)),
                const SizedBox(height: 24),
                _buildBotones(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCampoDocumento(DocumentoConfig doc) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    doc.nombre,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (doc.requerido)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Obligatorio',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            if (doc.descripcion != null && doc.descripcion!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                doc.descripcion!,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 16),

            // Campo dinámico según tipo
            if (doc.tipo == 'foto')
              DocumentoUploadWidget(
                titulo: doc.nombre,
                urlInicial: null,
                verificado: false,
                soloLectura: false,
                requerido: doc.requerido,
                onArchivoCambiado: (archivo) {
                  setState(() {
                    _nuevosArchivos[doc.id] = archivo;
                  });
                },
              )
            else
              CampoDinamicoWidget(
                documento: doc,
                valorTextoInicial: '',
                onTextoCambiado: (valor) {
                  setState(() {
                    _nuevosValoresTexto[doc.id] = valor;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotones() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _guardando ? null : () => Modular.to.pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Cancelar'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _guardando ? null : _guardarDocumentos,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _guardando
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Guardar Documentos'),
          ),
        ),
      ],
    );
  }

  Future<void> _guardarDocumentos() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validar que todos los documentos requeridos tengan datos
    final documentosFaltantesRequeridos = _documentosFaltantes
        .where((doc) => doc.requerido)
        .where((doc) {
          if (doc.tipo == 'foto') {
            return _nuevosArchivos[doc.id] == null;
          } else {
            final valor = _nuevosValoresTexto[doc.id];
            return valor == null || valor.isEmpty;
          }
        })
        .toList();

    if (documentosFaltantesRequeridos.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Falta cargar: ${documentosFaltantesRequeridos.map((d) => d.nombre).join(", ")}',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _guardando = true);

    if (!mounted) return;
    Cargando.show(context, message: 'Guardando documentos...');

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Usuario no autenticado');

      final Map<String, dynamic> datosActualizar = {};

      // Subir fotos nuevas
      for (final doc in _documentosFaltantes) {
        if (doc.tipo == 'foto') {
          final archivo = _nuevosArchivos[doc.id];
          if (archivo != null) {
            final url = await SaveImgNube.upload(
              sectionName: 'documentosVehiculo/${doc.id}',
              file: archivo,
              filenameOverride:
                  '${doc.id}_${DateTime.now().millisecondsSinceEpoch}',
            );
            datosActualizar[doc.id] = url;
            datosActualizar['verificado${doc.id[0].toUpperCase()}${doc.id.substring(1)}'] =
                false;
          }
        } else {
          final valor = _nuevosValoresTexto[doc.id];
          if (valor != null && valor.isNotEmpty) {
            datosActualizar[doc.id] = valor;
          }
        }
      }

      // Actualizar fecha de actualización
      datosActualizar['fechaActualizacion'] = DateTime.now().toIso8601String();

      // Guardar en Firestore (merge para no sobrescribir datos existentes)
      await FirebaseFirestore.instance.collection('taxistas').doc(uid).set({
        'documentosVehiculo': datosActualizar,
      }, SetOptions(merge: true));

      // Verificar mounted antes de operaciones con UI
      if (!mounted) return;

      Cargando.hide();

      // Navegar inmediatamente sin SnackBar para evitar race condition
      Modular.to.pop(true); // Retornar true para indicar éxito
    } catch (e) {
      if (!mounted) return;

      try {
        Cargando.hide();
      } catch (e) {
        debugPrint('⚠️ Error al ocultar loading: $e');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }
}
