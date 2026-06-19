import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para input formatters
import 'package:flutter_modular/flutter_modular.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:buses2/core/utils/string_extensions.dart';

// Imports de tu proyecto (Mantenidos)
import 'package:buses2/shared/widgets/botones/btn_fijo_abajo.dart';
import 'package:buses2/shared/widgets/botones/boton.dart';
import 'package:buses2/shared/widgets/app_bar/app_bar.dart';
import 'package:buses2/shared/widgets/overlays/cargando.dart';
import 'package:buses2/shared/services/save_traer_firebase/escrituras/doc.dart';
import '../../../core/services/users.UID.generico/save_fotos_generico.dart';
import 'package:buses2/core/services/ubicacion_usuario/ubicacion_usuario.dart';
import 'package:buses2/features/mapa_destino/service/servicios.dart';
import 'package:buses2/shared/widgets/cajas/subir_foto/subir_foto.dart';
import 'package:buses2/features/auth/widgets/phone_input_reusable.dart';
import 'package:buses2/shared/services/codigos/codigos_service.dart';
import 'package:buses2/shared/services/facial/face_detector_service.dart';

class RegistroTaxista extends StatefulWidget {
  const RegistroTaxista({Key? key}) : super(key: key);

  @override
  State<RegistroTaxista> createState() => _RegistroTaxistaState();
}

