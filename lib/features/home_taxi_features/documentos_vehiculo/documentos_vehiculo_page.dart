import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:buses2/core/utils/string_extensions.dart';
import 'package:buses2/shared/widgets/app_bar/app_bar.dart';
import 'package:buses2/shared/widgets/overlays/cargando.dart';
import 'package:buses2/shared/services/save_traer_firebase/escrituras/doc.dart';
import 'package:buses2/core/services/users.UID.generico/save_fotos_generico.dart';
import 'package:buses2/shared/services/save_traer_firebase/lecturas/docGet.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:buses2/features/mapa_destino/service/servicios.dart';
import 'models/documento_config_model.dart';
import 'services/documentos_config_service.dart';
import 'helpers/steps_builder.dart';

/// Página para registrar documentos del vehículo y del conductor
/// Se debe completar obligatoriamente después del registro inicial del taxista
class DocumentosVehiculoPage extends StatefulWidget {
  const DocumentosVehiculoPage({super.key});

  @override
  State<DocumentosVehiculoPage> createState() => _DocumentosVehiculoPageState();
}

class _DocumentosVehiculoPageState extends State<DocumentosVehiculoPage> {
  final _formKey = GlobalKey<FormState>();

  // Control de pasos
  int _currentStep = 0;
  static const int _lastStepIndex = 3; // hay 4 pasos (0..3)

  // Control de expansión del cuadro informativo
  bool _infoExpanded = true;

  // Configuración dinámica de documentos
  ConfiguracionDocumentos? _configuracionDocumentos;
  bool _cargandoConfiguracion = true;

  // Datos del vehículo (Paso 0)
  final _marcaController = TextEditingController();
  final _colorController = TextEditingController();
  final _asientosController = TextEditingController();
  final _licenciaController = TextEditingController();
  final _numeroPlacaController = TextEditingController();
  final _tipoVehiculoController = TextEditingController();
  final _modeloController = TextEditingController();

  // Mapa dinámico para almacenar archivos de documentos
  // La clave es el ID del documento de la configuración
  final Map<String, File?> _documentosArchivos = {};

  // Mapa para almacenar valores de campos de texto/número por ID de documento
  final Map<String, String?> _documentosValoresTexto = {};

  // Archivos de documentos (mantener para compatibilidad con código existente)
  File? _fotoAntecedentesPenales;
  File? _fotoConductor;
  File? _fotoCarneAnverso;
  File? _fotoCarneReverso;
  File? _fotoLicenciaAnverso;
  File? _fotoLicenciaReverso;
  File? _fotoSoat;
  File? _fotoPermisoCirculacion;
  File? _fotoRevisionTecnica;
  File? _fotoVehiculo1;
  File? _fotoVehiculo2;

  // Selección de servicio por departamento (Paso 5)
  String? _departamentoServicio;
  String? _servicioSeleccionado;

  // Cache de servicios por departamento para el Paso 5
  // Future<Map<String, List<String>>>? _serviciosPorDepartamentoFuture;

  @override
  void initState() {
    super.initState();
    // Cargar configuración de documentos desde Firestore
    _cargarConfiguracionDocumentos();
    // Precargar metadatos de documentosVehiculo (empresa / servicio) si ya existen
    _cargarMetadatosDocumentosVehiculo();
  }

  @override
  void dispose() {
    _marcaController.dispose();
    _colorController.dispose();
    _asientosController.dispose();
    _licenciaController.dispose();
    _numeroPlacaController.dispose();
    _tipoVehiculoController.dispose();
    _modeloController.dispose();
    super.dispose();
  }

  /// Carga desde Firestore los metadatos básicos de documentosVehiculo
  /// (empresa, departamentoServicio, servicioSeleccionado) para precargar el formulario.
  Future<void> _cargarMetadatosDocumentosVehiculo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final docs = await DocGet.documentosGet(rutas: ['taxistas/${user.uid}']);

      if (docs.isEmpty) return;
      final data = docs.first['data'] as Map<String, dynamic>?;
      if (data == null) return;

