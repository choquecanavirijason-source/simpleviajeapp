import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:buses2/features/home/data/recientes.dart';
import 'package:buses2/features/home/data/lugares_guardados.dart';

import 'package:buses2/features/home/controller/home_controller.dart';
import 'package:buses2/features/home/widgets/appBar_ubicacion.dart';
import 'package:buses2/shared/layout/padding_margin.dart';
import 'package:buses2/shared/services/chat_listener_service.dart';
import 'package:buses2/shared/widgets/banners/banner_publicitario/banner_publicitario.dart';
import 'package:buses2/shared/services/banner_service.dart';
import 'package:buses2/shared/services/login_google/login_google_service.dart';
import 'package:buses2/shared/widgets/cajas/sugerencias_busqueda/sugerencias_busqueda.dart';
import 'package:buses2/features/home/widgets/menu_lateral.dart';
import 'package:buses2/core/services/ubicacion_usuario/ubicacion_user.dart';
import 'package:buses2/features/home/widgets/modal_inferior_AyB.dart';
import 'package:buses2/core/utils/particionarDireccion.dart';
import 'package:buses2/shared/widgets/ofertas/oferta_card.dart';
import 'package:buses2/shared/widgets/ofertas/oferta_builder.dart';

// Firebase
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:buses2/features/chats/data/repositories/chat_repository.dart';
import 'package:buses2/features/chats/service/firestore_profiles.dart';
import 'dart:async';
import 'package:rxdart/rxdart.dart';

// ===== Diseño: paleta y utilidades =====
class AppColors {
  static const Color primaryBlue = Color(0xFF00359D);
  static const Color successGreen = Color(0xFF2CAC3F);
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color surfaceWhite = Colors.white;
}

class ViajesPage extends StatefulWidget {
  const ViajesPage({Key? key}) : super(key: key);

  @override
  State<ViajesPage> createState() => _ViajesPageState();
}

