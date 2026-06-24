import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:buses2/features/home_taxi_features/home_taxi/services/DriverOfferCounterOfferListenerService.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../documentos_vehiculo/services/documentos_config_service.dart';
import '../documentos_vehiculo/models/documento_config_model.dart';
import 'services/driver_offer_accepted_listener_service.dart';
import 'services/orders_listener.dart';
import 'widgets/menu_lateral.dart';

class HomeTaxista extends StatefulWidget {
  const HomeTaxista({Key? key}) : super(key: key);

  /// Key del Scaffold padre. Las páginas hijas (SolicitudesTaxistaPage, etc.)
  /// tienen su propio Scaffold local, así que `Scaffold.of(ctx)` no encuentra
  /// el drawer. Usa esta key para abrirlo desde donde sea:
  ///   HomeTaxista.scaffoldKey.currentState?.openDrawer();
  static final GlobalKey<ScaffoldState> scaffoldKey =
      GlobalKey<ScaffoldState>();

  @override
  State<HomeTaxista> createState() => _HomeTaxistaState();
}

class _HomeTaxistaState extends State<HomeTaxista> {
  int _currentIndex = 0;
  bool _verificandoDocumentos = true;
  bool _mostrarBannerDocumentos = false;
  int _cantidadDocumentosFaltantes = 0;

  void _syncIndexWithPath() {
    final p = Modular.to.path;
    if (p == '/home-taxista' || p == '/home-taxista/') {
      setState(() => _currentIndex = 0); // default
    } else if (p.contains('/home-taxista/viajes_taxista')) {
      setState(() => _currentIndex = 0);
    } else if (p.contains('/home-taxista/historial_taxista')) {
      setState(() => _currentIndex = 1);
    } else if (p.contains('/home-taxista/billetera_taxista')) {
      // ✅ sin espacio
      setState(() => _currentIndex = 2);
    } else if (p.contains('/home-taxista/chats_taxista')) {
      setState(() => _currentIndex = 3);
    }
  }

