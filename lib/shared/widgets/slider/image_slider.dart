import 'dart:async';
import 'package:flutter/material.dart';

class ImageSlider extends StatefulWidget {
  const ImageSlider({
    super.key,
    required this.images, // URLs, assets o ImageProvider
    this.height = 220,
    this.showDots = true,
    this.onPageChanged,
    this.infinite = false, // loop infinito opcional
    this.autoPlay = false, // autoplay on/off
    this.autoPlayInterval = const Duration(seconds: 3),
    this.showArrows = true, // mostrar/ocultar flechas
    this.openOnTap = true, // visor de imagenes
  });

  final List<dynamic> images;
  final double height;
  final bool showDots;
  final ValueChanged<int>? onPageChanged;
  final bool infinite;
  final bool autoPlay;
  final Duration autoPlayInterval;
  final bool showArrows;
  final bool openOnTap;

  @override
  State<ImageSlider> createState() => _ImageSliderState();
}

class _ImageSliderState extends State<ImageSlider> {
  static const _kRadius = BorderRadius.all(Radius.circular(12));
  static const _kInitialPage = 0;
  static const _kAnimDuration = Duration(milliseconds: 450);
  static const _kAnimCurve = Curves.easeInOutCubic;

  late final PageController _pageCtrl;
  int _index = _kInitialPage;
  Timer? _autoTimer;

  int get _loopBaseStart {
    final len = widget.images.length;
    if (len <= 0) return 0;
    return len * 1000; // punto medio grande para infinito
  }

  @override
  void initState() {
    super.initState();
    final start = widget.infinite ? _loopBaseStart : _kInitialPage;
    _index = start;
    _pageCtrl = PageController(initialPage: start);
    _setupAutoplay();
  }

  @override
  void didUpdateWidget(covariant ImageSlider oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.infinite != widget.infinite ||
        oldWidget.images.length != widget.images.length) {
      final start = widget.infinite ? _loopBaseStart : _kInitialPage;
      _index = start;
      _pageCtrl.jumpToPage(start);
    }

