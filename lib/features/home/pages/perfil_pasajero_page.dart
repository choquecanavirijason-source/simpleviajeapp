import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:buses2/shared/widgets/botones/boton.dart';
import 'package:buses2/shared/widgets/app_bar/app_bar.dart';
import 'package:buses2/shared/widgets/overlays/cargando.dart';
import 'package:buses2/shared/widgets/cajas/subir_foto/subir_foto.dart';
import 'package:buses2/core/services/users.UID.generico/save_fotos_generico.dart';
import 'package:buses2/shared/widgets/notificacion/notificacion.dart';
import 'package:buses2/features/auth/widgets/phone_input_reusable.dart';
import 'package:buses2/shared/utils/phone_formatter.dart';

class PerfilPasajeroPage extends StatefulWidget {
  const PerfilPasajeroPage({super.key});

  @override
  State<PerfilPasajeroPage> createState() => _PerfilPasajeroPageState();
}

class _PerfilPasajeroPageState extends State<PerfilPasajeroPage> {
  final _formKey = GlobalKey<FormState>();

  // Controladores de inputs (similar a registro_taxi)
  final _nameCtrl = TextEditingController();
  final _carnetCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController(); // solo lectura

  File? _fotoLocal;
  String? _fotoInicialUrl;
  String _selectedCountryCode = '+591';

  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _carnetCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() => _cargando = false);
        }
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('pasajeros')
          .doc(user.uid)
          .get();

      final data = doc.data() ?? <String, dynamic>{};
      final perfil = (data['perfil'] as Map?)?.cast<String, dynamic>() ?? {};

      final telefonoCompleto = perfil['telefono']?.toString();
      final codigoPais = perfil['codigoPais']?.toString();
      String telefonoSolo8 = '';
      if (telefonoCompleto != null && telefonoCompleto.isNotEmpty) {
        final digits = telefonoCompleto.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.length >= 8) {
          telefonoSolo8 = digits.substring(digits.length - 8);
        } else if (digits.isNotEmpty) {
          telefonoSolo8 = digits;
        }
      }

      if (!mounted) return;

      setState(() {
        _selectedCountryCode = codigoPais ?? '+591'; // Detectar o usar Bolivia
        _nameCtrl.text = (perfil['name']?.toString().trim().isNotEmpty == true)
            ? perfil['name'].toString()
            : (user.displayName ?? '');

        _emailCtrl.text =
            (perfil['email']?.toString().trim().isNotEmpty == true)
            ? perfil['email'].toString()
            : (user.email ?? '');

        _carnetCtrl.text =
            (perfil['carnet']?.toString().trim().isNotEmpty == true)
            ? perfil['carnet'].toString()
            : '';

        _phoneCtrl.text = telefonoSolo8;

        _fotoInicialUrl = perfil['photoUrl']?.toString() ?? user.photoURL;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Corrige los errores en rojo.')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesión no válida. Vuelve a iniciar sesión.'),
        ),
      );
      return;
    }

    Cargando.show(context, message: 'Guardando perfil...');

    try {
      String? fotoFinal = _fotoInicialUrl;
      if (_fotoLocal != null) {
        fotoFinal = await SaveFotoStorage.subir(
          file: _fotoLocal!,
          path: 'pasajeros/{uid}/perfil/foto.jpg',
          replace: true,
        );
      }

      final cleanPhone = _phoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
      final telefonoCompleto = cleanPhone.isNotEmpty
          ? '$_selectedCountryCode$cleanPhone'
          : null;

      final perfilUpdate = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'carnet': _carnetCtrl.text.trim(),
        if (telefonoCompleto != null) 'telefono': telefonoCompleto,
        if (telefonoCompleto != null) 'codigoPais': _selectedCountryCode,
        'email': _emailCtrl.text.trim(),
        if (fotoFinal != null && fotoFinal.isNotEmpty) 'photoUrl': fotoFinal,
        'datosCompletos': true,
      };

      await FirebaseFirestore.instance
          .collection('pasajeros')
          .doc(user.uid)
          .set({'perfil': perfilUpdate}, SetOptions(merge: true));

      if (!mounted) return;
      Cargando.hide();

      // Volver al home
      Modular.to.pushNamedAndRemoveUntil('/home/', (_) => false);
    } catch (e) {
      if (!mounted) return;
      Cargando.hide();
      notificacion(
        context,
        title: 'Error',
        subtitle: 'No se pudo guardar: $e',
        seconds: 6,
        icon: Icons.error_outline,
        color: Colors.red,
      );
    }
  }

  // --- UI helpers similares a registro_taxi ---

  Widget _buildFotoPerfil() {
    return SubirFotoWidget2(
      icono: Icons.camera_alt,
      texto: 'Foto de perfil',
      initialUrl: _fotoInicialUrl,
      initialFile: _fotoLocal,
      alignment: Alignment.center,
      badgePosition: CameraBadgePosition.bottomRight,
      badgeColor: const Color(0xFF34A853),
      onPicked: (file) {
        setState(() {
          _fotoLocal = file;
        });
      },
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
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      inputFormatters: formatters,
      validator: validator,
      readOnly: readOnly,
      decoration: _inputDeco(
        label: label,
        icon: icon,
        hint: hint,
        prefixText: prefixText,
      ),
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
        borderSide: const BorderSide(color: Color(0xFF34A853), width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Estilo de errores similar a registro_taxi
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

    return Theme(
      data: Theme.of(
        context,
      ).copyWith(inputDecorationTheme: inputDecorationTheme),
      child: WillPopScope(
        onWillPop: () async {
          Modular.to.pushNamedAndRemoveUntil('/home/', (_) => false);
          return false;
        },
        child: Scaffold(
          appBar: AppBar1(
            titleSize: TitleSize.big,
            titulo: 'Perfil Pasajero',
            leftAction: LeftAction.back,
            iconoIzquierda: Icons.arrow_back,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFotoPerfil(),
                  const SizedBox(height: 25),

                  _buildSectionHeader('Datos personales'),

                  _buildInput(
                    controller: _nameCtrl,
                    label: 'Nombre completo',
                    icon: Icons.person,
                    hint: 'Tu nombre tal como figura en tu documento',
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'El nombre es obligatorio';
                      }
                      if (v.trim().length < 3) {
                        return 'Mínimo 3 caracteres';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  _buildInput(
                    controller: _carnetCtrl,
                    label: 'Identificación Personal o Empresarial (CI/NIT)',
                    icon: Icons.badge,
                    hint: '8737***',
                    inputType: TextInputType.number,
                    formatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return null; // opcional
                      if (!RegExp(r'^\d+$').hasMatch(t)) {
                        return 'Solo se permiten números';
                      }
                      if (t.length < 4) {
                        return 'Debe tener al menos 4 dígitos';
                      }
                      return null;
                    },
                  ),

                  _buildSectionHeader('Contacto'),

                  // Celular con selector de país
                  PhoneNumberField(
                    controller: _phoneCtrl,
                    initialCountryCode: _selectedCountryCode,
                    label: 'Celular',
                    hint: 'Tu número de celular',
                    onCountryChanged: (dialCode) {
                      setState(() {
                        _selectedCountryCode = dialCode;
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  _buildInput(
                    controller: _emailCtrl,
                    label: 'Correo electrónico',
                    icon: Icons.email_outlined,
                    hint: 'tucorreo@ejemplo.com',
                    inputType: TextInputType.emailAddress,
                    readOnly: true,
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return 'El correo es obligatorio';
                      final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                      if (!emailRegex.hasMatch(t)) return 'Correo inválido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),
                  Boton1(
                    label: 'GUARDAR Y VOLVER AL INICIO',
                    color: BotonColor.color1,
                    borde: BotonBorde.borde1,
                    iconoDerecho: Icons.arrow_forward_ios,
                    onPressed: _guardar,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
