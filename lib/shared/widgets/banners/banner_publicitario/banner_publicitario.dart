import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/banner_model.dart';

class BannerPublicidad extends StatefulWidget {
  /// Lista de rutas (URL o assets) - Solo si NO usas stream
  final List<String>? imagenes;

  /// Stream de banners desde Firestore (opcional)
  final Stream<List<BannerModel>>? streamBanners;

  /// ¿Avanza solo?  Se controla desde fuera.
  final bool autoPlay;

  /// Intervalo entre cambios automáticos
  final Duration intervalo;

  const BannerPublicidad({
    super.key,
    this.imagenes,
    this.streamBanners,
    this.autoPlay = true,
    this.intervalo = const Duration(seconds: 5),
  }) : assert(
         imagenes != null || streamBanners != null,
         'Debes proveer imagenes o streamBanners',
       ),
       assert(
         !(imagenes != null && streamBanners != null),
         'No puedes proveer imagenes Y streamBanners al mismo tiempo',
       );

  @override
  State<BannerPublicidad> createState() => _BannerPublicidadState();
}

class _BannerPublicidadState extends State<BannerPublicidad> {
  /// Banners locales: se muestran si no hay banners remotos que funcionen
  /// (Storage devuelve 402/403/404, el stream falla o no hay activos).
  /// Para agregar más: copia la imagen a assets/images/, decláralo en
  /// pubspec.yaml y agrégalo a esta lista. Tamaño ideal 1200x800 (3:2).
  static const List<String> bannersLocales = [
    'assets/images/banner_respaldo.jpg',
    'assets/images/banner_2_rapido.jpg',
    'assets/images/banner_3_seguridad.jpg',
    'assets/images/banner_4_precio.jpg',
    'assets/images/banner_5_conductor.jpg',
  ];

  /// URLs que ya fallaron en esta sesión: se omiten para no mostrar el
  /// parpadeo en blanco cada vez que el carrusel vuelve a ellas.
  static final Set<String> _urlsFallidas = {};

  static const int _vueltas = 1000; // páginas "infinitas"

  PageController? _pageController;
  int _cantidadActual = 0;
  int _paginaActual = 0;
  Timer? _timer;

  @override
  void didUpdateWidget(covariant BannerPublicidad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoPlay != widget.autoPlay ||
        oldWidget.intervalo != widget.intervalo) {
      _configurarAutoPlay(_cantidadActual);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController?.dispose();
    super.dispose();
  }

  /// Crea el controller solo cuando cambia la cantidad de imágenes, para que
  /// las reconstrucciones del stream no reinicien el carrusel.
  PageController _controllerPara(int cantidad) {
    if (_pageController != null && cantidad == _cantidadActual) {
      return _pageController!;
    }
    _pageController?.dispose();
    _cantidadActual = cantidad;
    _paginaActual = 0;
    _pageController = PageController(initialPage: cantidad * _vueltas);
    _configurarAutoPlay(cantidad);
    return _pageController!;
  }

  void _configurarAutoPlay(int cantidad) {
    _timer?.cancel();
    if (!widget.autoPlay || cantidad < 2) return;
    _timer = Timer.periodic(widget.intervalo, (_) {
      final c = _pageController;
      if (!mounted || c == null || !c.hasClients) return;
      c.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }

  void _marcarFallida(String url) {
    if (_urlsFallidas.add(url)) {
      // Reconstruir fuera del frame actual para quitarla del carrusel.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  static Widget _asset(String ruta) => Image.asset(
        ruta,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF0D47A1)),
      );

  Widget _buildImagen(String ruta) {
    if (!ruta.startsWith('http')) return _asset(ruta);
    return Image.network(
      ruta,
      fit: BoxFit.cover,
      width: double.infinity,
      // Mientras carga, el banner local de fondo (no un recuadro blanco).
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : _asset(bannersLocales.first),
      errorBuilder: (_, error, __) {
        debugPrint('🟥 banner remoto falló ($ruta): $error');
        _marcarFallida(ruta);
        return _asset(bannersLocales.first);
      },
    );
  }

  /// Remotas que no han fallado; si no queda ninguna, las locales.
  List<String> _imagenesAMostrar(List<String> remotas) {
    final validas = remotas
        .map((u) => u.trim())
        .where((u) => u.isNotEmpty && !_urlsFallidas.contains(u))
        .toList();
    return validas.isNotEmpty ? validas : bannersLocales;
  }

  Widget _buildCarousel(List<String> imagenes) {
    if (imagenes.length == 1) return _buildImagen(imagenes.first);

    final controller = _controllerPara(imagenes.length);
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: PageView.builder(
            controller: controller,
            onPageChanged: (i) =>
                setState(() => _paginaActual = i % imagenes.length),
            itemBuilder: (_, i) => _buildImagen(imagenes[i % imagenes.length]),
          ),
        ),
        Positioned(
          top: 6,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(imagenes.length, (i) {
              final activo = _paginaActual == i;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: activo ? 10 : 8,
                height: activo ? 10 : 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: activo
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.45),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 6 / 4,
      child: widget.streamBanners != null
          ? StreamBuilder<List<BannerModel>>(
              stream: widget.streamBanners,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint('🟥 Error en banner stream: ${snapshot.error}');
                }
                final remotas = (snapshot.data ?? const <BannerModel>[])
                    .map((b) => b.imageUrl)
                    .toList();
                return _buildCarousel(_imagenesAMostrar(remotas));
              },
            )
          : _buildCarousel(_imagenesAMostrar(widget.imagenes!)),
    );
  }
}

/*Ejemplo de uso:
BannerPublicidad(
  imagenes: [
    'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=1080',
    'assets/images/onboarding_bg.jpg',
    'https://images.unsplash.com/photo-1542281286-9e0a16bb7366?w=1080',
    'assets/images/onboarding_bg.jpg',
  ],
  autoPlay: true,                     // ← deslizamiento automático
  intervalo: Duration(seconds: 5),    // ← tiempo de deslizamiento
),

Nota importante:
flutter:
  assets:
    - assets/images/onboarding_bg.jpg
    # agrega los demás…
Asegúrate de que las imágenes estén en pubspec.yaml.
Si son URLs, no es necesario.
*/
/* Recomendaciones para banners:
Relación de aspecto	≈ 3 : 1
Tamaño ideal	1080 × 360 px
Tamaño mínimo	720 × 240 px
Formato	JPG o PNG, ≤ 1 MB
*/