    if (oldWidget.autoPlay != widget.autoPlay ||
        oldWidget.autoPlayInterval != widget.autoPlayInterval) {
      _setupAutoplay();
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _setupAutoplay() {
    _autoTimer?.cancel();
    final len = widget.images.length;
    if (!widget.autoPlay || len <= 1) return;

    _autoTimer = Timer.periodic(widget.autoPlayInterval, (_) {
      if (!mounted) return;
      final lenNow = widget.images.length;
      if (lenNow <= 1) return;

      final realIndex = widget.infinite ? _index % lenNow : _index;

      if (!widget.infinite && realIndex >= lenNow - 1) {
        _autoTimer?.cancel();
        return;
      }

      _pageCtrl.nextPage(duration: _kAnimDuration, curve: _kAnimCurve);
    });
  }

  ImageProvider _providerOf(dynamic src) {
    if (src is ImageProvider) return src;
    if (src is String) {
      if (src.startsWith('http')) return NetworkImage(src);
      if (src.startsWith('assets/')) return AssetImage(src);
      return AssetImage(src);
    }
    throw ArgumentError('Tipo de imagen no soportado: $src');
  }

  void _openFullScreen(int initialRealIndex) {
    showGeneralDialog(
      context: context,
      barrierLabel: 'image-viewer',
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(
        0.9,
      ), // fondo negro semitransparente
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim, secondaryAnim) {
        return _FullScreenGallery(
          images: widget.images,
          initialIndex: initialRealIndex,
          providerOf: _providerOf,
        );
      },
      transitionBuilder: (_, anim, __, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final len = widget.images.length;

    if (len == 0) {
      return ClipRRect(
        borderRadius: _kRadius,
        child: Container(
          height: widget.height,
          color: cs.surfaceContainerHighest.withOpacity(.3),
          alignment: Alignment.center,
          child: Icon(
            Icons.image_not_supported_outlined,
            color: cs.onSurface.withOpacity(.5),
          ),
        ),
      );
    }

    final itemCount = widget.infinite ? null : len; // null => builder infinito

    final pageView = ClipRRect(
      borderRadius: _kRadius,
      child: SizedBox(
        height: widget.height,
        child: PageView.builder(
          controller: _pageCtrl,
          physics: const BouncingScrollPhysics(),
          itemCount: itemCount,
          onPageChanged: (i) {
            setState(() => _index = i);
            final real = widget.infinite ? i % len : i;
            widget.onPageChanged?.call(real);
          },
          itemBuilder: (_, i) {
            final real = widget.infinite ? i % len : i;
            final provider = _providerOf(widget.images[real]);
            final image = Image(
              image: provider,
              fit: BoxFit.cover,
              width: double.infinity,
              height: widget.height,
            );

            return Stack(
              fit: StackFit.expand,
              children: [
                Container(color: cs.surfaceContainerHighest.withOpacity(.3)),

                // 👉 solo abre full-screen si openOnTap == true
                if (widget.openOnTap)
                  InkWell(onTap: () => _openFullScreen(real), child: image)
                else
                  image,

                // sombras laterales...
                IgnorePointer(
                  child: Row(
                    children: const [
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [Colors.black26, Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerRight,
                              end: Alignment.centerLeft,
                              colors: [Colors.black26, Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );

    final realIndex = widget.infinite ? _index % len : _index;

    final arrows = Positioned.fill(
      child: IgnorePointer(
        ignoring: !widget.showArrows || len <= 1,
        child: Row(
          children: [
            _ArrowButton(
              visible: widget.showArrows
                  ? (widget.infinite ? true : realIndex > 0)
                  : false,
              onTap: () {
                _pageCtrl.previousPage(
                  duration: _kAnimDuration,
                  curve: _kAnimCurve,
                );
              },
            ),
            const Spacer(),
            _ArrowButton(
              right: true,
              visible: widget.showArrows
                  ? (widget.infinite ? true : realIndex < len - 1)
                  : false,
              onTap: () {
                _pageCtrl.nextPage(
                  duration: _kAnimDuration,
                  curve: _kAnimCurve,
                );
              },
            ),
          ],
        ),
      ),
    );

    final dots = Positioned(
      left: 0,
      right: 0,
      bottom: 8,
      child: Visibility(
        visible: widget.showDots && len > 1,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(len, (i) {
            final active = i == realIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              width: active ? 16 : 6,
              decoration: BoxDecoration(
                color: active ? cs.primary : cs.onSurface.withOpacity(.35),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
      ),
    );

    return Stack(children: [pageView, arrows, dots]);
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    this.right = false,
    required this.onTap,
    this.visible = true,
  });

  final bool right;
  final VoidCallback onTap;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(left: right ? 0 : 4, right: right ? 4 : 0),
      child: Align(
        alignment: right ? Alignment.centerRight : Alignment.centerLeft,
        child: Material(
          color: Colors.black45,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.chevron_right, color: Colors.white, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

/// ===== Visor de pantalla completa =====
class _FullScreenGallery extends StatefulWidget {
  const _FullScreenGallery({
    required this.images,
    required this.initialIndex,
    required this.providerOf,
  });

  final List<dynamic> images;
  final int initialIndex;
  final ImageProvider Function(dynamic src) providerOf;

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late final PageController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fondo negro + safe area
    return Material(
      color: Colors.black,
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Paginador de imágenes
            PageView.builder(
              controller: _ctrl,
              itemCount: widget.images.length,
              itemBuilder: (_, i) {
                final src = widget.images[i];

                Widget img;
                if (src is String && src.startsWith('http')) {
                  img = Image.network(
                    src,
                    fit: BoxFit.contain,
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    },
                    errorBuilder: (ctx, err, stack) {
                      return const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white70,
                          size: 48,
                        ),
                      );
                    },
                  );
                } else {
                  final provider = widget.providerOf(src);
                  img = Image(image: provider, fit: BoxFit.contain);
                }

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragEnd: (_) => Navigator.of(context).maybePop(),
                  onTap: () {}, // (tap no cierra accidentalmente)
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Center(child: img),
                  ),
                );
              },
            ),

            // Botón cerrar (arriba a la izquierda)
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: 'Cerrar',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* Ejemplo de uso:
ImageSlider(
  images: [
      'https://picsum.photos/id/1018/800/500',
      'https://picsum.photos/id/1015/800/500',
      'https://picsum.photos/id/1019/800/500',
      'https://picsum.photos/id/1020/800/500',
      'https://picsum.photos/id/1024/800/500',
      'https://picsum.photos/id/1025/800/500',
      'https://picsum.photos/id/1041/800/500',
  ],
  height: 220,     // puedes cambiar el alto si quieres
  showDots: true,  // puedes ocultar/mostrar puntos
  showArrows: false, // puedes ocultar/mostrar flechas
  // onPageChanged: (i) => debugPrint('Página: $i'), // opcional
  infinite: true,  // loop infinito
  autoPlay: true, // autoplay activado
  autoPlayInterval: Duration(seconds: 4),
  openOnTap: true, // abre el visor de img
),
*/
