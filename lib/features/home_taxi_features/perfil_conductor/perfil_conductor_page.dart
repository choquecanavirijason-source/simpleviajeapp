import 'dart:io';
import 'package:flutter/material.dart';
import 'package:buses2/shared/widgets/app_bar/app_bar.dart';
import 'package:buses2/shared/widgets/cajas/caja_portada/caja_portada.dart';
import 'package:buses2/shared/widgets/cajas/subir_foto/subir_foto.dart';
import 'package:buses2/shared/widgets/casillas/casillas.dart';
import 'package:buses2/shared/widgets/modal/modal.dart';
import 'package:buses2/shared/widgets/botones/boton_small.dart';
import 'package:buses2/shared/widgets/inputs/input_text.dart';
import 'package:buses2/shared/widgets/notificacion/notificacion.dart';
import 'package:buses2/shared/widgets/overlays/cargando.dart';
import 'package:buses2/core/services/users.UID.generico/get_datos_genericos.dart';
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
  static const double _avatarSize = 110;
  static const double _headerHeight = 90;
  final _nameFormKey = GlobalKey<FormState>();
  String _name = 'Nombre del Conductor';
  final _telFormKey = GlobalKey<FormState>();
  String _telefono = 'No definido';
  String _correo = 'No definido';
  bool _verificado = false;
  String? _fotoUrl;
  File? _fotoLocal;

  // Datos del servicio
  String? _servicioSeleccionado;
  String? _departamentoServicio;
  String? _logoServicio;

  // Datos de puntuación
  double? _promedioEstrellas;
  int? _numeroResenias;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _editarNombre() async {
    final _nameCtrl = TextEditingController(text: _name);

    showAppModal(
      context,
      title: 'Editar nombre',
      body: Form(
        key: _nameFormKey,
        child: Column(
          children: [
            TextInput2(
              controller: _nameCtrl,
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

            final nuevo = _nameCtrl.text.trim();
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
    final _telefonoCtrl = TextEditingController(text: _telefono);

    showAppModal(
      context,
      title: 'Editar teléfono',
      body: Form(
        key: _telFormKey,
        child: Column(
          children: [
            TextInput2(
              controller: _telefonoCtrl,
              label: 'Número de teléfono',
              placeholder: 'Ingresa tu número',
              prefixIcon: Icons.phone,
              // Si tu TextInput2 lo soporta, descomenta:
              // keyboardType: TextInputType.phone,
              validator: (v) {
                final t = (v ?? '').replaceAll(
                  RegExp(r'\D'),
                  '',
                ); // solo dígitos
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
            // 1) validar
            if (!(_telFormKey.currentState?.validate() ?? false)) return;

            // 2) normalizar a solo dígitos
            final nuevoTel = _telefonoCtrl.text.replaceAll(RegExp(r'\D'), '');

            try {
              // 3) guardar en Firestore
              await SaveDatosGenericos.guardarCampoEnMap(
                absoluteDocPath: 'taxistas/{uid}',
                nombreMap: 'perfilTaxista',
                nombreCampo: 'telefono',
                valor: nuevoTel,
              );

              if (!mounted) return;

              // 4) refrescar UI
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

      // Cargar datos del perfil del taxista completo
      final docTaxista = await FirebaseFirestore.instance
          .collection('taxistas')
          .doc(user.uid)
          .get();

      if (!docTaxista.exists) {
        debugPrint('Documento de taxista no encontrado');
        return;
      }

      final dataTaxista = docTaxista.data();
      final perfilTaxista =
          dataTaxista?['perfilTaxista'] as Map<String, dynamic>?;
      final documentosVehiculo =
          dataTaxista?['documentosVehiculo'] as Map<String, dynamic>?;

      // Obtener correo de Firebase Auth
      final correoAuth = user.email;

      // Obtener datos de servicio
      String? servicio = documentosVehiculo?['servicioSeleccionado'] as String?;
      String? departamento =
          documentosVehiculo?['departamentoServicio'] as String?;

      // Obtener datos de puntuación
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

      // Cargar logo del servicio desde Firestore
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
            final servicioData = tarifaData?[servicio] as Map<String, dynamic>?;
            logoUrl = servicioData?['logo'] as String?;
          }
        } catch (e) {
          debugPrint('Error al cargar logo del servicio: $e');
        }
      }

      // Obtener estado de verificación desde empresa
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
        _correo = perfilTaxista?['correo'] ?? correoAuth ?? 'No definido';
        _fotoUrl = perfilTaxista?['fotoPerfil'];
        _verificado = verificado;

        // Actualizar datos de servicio
        _servicioSeleccionado = servicio;
        _departamentoServicio = departamento;
        _logoServicio = logoUrl;

        // Actualizar datos de puntuación
        _promedioEstrellas = promedio;
        _numeroResenias = numResenias;
      });
    } catch (e) {
      debugPrint('Error al cargar datos: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final double overlap = _avatarSize / 2; // cuánto se solapa el avatar
    final double stackHeight =
        _headerHeight + overlap; // alto total del header compuesto
    return Scaffold(
      appBar: const AppBar1(
        titleSize: TitleSize.big,
        titulo: 'Perfil del Conductor',
        leftAction: LeftAction.back,
        iconoIzquierda: Icons.arrow_back,
        iconoDerecha: Icons.edit,
      ),
      body: ListView(
        padding: EdgeInsets.zero, // sin espacio entre AppBar y contenido
        children: [
          SizedBox(
            height: stackHeight, // <-- aquí va stackHeight (SIN guion bajo)
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Portada verde
                CajaPortada(
                  height: _headerHeight,
                  color: const Color(
                    0xFF43A047,
                  ), // Verde consistente con la app
                  showVerified: _verificado,
                  verifiedText: _verificado ? 'Verificado' : 'No Verificado',
                  verifiedIcon: _verificado
                      ? Icons.verified
                      : Icons.error_outline,
                  verifiedGradient: LinearGradient(
                    colors: _verificado
                        ? [const Color(0xFF43A047), const Color(0xFF66BB6A)]
                        : [Colors.orange.shade600, Colors.orange.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  verifiedShadowColor: _verificado
                      ? const Color(0xFF43A047)
                      : Colors.orange,
                  verifiedForegroundColor: Colors.white, // Color icono y texto
                ),

                // Avatar pegado a la izquierda, solapando mitad
                Positioned(
                  left: 16, // o center/right según quieras
                  //bottom: -55,      // cuánto se superpone sobre la portada
                  top: _headerHeight - (_avatarSize / 2), // 90 - 55 = 35
                  child: SubirFotoWidget2(
                    alignment: Alignment.centerLeft,
                    badgePosition: CameraBadgePosition.bottomRight, // opcional
                    badgeColor: const Color(0xFF43A047),
                    icono: Icons.camera_alt,
                    texto: "Foto de Perfil",
                    initialFile: _fotoLocal, // <- img local
                    initialUrl: _fotoUrl, // <- img nube
                    onPicked: (file) async {
                      setState(() {
                        _fotoLocal = file;
                        _fotoUrl = null; // limpia url mientras sube
                      });

                      // Subir foto inmediatamente
                      try {
                        Cargando.show(context, message: 'Subiendo foto...');

                        final nuevaUrl = await SaveFotoStorage.subir(
                          file: file,
                          path: 'taxistas/{uid}/perfilTaxista/foto.jpg',
                          replace: true,
                        );

                        // Guardar URL en Firestore
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
                // ===== Nombre + correo en el "rincón vacío" derecho =====
                // Nota: SubirFotoWidget2 usa size=110; 16 (margen izq) + 110 (avatar) + 12 (separación)
                Positioned(
                  left:
                      16 +
                      _avatarSize +
                      12, // margen + ancho avatar + separación
                  right: 16,
                  // bottom: -40, // ajusta fino si lo quieres un poco más arriba/abajo
                  top: _headerHeight - 0, // ajusta fino si quieres
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Nombre con lápiz (editable)
                      GestureDetector(
                        onTap: _editarNombre,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                _name.isEmpty ? '---' : _name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              iconSize: 18,
                              color: Colors.black,
                              tooltip: 'Editar nombre',
                              onPressed: _editarNombre,
                              icon: const Icon(Icons.edit),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _correo == 'No definido' ? 'Sin correo' : _correo,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Compensa el solape para que el contenido no “choque”
          //const SizedBox(height: 45),
          // Contenido existente con padding de 16
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Divider(height: 0),
                // líneas “pegadas” al tile
                const Divider(height: 1, thickness: 0.8),
                Casillas(
                  title: 'Teléfono',
                  subtitle: _telefono,
                  leading: Casillas.blueCircleIcon(
                    Icons.phone,
                    backgroundColor: const Color(0xFF43A047),
                  ),
                  trailing: const Icon(Icons.edit, size: 18),
                  onTap: _editarTelefono,
                  showTopDivider: true, // línea arriba
                  showBottomDivider: false, // sin línea abajo
                ),
                Casillas(
                  title: 'Correo',
                  subtitle: _correo,
                  leading: Casillas.blueCircleIcon(
                    Icons.email,
                    backgroundColor: const Color(0xFF43A047),
                  ),
                  onTap: () {}, // Solo lectura
                  showTopDivider: true,
                  showBottomDivider: false,
                ),
                if (_servicioSeleccionado != null)
                  Casillas(
                    title: 'Servicio',
                    subtitle: _servicioSeleccionado!,
                    leading: _logoServicio != null && _logoServicio!.isNotEmpty
                        ? CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage: NetworkImage(_logoServicio!),
                          )
                        : Casillas.blueCircleIcon(
                            Icons.local_taxi,
                            backgroundColor: const Color(0xFF43A047),
                          ),
                    onTap: () {}, // Solo lectura
                    showTopDivider: true,
                    showBottomDivider: false,
                  ),
                Casillas(
                  title: 'Puntuación',
                  subtitle: _promedioEstrellas != null
                      ? '${_promedioEstrellas!.toStringAsFixed(1)} ★ (${_numeroResenias ?? 0} ${(_numeroResenias ?? 0) == 1 ? 'opinión' : 'opiniones'})'
                      : '5.0 ★ (Sin opiniones)',
                  leading: Casillas.blueCircleIcon(
                    Icons.star,
                    backgroundColor: const Color(0xFF43A047),
                  ),
                  onTap: () {},
                  showTopDivider: true,
                  showBottomDivider: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
