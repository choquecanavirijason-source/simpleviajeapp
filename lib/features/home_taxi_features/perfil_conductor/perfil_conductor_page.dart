import 'dart:io';
import 'package:flutter/material.dart';
import 'package:buses2/shared/widgets/app_bar/app_bar.dart';
import 'package:buses2/shared/widgets/cajas/subir_foto/subir_foto.dart';
import 'package:buses2/shared/widgets/modal/modal.dart';
import 'package:buses2/shared/widgets/botones/boton_small.dart';
import 'package:buses2/shared/widgets/inputs/input_text.dart';
import 'package:buses2/shared/widgets/notificacion/notificacion.dart';
import 'package:buses2/shared/widgets/overlays/cargando.dart';
import 'package:buses2/core/services/users.UID.generico/save_datos_genericos.dart';
import 'package:buses2/core/services/users.UID.generico/save_fotos_generico.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PerfilConductorPage extends StatefulWidget {
  const PerfilConductorPage({super.key});

  @override
  State<PerfilConductorPage> createState() => _PerfilConductorPageState();
}

class _PerfilConductorPageState extends State<PerfilConductorPage> {
  static const double _avatarRadius = 54.0;
  static const double _headerHeight = 155.0;
  static const Color _green = Color(0xFF1B5E20);
  static const Color _greenMid = Color(0xFF2E7D32);
  static const Color _greenLight = Color(0xFF43A047);

  final _nameFormKey = GlobalKey<FormState>();
  final _telFormKey = GlobalKey<FormState>();

  String _name = '';
  String _telefono = '';
  String _correo = '';
  bool _verificado = false;
  String? _fotoUrl;
  File? _fotoLocal;
  String? _servicioSeleccionado;
  String? _departamentoServicio;
  String? _logoServicio;
  double? _promedioEstrellas;
  int? _numeroResenias;

