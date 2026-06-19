import 'dart:async';
import 'package:flutter/material.dart';

class ImageSlider2 extends StatefulWidget {
  const ImageSlider2({
    super.key,
    required this.images,
    this.height = 180,
    this.viewportFraction = 0.82,
    this.borderRadius = 18,
    this.enableIndicator = true, // 👈 mostrar/ocultar puntos
    this.indicatorSpacing = 10, // 👈 separación antes de los puntos
    this.autoPlay = false,
    this.autoPlayInterval = const Duration(seconds: 4),
    this.fit = BoxFit.cover,
    this.onPageChanged,
    this.onTap,
    this.backgroundColor = Colors.transparent,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
    this.infinite = false,

    // Sombra externa (por tarjeta)
    this.cardShadowColor = Colors.black,
    this.cardShadowOpacity = 0.60,
    this.cardShadowBlur = 4,
    this.cardShadowOffset = const Offset(0, 4),
  });

  final List<String> images;
  final double height;
  final double viewportFraction;
  final double borderRadius;

  /// Muestra los indicadores (puntitos) si hay 2+ imágenes.
  final bool enableIndicator;

  /// Separación vertical sobre los indicadores (sólo si se muestran).
  final double indicatorSpacing;

  final bool autoPlay;
  final Duration autoPlayInterval;
  final BoxFit fit;
  final ValueChanged<int>? onPageChanged;
  final ValueChanged<int>? onTap;
  final Color backgroundColor;

  /// Padding EXTERNO del componente (no el de los puntos).
  final EdgeInsetsGeometry padding;

  final bool infinite;

  // Sombra externa
  final Color cardShadowColor;
  final double cardShadowOpacity; // 0..1
  final double cardShadowBlur;
  final Offset cardShadowOffset;

  @override
  State<ImageSlider2> createState() => _ImageSlider2State();
}

class _ImageSlider2State extends State<ImageSlider2> {
  late final PageController _controller;
  late final int _initialPage;
  int _index = 0;
  Timer? _timer;

  int get _len => widget.images.length;

