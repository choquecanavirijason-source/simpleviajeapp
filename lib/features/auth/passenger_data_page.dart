import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:buses2/features/auth/widgets/phone_input_reusable.dart';
import 'package:buses2/core/services/ubicacion_usuario/ubicacion_usuario.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';

class PassengerDataPage extends StatefulWidget {
  const PassengerDataPage({Key? key}) : super(key: key);

  @override
  State<PassengerDataPage> createState() => _PassengerDataPageState();
}

class _PassengerDataPageState extends State<PassengerDataPage> {
  final _formKey = GlobalKey<FormState>();
  final _telefonoController = TextEditingController();
  final _nameController = TextEditingController();
  final _carnetController = TextEditingController();

  String? _generoSeleccionado;
  String? _departamentoSeleccionado;
  String? _paisSeleccionado;
  bool _isLoading = false;
  String _selectedCountryCode = '+54';

  static const List<String> _paisesDisponibles = ['Bolivia', 'Argentina'];

  bool _rostroVerificado = false;
  bool _verificandoRostro = false;

  bool get _soportaVerificacionFacial {
    return !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
  }

  static const List<String> _departamentosBolivia = [
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

  static const List<String> _departamentosArgentina = [
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

  late List<String> _departamentosDisponibles;

  final List<String> _generos = ['Masculino', 'Femenino', 'Otro'];

  @override
  void initState() {
    super.initState();
    _paisSeleccionado = 'Argentina';
    _departamentosDisponibles = _departamentosArgentina;
    final user = FirebaseAuth.instance.currentUser;
    // Prefill name from Google account if available
    _nameController.text = user?.displayName ?? '';

    _configurarDepartamentosSegunGPS();
  }

  List<String> _departamentosDePais(String pais) {
    switch (pais) {
      case 'Argentina':
        return _departamentosArgentina;
      case 'Bolivia':
      default:
        return _departamentosBolivia;
    }
  }

  void _onPaisChanged(String? nuevoPais) {
    if (nuevoPais == null || nuevoPais == _paisSeleccionado) return;
    setState(() {
      _paisSeleccionado = nuevoPais;
      _departamentosDisponibles = _departamentosDePais(nuevoPais);
      _departamentoSeleccionado = null;
    });
  }

  String _normalizarTexto(String value) {
    final lower = value.trim().toLowerCase();
    const map = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
    };
    final buffer = StringBuffer();
    for (final ch in lower.split('')) {
      buffer.write(map[ch] ?? ch);
    }
    return buffer.toString();
  }

  String _normalizarRegion(String value) {
    var s = _normalizarTexto(value);
    s = s
        .replaceAll('departamento de', '')
        .replaceAll('departamento', '')
        .replaceAll('provincia de', '')
        .replaceAll('provincia', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return s;
  }

  String? _encontrarRegionEnLista(List<String> opciones, String candidato) {
    final objetivo = _normalizarRegion(candidato);
    for (final opcion in opciones) {
      if (_normalizarRegion(opcion) == objetivo) {
        return opcion;
      }
    }
    return null;
  }

  List<String>? _departamentosPorCoordenadas(double lat, double lng) {
    final inBolivia =
        lat >= -22.9 && lat <= -9.0 && lng >= -69.7 && lng <= -57.4;
    final inArgentina =
        lat >= -55.0 && lat <= -21.8 && lng >= -73.6 && lng <= -53.6;

    if (inArgentina && !inBolivia) return _departamentosArgentina;
    if (inBolivia && !inArgentina) return _departamentosBolivia;
    return null;
  }

  Future<void> _configurarDepartamentosSegunGPS() async {
    try {
      final ubicacionUsuario = UbicacionUsuario();
      final position = await ubicacionUsuario.obtenerUbicacionActual();
      if (!mounted || position == null) return;

      final fallback = _departamentosPorCoordenadas(
        position.latitude,
        position.longitude,
      );

      List<String>? nuevosDepartamentos;
      String? deptoAuto;

      try {
        final info = await ubicacionUsuario.obtenerDireccionLegible(
          position.latitude,
          position.longitude,
        );

        if (mounted && info != null) {
          final pais = info['pais']?.trim();
          if (pais != null && pais.isNotEmpty) {
            final paisNorm = _normalizarTexto(pais);
            if (paisNorm.contains('argentina')) {
              nuevosDepartamentos = _departamentosArgentina;
            } else if (paisNorm.contains('bolivia')) {
              nuevosDepartamentos = _departamentosBolivia;
            }
          }

          nuevosDepartamentos ??= fallback;

          final deptoDetectado = info['departamento']?.trim();
          if (nuevosDepartamentos != null &&
              deptoDetectado != null &&
              deptoDetectado.isNotEmpty &&
              deptoDetectado != 'Desconocido') {
            deptoAuto = _encontrarRegionEnLista(
              nuevosDepartamentos!,
              deptoDetectado,
            );
          }
        } else {
          nuevosDepartamentos = fallback;
        }
      } catch (_) {
        nuevosDepartamentos = fallback;
      }

      if (!mounted || nuevosDepartamentos == null) return;

      setState(() {
        _departamentosDisponibles = nuevosDepartamentos!;

        if (identical(_departamentosDisponibles, _departamentosArgentina)) {
          _paisSeleccionado = 'Argentina';
        } else if (identical(_departamentosDisponibles, _departamentosBolivia)) {
          _paisSeleccionado = 'Bolivia';
        }

        if (_departamentoSeleccionado != null &&
            !_departamentosDisponibles.contains(_departamentoSeleccionado)) {
          _departamentoSeleccionado = null;
        }

        _departamentoSeleccionado ??= deptoAuto;
      });
    } catch (_) {}
  }

  Future<void> _verificarRostro() async {
    if (!_soportaVerificacionFacial) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La verificación facial no está disponible aquí.'),
        ),
      );
      return;
    }

