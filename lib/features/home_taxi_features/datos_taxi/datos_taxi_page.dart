import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Necesario para validaciones y formatos
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Imports de tu arquitectura
import 'package:buses2/shared/widgets/app_bar/app_bar.dart';
import 'package:buses2/shared/widgets/botones/btn_fijo_abajo.dart';
import 'package:buses2/shared/widgets/botones/boton.dart';
import 'package:buses2/shared/widgets/inputs/input_text.dart';
import 'package:buses2/shared/widgets/cajas/caja_contenedora/caja_contenedora.dart';
import 'package:buses2/shared/widgets/overlays/cargando.dart';

class DatosTaxiPage extends StatefulWidget {
  const DatosTaxiPage({super.key});

  @override
  State<DatosTaxiPage> createState() => _DatosTaxiPageState();
}

class _DatosTaxiPageState extends State<DatosTaxiPage> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Controladores
  final _marcaCtrl = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _placaCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _numeroAsientosCtrl = TextEditingController();
  final _numeroLicenciaCtrl = TextEditingController();

  // Expresión Regular para Placas (Formato: 3-4 números y 3 letras)
  final _placaRegex = RegExp(r'^[0-9]{3,4}-?[A-Z]{3}$');

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final docVehiculo = await _firestore
            .collection('taxistas')
            .doc(user.uid)
            .get();

        final documentos =
            docVehiculo.data()?['documentosVehiculo'] as Map<String, dynamic>?;

        if (documentos != null) {
          setState(() {
            _marcaCtrl.text = (documentos['marca'] ?? '').toString();
            _modeloCtrl.text = (documentos['modelo'] ?? '').toString();
            _placaCtrl.text = (documentos['numeroPlaca'] ?? '').toString();
            _colorCtrl.text = (documentos['color'] ?? '').toString();
            _numeroAsientosCtrl.text =
                documentos['numeroAsientos']?.toString() ?? '';
            _numeroLicenciaCtrl.text = (documentos['numeroLicencia'] ?? '')
                .toString();
          });
        }
      }
    } catch (e) {
      debugPrint('Error al cargar datos: $e');
    }
  }

  @override
  void dispose() {
    _marcaCtrl.dispose();
    _modeloCtrl.dispose();
    _placaCtrl.dispose();
    _colorCtrl.dispose();
    _numeroAsientosCtrl.dispose();
    _numeroLicenciaCtrl.dispose();
    super.dispose();
  }

  void _guardar() async {
    // 1. Ocultar teclado
    FocusScope.of(context).unfocus();

    // 2. Validar campos
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Cargando.show(context, message: "Guardando datos...");

    try {
      final user = _auth.currentUser;
      if (user != null) {
        final docRef = _firestore.collection('taxistas').doc(user.uid);

        // Preparamos el mapa de actualización (Flat structure para no borrar otros campos en el doc)
        Map<String, dynamic> nuevosDatosVehiculo = {
          'documentosVehiculo.marca': _marcaCtrl.text.trim(),
          'documentosVehiculo.modelo': _modeloCtrl.text.trim(),
          'documentosVehiculo.placa': _placaCtrl.text.trim().toUpperCase(),
          'documentosVehiculo.color': _colorCtrl.text.trim(),
          'documentosVehiculo.numeroAsientos':
              int.tryParse(_numeroAsientosCtrl.text.trim()) ?? 4,
          'documentosVehiculo.numeroLicencia': _numeroLicenciaCtrl.text
              .trim()
              .toUpperCase(),
          'documentosVehiculo.fechaActualizacion': DateTime.now()
              .toIso8601String(),
        };

        await docRef.update(nuevosDatosVehiculo);
      }

      if (!mounted) return;
      Cargando.hide();

      // Feedback de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Datos actualizados correctamente'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // 3. RETROCEDER: Esperamos un instante y volvemos a la pantalla anterior
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      Cargando.hide();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al guardar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldConBottom(
      appBar: const AppBar1(
        titleSize: TitleSize.big,
        titulo: 'Datos del Automóvil',
        leftAction: LeftAction.back,
        iconoIzquierda: Icons.arrow_back,
      ),
      scrollBody: true,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 16),

              // --- SECCIÓN VEHÍCULO ---
              CajaContenedora(
                titulo: 'Información del Taxi',
                iconoTitulo: Icons.local_taxi,
                tituloAlign: TituloAlign.center,
                iconoDerecha: Icons.info_outline,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextInput2(
                      controller: _marcaCtrl,
                      label: 'Marca del Auto',
                      placeholder: 'Ej: Toyota',
                      prefixIcon: Icons.business,
                      // textCapitalization: TextCapitalization.sentences,
                      validator: (v) => (v == null || v.length < 2)
                          ? 'Ingrese marca válida'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    TextInput2(
                      controller: _modeloCtrl,
                      label: 'Modelo',
                      placeholder: 'Ej: Corolla',
                      prefixIcon: Icons.directions_car,
                      // textCapitalization: TextCapitalization.sentences,
                      validator: (v) => (v == null || v.length < 2)
                          ? 'Ingrese modelo válido'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    TextInput2(
                      controller: _placaCtrl,
                      label: 'Número de Placa',
                      placeholder: 'Ej: 1234ABC',
                      prefixIcon: Icons.confirmation_number,
                      // textCapitalization: TextCapitalization.characters,
                      // inputFormatters: [
                      //   _UpperCaseTextFormatter(),
                      //   FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9-]')),
                      // ],
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Requerido';
                        if (!_placaRegex.hasMatch(v.toUpperCase()))
                          return 'Formato inválido (1234ABC)';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextInput2(
                      controller: _colorCtrl,
                      label: 'Color del Auto',
                      placeholder: 'Ej: Blanco',
                      prefixIcon: Icons.color_lens,
                      // textCapitalization: TextCapitalization.sentences,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 16),

                    TextInput2(
                      controller: _numeroAsientosCtrl,
                      label: 'Número de Asientos',
                      placeholder: 'Ej: 4',
                      prefixIcon: Icons.airline_seat_recline_normal,
                      keyboardType: TextInputType.number,
                      // inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Requerido';
                        final num = int.tryParse(v);
                        if (num == null || num < 2 || num > 12)
                          return 'Rango inválido (2-12)';
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // --- SECCIÓN CONDUCTOR ---
              CajaContenedora(
                titulo: 'Información del Conductor',
                iconoTitulo: Icons.person,
                tituloAlign: TituloAlign.center,
                iconoDerecha: Icons.card_membership,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextInput2(
                      controller: _numeroLicenciaCtrl,
                      label: 'N.° de Licencia de Conducir',
                      placeholder: 'Ej: 7654321',
                      prefixIcon: Icons.credit_card,
                      // textCapitalization: TextCapitalization.characters,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Requerido' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 100,
              ), // Espacio para que el scroll no tape el último input
            ],
          ),
        ),
      ),
      btnFijoAbajo: Boton1(
        label: 'Guardar Datos',
        color: BotonColor.color1,
        borde: BotonBorde.borde1,
        iconoIzquierdo: Icons.save,
        iconoDerecho: Icons.arrow_forward,
        onPressed: _guardar,
      ),
    );
  }
}

/// Formateador para forzar mayúsculas mientras el usuario escribe
class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