      final docVehiculoAny = data['documentosVehiculo'];
      if (docVehiculoAny is! Map<String, dynamic>) return;

      if (!mounted) return;
      setState(() {
        _departamentoServicio = (docVehiculoAny['departamentoServicio'] ?? '')
            ?.toString();
        _servicioSeleccionado = (docVehiculoAny['servicioSeleccionado'] ?? '')
            ?.toString();
        // Precargar metadatos básicos si están presentes
        _marcaController.text =
            (docVehiculoAny['marca'] ?? '')?.toString() ?? '';
        _colorController.text =
            (docVehiculoAny['color'] ?? '')?.toString() ?? '';
        _asientosController.text =
            (docVehiculoAny['numeroAsientos'] ?? '')?.toString() ?? '';
        // Preferir numeroPlaca; si no existe, mapear desde numeroLicencia para compatibilidad
        if (docVehiculoAny['numeroPlaca'] != null &&
            docVehiculoAny['numeroPlaca'].toString().trim().isNotEmpty) {
          _numeroPlacaController.text = docVehiculoAny['numeroPlaca']
              .toString();
        } else if (docVehiculoAny['numeroLicencia'] != null &&
            docVehiculoAny['numeroLicencia'].toString().trim().isNotEmpty) {
          _numeroPlacaController.text = docVehiculoAny['numeroLicencia']
              .toString();
        }
        _tipoVehiculoController.text =
            (docVehiculoAny['tipoVehiculo'] ?? '')?.toString() ?? '';
        _modeloController.text =
            (docVehiculoAny['modelo'] ?? '')?.toString() ?? '';
      });
    } catch (e) {
      debugPrint('❌ Error al cargar metadatos de documentosVehiculo: $e');
    }
  }

  /// Carga la configuración de documentos desde Firestore
  Future<void> _cargarConfiguracionDocumentos() async {
    try {
      debugPrint('📥 Cargando configuración de documentos desde Firestore...');
      final configuracion =
          await DocumentosConfigService.cargarConfiguracionConFallback();

      if (!mounted) return;

      setState(() {
        _configuracionDocumentos = configuracion;
        _cargandoConfiguracion = false;
      });

      debugPrint(
        '✅ Configuración cargada: ${configuracion.documentos.length} documentos',
      );
    } catch (e) {
      debugPrint('❌ Error al cargar configuración de documentos: $e');
      if (!mounted) return;

      setState(() {
        _cargandoConfiguracion = false;
      });
    }
  }

  /// Valida que todos los documentos obligatorios estén cargados
  bool _validarDocumentos() {
    if (_configuracionDocumentos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Error: No se pudo cargar la configuración de documentos',
          ),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    final documentosFaltantes = <String>[];
    final documentosRequeridos = _configuracionDocumentos!
        .getDocumentosRequeridos();

    for (final doc in documentosRequeridos) {
      // Solo validar documentos activos y de tipo foto
      if (!doc.activo || doc.tipo != 'foto') continue;

      final archivo = _documentosArchivos[doc.id];
      if (archivo == null) {
        documentosFaltantes.add(doc.nombre);
      }
    }

    if (documentosFaltantes.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Faltan documentos obligatorios:\n${documentosFaltantes.join('\n')}',
          ),
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    return true;
  }

  /// Sube un archivo a Firebase Storage y retorna la URL
  Future<String?> _subirArchivo(File archivo, String pathRelativo) async {
    try {
      debugPrint('📤 Subiendo archivo a Firebase Storage: $pathRelativo');
      final url = await SaveFotoStorage.subir(
        file: archivo,
        path: 'taxistas/{uid}/documentosVehiculo/$pathRelativo',
        replace: true,
      );
      debugPrint('✅ Archivo subido exitosamente: $pathRelativo -> $url');
      return url;
    } catch (e) {
      debugPrint('❌ Error al subir $pathRelativo: $e');
      rethrow; // Re-lanzar el error para manejarlo en _guardarDocumentos
    }
  }

  /// Guarda todos los documentos en Firestore
  Future<void> _guardarDocumentos() async {
    FocusScope.of(context).unfocus();

    // Validar formulario
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validar documentos
    if (!_validarDocumentos()) {
      return;
    }

    if (_configuracionDocumentos == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Error: No se pudo cargar la configuración de documentos',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Variables para el indicador de progreso
    OverlayEntry? progressOverlay;
    final ValueNotifier<int> archivosSubidos = ValueNotifier<int>(0);
    int totalArchivos = 0;

    // Contar archivos a subir
    for (final doc in _configuracionDocumentos!.documentos) {
      if (!doc.activo || doc.tipo != 'foto') continue;
      final archivo = _documentosArchivos[doc.id];
      if (archivo != null) {
        totalArchivos++;
      }
    }

    try {
      // Crear overlay con indicador de progreso
      if (!mounted) return;

      progressOverlay = OverlayEntry(
        builder: (context) => Material(
          color: Colors.black54,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.symmetric(horizontal: 40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text(
                    'Subiendo documentos...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<int>(
                    valueListenable: archivosSubidos,
                    builder: (context, subidos, child) {
                      return Text(
                        '$subidos de $totalArchivos archivos',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      Overlay.of(context).insert(progressOverlay);

      debugPrint('🚀 Iniciando subida de documentos a Firebase Storage');
      debugPrint('📊 Total de archivos a subir: $totalArchivos');

      // Mapa para almacenar las URLs resultantes con el ID del documento
      final Map<String, String> urlsDocumentos = {};

      // Subir todos los archivos en paralelo con actualización de progreso
      final futures = <Future<String?>>[];
      final documentosParaSubir = <DocumentoConfig>[];

      for (final doc in _configuracionDocumentos!.documentos) {
        // Solo procesar documentos activos de tipo foto que tengan archivo
        if (!doc.activo || doc.tipo != 'foto') continue;

        final archivo = _documentosArchivos[doc.id];
        if (archivo != null) {
          documentosParaSubir.add(doc);
          // Usar el ID del documento como nombre de archivo
          futures.add(
            _subirArchivo(archivo, '${doc.id}.jpg').then((url) {
              if (url != null) {
                archivosSubidos.value++;
                debugPrint(
                  '✅ Archivo ${archivosSubidos.value}/$totalArchivos subido: ${doc.id}',
                );
              }
              return url;
            }),
          );
        }
      }

      if (futures.isEmpty) {
        throw Exception('No hay documentos para subir');
      }

      // Esperar a que todas las subidas terminen
      final urls = await Future.wait(futures);

      // Mapear URLs con IDs de documentos
      for (int i = 0; i < documentosParaSubir.length; i++) {
        if (urls[i] != null) {
          urlsDocumentos[documentosParaSubir[i].id] = urls[i]!;
        }
      }

      debugPrint(
        '✅ Todos los archivos subidos exitosamente a Firebase Storage',
      );
      debugPrint('💾 Guardando URLs en Firestore...');

      // Crear mapa con los datos (incluye datos generales del vehículo)
      final datosDocumentos = <String, dynamic>{
        'fechaRegistro': DateTime.now().toIso8601String(),
        'fechaActualizacion': DateTime.now().toIso8601String(),

        // Datos generales del vehículo
        'marca': _marcaController.text.trim(),
        'color': _colorController.text.trim(),
        'numeroAsientos': _asientosController.text.trim(),
        // Guardar numeroPlaca como la nueva clave y mantener numeroLicencia por compatibilidad
        'numeroPlaca': _numeroPlacaController.text.trim(),
        'numeroLicencia': _numeroPlacaController.text.trim(),
        'tipoVehiculo': _tipoVehiculoController.text.trim(),
        'modelo': _modeloController.text.trim(),

        // Datos de empresa/servicio seleccionados
        'empresa': 'mujeresalvolante',
        'departamentoServicio': _departamentoServicio,
        'servicioSeleccionado': _servicioSeleccionado,
      };

      // Agregar URLs de documentos dinámicamente con verificación inicial en false
      for (final doc in _configuracionDocumentos!.documentos) {
        if (!doc.activo) continue;

        final url = urlsDocumentos[doc.id];
        if (url != null) {
          datosDocumentos[doc.id] = url;
          datosDocumentos['verificado${doc.id.substring(0, 1).toUpperCase()}${doc.id.substring(1)}'] =
              false;
        }
      }

      // Guardar en Firestore con manejo de errores específico
      debugPrint('💾 Guardando en Firestore: ${datosDocumentos.keys.toList()}');
      try {
        await DocSets.set(
          absoluteDocPath: ['taxistas/{uid}'],
          nombreMap: ['documentosVehiculo'],
          data: [datosDocumentos],
        );
        debugPrint('✅ DocSets.set completado exitosamente');
      } catch (firestoreError) {
        debugPrint('❌ Error específico en DocSets.set: $firestoreError');
        rethrow;
      }

      debugPrint('✅ Datos guardados exitosamente en Firestore');
      debugPrint('📦 Total de campos guardados: ${datosDocumentos.length}');
      debugPrint('📝 Campos: ${datosDocumentos.keys.toList()}');
      debugPrint('📍 Ruta Storage: taxistas/{uid}/documentosVehiculo/');
      debugPrint('📍 Ruta Firestore: taxistas/{uid}/documentosVehiculo');

      // Guardar referencias para limpieza después de navegación
      final overlayToRemove = progressOverlay;
      final notifierToDispose = archivosSubidos;

      // Limpiar referencias locales para evitar double-dispose
      progressOverlay = null;

      // Verificar mounted antes de operaciones con context
      if (!mounted) {
        // Si no está mounted, limpiar recursos y salir
        try {
          notifierToDispose.dispose();
        } catch (e) {
          debugPrint('⚠️ Error al disponer notifier: $e');
        }
        overlayToRemove?.remove();
        return;
      }

      debugPrint('🏠 Navegando a /home-taxista');

      // Navegar primero (con el overlay visible)
      Modular.to.pushReplacementNamed('/home-taxista');

      // Programar limpieza después de la navegación
      scheduleMicrotask(() {
        try {
          notifierToDispose.dispose();
        } catch (e) {
          debugPrint('⚠️ Error al disponer notifier después de navegación: $e');
        }

        if (overlayToRemove != null && overlayToRemove.mounted) {
          overlayToRemove.remove();
        }
      });
    } catch (e, stackTrace) {
      debugPrint('❌ Error en _guardarDocumentos: $e');
      debugPrint('❌ Stack trace: $stackTrace');

      // Limpiar overlay y notifier de forma segura
      if (progressOverlay != null) {
        try {
          progressOverlay.remove();
        } catch (e) {
          debugPrint('⚠️ Error al remover overlay en catch: $e');
        }
        progressOverlay = null;
      }

      try {
        archivosSubidos.dispose();
      } catch (e) {
        debugPrint('⚠️ Error al disponer notifier en catch: $e');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar documentos: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      // Limpieza final solo si aún hay referencias
      if (progressOverlay != null) {
        try {
          if (progressOverlay.mounted) {
            progressOverlay.remove();
          }
        } catch (e) {
          debugPrint('⚠️ Error al remover overlay en finally: $e');
        }
      }
    }
  }

  /// Muestra diálogo de confirmación para volver al modo pasajero sin guardar
  Future<bool> _confirmarSalida() async {
    // Verificar si tiene cuenta de pasajero completa
    bool tieneCuentaPasajero = false;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final docPasajero = await FirebaseFirestore.instance
            .collection('pasajeros')
            .doc(user.uid)
            .get();
        tieneCuentaPasajero = docPasajero.exists;
      }
    } catch (e) {
      debugPrint('Error al verificar cuenta de pasajero: $e');
    }

    if (!mounted) return false;

    // Mostrar diálogo de confirmación
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_rounded, color: Colors.orange),
            SizedBox(width: 12),
            Expanded(child: Text('⚠️ Documentos Incompletos')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Si sales ahora sin completar todos los documentos, se borrarán todos los datos ingresados.',
              style: TextStyle(fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Text(
                '🔴 IMPORTANTE: Debes completar todos los documentos obligatorios para poder trabajar como conductor.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
            if (tieneCuentaPasajero) ...[
              const SizedBox(height: 12),
              const Text(
                'Puedes volver a tu cuenta de pasajero y completar estos documentos más tarde.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Continuar Llenando',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              tieneCuentaPasajero ? 'Salir y Borrar' : 'Salir al Login',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    // Si confirma salir, borrar documentos incompletos
    if (result == true) {
      await _borrarDocumentosIncompletos();
    }

    return result ?? false;
  }

  /// Borra los documentos incompletos de Firestore
  /// Solo borra si realmente están incompletos según la configuración dinámica
  Future<void> _borrarDocumentosIncompletos() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      debugPrint(
        '🔍 Verificando si hay documentos incompletos para ${user.uid}',
      );

      // Obtener el documento actual
      final taxistaDoc = await FirebaseFirestore.instance
          .collection('taxistas')
          .doc(user.uid)
          .get();

      if (!taxistaDoc.exists) {
        debugPrint('⚠️ Documento de taxista no existe');
        return;
      }

      final data = taxistaDoc.data();
      final documentosVehiculo =
          data?['documentosVehiculo'] as Map<String, dynamic>?;

      if (documentosVehiculo == null || documentosVehiculo.isEmpty) {
        debugPrint('⚠️ No hay documentos que borrar');
        return;
      }

      // Verificar campos obligatorios básicos del Paso 0 (placa puede venir en 'numeroPlaca' o legacy 'numeroLicencia')
      final camposObligatorios = ['marca', 'color', 'numeroAsientos'];

      bool faltanCamposBasicos = false;
      for (final campo in camposObligatorios) {
        final valor = documentosVehiculo[campo];
        if (valor == null || (valor is String && valor.trim().isEmpty)) {
          faltanCamposBasicos = true;
          debugPrint('❌ Falta campo básico: $campo');
          break;
        }
      }

      // Verificar placa (aceptar numeroPlaca o numeroLicencia legacy)
      final placaValor =
          (documentosVehiculo['numeroPlaca'] ??
          documentosVehiculo['numeroLicencia']);
      if (placaValor == null ||
          (placaValor is String && placaValor.trim().isEmpty)) {
        faltanCamposBasicos = true;
        debugPrint('❌ Falta campo básico: numeroPlaca / numeroLicencia');
      }

      // Verificar documentos según configuración dinámica (solo fotos)
      final documentosRequeridos =
          _configuracionDocumentos?.documentos
              .where(
                (doc) =>
                    doc.activo && doc.requerido == true && doc.tipo == 'foto',
              )
              .toList() ??
          [];

      bool faltanDocumentos = false;
      for (final doc in documentosRequeridos) {
        final valor = documentosVehiculo[doc.id];
        if (valor == null || (valor is String && valor.trim().isEmpty)) {
          faltanDocumentos = true;
          debugPrint('❌ Falta documento: ${doc.nombre} (${doc.id})');
          break;
        }
      }

      // Solo borrar si realmente están incompletos
      if (faltanCamposBasicos || faltanDocumentos) {
        debugPrint(
          '🗑️ Borrando documentos incompletos del usuario ${user.uid}',
        );

        await FirebaseFirestore.instance
            .collection('taxistas')
            .doc(user.uid)
            .update({'documentosVehiculo': FieldValue.delete()});

        debugPrint('✅ Documentos incompletos borrados exitosamente');
      } else {
        debugPrint('✅ Documentos completos, no se borrarán');
      }
    } catch (e) {
      debugPrint('❌ Error al verificar/borrar documentos: $e');
    }
  }

  /// Verifica si el usuario actual tiene perfil de pasajero y navega en consecuencia.
  ///
  /// - Si existe documento en `pasajeros/{uid}`: cambia modo a pasajero y va a `/home`.
  /// - Si no existe o hay error: va a `/login`.
  Future<void> _navegarSegunCuentaPasajero() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Modular.to.pushNamedAndRemoveUntil('/login', (_) => false);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('pasajeros')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        // Tiene perfil de pasajero: actualizar modo en Firestore y volver al home pasajero
        try {
          await FirebaseFirestore.instance
              .collection('pasajeros')
              .doc(user.uid)
              .update({'modo': 'pasajero'});

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('modo', 'pasajero');
        } catch (e) {
          debugPrint('❌ Error al cambiar modo: $e');
        }

        Modular.to.pushNamedAndRemoveUntil('/home', (route) => false);
      } else {
        // No tiene perfil de pasajero: enviar al login
        Modular.to.pushNamedAndRemoveUntil('/login', (_) => false);
      }
    } catch (e) {
      debugPrint('❌ Error al verificar cuenta de pasajero: $e');
      Modular.to.pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Permitir retroceder con confirmación
      onWillPop: () async {
        final confirmar = await _confirmarSalida();
        if (confirmar) {
          // Navegar según si tiene o no perfil de pasajero
          await _navegarSegunCuentaPasajero();
        }
        return false; // No hacer el pop automático
      },
      child: Scaffold(
        appBar: AppBar1(
          titleSize: TitleSize.big,
          titulo: 'Documentos del Vehículo',
          leftAction: LeftAction.custom,
          iconoIzquierda: Icons.arrow_back,
          onTapIzquierda: () async {
            final confirmar = await _confirmarSalida();
            if (confirmar) {
              // Navegar según si tiene o no perfil de pasajero
              await _navegarSegunCuentaPasajero();
            }
          },
          iconoDerecha: Icons.info_outline,
          onTapDerecha: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Información'),
                content: const Text(
                  'Debes completar todos los documentos obligatorios para poder continuar. '
                  'Estos documentos serán verificados por el administrador.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Entendido'),
                  ),
                ],
              ),
            );
          },
        ),
        body: Form(
          key: _formKey,
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: const Color(0xFF43A047),
                onPrimary: Colors.white,
              ),
            ),
            child: Stepper(
              currentStep: _currentStep,
              onStepContinue: _onStepContinue,
              onStepCancel: _onStepCancel,
              onStepTapped: _onStepTapped,
              margin: EdgeInsets.zero,
              controlsBuilder: (context, details) {
                final isLastStep = _currentStep == _lastStepIndex;
                final showBack = _currentStep > 0;
                return Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 8),
                  child: Row(
                    children: [
                      if (showBack)
                        Expanded(
                          child: Container(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: details.onStepCancel,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade100,
                                foregroundColor: Colors.grey.shade700,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(50),
                                  side: BorderSide(
                                    color: Colors.grey.shade300,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Atrás',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (showBack) const SizedBox(width: 14),
                      Expanded(
                        child: Container(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: details.onStepContinue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF43A047),
                              foregroundColor: Colors.white,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              shadowColor: const Color(
                                0xFF43A047,
                              ).withOpacity(0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50),
                              ),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                isLastStep ? 'Guardar' : 'Siguiente',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              steps: StepsBuilder.construirPasos(
                configuracion: _configuracionDocumentos,
                cargando: _cargandoConfiguracion,
                currentStep: _currentStep,
                infoExpanded: _infoExpanded,
                onToggleInfo: () =>
                    setState(() => _infoExpanded = !_infoExpanded),
                marcaController: _marcaController,
                colorController: _colorController,
                asientosController: _asientosController,
                numeroPlacaController: _numeroPlacaController,
                tipoVehiculoController: _tipoVehiculoController,
                modeloController: _modeloController,
                documentosArchivos: _documentosArchivos,
                onArchivoCambiado: (docId, file) {
                  setState(() {
                    _documentosArchivos[docId] = file;
                    _actualizarVariablesLegacy(docId, file);
                  });
                },
                onTextoCambiado: (docId, texto) {
                  setState(() {
                    _documentosValoresTexto[docId] = texto;
                  });
                },
              ),
            ),
          ), // Cerrar Theme
        ),
      ),
    ); // Cerrar WillPopScope
  }

  // Métodos de navegación del Stepper
  Future<void> _onStepContinue() async {
    if (_currentStep == _lastStepIndex) {
      // Último paso: guardar documentos
      await _guardarDocumentos();
    } else {
      // Validar el paso actual antes de continuar
      if (_validarPasoActual()) {
        setState(() => _currentStep += 1);
      }
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    }
  }

  void _onStepTapped(int step) {
    // Permitir siempre volver hacia atrás sin validaciones
    if (step < _currentStep) {
      setState(() => _currentStep = step);
      return;
    }

    // Si toca el mismo paso, no hacer nada
    if (step == _currentStep) return;

    // Solo permitir avanzar al siguiente paso inmediato
    if (step == _currentStep + 1) {
      if (_validarPasoActual()) {
        setState(() => _currentStep = step);
      }
      return;
    }

    // Si intenta saltar más de un paso hacia adelante, bloquearlo
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Debes completar y validar los pasos anteriores antes de continuar.',
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Actualiza las variables legacy para compatibilidad con código existente
  void _actualizarVariablesLegacy(String docId, File? file) {
    switch (docId) {
      case 'fotoAntecedentesPenales':
        _fotoAntecedentesPenales = file;
        break;
      case 'fotoConductor':
        _fotoConductor = file;
        break;
      case 'fotoCarneIdentidadAnverso':
        _fotoCarneAnverso = file;
        break;
      case 'fotoCarneIdentidadReverso':
        _fotoCarneReverso = file;
        break;
      case 'fotoLicenciaConducirAnverso':
        _fotoLicenciaAnverso = file;
        break;
      case 'fotoLicenciaConducirReverso':
        _fotoLicenciaReverso = file;
        break;
      case 'fotoSoat':
        _fotoSoat = file;
        break;
      case 'fotoPermisoCirculacion':
        _fotoPermisoCirculacion = file;
        break;
      case 'fotoRevisionTecnica':
        _fotoRevisionTecnica = file;
        break;
      case 'fotoVehiculo1':
        _fotoVehiculo1 = file;
        break;
      case 'fotoVehiculo2':
        _fotoVehiculo2 = file;
        break;
    }
  }

  bool _validarPasoActual() {
    switch (_currentStep) {
      case 0:
        // Paso 0: validar SOLO los datos del vehículo
        // Ejecutamos validate() solo para mostrar errores visuales en los campos,
        // pero la decisión de avanzar se toma en base a los controllers del paso 0
        _formKey.currentState?.validate();

        final marca = _marcaController.text.trim();
        final color = _colorController.text.trim();
        final asientos = _asientosController.text.trim();
        final modelo = _modeloController.text.trim();
        final tipoVehiculo = _tipoVehiculoController.text.trim();
        final placa = _numeroPlacaController.text.trim();

        final faltaAlguno =
            marca.isEmpty ||
            color.isEmpty ||
            asientos.isEmpty ||
            modelo.isEmpty ||
            tipoVehiculo.isEmpty ||
            placa.isEmpty;

        if (faltaAlguno) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Completa los datos del vehículo para continuar.'),
              backgroundColor: Colors.red,
            ),
          );
          return false;
        }
        return true;
      case 1:
      case 2:
      case 3:
        // Validar documentos del paso actual según configuración dinámica
        if (_configuracionDocumentos == null) {
          return true; // Si no hay configuración, permitir avanzar
        }

        final documentosPaso = _configuracionDocumentos!
            .getDocumentosPorPaso(_currentStep)
            .where((doc) => doc.activo && doc.requerido == true)
            .toList();

        final faltantes = <String>[];

        for (final doc in documentosPaso) {
          // Fotos: validar que exista archivo cargado
          if (doc.tipo == 'foto') {
            final archivo = _documentosArchivos[doc.id];
            if (archivo == null) {
              faltantes.add(doc.nombre);
            }
          } else {
            // Campos de texto/número/selección: validar que tengan valor si son requeridos
            final valor = _documentosValoresTexto[doc.id];
            if (valor == null || valor.trim().isEmpty) {
              faltantes.add(doc.nombre);
            }
          }
        }

        if (faltantes.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Faltan documentos obligatorios:\n${faltantes.join('\n')}',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
          return false;
        }
        return true;
      default:
        return true;
    }
  }
}