  @override
  void initState() {
    super.initState();
    _initialPage = (widget.infinite && _len > 1) ? _len * 1000 : 0;
    _controller = PageController(
      viewportFraction: widget.viewportFraction,
      initialPage: _initialPage,
    );

    if (widget.autoPlay && _len > 1) {
      _timer = Timer.periodic(widget.autoPlayInterval, (_) {
        if (!mounted) return;
        if (widget.infinite) {
          _controller.nextPage(
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
          );
        } else {
          final next = ((_index + 1) % _len);
          _controller.animateToPage(
            next,
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  bool _isNetwork(String src) =>
      src.startsWith('http://') || src.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    final br = Radius.circular(widget.borderRadius);
    final bool showDots = widget.enableIndicator && _len > 1;

    // Para conocer la altura disponible que nos impone el padre (p. ej. SizedBox 210)
    return LayoutBuilder(
      builder: (context, constraints) {
        // Altura total que nos dan (puede ser infinita si no nos limitan)
        final maxH = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : null;

        // Padding vertical del contenedor
        final EdgeInsets pad = widget.padding is EdgeInsets
            ? (widget.padding as EdgeInsets)
            : EdgeInsets.zero;
        final double padV = pad.top + pad.bottom;

        // Altura que ocupan los puntos (si se muestran)
        const double dotsHeight = 6.0;
        final double indicatorsBlock = showDots
            ? (widget.indicatorSpacing + dotsHeight)
            : 0.0;

        // Altura de la PageView: si el padre fija altura, nos adaptamos; si no, usamos widget.height
        final double pageViewHeight = (maxH != null)
            ? (maxH - padV - indicatorsBlock).clamp(0.0, double.infinity)
            : widget.height;

        return Container(
          color: widget.backgroundColor,
          padding: pad,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: pageViewHeight,
                child: PageView.builder(
                  controller: _controller,
                  physics: const BouncingScrollPhysics(),
                  itemCount: widget.infinite ? null : _len,
                  onPageChanged: (rawIndex) {
                    final real = (widget.infinite && _len > 0)
                        ? rawIndex % _len
                        : rawIndex;
                    setState(() => _index = real);
                    widget.onPageChanged?.call(real);
                  },
                  itemBuilder: (context, rawI) {
                    final i = (widget.infinite && _len > 0)
                        ? rawI % _len
                        : rawI;

                    return AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        double value;
                        if (_controller.position.haveDimensions) {
                          final double page =
                              _controller.page ??
                              _controller.initialPage.toDouble();
                          value = (page - rawI.toDouble()).abs();
                        } else {
                          value =
                              (_controller.initialPage.toDouble() -
                                      rawI.toDouble())
                                  .abs();
                        }
                        value = value.clamp(0.0, 1.0);
                        final scale = 1.0 - (value * 0.08);

                        return Center(
                          child: GestureDetector(
                            onTap: () => widget.onTap?.call(i),
                            child: Transform.scale(
                              scale: scale,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.all(br),
                                  boxShadow: [
                                    BoxShadow(
                                      color: widget.cardShadowColor.withOpacity(
                                        widget.cardShadowOpacity,
                                      ),
                                      blurRadius: widget.cardShadowBlur,
                                      offset: widget.cardShadowOffset,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.all(br),
                                  child: AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: _isNetwork(widget.images[i])
                                        ? Image.network(
                                            widget.images[i],
                                            fit: widget.fit,
                                            loadingBuilder: (c, w, p) =>
                                                p == null
                                                ? w
                                                : const Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  ),
                                            errorBuilder: (c, e, s) =>
                                                _errorBox(),
                                          )
                                        : Image.asset(
                                            widget.images[i],
                                            fit: widget.fit,
                                            errorBuilder: (c, e, s) =>
                                                _errorBox(),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Indicadores sólo si corresponde; si no, no se reserva espacio.
              if (showDots) ...[
                SizedBox(height: widget.indicatorSpacing),
                Wrap(
                  spacing: 6,
                  children: List.generate(_len, (i) {
                    final active = i == _index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: dotsHeight,
                      width: active ? 20 : 6,
                      decoration: BoxDecoration(
                        color: active ? Colors.black87 : Colors.black26,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    );
                  }),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _errorBox() => Container(
    color: Colors.grey.shade200,
    alignment: Alignment.center,
    child: const Icon(Icons.broken_image_outlined),
  );
}

/*
ImageSlider2(
  images: const [
    'assets/banners/banner1.jpg',      // imágenes (assets o URLs)
    'assets/banners/banner2.jpg',
    'assets/banners/banner3.jpg',
  ],
  height: 190,                         // alto del carrusel
  viewportFraction: 0.86,              // ancho que ocupa cada tarjeta (muestra “peek” de vecinas)
  borderRadius: 22,                    // radio de borde de la tarjeta
  enableIndicator: true,               // muestra los puntitos indicadores
  autoPlay: true,                      // activa avance automático
  autoPlayInterval: Duration(seconds: 4), // intervalo del autoplay
  fit: BoxFit.cover,                   // cómo se ajusta la imagen dentro
  backgroundColor: Colors.transparent, // color detrás del carrusel
  padding: EdgeInsets.symmetric(vertical: 12), // padding externo del carrusel
  infinite: true,                      // loop infinito (no hay tope)
  enableIndicator: true,     // ⬅️ muestra los puntos
  indicatorSpacing: 10,
  onPageChanged: (i) => debugPrint('cambió a $i'), // callback al cambiar
  onTap: (i) => debugPrint('tap en $i'),           // tap en tarjeta

  // SOMBRA EXTERNA (drop shadow por tarjeta)
  cardShadowColor: Colors.black,       // color base de la sombra
  cardShadowOpacity: 0.22,             // opacidad de la sombra (0..1)
  cardShadowBlur: 20,                  // blur-radius (difuminado)
  cardShadowOffset: Offset(0, 12),     // desplazamiento (x, y) de la sombra
)

*/