  @override
  void initState() {
    super.initState();
    _verificarModoUsuario();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = Modular.to.path;
      // Solo redirige si estás exactamente en el contenedor
      if (p == '/home-taxista' || p == '/home-taxista/') {
        Modular.to.navigate('/home-taxista/viajes_taxista');
      } else {
        _syncIndexWithPath();
      }
    });
    Modular.to.addListener(_syncIndexWithPath);
  }

  /// Verifica que el usuario tenga modo 'taxista' antes de validar documentos
  Future<void> _verificarModoUsuario() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          Modular.to.navigate('/login');
        }
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final modo = prefs.getString('modo');

      if (modo != 'taxista') {
        debugPrint(
          '⚠️ [HomeTaxista] Usuario con modo "$modo" intentó acceder a HomeTaxista',
        );
        if (mounted) {
          // Redirigir según el modo correcto
          if (modo == 'pasajero') {
            Modular.to.navigate('/home');
          } else if (modo == 'empresa') {
            Modular.to.navigate('/home-empresa');
          } else {
            Modular.to.navigate('/user-type-selection');
          }
        }
        return;
      }

      debugPrint('✅ [HomeTaxista] Usuario confirmado como taxista');
      // Iniciar escucha de órdenes SIEMPRE que sea taxista, antes de validar docs.
      // No debe bloquearse por documentos incompletos.
      OrderService.instance.startListening();
      // Asegurar que el listener de ofertas aceptadas del taxista esté activo
      await DriverOfferAcceptedListenerService.instance.startListening();
      await DriverOfferCounterOfferListenerService.instance.startListening();
      // Si es taxista, verificar documentos (solo muestra advertencia, no bloquea)
      await _verificarDocumentosCompletos();
    } catch (e) {
      debugPrint('❌ Error al verificar modo de usuario: $e');
      // En caso de error, redirigir a selección segura
      if (mounted) {
        Modular.to.navigate('/user-type-selection');
      }
    }
  }

  /// Verifica si el taxista tiene documentos completos
  Future<void> _verificarDocumentosCompletos() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _redirigirADocumentos('Usuario no autenticado', []);
        return;
      }

      // Cargar configuración de documentos desde Firestore
      debugPrint('📥 Cargando configuración de documentos para validación...');
      final configuracion =
          await DocumentosConfigService.cargarConfiguracionConFallback();

      final taxistaDoc = await FirebaseFirestore.instance
          .collection('taxistas')
          .doc(user.uid)
          .get();

      if (!taxistaDoc.exists) {
        _redirigirADocumentos('Perfil de taxista no encontrado', []);
        return;
      }

      final data = taxistaDoc.data();
      final documentosVehiculo =
          data?['documentosVehiculo'] as Map<String, dynamic>?;

      debugPrint(
        '📦 Campos en documentosVehiculo: ${documentosVehiculo?.keys.toList()}',
      );
      debugPrint('📊 Total de campos: ${documentosVehiculo?.length ?? 0}');

      if (documentosVehiculo == null || documentosVehiculo.isEmpty) {
        debugPrint('❌ documentosVehiculo está vacío o es null');
        _redirigirADocumentos('No hay documentos registrados', []);
        return;
      }

      // Verificar campos obligatorios básicos del Paso 0
      final camposObligatorios = [
        'marca',
        'color',
        'numeroAsientos',
        'numeroLicencia',
      ];

      final List<String> documentosFaltantes = [];

      for (final campo in camposObligatorios) {
        final valor = documentosVehiculo[campo];
        if (valor == null || (valor is String && valor.trim().isEmpty)) {
          documentosFaltantes.add('Datos del vehículo: $campo');
        }
      }

      // Verificar documentos según configuración dinámica
      final documentosRequeridos = configuracion.documentos
          .where(
            (doc) => doc.activo && doc.requerido == true && doc.tipo == 'foto',
          )
          .toList();

      debugPrint(
        '🔍 Validando ${documentosRequeridos.length} documentos obligatorios activos',
      );

      for (final doc in documentosRequeridos) {
        final valor = documentosVehiculo[doc.id];
        if (valor == null || (valor is String && valor.trim().isEmpty)) {
          documentosFaltantes.add('${doc.nombre} (Paso ${doc.paso})');
          debugPrint('❌ Falta documento: ${doc.nombre} (${doc.id})');
        } else {
          debugPrint('✅ Documento presente: ${doc.nombre}');
        }
      }

      if (documentosFaltantes.isNotEmpty) {
        _redirigirADocumentos(
          'Faltan documentos obligatorios',
          documentosFaltantes,
        );
        return;
      }

      // Todo OK
      setState(() => _verificandoDocumentos = false);
      debugPrint('✅ Todos los documentos verificados correctamente');

      // Verificar si hay documentos faltantes (no obligatorios)
      // para mostrar banner informativo
      _verificarDocumentosFaltantesParaBanner(
        configuracion,
        documentosVehiculo,
      );
    } catch (e) {
      debugPrint('❌ Error al verificar documentos: $e');
      // Si hay error, permitir acceso pero logear el error
      setState(() => _verificandoDocumentos = false);
    }
  }

  /// Verifica si hay documentos faltantes (obligatorios o no)
  /// para mostrar banner informativo sin bloquear el acceso
  void _verificarDocumentosFaltantesParaBanner(
    ConfiguracionDocumentos configuracion,
    Map<String, dynamic> documentosVehiculo,
  ) {
    try {
      final faltantes = DocumentosConfigService.obtenerDocumentosFaltantes(
        configuracion: configuracion,
        documentosUsuario: documentosVehiculo,
      );

      if (faltantes.isNotEmpty) {
        setState(() {
          _mostrarBannerDocumentos = true;
          _cantidadDocumentosFaltantes = faltantes.length;
        });
        debugPrint(
          '📢 Banner de documentos faltantes activado: ${faltantes.length} documentos',
        );
      }
    } catch (e) {
      debugPrint('❌ Error al verificar documentos faltantes para banner: $e');
    }
  }

  void _redirigirADocumentos(String razon, List<String> documentosFaltantes) {
    debugPrint('🔴🔴🔴 HOME_TAXISTA_PAGE: Redirigiendo a documentos');
    debugPrint('🔴 Razón: $razon');
    debugPrint('🔴 Documentos faltantes: $documentosFaltantes');
    debugPrint('🔴 Stack trace:');
    debugPrint(StackTrace.current.toString());
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.warning_rounded, color: Colors.orange, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Documentos Incompletos',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Debes completar todos los documentos obligatorios para poder trabajar como conductor.',
                    style: TextStyle(fontSize: 15, height: 1.4),
                  ),
                  if (documentosFaltantes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '📋 Documentos faltantes:',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...documentosFaltantes.map(
                            (doc) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '• $doc',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.red,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: const Text(
                      '📸 Te redirigiremos a la pantalla de registro de documentos para que completes los documentos faltantes.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  debugPrint('🔄 Usuario eligió volver a modo Pasajero');
                  Navigator.of(context).pop();

                  try {
                    // Cambiar modo a pasajero en Firestore
                    await FirebaseFirestore.instance
                        .collection('pasajeros')
                        .doc(FirebaseAuth.instance.currentUser?.uid)
                        .update({'modo': 'pasajero'});

                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('modo', 'pasajero');

                    if (mounted) {
                      Modular.to.navigate('/home');
                    }
                  } catch (e) {
                    debugPrint('❌ Error al cambiar a modo pasajero: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Error al cambiar de modo'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text(
                  'Volver a Pasajero',
                  style: TextStyle(fontSize: 14),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  debugPrint(
                    '🟡🟡🟡 MODAL: Usuario presionó botón para ir a documentos nuevos',
                  );
                  Navigator.of(context).pop();
                  Modular.to.pushNamed('/documentos-nuevos').then((_) {
                    // Verificar documentos después de volver
                    _verificarDocumentosCompletos();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  'Completar Documentos',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    // Detener listener global de órdenes al salir de HomeTaxista
    // OrderService.instance.stopListening();

    Modular.to.removeListener(_syncIndexWithPath);
    super.dispose();
  }

  void _onTap(int i) {
    setState(() => _currentIndex = i);
    switch (i) {
      case 0:
        Modular.to.navigate('/home-taxista/viajes_taxista');
        break;
      case 1:
        Modular.to.navigate('/home-taxista/historial_taxista');
        break;
      case 2:
        Modular.to.navigate('/home-taxista/billetera_taxista');
        break;
      case 3:
        Modular.to.navigate(
          '/home-taxista/chats_taxista',
          arguments: {'mode': 'taxista'},
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si está verificando documentos, mostrar loading
    // if (_verificandoDocumentos) {
    //   return Scaffold(
    //     body: Center(
    //       child: Column(
    //         mainAxisAlignment: MainAxisAlignment.center,
    //         children: const [
    //           CircularProgressIndicator(),
    //           SizedBox(height: 16),
    //           Text(
    //             'Verificando documentos...',
    //             style: TextStyle(fontSize: 16, color: Colors.grey),
    //           ),
    //         ],
    //       ),
    //     ),
    //   );
    // }

    // Interceptar el botón atrás para evitar volver a StartupPage
    return WillPopScope(
      onWillPop: () async {
        debugPrint('⚠️ Botón atrás presionado en HomeTaxistaPage');
        // Mostrar diálogo preguntando si quiere cerrar la app
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Salir de la aplicación'),
            content: const Text('¿Deseas cerrar la aplicación?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Salir', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        return shouldExit ?? false;
      },
      child: Scaffold(
        key: HomeTaxista.scaffoldKey,
        extendBody: true,
        // El drawer vive en el Scaffold padre para que, al abrirse, cubra
        // también la floating nav (comportamiento estándar de Flutter).
        drawer: const TaxiDrawer(),
        body: Column(
          children: [
            // Banner de documentos faltantes (no bloquea acceso)
            if (_mostrarBannerDocumentos)
              Material(
                color: Colors.orange.shade50,
                child: InkWell(
                  onTap: () {
                    Modular.to.pushNamed('/documentos-nuevos').then((_) {
                      // Recargar verificación después de volver
                      _verificarDocumentosCompletos();
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.orange.shade200,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange.shade800,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Documentos requeridos pendientes',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tienes $_cantidadDocumentosFaltantes documento${_cantidadDocumentosFaltantes > 1 ? "s" : ""} por completar',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.orange.shade700,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Contenido principal
            const Expanded(child: RouterOutlet()),
          ],
        ),

        bottomNavigationBar: _FloatingNavBar(
          currentIndex: _currentIndex,
          onTap: _onTap,
          items: const [
            _NavItemData(icon: Icons.list_alt_rounded, label: 'Viajes'),
            _NavItemData(icon: Icons.bar_chart_rounded, label: 'Historial'),
            _NavItemData(
              icon: Icons.account_balance_wallet_rounded,
              label: 'Billetera',
            ),
            _NavItemData(icon: Icons.chat_bubble_rounded, label: 'Chats'),
          ],
        ),
      ),
    );
  }
}

/// Modelo simple para los items de la nav flotante.
class _NavItemData {
  final IconData icon;
  final String label;
  const _NavItemData({required this.icon, required this.label});
}

/// Bottom navigation flotante: pill blanco redondeado con sombra,
/// separado de los bordes y con el item activo resaltado.
class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<_NavItemData> items;

  static const Color _activeColor = Color(0xFF0F172A);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 6, 14, 10 + bottomInset),
      child: Material(
        elevation: 14,
        shadowColor: Colors.black.withOpacity(0.20),
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(items.length, (i) {
              final active = i == currentIndex;
              return Expanded(
                child: _FloatingNavCell(
                  data: items[i],
                  active: active,
                  activeColor: _activeColor,
                  onTap: () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _FloatingNavCell extends StatelessWidget {
  const _FloatingNavCell({
    required this.data,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  final _NavItemData data;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        splashColor: activeColor.withOpacity(0.10),
        highlightColor: activeColor.withOpacity(0.06),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? activeColor.withOpacity(0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                data.icon,
                size: 22,
                color: active ? activeColor : Colors.black54,
              ),
              const SizedBox(height: 4),
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.1,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  color: active ? activeColor : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