    if (_verificandoRostro) return;

    setState(() => _verificandoRostro = true);

    FaceDetector? faceDetector;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85,
      );

      if (!mounted) return;

      if (picked == null) return;

      final inputImage = InputImage.fromFilePath(picked.path);
      faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
          enableLandmarks: false,
          enableContours: false,
          enableClassification: false,
          minFaceSize: 0.15,
        ),
      );

      final faces = await faceDetector.processImage(inputImage);
      if (!mounted) return;

      if (faces.isEmpty) {
        setState(() => _rostroVerificado = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se detectó ningún rostro. Intenta de nuevo con buena luz.',
            ),
          ),
        );
        return;
      }

      if (faces.length > 1) {
        setState(() => _rostroVerificado = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Se detectaron varios rostros. Intenta de nuevo con una sola persona.',
            ),
          ),
        );
        return;
      }

      setState(() => _rostroVerificado = true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rostro verificado correctamente.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al verificar rostro: $e')));
    } finally {
      try {
        await faceDetector?.close();
      } catch (_) {}
      if (mounted) {
        setState(() => _verificandoRostro = false);
      }
    }
  }

  @override
  void dispose() {
    _telefonoController.dispose();
    _nameController.dispose();
    _carnetController.dispose();
    super.dispose();
  }

  Future<void> _guardarDatos() async {
    if (!_formKey.currentState!.validate()) return;

    if (_generoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona tu género')),
      );
      return;
    }

    if (_paisSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona tu país')),
      );
      return;
    }

    if (_departamentoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _paisSeleccionado == 'Argentina'
                ? 'Por favor selecciona tu provincia'
                : 'Por favor selecciona tu departamento',
          ),
        ),
      );
      return;
    }

    if (_soportaVerificacionFacial && !_rostroVerificado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor verifica tu rostro (selfie) para continuar'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          Modular.to.pushNamedAndRemoveUntil('/login', (_) => false);
        }
        return;
      }

      // Crear el documento completo del pasajero con todos los datos
      final telefonoLocal = _telefonoController.text.trim();
      final telefonoCompleto = '$_selectedCountryCode$telefonoLocal';

      // Crear documento completo con perfil Y modo
      await FirebaseFirestore.instance
          .collection('pasajeros')
          .doc(user.uid)
          .set({
            'perfil': {
              'email': user.email,
              'name': _nameController.text.trim(),
              'carnet': _carnetController.text.trim(),
              'photoUrl': user.photoURL,
              'provider': 'google',
              'telefono': telefonoCompleto,
              'codigoPais': _selectedCountryCode,
              'genero': _generoSeleccionado,
              'pais': _paisSeleccionado,
              'departamento': _departamentoSeleccionado,
              'rostroVerificado': _rostroVerificado,
              'datosCompletos': true,
              'ultimoLogin': FieldValue.serverTimestamp(),
            },
            'modo': 'pasajero',
          });

      if (mounted) {
        Modular.to.pushNamedAndRemoveUntil('/home', (_) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Navegar al selector principal en lugar de salir
        if (mounted) {
          Modular.to.pushNamedAndRemoveUntil(
            '/user-type-selection',
            (_) => false,
          );
        }
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Modular.to.pushNamedAndRemoveUntil(
                '/user-type-selection',
                (_) => false,
              );
            },
          ),
          title: const Text('Completa tu perfil'),
          centerTitle: true,
          backgroundColor: const Color(0xFF34A853),
          // Mantener el fondo, pero forzar color blanco para texto e iconos
          iconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.person_add,
                        size: 80,
                        color: Color(0xFF34A853),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Información básica',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Necesitamos algunos datos para completar tu registro',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // Campo de nombre (editable, prefills from Google)
                      TextFormField(
                        controller: _nameController,
                        keyboardType: TextInputType.name,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El nombre es requerido';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: 'Nombre Completo / Empresa',
                          hintText: 'Tu nombre completo o nombre de la empresa',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Campo opcional carnet / NIT
                      TextFormField(
                        controller: _carnetController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText:
                              'Identificación Personal o Empresarial (CI/NIT)',
                          hintText: '8737***',

                          prefixIcon: const Icon(Icons.badge),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Campo de teléfono celular con selector de país
                      PhoneNumberField(
                        controller: _telefonoController,
                        initialCountryCode: _selectedCountryCode,
                        label: 'Número de celular',
                        hint: 'Tu número de celular',
                        onCountryChanged: (dialCode) {
                          setState(() {
                            _selectedCountryCode = dialCode;
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      // Selector de género
                      DropdownButtonFormField<String>(
                        value: _generoSeleccionado,
                        decoration: InputDecoration(
                          labelText: 'Género',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        items: _generos.map((genero) {
                          return DropdownMenuItem(
                            value: genero,
                            child: Text(genero),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _generoSeleccionado = value);
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Por favor selecciona tu género';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Selector de país
                      DropdownButtonFormField<String>(
                        value: _paisSeleccionado,
                        decoration: InputDecoration(
                          labelText: 'País',
                          prefixIcon: const Icon(Icons.public),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        items: _paisesDisponibles.map((pais) {
                          return DropdownMenuItem(
                            value: pais,
                            child: Text(pais),
                          );
                        }).toList(),
                        onChanged: _onPaisChanged,
                        validator: (value) {
                          if (value == null) {
                            return 'Por favor selecciona tu país';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Selector de departamento / provincia (depende del país)
                      DropdownButtonFormField<String>(
                        value: _departamentoSeleccionado,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: _paisSeleccionado == 'Argentina'
                              ? 'Provincia'
                              : 'Departamento',
                          prefixIcon: const Icon(Icons.location_city),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        items: _departamentosDisponibles.map((depto) {
                          return DropdownMenuItem(
                            value: depto,
                            child: Text(depto),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _departamentoSeleccionado = value);
                        },
                        validator: (value) {
                          if (value == null) {
                            return _paisSeleccionado == 'Argentina'
                                ? 'Por favor selecciona tu provincia'
                                : 'Por favor selecciona tu departamento';
                          }
                          return null;
                        },
                      ),
                      if (_soportaVerificacionFacial) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                            color: Colors.grey[50],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Verificación facial',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _rostroVerificado
                                    ? 'Rostro verificado.'
                                    : 'Toma una selfie para verificar que eres tú.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _rostroVerificado
                                      ? const Color(0xFF34A853)
                                      : Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _verificandoRostro
                                      ? null
                                      : _verificarRostro,
                                  icon: _verificandoRostro
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.camera_alt),
                                  label: Text(
                                    _rostroVerificado
                                        ? 'Repetir verificación'
                                        : 'Tomar selfie y verificar',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),

                      // Botón de guardar
                      ElevatedButton(
                        onPressed: _guardarDatos,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF34A853),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Continuar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