class _ViajesPageState extends State<ViajesPage>
    with SingleTickerProviderStateMixin {
  final HomeController controller = HomeController();
  final TextEditingController _destinoController = TextEditingController();
  final UbicacionUsuario ubicacion = UbicacionUsuario();
  final BannerService _bannerService = BannerService();

  double? latitud;
  double? longitud;
  String calle = '';
  String ciudad = '';
  String departamento = '';
  String pais = '';

  String direccionGuardada = 'Tu Ubicación';
  bool _loading = false;

  // Animaciones
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // recientes
  List<SugerenciaEntry> _recientesUI = [];
  List<DestinoReciente> _recientesData = [];
  bool _cargandoRecientes = false;
  String? _errorRecientes;

  // lugares guardados
  LugarGuardado? _casa;
  LugarGuardado? _trabajo;

  // Control de actualización de ofertas (debounce)
  DateTime? _lastOfertasUpdate;
  QuerySnapshot<Map<String, dynamic>>? _cachedOfertasSnapshot;
  List<LugarGuardado> _favoritos = [];

  // Agregar estado para controlar el tipo de orden a mostrar
  bool _mostrarOrdenesProgramadas = false;

  Future<void> mostrarUbicacionUsuario() async {
    final coords = await ubicacion.coordenadasUser();
    if (coords != null) {
      final direccionCompleta = await ubicacion
          .obtenerDireccionDesdeCoordenadas(coords['lat']!, coords['lng']!);
      if (direccionCompleta != null) {
        final partes = direccionPorPartes(direccionCompleta);
        setState(() {
          latitud = coords['lat'];
          longitud = coords['lng'];
          calle = partes['calle'] ?? '';
          ciudad = partes['ciudad'] ?? '';
          departamento = partes['departamento'] ?? '';
          pais = partes['pais'] ?? '';
          direccionGuardada = partes['titulo'] ?? direccionCompleta;
        });
      }
    }
  }

  Future<void> _cargarSugerenciasRecientes() async {
    setState(() {
      _cargandoRecientes = true;
      _errorRecientes = null;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() {
          _cargandoRecientes = false;
          _recientesUI = [];
          _recientesData = [];
        });
        return;
      }

      final recientes = await RecientesRepo.obtenerRecientes(uid: uid);

      final ui = <SugerenciaEntry>[];
      for (final r in recientes) {
        String titulo;
        if (r.texto?.trim().isNotEmpty ?? false) {
          titulo = r.texto!.trim();
        } else if (r.calle?.trim().isNotEmpty ?? false) {
          titulo = r.calle!.trim();
        } else {
          titulo = 'Destino reciente';
        }

        final sub = [
          r.ciudad?.trim(),
          r.pais?.trim(),
        ].where((e) => (e ?? '').isNotEmpty).join(' - ');

        ui.add(
          SugerenciaEntry(
            titulo: titulo,
            subtitulo: sub.isNotEmpty ? sub : 'Ubicación reciente',
            leadingIcon: Icons.location_on,
            trailingIcon: r.programado ? Icons.schedule : Icons.north_east,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _recientesUI = ui;
        _recientesData = recientes;
        _cargandoRecientes = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorRecientes = e.toString();
        _cargandoRecientes = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    mostrarUbicacionUsuario();
    _cargarSugerenciasRecientes();
    _cargarLugaresGuardados();

    // Inicializar animaciones
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    // Iniciar animación
    _animationController.forward();
  }

  Future<void> _cargarLugaresGuardados() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final casa = await LugaresGuardadosRepo.obtenerLugar(
      uid: uid,
      tipo: 'casa',
    );
    final trabajo = await LugaresGuardadosRepo.obtenerLugar(
      uid: uid,
      tipo: 'trabajo',
    );
    final favoritos = await LugaresGuardadosRepo.obtenerFavoritos(uid: uid);

    if (mounted) {
      setState(() {
        _casa = casa;
        _trabajo = trabajo;
        _favoritos = favoritos;
      });
    }
  }

  Future<void> _irACasa() async {
    if (_casa == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configura tu dirección de casa primero')),
      );
      Modular.to.pushNamed('/lugares-guardados');
      return;
    }

    await mostrarUbicacionUsuario();
    await Modular.to.pushNamed(
      '/mapa-destino',
      arguments: {
        'lat': latitud,
        'lng': longitud,
        'calle': calle,
        'ciudad': ciudad,
        'pais': pais,
        'departamento': departamento,
        'destinoLat': _casa!.lat,
        'destinoLng': _casa!.lng,
        'destinoCalle': _casa!.calle,
        'destinoCiudad': _casa!.ciudad,
        'destinoPais': _casa!.pais,
        'destinoDepartamento': _casa!.departamento,
        'destinoTexto': _casa!.texto ?? _casa!.nombre,
        'openSheet2': true,
      },
    );
  }

  Future<void> _irATrabajo() async {
    if (_trabajo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configura tu dirección de trabajo primero'),
        ),
      );
      Modular.to.pushNamed('/lugares-guardados');
      return;
    }

    await mostrarUbicacionUsuario();
    await Modular.to.pushNamed(
      '/mapa-destino',
      arguments: {
        'lat': latitud,
        'lng': longitud,
        'calle': calle,
        'ciudad': ciudad,
        'pais': pais,
        'departamento': departamento,
        'destinoLat': _trabajo!.lat,
        'destinoLng': _trabajo!.lng,
        'destinoCalle': _trabajo!.calle,
        'destinoCiudad': _trabajo!.ciudad,
        'destinoPais': _trabajo!.pais,
        'destinoDepartamento': _trabajo!.departamento,
        'destinoTexto': _trabajo!.texto ?? _trabajo!.nombre,
        'openSheet2': true,
      },
    );
  }

  Future<void> _mostrarFavoritos() async {
    if (_favoritos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tienes favoritos guardados')),
      );
      Modular.to.pushNamed('/lugares-guardados');
      return;
    }

    final seleccionado = await showModalBottomSheet<LugarGuardado>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.star, color: Color(0xFFFFA726)),
                  const SizedBox(width: 12),
                  const Text(
                    'Mis Favoritos',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListView.separated(
                shrinkWrap: true,
                itemCount: _favoritos.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final fav = _favoritos[index];
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFA726).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.star, color: Color(0xFFFFA726)),
                    ),
                    title: Text(
                      fav.nombre,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      fav.calle ?? fav.texto ?? 'Ubicación guardada',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    onTap: () => Navigator.pop(context, fav),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );

    if (seleccionado != null) {
      await mostrarUbicacionUsuario();
      await Modular.to.pushNamed(
        '/mapa-destino',
        arguments: {
          'lat': latitud,
          'lng': longitud,
          'calle': calle,
          'ciudad': ciudad,
          'pais': pais,
          'departamento': departamento,
          'destinoLat': seleccionado.lat,
          'destinoLng': seleccionado.lng,
          'destinoCalle': seleccionado.calle,
          'destinoCiudad': seleccionado.ciudad,
          'destinoPais': seleccionado.pais,
          'destinoDepartamento': seleccionado.departamento,
          'destinoTexto': seleccionado.texto ?? seleccionado.nombre,
          'openSheet2': true,
        },
      );
    }
  }

  @override
  void dispose() {
    _destinoController.dispose();
    controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _irAMapaDestinoCon(DestinoReciente d) async {
    // Origen actual
    await mostrarUbicacionUsuario();

    Modular.to.pushNamed(
      '/mapa-destino',
      arguments: {
        // Origen (A)
        'lat': latitud,
        'lng': longitud,
        'calle': calle,
        'ciudad': ciudad,
        'pais': pais,

        // Destino (B)
        'destinoLat': d.lat,
        'destinoLng': d.lng,
        'destinoTexto': d.texto,
        'destinoCalle': d.calle,
        'destinoCiudad': d.ciudad,
        'destinoPais': d.pais,

        // Forzar “trazado + Modal 2”
        'openSheet2': true,
      },
    );
  }

  /// Firma que pide SugerenciasBusqueda: Future<void> Function(SugerenciaEntry)
  Future<void> _onSugerenciaTap(SugerenciaEntry entry) async {
    final idx = _recientesUI.indexWhere(
      (e) => e.titulo == entry.titulo && e.subtitulo == entry.subtitulo,
    );
    if (idx >= 0 && idx < _recientesData.length) {
      final d = _recientesData[idx];
      if (d.lat != null && d.lng != null) {
        await _irAMapaDestinoCon(d);
      } else {
        debugPrint('⚠️ Sugerencia sin lat/lng; no se puede trazar.');
      }
    } else {
      debugPrint(
        '⚠️ No encontré la sugerencia en la lista (posible desalineación).',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Modular.get<LoginService>();
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBars.navbarUbicacion(
        context: context,
        controller: controller,
        onStateUpdate: () async {
          setState(() {});
        },
        direccion: direccionGuardada,
      ),
      drawer: MenuLateral(auth: auth),
      body: Stack(
        children: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                padding: AppSpacing.container,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner desde Firestore (en tarjeta elegante)
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BannerPublicidad(
                          streamBanners: _bannerService.streamBannersActivos(),
                          autoPlay: true,
                          intervalo: const Duration(seconds: 5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ¿A dónde vamos? (hero search bar)
                    _HeroSearchBar(
                      loading: _loading,
                      onTap: () async {
                        setState(() => _loading = true);
                        try {
                          await mostrarUbicacionUsuario();
                          await ModalInferiorAyB.mostrar(
                            context: context,
                            destinoController: _destinoController,
                            lat: latitud,
                            lng: longitud,
                            calle: calle,
                            ciudad: ciudad,
                            pais: pais,
                            departamento: departamento,
                          );
                        } finally {
                          if (mounted) setState(() => _loading = false);
                        }
                      },
                    ),

                    const SizedBox(height: 28),

                    // Ofertas en tiempo real
                    _buildOfertasTaxistasEnTiempoReal(),

                    const SizedBox(height: 28),

                    // Accesos rápidos
                    _buildQuickActions(),

                    const SizedBox(height: 28),

                    // Card de Destinos recientes (solo si hay algo que mostrar)
                    if (_recientesUI.isNotEmpty ||
                        _cargandoRecientes ||
                        _errorRecientes != null)
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionHeader(
                              icon: Icons.history_rounded,
                              title: 'Destinos recientes',
                              color: AppColors.successGreen,
                            ),
                            const SizedBox(height: 12),

                            if (_cargandoRecientes)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'Cargando ubicaciones recientes…',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            if (_errorRecientes != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  'No se pudieron cargar recientes: $_errorRecientes',
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),

                            SugerenciasBusqueda(
                              controller: _destinoController,
                              onUpdate: _onSugerenciaTap,
                              items: _recientesUI,
                              mostrarSubtitulo: true,
                              dense: false,
                              showDivider: true,
                              iconSize: 24,
                              itemVerticalPadding: 10,
                              leadingGap: 10,
                              trailingGap: 6,
                              defaultLeadingColor: AppColors.successGreen,
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget de accesos rápidos

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.flash_on_rounded,
          title: 'Accesos rápidos',
          color: AppColors.primaryBlue,
          trailing: TextButton.icon(
            onPressed: () =>
                Modular.to.navigate('/home/lugares-guardados'),
            icon: const Icon(Icons.tune_rounded, size: 17),
            label: const Text(
              'Configurar',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryBlue,
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.home_rounded,
                label: 'Casa',
                color: const Color(0xFF43A047),
                onTap: _irACasa,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.work_rounded,
                label: 'Trabajo',
                color: const Color(0xFF1E88E5),
                onTap: _irATrabajo,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.star_rounded,
                label: 'Favoritos',
                color: const Color(0xFFFFA726),
                onTap: _mostrarFavoritos,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Obtiene la última orden en estado 'pedido' del pasajero actual
  /// Ahora busca tanto en 'ordenes' como en 'ordenesProgramados'
  /// Si [soloProgramadas] es true, solo busca en ordenesProgramados
  /// Si [soloProgramadas] es false, solo busca en ordenes
  Stream<List<DocumentSnapshot>> _getTodasLasOrdenesActivas({
    bool soloProgramadas = false,
  }) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    final collectionRef = FirebaseFirestore.instance
        .collection('ordenesPasajeros')
        .doc(uid)
        .collection(soloProgramadas ? 'ordenesProgramados' : 'ordenes');

    return collectionRef.where('estado', isEqualTo: 'pedido').snapshots().map((
      snapshot,
    ) {
      // Retornamos TODAS las órdenes ordenadas por fecha
      final docs = snapshot.docs.toList();
      docs.sort((a, b) {
        final aTime = a.data()['createdAt'] as Timestamp?;
        final bTime = b.data()['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });
      return docs; // Devolvemos la lista entera, no solo el primero
    });
  }

  /// Verifica si hay órdenes programadas disponibles
  Stream<bool> _hayOrdenesProgramadasDisponibles() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(false);

    return FirebaseFirestore.instance
        .collection('ordenesPasajeros')
        .doc(uid)
        .collection('ordenesProgramados')
        .where('estado', isEqualTo: 'pedido')
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }

  /// Widget que muestra ofertas en tiempo real de la última orden en estado "pedido"
  Widget _buildOfertasTaxistasEnTiempoReal() {
    return StreamBuilder<bool>(
      stream: _hayOrdenesProgramadasDisponibles(),
      builder: (context, hayProgramadasSnapshot) {
        final hayProgramadas = hayProgramadasSnapshot.data ?? false;

        return StreamBuilder<List<DocumentSnapshot>>(
          // Usamos el nuevo stream que devuelve LISTA
          stream: _getTodasLasOrdenesActivas(
            soloProgramadas: _mostrarOrdenesProgramadas,
          ),
          builder: (context, ordenesSnapshot) {
            final ordenes = ordenesSnapshot.data ?? [];

            return Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(
                    icon: Icons.local_taxi_rounded,
                    color: AppColors.primaryBlue,
                    title: _mostrarOrdenesProgramadas
                        ? 'Ofertas programadas'
                        : 'Ofertas de drivers',
                    trailing: ordenes.isNotEmpty
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.successGreen.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: AppColors.successGreen,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${ordenes.length} activa${ordenes.length == 1 ? "" : "s"}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.successGreen,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : null,
                  ),
                  if (hayProgramadas) ...[
                    const SizedBox(height: 12),
                    _buildToggleButton(),
                  ],
                  const SizedBox(height: 14),

                  if (ordenes.isEmpty)
                    _buildEmptyState()
                  else
                    Column(
                      children: ordenes.map((ordenDoc) {
                        return _BloqueOfertasDeOrden(
                          ordenDoc: ordenDoc,
                          esProgramado: _mostrarOrdenesProgramadas,
                          onAceptarOferta: _aceptarOferta,
                        );
                      }).toList(),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_taxi_rounded,
              color: AppColors.primaryBlue,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Sin solicitudes activas',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pide un viaje y aquí verás las ofertas de los drivers en tiempo real.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  /// Segmented control para alternar entre órdenes normales y programadas.
  Widget _buildToggleButton() {
    Widget seg({
      required String label,
      required IconData icon,
      required bool esProgramadasOption,
      required Color activeColor,
    }) {
      final active = _mostrarOrdenesProgramadas == esProgramadasOption;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (active) return;
            setState(() {
              _mostrarOrdenesProgramadas = esProgramadasOption;
              _cachedOfertasSnapshot = null;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: active ? activeColor : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: activeColor.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: active ? Colors.white : Colors.black54,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    color: active ? Colors.white : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          seg(
            label: 'Normales',
            icon: Icons.directions_car_rounded,
            esProgramadasOption: false,
            activeColor: AppColors.successGreen,
          ),
          seg(
            label: 'Programadas',
            icon: Icons.schedule_rounded,
            esProgramadasOption: true,
            activeColor: AppColors.primaryBlue,
          ),
        ],
      ),
    );
  }

  /// Método para aceptar una oferta
  Future<void> _aceptarOferta({
    required BuildContext context,
    required String ordenPath,
    required String ofertaId,
    required String precio,
  }) async {
    try {
      final db = FirebaseFirestore.instance;
      final ordenRef = db.doc(ordenPath);
      final ofertaRef = ordenRef.collection('ofertas').doc(ofertaId);

      String? uidTaxistaFromOffer;
      String? taxistaNombre;
      String? taxistaPhotoUrl;

      // Ejecutar transacción
      await db.runTransaction((tx) async {
        // 1. Obtener datos de la oferta
        final ofertaSnap = await tx.get(ofertaRef);
        if (!ofertaSnap.exists) {
          throw 'La oferta ya no existe.';
        }
        final ofertaData = ofertaSnap.data() as Map<String, dynamic>;
        final estado = (ofertaData['estado'] ?? '').toString();
        if (estado != 'pendiente') return;

        // Obtener uid del taxista
        final uidTaxista =
            (ofertaData['uidTaxista'] ??
                    ofertaData['idTaxista'] ??
                    ofertaData['uid'] ??
                    '')
                .toString();
        uidTaxistaFromOffer = uidTaxista;
        taxistaNombre = ofertaData['nombre']?.toString() ?? 'Conductor';
        taxistaPhotoUrl = ofertaData['foto']?.toString() ?? '';

        // Precio ofertado
        final precioOfertadoNum =
            ofertaData['precioOfertado'] ??
            ofertaData['precioOfrecido'] ??
            ofertaData['precioRecomendado'];
        final precioOfertado = (precioOfertadoNum is num)
            ? precioOfertadoNum.toDouble()
            : double.tryParse(precio) ?? 0.0;

        // 2. Actualizar la oferta a estado 'aceptado'
        tx.update(ofertaRef, {
          'estado': 'aceptado',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 3. Actualizar la orden a estado 'aceptado' y guardar info completa
        final updates = <String, dynamic>{
          'estado': 'aceptado',
          'uidTaxista': uidTaxista,
          'ofertaAceptadaId': ofertaId,
          'tarifa.total': precioOfertado,
          'tarifa.precioOfertado': precioOfertado,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        tx.update(ordenRef, updates);
      });

      // 4. Crear el chat después de la transacción
      if (uidTaxistaFromOffer != null && uidTaxistaFromOffer!.isNotEmpty) {
        final pasajeroUid = FirebaseAuth.instance.currentUser?.uid;
        if (pasajeroUid != null) {
          try {
            // Obtener perfil del pasajero
            String pasajeroNombre = 'Pasajero';
            String pasajeroPhotoUrl = '';
            try {
              final p = await getPassengerPublic(pasajeroUid);
              pasajeroNombre = p['name'] ?? pasajeroNombre;
              pasajeroPhotoUrl = p['photoUrl'] ?? pasajeroPhotoUrl;
            } catch (_) {}

            // Crear el chat (taxista primero, pasajero segundo)
            final chatId = await ChatRepository().createChat(
              uidTaxistaFromOffer!,
              pasajeroUid,
              taxistaNombre ?? 'Conductor',
              pasajeroNombre,
              taxistaPhotoUrl ?? '',
              pasajeroPhotoUrl,
            );
            // escuchar mensajes en el chat creado
            // ChatListenerService.instance.startListening();
            // Guardar chatId en la orden
            if (chatId != null) {
              await ordenRef.set({'chatId': chatId}, SetOptions(merge: true));
            }
          } catch (e) {
            debugPrint('Error creando chat: $e');
          }
        }
      }
      Modular.to.navigate('/home/historial');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Oferta aceptada'),
            backgroundColor: Color(0xFF43A047),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo aceptar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _BloqueOfertasDeOrden extends StatelessWidget {
  final DocumentSnapshot ordenDoc;
  final bool esProgramado;
  final Function({
    required BuildContext context,
    required String ordenPath,
    required String ofertaId,
    required String precio,
  })
  onAceptarOferta;

  const _BloqueOfertasDeOrden({
    Key? key,
    required this.ordenDoc,
    required this.esProgramado,
    required this.onAceptarOferta,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dataOrden = ordenDoc.data() as Map<String, dynamic>?;
    // Opcional: Mostrar destino para diferenciar si hay varias órdenes
    final destino = dataOrden?['destino']?['texto'] ?? 'Destino desconocido';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // // Título de la orden específica (útil si hay varias)
        // Padding(
        //   padding: const EdgeInsets.symmetric(vertical: 8.0),
        //   child: Text(
        //     "Viaje a: $destino",
        //     style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
        //   ),
        // ),

        // El Stream de ofertas específico para ESTA orden
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: ordenDoc.reference
              .collection('ofertas')
              .where('estado', isEqualTo: 'pendiente')
              .snapshots(),
          builder: (context, ofertasSnapshot) {
            if (!ofertasSnapshot.hasData)
              return const LinearProgressIndicator();

            final ofertas = ofertasSnapshot.data!.docs;

            // Ordenar ofertas (mayor a menor precio o estrellas, o por fecha)
            // Aquí copio tu lógica de ordenamiento
            final ofertasOrdenadas = ofertas.toList();
            // ... tu lógica de sort aquí ...

            if (ofertasOrdenadas.isEmpty) {
              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text("Esperando conductores para esta orden..."),
              );
            }

            return Column(
              children: ofertasOrdenadas.map((ofertaDoc) {
                final oferta = ofertaDoc.data();
                // ... Extraer datos (nombre, precio, etc) ...
                // Copia tu lógica de extracción de datos aquí

                return buildOfferCardFromDoc(
                  context: context,
                  ofertaDoc: ofertaDoc,
                  ordenPath: ordenDoc.reference.path,
                  esProgramado: esProgramado,
                  onAccept: onAceptarOferta,
                );
              }).toList(),
            );
          },
        ),
        const Divider(height: 30, thickness: 2), // Separador entre órdenes
      ],
    );
  }
}

/// Tarjeta de acceso rápido (card blanca + icono en círculo del color de la categoría).
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: color.withOpacity(0.12),
        highlightColor: color.withOpacity(0.06),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Encabezado reutilizable para secciones (icono en chip + título + acción opcional).
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Hero search bar tipo "¿A dónde vamos?" — luce como input pero abre el modal de destino.
class _HeroSearchBar extends StatelessWidget {
  const _HeroSearchBar({required this.onTap, required this.loading});

  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: loading ? null : onTap,
        splashColor: AppColors.successGreen.withOpacity(0.1),
        highlightColor: AppColors.successGreen.withOpacity(0.05),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.successGreen.withOpacity(0.25),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.successGreen.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.search_rounded,
                  color: AppColors.successGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '¿A dónde vamos?',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      loading
                          ? 'Cargando ubicación…'
                          : 'Toca para elegir tu destino',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: AppColors.successGreen,
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.successGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