  @override
  void initState() {
    super.initState();
    // Pre-populate from Firebase Auth synchronously — eliminates the 1-second flicker.
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _name = user.displayName ?? '';
      _correo = user.email ?? '';
      _fotoUrl = user.photoURL;
    }
    _cargarDatos();
  }

  Future<void> _editarNombre() async {
    final nameCtrl = TextEditingController(text: _name);

    showAppModal(
      context,
      title: 'Editar nombre',
      body: Form(
        key: _nameFormKey,
        child: Column(
          children: [
            TextInput2(
              controller: nameCtrl,
              placeholder: 'Ingresa tu nombre',
              prefixIcon: Icons.person,
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return 'Requerido';
                if (t.length < 3) return 'Mínimo 3 caracteres';
                return null;
              },
            ),
          ],
        ),
      ),
      showCancel: false,
      footerButtons: [
        BotonSmall(
          label: 'Guardar',
          onPressed: () async {
            if (!(_nameFormKey.currentState?.validate() ?? false)) return;
            final nuevo = nameCtrl.text.trim();
            try {
              await SaveDatosGenericos.guardarCampoEnMap(
                absoluteDocPath: 'taxistas/{uid}',
                nombreMap: 'perfilTaxista',
                nombreCampo: 'nombre',
                valor: nuevo,
              );
              if (!mounted) return;
              setState(() => _name = nuevo);
              Navigator.of(context).pop();
              notificacion(
                context,
                title: 'Nombre guardado',
                subtitle: 'Se actualizó tu perfil correctamente',
                seconds: 6,
                icon: Icons.check_rounded,
                color: Colors.green,
              );
            } catch (e) {
              if (!mounted) return;
              notificacion(
                context,
                title: 'Error',
                subtitle: 'No se pudo guardar: $e',
                seconds: 6,
                icon: Icons.error_outline,
                color: Colors.red,
              );
            }
          },
        ),
      ],
    );
  }

  Future<void> _editarTelefono() async {
    final telCtrl = TextEditingController(text: _telefono);

    showAppModal(
      context,
      title: 'Editar teléfono',
      body: Form(
        key: _telFormKey,
        child: Column(
          children: [
            TextInput2(
              controller: telCtrl,
              label: 'Número de teléfono',
              placeholder: 'Ingresa tu número',
              prefixIcon: Icons.phone,
              validator: (v) {
                final t = (v ?? '').replaceAll(RegExp(r'\D'), '');
                if (t.isEmpty) return 'Requerido';
                if (t.length != 8) return 'Debe tener 8 dígitos';
                return null;
              },
            ),
          ],
        ),
      ),
      showCancel: false,
      footerButtons: [
        BotonSmall(
          label: 'Guardar',
          onPressed: () async {
            if (!(_telFormKey.currentState?.validate() ?? false)) return;
            final nuevoTel = telCtrl.text.replaceAll(RegExp(r'\D'), '');
            try {
              await SaveDatosGenericos.guardarCampoEnMap(
                absoluteDocPath: 'taxistas/{uid}',
                nombreMap: 'perfilTaxista',
                nombreCampo: 'telefono',
                valor: nuevoTel,
              );
              if (!mounted) return;
              setState(() => _telefono = nuevoTel);
              Navigator.of(context).pop();
              notificacion(
                context,
                title: 'Teléfono actualizado',
                subtitle: 'Se actualizó tu teléfono correctamente',
                seconds: 6,
                icon: Icons.check_rounded,
                color: Colors.green,
              );
            } catch (e) {
              if (!mounted) return;
              notificacion(
                context,
                title: 'Error',
                subtitle: 'No se pudo guardar: $e',
                seconds: 6,
                icon: Icons.error_outline,
                color: Colors.red,
              );
            }
          },
        ),
      ],
    );
  }

  Future<void> _cargarDatos() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final docTaxista = await FirebaseFirestore.instance
          .collection('taxistas')
          .doc(user.uid)
          .get();

      if (!docTaxista.exists) return;

      final dataTaxista = docTaxista.data();
      final perfilTaxista =
          dataTaxista?['perfilTaxista'] as Map<String, dynamic>?;
      final documentosVehiculo =
          dataTaxista?['documentosVehiculo'] as Map<String, dynamic>?;

      final correoAuth = user.email;
      final servicio = documentosVehiculo?['servicioSeleccionado'] as String?;
      final departamento =
          documentosVehiculo?['departamentoServicio'] as String?;

      double? promedio;
      int? numResenias;
      final promedioRaw = dataTaxista?['promedioEstrellas'];
      if (promedioRaw != null) {
        promedio = (promedioRaw is num) ? promedioRaw.toDouble() : null;
      }
      final reseniasRaw = dataTaxista?['numeroResenias'];
      if (reseniasRaw != null) {
        numResenias = (reseniasRaw is num) ? reseniasRaw.toInt() : null;
      }

      String? logoUrl;
      if (servicio != null && departamento != null) {
        try {
          final docTarifa = await FirebaseFirestore.instance
              .collection('empresas')
              .doc('mujeresalvolante')
              .collection('tarifas')
              .doc(departamento)
              .get();
          if (docTarifa.exists) {
            final tarifaData = docTarifa.data();
            final servicioData =
                tarifaData?[servicio] as Map<String, dynamic>?;
            logoUrl = servicioData?['logo'] as String?;
          }
        } catch (e) {
          debugPrint('Error al cargar logo del servicio: $e');
        }
      }

      bool verificado = false;
      try {
        final docEmpresa = await FirebaseFirestore.instance
            .collection('empresas')
            .doc('mujeresalvolante')
            .collection('trabajadores')
            .doc(user.uid)
            .get();
        if (docEmpresa.exists) {
          final documentos =
              docEmpresa.data()?['documentos'] as Map<String, dynamic>?;
          final estadoTaxista = documentos?['estadoTaxista'] as String?;
          verificado = estadoTaxista?.toLowerCase() == 'aprobado';
        }
      } catch (e) {
        debugPrint('Error al cargar estado de verificación: $e');
      }

      if (!mounted) return;

      setState(() {
        _name = perfilTaxista?['nombre'] ?? _name;
        _telefono = perfilTaxista?['telefono'] ?? _telefono;
        _correo = perfilTaxista?['correo'] ?? correoAuth ?? _correo;
        _fotoUrl = perfilTaxista?['fotoPerfil'] ?? _fotoUrl;
        _verificado = verificado;
        _servicioSeleccionado = servicio;
        _departamentoServicio = departamento;
        _logoServicio = logoUrl;
        _promedioEstrellas = promedio;
        _numeroResenias = numResenias;
      });
    } catch (e) {
      debugPrint('Error al cargar datos: $e');
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final stackHeight = _headerHeight + _avatarRadius + 4.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar1(
        titleSize: TitleSize.big,
        titulo: 'Perfil del Conductor',
        leftAction: LeftAction.back,
        iconoIzquierda: Icons.arrow_back,
        iconoDerecha: Icons.edit_rounded,
        onTapDerecha: _editarNombre,
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Gradient header + centered overlapping avatar ──
          SizedBox(
            height: stackHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: _headerHeight,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_green, _greenMid, _greenLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Align(
                    alignment: const Alignment(0, -0.3),
                    child: Icon(
                      Icons.directions_car_rounded,
                      size: 80,
                      color: Colors.white.withValues(alpha: 0.07),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: _headerHeight - _avatarRadius,
                  child: Center(
                    child: SubirFotoWidget2(
                      alignment: Alignment.center,
                      badgePosition: CameraBadgePosition.bottomRight,
                      badgeColor: _greenLight,
                      icono: Icons.camera_alt,
                      texto: 'Foto de Perfil',
                      initialFile: _fotoLocal,
                      initialUrl: _fotoUrl,
                      onPicked: (file) async {
                        setState(() {
                          _fotoLocal = file;
                          _fotoUrl = null;
                        });
                        try {
                          Cargando.show(context, message: 'Subiendo foto...');
                          final nuevaUrl = await SaveFotoStorage.subir(
                            file: file,
                            path: 'taxistas/{uid}/perfilTaxista/foto.jpg',
                            replace: true,
                          );
                          await SaveDatosGenericos.guardarCampoEnMap(
                            absoluteDocPath: 'taxistas/{uid}',
                            nombreMap: 'perfilTaxista',
                            nombreCampo: 'fotoPerfil',
                            valor: nuevaUrl,
                          );
                          if (!mounted) return;
                          Cargando.hide();
                          setState(() {
                            _fotoUrl = nuevaUrl;
                            _fotoLocal = null;
                          });
                          notificacion(
                            context,
                            title: 'Foto actualizada',
                            subtitle:
                                'Tu foto de perfil se actualizó correctamente',
                            seconds: 4,
                            icon: Icons.check_rounded,
                            color: Colors.green,
                          );
                        } catch (e) {
                          if (!mounted) return;
                          Cargando.hide();
                          notificacion(
                            context,
                            title: 'Error',
                            subtitle: 'No se pudo subir la foto: $e',
                            seconds: 6,
                            icon: Icons.error_outline,
                            color: Colors.red,
                          );
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Name + email + chips ──
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _editarNombre,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _name.isEmpty ? 'Conductor' : _name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A2E),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.edit_rounded,
                        size: 15,
                        color: Color(0xFF94A3B8),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _correo.isEmpty ? 'Sin correo' : _correo,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF64748B),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [_ratingChip(), const SizedBox(width: 8), _verifiedChip()],
                ),
              ],
            ),
          ),

          // ── Info cards ──
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel('INFORMACIÓN DE CONTACTO'),
                const SizedBox(height: 8),
                _card([
                  _tile(
                    icon: Icons.phone_rounded,
                    label: 'Teléfono',
                    value: _telefono.isEmpty ? 'Sin número' : _telefono,
                    onTap: _editarTelefono,
                    editable: true,
                    divider: true,
                  ),
                  _tile(
                    icon: Icons.email_rounded,
                    label: 'Correo electrónico',
                    value: _correo.isEmpty ? 'Sin correo' : _correo,
                  ),
                ]),
                if (_servicioSeleccionado != null) ...[
                  const SizedBox(height: 20),
                  _sectionLabel('SERVICIO'),
                  const SizedBox(height: 8),
                  _card([
                    _tile(
                      icon: Icons.local_taxi_rounded,
                      label: 'Tipo de servicio',
                      value: _servicioSeleccionado!,
                      customLeading:
                          _logoServicio != null && _logoServicio!.isNotEmpty
                              ? CircleAvatar(
                                  radius: 19,
                                  backgroundImage:
                                      NetworkImage(_logoServicio!),
                                )
                              : null,
                    ),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Chip helpers ───────────────────────────────────────────────────────────

  Widget _ratingChip() {
    final hasRating = _promedioEstrellas != null && (_numeroResenias ?? 0) > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: hasRating ? Colors.amber.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: hasRating ? Colors.amber.shade200 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: 15,
            color: hasRating ? Colors.amber.shade700 : Colors.grey.shade400,
          ),
          const SizedBox(width: 4),
          if (hasRating) ...[
            Text(
              _promedioEstrellas!.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.amber.shade800,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '($_numeroResenias ${_numeroResenias == 1 ? 'opinión' : 'opiniones'})',
              style: TextStyle(fontSize: 12, color: Colors.amber.shade700),
            ),
          ] else
            Text(
              'Sin calificaciones',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _verifiedChip() => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: _verificado ? Colors.green.shade50 : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: _verificado
                ? Colors.green.shade200
                : Colors.orange.shade200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _verificado
                  ? Icons.verified_rounded
                  : Icons.pending_rounded,
              size: 14,
              color: _verificado
                  ? Colors.green.shade700
                  : Colors.orange.shade700,
            ),
            const SizedBox(width: 4),
            Text(
              _verificado ? 'Verificado' : 'Pendiente',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _verificado
                    ? Colors.green.shade800
                    : Colors.orange.shade800,
              ),
            ),
          ],
        ),
      );

  // ── Layout helpers ─────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF94A3B8),
          letterSpacing: 1.0,
        ),
      );

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(children: children),
      );

  Widget _tile({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
    bool editable = false,
    bool divider = false,
    Widget? customLeading,
  }) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          customLeading ??
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: _green),
              ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (editable)
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Colors.grey.shade400,
            ),
        ],
      ),
    );

    return Column(
      children: [
        onTap != null
            ? InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(16),
                child: content,
              )
            : content,
        if (divider)
          Divider(height: 1, indent: 68, color: Colors.grey.shade100),
      ],
    );
  }
}