class _RegistroTaxistaState extends State<RegistroTaxista>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();

  // --- Controladores ---
  final _nameCtrl = TextEditingController();
  final _ciCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _cityCtrl = TextEditingController(); // Automático ReadOnly

  // Emergencia
  final _emergencyNameCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController();

  // Código de referido (opcional, al registrarse)
  final _refCodigoCtrl = TextEditingController();

  // Country codes for phone numbers (default Argentina)
  String _selectedCountryCode = '+54';
  String _emergencyCountryCode = '+54';

  // --- Estado ---
  File? _logoFile;
  String? _fotoInicialUrl;

  // Selfie de verificación facial (separada de la foto de perfil)
  File? _selfieFile;
  bool _selfieVerificada = false;
  bool _verificandoSelfie = false;

  // Selectores
  String? _generoSeleccionado;
  String? _tipoLicenciaSeleccionada;
  String? _empresaSeleccionada;

  // Lógica de Negocio
  bool _ubicacionLista = false;
  bool _gpsPermitido = false;
  String _ubicacionTexto = '';
  bool _cargandoServicios = false;
  List<_ServicioConLogo> _serviciosDepartamento = [];

  // Datos Estáticos Bolivia
  final List<String> _generos = ['Masculino', 'Femenino', 'Otro'];

  final List<String> _tiposLicencia = ['A', 'B', 'C', 'P'];

  // Lista de Departamentos para matchear respuesta del GPS
  final List<String> _departamentosBolivia = [
    'La Paz',
    'Cochabamba',
    'Santa Cruz',
    'Oruro',
    'Potosí',
    'Chuquisaca',
    'Tarija',
    'Beni',
    'Pando',
  ];

  // Operación (editable): País y departamento/provincia. Default Argentina.
  String? _paisOperacionSeleccionado = 'Argentina';
  String? _departamentoOperacionSeleccionado;
  bool _detectandoUbicacion = false;

  final List<String> _paisesOperacion = const ['Bolivia', 'Argentina'];

  final List<String> _jurisdiccionesArgentina = const [
    'Buenos Aires',
    'Ciudad Autónoma de Buenos Aires',
    'Catamarca',
    'Chaco',
    'Chubut',
    'Córdoba',
    'Corrientes',
    'Entre Ríos',
    'Formosa',
    'Jujuy',
    'La Pampa',
    'La Rioja',
    'Mendoza',
    'Misiones',
    'Neuquén',
    'Río Negro',
    'Salta',
    'San Juan',
    'San Luis',
    'Santa Cruz',
    'Santa Fe',
    'Santiago del Estero',
    'Tierra del Fuego',
    'Tucumán',
  ];

  String _normalizarTexto(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargarDatosGoogle();
    _inicializarUbicacionAutomatica();
  }

  @override
  void dispose() {
    // Al salir de la pantalla, cerrar cualquier SnackBar activo
    try {
      ScaffoldMessenger.of(context).clearSnackBars();
    } catch (_) {}

    _nameCtrl.dispose();
    _ciCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _cityCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    _refCodigoCtrl.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed &&
        (!_gpsPermitido || !_ubicacionLista)) {
      // Al volver de la configuración del sistema, volvemos a intentar
      _inicializarUbicacionAutomatica();
    }
  }

  void _cargarDatosGoogle() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _nameCtrl.text = user.displayName?.toTitleCase() ?? '';
        _emailCtrl.text = user.email ?? '';
        _fotoInicialUrl = user.photoURL;
      });
    }
  }

  /// ------------------------------------------------------------
  /// LÓGICA DE UBICACIÓN Y SERVICIOS
  /// ------------------------------------------------------------

  Future<void> _inicializarUbicacionAutomatica() async {
    final operacionCompleta =
        _paisOperacionSeleccionado != null &&
        _departamentoOperacionSeleccionado != null;

    if (_gpsPermitido && operacionCompleta) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }
      return;
    }

    if (mounted) {
      setState(() {
        _detectandoUbicacion = true;
        _ubicacionTexto = "Detectando ubicación...";
      });
    }

    try {
      // 1. Verificar permisos y GPS
      final servicioActivo = await Geolocator.isLocationServiceEnabled();
      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (!servicioActivo ||
          permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _gpsPermitido = false;
            _ubicacionTexto = "Ubicación no disponible";
          });
        }
        _mostrarErrorUbicacionPersistent();
        return;
      }

      // 2. Obtener Ubicación (Usando tu servicio existente)
      final ubicacionService = UbicacionUsuario();
      final ubicacion = await ubicacionService.obtenerUbicacion40mtrs();

      final Position? posicion = ubicacion?['position'] as Position?;
      final String? direccion = ubicacion?['direccion'] as String?;
      String? departamento = ubicacion?['departamento'] as String?;
      String? pais = ubicacion?['pais'] as String?;

      // Fallback: si no tenemos país (caché viejo), lo resolvemos una vez
      if ((pais == null || pais.trim().isEmpty) && posicion != null) {
        final info = await ubicacionService.obtenerDireccionLegible(
          posicion.latitude,
          posicion.longitude,
        );
        if (info != null) {
          departamento = info['departamento'];
          pais = info['pais'];
          await ubicacionService.guardarCoordenadas(posicion, info: info);
        }
      }

      if (mounted) {
        setState(() {
          final direccionLimpia = direccion?.trim();
          if (direccionLimpia != null && direccionLimpia.isNotEmpty) {
            _ubicacionTexto = direccionLimpia;
          } else if (posicion != null) {
            _ubicacionTexto =
                'Lat: ${posicion.latitude.toStringAsFixed(5)}, Lng: ${posicion.longitude.toStringAsFixed(5)}';
          } else {
            _ubicacionTexto = 'Ubicación no disponible';
          }
        });
      }

      final paisNorm = _normalizarTexto(pais ?? '');
      String? paisDetectado;
      if (paisNorm.contains('bolivia')) {
        paisDetectado = 'Bolivia';
      } else if (paisNorm.contains('argentina')) {
        paisDetectado = 'Argentina';
      }
      // Si GPS devuelve otro país (o nada): NO bloqueamos. Dejamos que el
      // usuario complete país y provincia manualmente con el default Argentina.
      paisDetectado ??= _paisOperacionSeleccionado ?? 'Argentina';

      final deptoLimpio = (departamento ?? '').trim();
      final deptoNorm = _normalizarTexto(deptoLimpio)
          .replaceAll('provincia de ', '')
          .replaceAll('departamento de ', '')
          .replaceAll('provincia del ', '')
          .replaceAll('departamento del ', '')
          .replaceAll('provincia de la ', '')
          .replaceAll('departamento de la ', '');

      final candidatos = paisDetectado == 'Argentina'
          ? _jurisdiccionesArgentina
          : _departamentosBolivia;

      final matchDepto = candidatos.firstWhere(
        (d) => _normalizarTexto(d) == deptoNorm,
        orElse: () => '',
      );
      final String? departamentoDetectado = matchDepto.isNotEmpty
          ? matchDepto
          : null;

      if (mounted) {
        setState(() {
          _gpsPermitido = true;

          // Autocompleta (pero luego el usuario puede editar)
          _paisOperacionSeleccionado ??= paisDetectado;

          if (_paisOperacionSeleccionado == paisDetectado &&
              _departamentoOperacionSeleccionado == null &&
              departamentoDetectado != null) {
            _departamentoOperacionSeleccionado = departamentoDetectado;
          }

          _ubicacionLista =
              (_paisOperacionSeleccionado != null &&
              _departamentoOperacionSeleccionado != null);

          _cityCtrl.text = _departamentoOperacionSeleccionado ?? '';
        });

        if (_gpsPermitido) {
          ScaffoldMessenger.of(context).clearSnackBars();
        }
      }

      // Servicios por departamento (solo Bolivia)
      if (_paisOperacionSeleccionado == 'Bolivia' &&
          _departamentoOperacionSeleccionado != null) {
        _cargarServicios(_departamentoOperacionSeleccionado!);
      } else if (mounted) {
        setState(() {
          _serviciosDepartamento = [];
          _empresaSeleccionada = null;
          _cargandoServicios = false;
        });
      }
    } catch (e) {
      debugPrint("Error GPS: $e");
      if (mounted) {
        setState(() {
          _gpsPermitido = false;
          _ubicacionTexto = "Error de GPS";
        });
      }
      _mostrarErrorUbicacionPersistent();
    } finally {
      if (mounted) {
        setState(() {
          _detectandoUbicacion = false;
        });
      }
    }
  }

  void _mostrarErrorUbicacionPersistent({String? mensaje}) {
    if (!mounted) return;
    // Si el GPS ya es válido, limpiamos cualquier mensaje viejo y no mostramos otro
    if (_gpsPermitido) {
      ScaffoldMessenger.of(context).clearSnackBars();
      return;
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.location_off, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(mensaje ?? 'Activa el GPS para registrarte.')),
          ],
        ),
        backgroundColor: Colors.redAccent,
        duration: const Duration(days: 1), // Persistente
        action: SnackBarAction(
          label: 'REINTENTAR',
          textColor: Colors.white,
          onPressed: () async {
            // Solo abrimos la configuración. Al volver a la app,
            // didChangeAppLifecycleState(AppLifecycleState.resumed)
            // llamará a _inicializarUbicacionAutomatica nuevamente.
            await Geolocator.openLocationSettings();
          },
        ),
      ),
    );
  }

  /// Toma una selfie con la cámara frontal y la valida con ML Kit.
  /// Solo deja la foto si contiene EXACTAMENTE un rostro.
  Future<void> _tomarYVerificarSelfie() async {
    if (_verificandoSelfie) return;
    setState(() => _verificandoSelfie = true);

    final res = await FaceDetectorService.tomarSelfieYValidar();
    if (!mounted) return;

    if (res == null) {
      // Usuario canceló — no cambiamos estado, solo apagamos el loading.
      setState(() => _verificandoSelfie = false);
      return;
    }

    if (res.ok) {
      setState(() {
        _selfieFile = res.file;
        _selfieVerificada = true;
        _verificandoSelfie = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rostro verificado correctamente.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      setState(() {
        _selfieVerificada = false;
        _verificandoSelfie = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.errorMensaje ?? 'No se pudo verificar el rostro.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _cargarServicios(String departamento) async {
    setState(() => _cargandoServicios = true);
    try {
      final serviciosData = await tarifasDeEmpresaEnDepartamento(
        departamento: departamento,
      );
      final listadoFiltrado = <_ServicioConLogo>[];

      for (var s in serviciosData) {
        if (s.activo && s.logo != null && s.logo!.isNotEmpty) {
          listadoFiltrado.add(
            _ServicioConLogo(nombre: s.servicio, logoUrl: s.logo!),
          );
        }
      }

      if (mounted) {
        setState(() {
          _serviciosDepartamento = listadoFiltrado;
          _cargandoServicios = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargandoServicios = false);
    }
  }

  /// ------------------------------------------------------------
  /// GUARDADO
  /// ------------------------------------------------------------

  Future<void> _guardar() async {
    // 1. Validaciones previas
    // Disparar validadores visuales
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ Hay campos incompletos o con errores.\n'
            'Revisa los campos marcados en rojo y completa todos los datos requeridos.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    final paisOperacion = _paisOperacionSeleccionado;
    final departamentoOperacion = _departamentoOperacionSeleccionado;
    if (paisOperacion == null || departamentoOperacion == null) {
      _inicializarUbicacionAutomatica();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona tu país y departamento/provincia'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_gpsPermitido) {
      _inicializarUbicacionAutomatica();
      return;
    }

    if (_serviciosDepartamento.isNotEmpty && _empresaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un tipo de servicio (Vehículo)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Verificación facial obligatoria
    if (!_selfieVerificada || _selfieFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Verifica tu rostro con una selfie antes de continuar.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 2. Proceso de Guardado
    Cargando.show(context, message: 'Creando perfil de conductor...');
    try {
      final user = FirebaseAuth.instance.currentUser!;

      // Subida de Foto (si aplica)
      String? fotoFinal = _fotoInicialUrl;
      if (_logoFile != null) {
        fotoFinal = await SaveFotoStorage.subir(
          file: _logoFile!,
          path: 'taxistas/${user.uid}/perfilTaxista/foto.jpg',
          replace: true,
        );
      }

      // Subida de Selfie de verificación (siempre que esté verificada)
      String? selfieUrl;
      if (_selfieFile != null) {
        selfieUrl = await SaveFotoStorage.subir(
          file: _selfieFile!,
          path: 'taxistas/${user.uid}/perfilTaxista/selfie_verificacion.jpg',
          replace: true,
        );
      }

      // Construcción del objeto C.I.
      final ciCompleto = _ciCtrl.text.trim();

      // Mapa de Datos Principal
      final telefonoLocal = _phoneCtrl.text.trim();
      final telefonoCompleto = '$_selectedCountryCode$telefonoLocal';
      final emergenciaLocal = _emergencyPhoneCtrl.text.trim();
      final emergenciaCompleto = '$_emergencyCountryCode$emergenciaLocal';

      final Map<String, dynamic> datosDriver = {
        'nombre': _nameCtrl.text.trim(),
        'ci': ciCompleto, // Guardamos concatenado o separado según tu backend
        'ci_numero': _ciCtrl.text.trim(),
        'ci_complemento': '',
        'ci_extension': '',
        'telefono': telefonoLocal, // Número local (compatibilidad)
        'telefonoCompleto': telefonoCompleto, // Número completo con código
        'codigoPais': _selectedCountryCode, // Código de país
        'correo': _emailCtrl.text.trim(),
        'genero': _generoSeleccionado,
        'tipoLicencia': _tipoLicenciaSeleccionada,
        'departamento': departamentoOperacion,
        'paisOperacion': paisOperacion,
        'contactoEmergencia': {
          'nombre': _emergencyNameCtrl.text.trim(),
          'telefono': emergenciaLocal, // Local (compatibilidad)
          'telefonoCompleto': emergenciaCompleto, // Completo con código
          'codigoPais': _emergencyCountryCode, // Código de país
        },
        'fotoPerfil': fotoFinal,
        'selfieVerificacion': selfieUrl,
        'rostroVerificado': true,
        'email': user.email,
        'provider': 'google',
        'datosCompletos': true,
        'fechaRegistro': FieldValue.serverTimestamp(),
      };

      // Escritura en Firestore (Batch/Set)
      await DocSets.set(
        absoluteDocPath: ['taxistas/${user.uid}', 'taxistas/${user.uid}'],
        nombreMap: ['perfilTaxista', '@root'],
        data: [
          datosDriver,
          {
            'uidTaxista': user.uid,
            'modo': 'taxista',
            'empresa': 'mujeresalvolante',
          },
        ],
      );

      // Metadatos Vehículo
      await DocSets.set(
        absoluteDocPath: ['taxistas/${user.uid}'],
        nombreMap: ['documentosVehiculo'],
        data: [
          {
            'empresa': 'mujeresalvolante',
            'paisServicio': paisOperacion,
            'departamentoServicio': departamentoOperacion,
            'servicioSeleccionado': _empresaSeleccionada,
          },
        ],
      );

      // Código de referido (opcional). Si falla, NO bloqueamos el registro:
      // el taxista ya quedó creado; solo mostramos un aviso del error.
      final codigoRef = _refCodigoCtrl.text.trim();
      String? mensajeReferido;
      if (codigoRef.isNotEmpty) {
        try {
          await CodigosService.instance.aplicarCodigoReferido(
            codigoIngresado: codigoRef,
            uidNuevoTaxista: user.uid,
          );
          mensajeReferido = '¡Código aplicado! Recibiste tu recompensa.';
        } catch (e) {
          mensajeReferido = e is String
              ? CodigoErrorCodes.mensaje(e)
              : 'No se pudo aplicar el código de referido.';
        }
      }

      if (!mounted) return;
      Cargando.hide();

      if (mensajeReferido != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeReferido),
            backgroundColor: mensajeReferido.startsWith('¡')
                ? Colors.green
                : Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      Modular.to.pushNamedAndRemoveUntil('/documentos-vehiculo', (_) => false);
    } catch (e) {
      if (!mounted) return;
      Cargando.hide();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  /// ------------------------------------------------------------
  /// CONFIRMACIÓN Y NAVEGACIÓN
  /// ------------------------------------------------------------

  /// Confirma si el usuario desea abandonar el registro sin completarlo
  Future<bool> _confirmarSalida() async {
    // Verificar si tiene cuenta de pasajero completa
    bool tieneCuentaPasajero = false;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final pasajeroDoc = await FirebaseFirestore.instance
            .collection('pasajeros')
            .doc(user.uid)
            .get();

        if (pasajeroDoc.exists) {
          final data = pasajeroDoc.data();
          final perfil = data?['perfil'] as Map<String, dynamic>?;
          tieneCuentaPasajero = perfil?['datosCompletos'] == true;
        }
      }
    } catch (e) {
      debugPrint('Error verificando cuenta pasajero: $e');
    }

    final titulo = tieneCuentaPasajero
        ? '¿Volver al modo pasajero?'
        : '¿Volver al inicio?';
    final contenido = tieneCuentaPasajero
        ? 'Si vuelves ahora, perderás toda la información ingresada. ¿Estás seguro de que deseas volver al modo pasajero?'
        : 'Si vuelves ahora, perderás toda la información ingresada. ¿Estás seguro de que deseas volver al inicio?';
    final botonTexto = tieneCuentaPasajero
        ? 'Volver a Pasajero'
        : 'Volver al Inicio';

    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: Text(contenido),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: Text(botonTexto),
          ),
        ],
      ),
    );
    return resultado ?? false;
  }

  /// Navega de regreso a la selección de tipo de usuario después de confirmar
  Future<void> _navegarASeleccionUsuario() async {
    Modular.to.pushNamedAndRemoveUntil('/user-type-selection', (_) => false);
  }

  /// ------------------------------------------------------------
  /// UI BUILDERS
  /// ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Definimos el estilo de error global para los inputs
    final inputDecorationTheme = Theme.of(context).inputDecorationTheme
        .copyWith(
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent, width: 2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
        );

    return WillPopScope(
      onWillPop: () async {
        final confirmar = await _confirmarSalida();
        if (confirmar) {
          await _navegarASeleccionUsuario();
        }
        return false; // No hacer el pop automático
      },
      child: Theme(
        data: Theme.of(
          context,
        ).copyWith(inputDecorationTheme: inputDecorationTheme),
        child: ScaffoldConBottom(
          appBar: AppBar1(
            titleSize: TitleSize.big,
            titulo: 'Perfil Conductor',
            leftAction: LeftAction.custom,
            iconoIzquierda: Icons.arrow_back,
            onTapIzquierda: () async {
              final confirmar = await _confirmarSalida();
              if (confirmar) {
                await _navegarASeleccionUsuario();
              }
            },
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              20,
              10,
              20,
              100,
            ), // Padding inferior para btn flotante
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFotoPerfil(),
                  const SizedBox(height: 25),

                  _buildSectionHeader("Datos Personales"),

                  // Nombre
                  _buildInput(
                    controller: _nameCtrl,
                    label: "Nombre Completo",
                    icon: Icons.person,
                    hint: "Como aparece en tu C.I.",
                    autofill: [AutofillHints.name],
                    validator: (v) =>
                        v!.isEmpty ? 'El nombre es obligatorio' : null,
                  ),

                  const SizedBox(height: 16),

                  // Documento de Identidad — acepta CI boliviano (5-10) y DNI argentino (7-8)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Documento de Identidad",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildInput(
                              controller: _ciCtrl,
                              label: _paisOperacionSeleccionado == 'Argentina'
                                  ? 'Número de DNI'
                                  : 'Número de C.I.',
                              hint: _paisOperacionSeleccionado == 'Argentina'
                                  ? 'Ej. 12345678'
                                  : 'Solo núm.',
                              inputType: TextInputType.number,
                              formatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Requerido';
                                if (v.length < 5) return 'Mín 5 dígitos';
                                if (v.length > 10) return 'Máx 10 dígitos';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Género
                  DropdownButtonFormField<String>(
                    value: _generoSeleccionado,
                    decoration: _inputDeco(label: "Género", icon: Icons.wc),
                    items: _generos
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (v) => setState(() => _generoSeleccionado = v),
                    validator: (v) => v == null ? 'Selecciona tu género' : null,
                  ),

                  _buildSectionHeader("Contacto y Ubicación"),

                  // Teléfono Personal (Multi-país)
                  PhoneNumberField(
                    controller: _phoneCtrl,
                    initialCountryCode: _selectedCountryCode,
                    label: 'Celular Personal',
                    hint: 'Tu número de celular',
                    onCountryChanged: (dialCode) {
                      setState(() {
                        _selectedCountryCode = dialCode;
                      });
                    },
                  ),

                  const SizedBox(height: 16),
                  // hacer input readOnly
                  _buildInput(
                    readOnly: true,
                    controller: _emailCtrl,
                    label: "Correo Electrónico",
                    icon: Icons.email_outlined,
                    inputType: TextInputType.emailAddress,
                    autofill: [AutofillHints.email],
                    validator: (v) => (v != null && v.contains('@'))
                        ? null
                        : 'Correo inválido',
                  ),

                  const SizedBox(height: 16),

                  // Código de referido (opcional)
                  _buildInput(
                    controller: _refCodigoCtrl,
                    label: "Código de referido (opcional)",
                    icon: Icons.card_giftcard,
                    hint: "Ej. REF-AB12CD",
                    inputType: TextInputType.text,
                  ),

                  const SizedBox(height: 16),

                  // Verificación facial (obligatoria)
                  _buildSelfieCard(),

                  const SizedBox(height: 16),

                  // Operación: País + Departamento/Provincia (autocompleta por GPS, pero editable)
                  DropdownButtonFormField<String>(
                    value: _paisOperacionSeleccionado,
                    decoration: _inputDeco(
                      label: "País de Operación",
                      icon: Icons.public,
                    ).copyWith(fillColor: Colors.grey.shade200),
                    items: _paisesOperacion
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _paisOperacionSeleccionado = v;
                        _departamentoOperacionSeleccionado = null;
                        _ubicacionLista = false;
                        _cityCtrl.text = '';
                        _serviciosDepartamento = [];
                        _empresaSeleccionada = null;
                        _cargandoServicios = false;
                      });
                    },
                    validator: (v) => v == null ? 'Selecciona un país' : null,
                    isExpanded: true,
                  ),

                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: _departamentoOperacionSeleccionado,
                    decoration:
                        _inputDeco(
                          label: _paisOperacionSeleccionado == 'Argentina'
                              ? 'Provincia / Jurisdicción'
                              : 'Departamento',
                          icon: Icons.location_on,
                        ).copyWith(
                          fillColor: Colors.grey.shade200,
                          helperText: _ubicacionTexto.trim().isNotEmpty
                              ? 'Ubicación actual: ${_ubicacionTexto.trim()}'
                              : null,
                          helperMaxLines: 2,
                          suffixIcon: _detectandoUbicacion
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Padding(
                                    padding: EdgeInsets.all(12),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : ((_gpsPermitido && _ubicacionLista)
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      )
                                    : null),
                        ),
                    items:
                        (_paisOperacionSeleccionado == 'Argentina'
                                ? _jurisdiccionesArgentina
                                : (_paisOperacionSeleccionado == 'Bolivia'
                                      ? _departamentosBolivia
                                      : <String>[]))
                            .map(
                              (d) => DropdownMenuItem(value: d, child: Text(d)),
                            )
                            .toList(),
                    onChanged: _paisOperacionSeleccionado == null
                        ? null
                        : (v) async {
                            setState(() {
                              _departamentoOperacionSeleccionado = v;
                              _ubicacionLista =
                                  (_paisOperacionSeleccionado != null &&
                                  v != null);
                              _cityCtrl.text = v ?? '';
                              _empresaSeleccionada = null;
                            });

                            if (v == null) return;

                            if (_paisOperacionSeleccionado == 'Bolivia') {
                              await _cargarServicios(v);
                            } else if (mounted) {
                              setState(() {
                                _serviciosDepartamento = [];
                                _empresaSeleccionada = null;
                                _cargandoServicios = false;
                              });
                            }
                          },
                    validator: (v) => v == null
                        ? 'Selecciona tu departamento/provincia'
                        : null,
                    isExpanded: true,
                  ),

                  _buildSectionHeader("Licencia y Vehículo"),

                  DropdownButtonFormField<String>(
                    value: _tipoLicenciaSeleccionada,
                    decoration: _inputDeco(
                      label: "Categoría Licencia",
                      icon: Icons.drive_eta,
                    ),
                    items: _tiposLicencia
                        .map(
                          (l) => DropdownMenuItem(
                            value: l,
                            child: Text("Categoría $l"),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _tipoLicenciaSeleccionada = v),
                    validator: (v) => v == null ? 'Requerido' : null,
                  ),

                  const SizedBox(height: 20),

                  // Selección de Servicios (Tarjetas)
                  if (_cargandoServicios)
                    const Center(child: CircularProgressIndicator())
                  else if (_serviciosDepartamento.isNotEmpty) ...[
                    Text(
                      "Selecciona tu Servicio",
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _serviciosDepartamento.map((servicio) {
                        final selected =
                            _empresaSeleccionada == servicio.nombre;
                        return _ServiceCard(
                          servicio: servicio,
                          isSelected: selected,
                          onTap: () => setState(
                            () => _empresaSeleccionada = servicio.nombre,
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  _buildSectionHeader(
                    "En caso de Emergencia",
                    color: Colors.redAccent,
                  ),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        _buildInput(
                          controller: _emergencyNameCtrl,
                          label: "Nombre del Contacto",
                          icon: Icons.person_add,
                          validator: (v) => v!.isEmpty ? 'Requerido' : null,
                        ),
                        const SizedBox(height: 16),
                        // Celular de Emergencia (Multi-país)
                        PhoneNumberField(
                          controller: _emergencyPhoneCtrl,
                          initialCountryCode: _emergencyCountryCode,
                          label: 'Celular de Emergencia',
                          hint: 'Contacto de emergencia',
                          onCountryChanged: (dialCode) {
                            setState(() {
                              _emergencyCountryCode = dialCode;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          btnFijoAbajo: Boton1(
            label: 'GUARDAR Y CONTINUAR',
            color: BotonColor.color1,
            borde: BotonBorde.borde1,
            iconoDerecho: Icons.arrow_forward_ios,
            onPressed: _guardar,
          ),
        ),
      ),
    );
  }

  // --- Widgets Internos Refinados ---

  Widget _buildFotoPerfil() {
    return SubirFotoWidget2(
      icono: Icons.camera_alt,
      texto: "Foto de perfil",
      initialUrl: _fotoInicialUrl,
      badgeColor: Theme.of(context).primaryColor,
      alignment: Alignment.center,
      badgePosition: CameraBadgePosition.bottomRight,
      onPicked: (file) => _logoFile = file,
    );
  }

  /// Tarjeta de verificación facial (selfie con detección de rostro).
  Widget _buildSelfieCard() {
    final bool verificada = _selfieVerificada && _selfieFile != null;
    final bool cargando = _verificandoSelfie;

    final Color borderColor = verificada
        ? const Color(0xFF22C55E)
        : Colors.grey.shade300;
    final Color bgColor = verificada
        ? const Color(0xFFE8F5E9)
        : Colors.grey.shade50;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor, width: verificada ? 1.5 : 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                verificada
                    ? Icons.verified_user_rounded
                    : Icons.face_retouching_natural,
                color: verificada
                    ? const Color(0xFF16A34A)
                    : Colors.grey[700],
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Verificación facial',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              if (verificada)
                const Text(
                  'Verificado',
                  style: TextStyle(
                    color: Color(0xFF16A34A),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            verificada
                ? 'Tu rostro fue detectado correctamente.'
                : 'Toma una selfie con buena luz. Detectamos automáticamente '
                      'que tu rostro sea visible.',
            style: TextStyle(color: Colors.grey[700], fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (_selfieFile != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    _selfieFile!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: cargando ? null : _tomarYVerificarSelfie,
                  icon: cargando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          verificada
                              ? Icons.refresh_rounded
                              : Icons.camera_alt_outlined,
                        ),
                  label: Text(
                    cargando
                        ? 'Verificando…'
                        : (verificada
                              ? 'Tomar de nuevo'
                              : 'Tomar selfie y verificar'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: verificada
                        ? Colors.white
                        : const Color(0xFF16A34A),
                    foregroundColor: verificada
                        ? const Color(0xFF16A34A)
                        : Colors.white,
                    elevation: 0,
                    side: verificada
                        ? const BorderSide(color: Color(0xFF16A34A))
                        : null,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black87,
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    String? hint,
    String? prefixText,
    TextInputType? inputType,
    List<TextInputFormatter>? formatters,
    List<String>? autofill,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      inputFormatters: formatters,
      autofillHints: autofill,
      validator: validator,
      decoration: _inputDeco(
        label: label,
        icon: icon,
        hint: hint,
        prefixText: prefixText,
      ),
      readOnly: readOnly,
    );
  }

  InputDecoration _inputDeco({
    required String label,
    IconData? icon,
    String? hint,
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefixText,
      prefixIcon: icon != null
          ? Icon(icon, color: Colors.grey[600], size: 22)
          : null,
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
      ),
    );
  }
}

// --- Widget de Tarjeta de Servicio ---
class _ServiceCard extends StatelessWidget {
  final _ServicioConLogo servicio;
  final bool isSelected;
  final VoidCallback onTap;

  const _ServiceCard({
    Key? key,
    required this.servicio,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorPrimario = Theme.of(context).primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 100, // Ancho fijo para las tarjetas
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? colorPrimario.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? colorPrimario : Colors.grey.shade300,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colorPrimario.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            // Check icon overlay
            if (isSelected)
              Align(
                alignment: Alignment.topRight,
                child: Icon(Icons.check_circle, size: 18, color: colorPrimario),
              ),

            // Imagen redonda
            Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: NetworkImage(servicio.logoUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              servicio.nombre.toTitleCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? colorPrimario : Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ServicioConLogo {
  final String nombre;
  final String logoUrl;
  const _ServicioConLogo({required this.nombre, required this.logoUrl});
}
