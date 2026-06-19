import 'dart:io';
import 'package:flutter/material.dart';

// UI compartida
import 'package:buses2/shared/widgets/cajas/subir_foto/subir_foto.dart';
import 'package:buses2/shared/widgets/app_bar/app_bar.dart';
import 'package:buses2/shared/widgets/inputs/input_text.dart';
import 'package:buses2/shared/widgets/botones/boton.dart';
import 'package:buses2/shared/widgets/botones/btn_fijo_abajo.dart';
import 'package:buses2/shared/widgets/overlays/cargando.dart';

// Firestore + Storage
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:buses2/shared/services/save_traer_firebase/storage/storage.dart';

class DatosEmpresaPage extends StatefulWidget {
  const DatosEmpresaPage({super.key});

  @override
  State<DatosEmpresaPage> createState() => _DatosEmpresaPageState();
}

class _DatosEmpresaPageState extends State<DatosEmpresaPage> {
  late final TextEditingController _nameEmpresaCtrl;
  late final TextEditingController _namePropietarioCtrl;
  late final TextEditingController _nameCelularCtrl;
  late final TextEditingController _nameEmailCtrl;

  // Logo seleccionado (local)
  File? _logoFile;

  // Datos actuales del perfil (desde Firestore)
  Map<String, dynamic>? _perfilEmpresa;

  bool _cargando = true;

  // Atajos
  DocumentReference<Map<String, dynamic>> get _empresaDoc =>
      FirebaseFirestore.instance.collection('empresas').doc('mujeresalvolante');

  @override
  void initState() {
    super.initState();
    _nameEmpresaCtrl = TextEditingController();
    _namePropietarioCtrl = TextEditingController();
    _nameCelularCtrl = TextEditingController();
    _nameEmailCtrl = TextEditingController();
    _cargarEmpresa(); // directo desde Firestore
  }

  Future<void> _cargarEmpresa() async {
    try {
      final snap = await _empresaDoc.get();
      final data = snap.data() ?? {};
      final perfil =
          (data['perfilEmpresa'] as Map?)?.cast<String, dynamic>() ?? {};

      _perfilEmpresa = perfil;

      // Rellenar controllers con lo que haya
      _nameEmpresaCtrl.text = (perfil['nombreEmpresa'] ?? '').toString();
      _namePropietarioCtrl.text = (perfil['representante'] ?? '').toString();
      _nameCelularCtrl.text = (perfil['telefono'] ?? '').toString();
      _nameEmailCtrl.text = (perfil['correo'] ?? '').toString();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error cargando empresa: $e')));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _actualizarEmpresa() async {
    Cargando.show(context, message: "Guardando...");

    try {
      // 1) Subir logo si corresponde
      String? logoUrl = _perfilEmpresa?['logoUrl']
          ?.toString(); // conservar existente
      if (_logoFile != null) {
        final storage = StorageService();
        // guarda bajo /empresas/mujeresalvolante/perfil/logo_<ts>.ext
        final ext = (() {
          final name = _logoFile!.path.split('/').last;
          final i = name.lastIndexOf('.');
          return i >= 0 ? name.substring(i) : '.jpg';
        })();
        final ts = DateTime.now().millisecondsSinceEpoch;
        final path = 'empresas/mujeresalvolante/perfil/logo_$ts$ext';
        final url = await storage.uploadPhoto(_logoFile!, path);
        if (url != null && url.isNotEmpty) {
          logoUrl = url;
        }
      }

      // 2) Construir payload de perfilEmpresa
      final payloadPerfil = <String, dynamic>{
        'nombreEmpresa': _nameEmpresaCtrl.text.trim(),
        'representante': _namePropietarioCtrl.text.trim(),
        'telefono': _nameCelularCtrl.text.trim(),
        'correo': _nameEmailCtrl.text.trim(),
        if (logoUrl != null && logoUrl.isNotEmpty) 'logoUrl': logoUrl,
      };

      // 3) Guardar con merge (no borra otros campos del doc)
      await _empresaDoc.set({
        'perfilEmpresa': payloadPerfil,
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Datos actualizados')));

      // 4) Refrescar desde Firestore
      await _cargarEmpresa();
      // Opcional: limpiar selección local
      // setState(() => _logoFile = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al actualizar: $e')));
      }
    } finally {
      Cargando.hide();
    }
  }

  @override
  void dispose() {
    _nameEmpresaCtrl.dispose();
    _namePropietarioCtrl.dispose();
    _nameCelularCtrl.dispose();
    _nameEmailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final logoActual = _perfilEmpresa?['logoUrl']?.toString();

    return ScaffoldConBottom(
      appBar: AppBar1(
        titleSize: TitleSize.big,
        titulo: 'Datos de la Empresa',
        leftAction: LeftAction.back,
        iconoIzquierda: Icons.arrow_back,
        iconoDerecha: Icons.settings,
        onTapDerecha: () => debugPrint('Ajustes'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- LOGO (visual) ---
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SubirFotoWidget(
                    icono: Icons.upload,
                    texto: 'Subir logo',
                    initialUrl: logoActual, // URL remota actual
                    onPicked: (file) {
                      setState(() {
                        _logoFile = file; // se subirá al guardar
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            TextInput2(
              controller: _nameEmpresaCtrl,
              label: 'Nombre Empresa',
              keyboardType: TextInputType.name,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Requerido';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextInput2(
              controller: _namePropietarioCtrl,
              label: 'Propietario',
              keyboardType: TextInputType.name,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Requerido';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextInput2(
              controller: _nameCelularCtrl,
              label: 'Celular',
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Requerido';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextInput2(
              controller: _nameEmailCtrl,
              label: 'Correo Electrónico',
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Requerido';
                return null;
              },
            ),
            const SizedBox(height: 16),

            const SizedBox(height: 80), // aire para el botón fijo
          ],
        ),
      ),

      // Botón fijo inferior
      btnFijoAbajo: Boton1(
        label: 'Actulizar Datos',
        color: BotonColor.color1,
        borde: BotonBorde.borde1,
        iconoIzquierdo: Icons.save,
        iconoDerecho: Icons.save,
        onPressed: _actualizarEmpresa,
      ),
    );
  }
}
