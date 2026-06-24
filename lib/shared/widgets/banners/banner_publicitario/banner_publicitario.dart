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
  PageController? _pageController;
  int _paginaActual = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Si tenemos imagenes hardcoded, inicializamos el controller
    if (widget.imagenes != null) {
      final imagenesLength = widget.imagenes!.length;
      final inicio = imagenesLength * 1000;
      _pageController = PageController(initialPage: inicio);
      _paginaActual = inicio % imagenesLength;
      _configurarAutoPlay(imagenesLength);
    }
  }

  @override
  void didUpdateWidget(covariant BannerPublicidad oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si cambia la bandera autoPlay reiniciamos el temporizador.
    if (oldWidget.autoPlay != widget.autoPlay ||
        oldWidget.intervalo != widget.intervalo) {
      if (widget.imagenes != null) {
        _configurarAutoPlay(widget.imagenes!.length);
      }
    }
  }

  void _configurarAutoPlay(int imagenesLength) {
    _timer?.cancel();
    if (widget.autoPlay && imagenesLength > 0) {
      _timer = Timer.periodic(widget.intervalo, (_) {
        if (!mounted || _pageController == null) return;
        _pageController!.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController?.dispose();
    super.dispose();
  }

  Widget _buildImagen(String ruta) {
    final esUrl = ruta.startsWith('http');
    return esUrl
        ? Image.network(ruta, fit: BoxFit.cover)
        : Image.asset(ruta, fit: BoxFit.cover);
  }

  Widget _buildCarousel(List<String> imagenes, {PageController? controller}) {
    // Si no se provee controller, creamos uno local
    final pageController =
        controller ?? PageController(initialPage: imagenes.length * 1000);
    final shouldDisposeController = controller == null;

    return StatefulBuilder(
      builder: (context, setLocalState) {
        // Configurar autoplay local si es necesario
        if (shouldDisposeController && widget.autoPlay) {
          _timer?.cancel();
          _timer = Timer.periodic(widget.intervalo, (_) {
            if (!mounted) return;
            pageController.nextPage(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
            );
          });
        }

        return Stack(
          alignment: Alignment.topCenter,
          children: [
            // Carrusel infinito
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: PageView.builder(
                controller: pageController,
                onPageChanged: (i) {
                  final newPage = i % imagenes.length;
                  setLocalState(() => _paginaActual = newPage);
                  setState(() => _paginaActual = newPage);
                },
                itemBuilder: (_, i) =>
                    _buildImagen(imagenes[i % imagenes.length]),
              ),
            ),

            // Puntitos indicadores
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
                          : Colors.white.withOpacity(0.45),
                    ),
                  );
                }),
              ),
            ),
          ],
        );
      },
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
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  print('Error en banner stream: ${snapshot.error}');
                  return Center(
                    child: Text(
                      'Error al cargar banners: ${snapshot.error}',
                      style: const TextStyle(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                final banners = snapshot.data ?? [];
                if (banners.isEmpty) {
                  return const Center(
                    child: Text('No hay banners disponibles'),
                  );
                }

                final imagenes = banners.map((b) => b.imageUrl).toList();
                return _buildCarousel(imagenes);
              },
            )
          : _buildCarousel(widget.imagenes!, controller: _pageController),
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
