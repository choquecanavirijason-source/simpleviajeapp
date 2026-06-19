import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum LeftAction { menu, back, custom }

enum TitleSize { small, big }

class AppBar1 extends StatelessWidget implements PreferredSizeWidget {
  const AppBar1({
    super.key,
    this.titulo,
    this.subtitulo,
    this.iconoIzquierda,
    this.iconoDerecha,
    this.onTapIzquierda,
    this.onTapDerecha,
    this.leftAction = LeftAction.menu,
    this.titleSize = TitleSize.small,
    this.backgroundColor = Colors.white,
    this.hasShadow = true,
    this.textColor = Colors.black87,
    this.systemOverlayIsLight = false,

    // 👇 NUEVO: widget central opcional (slot). Si viene, reemplaza título/subtítulo.
    this.center,
  });

  final String? titulo;
  final String? subtitulo;
  final IconData? iconoIzquierda;
  final IconData? iconoDerecha;
  final VoidCallback? onTapIzquierda;
  final VoidCallback? onTapDerecha;
  final LeftAction leftAction;
  final TitleSize titleSize;
  final bool systemOverlayIsLight;

  /// Color de fondo (por defecto blanco)
  final Color backgroundColor;

  /// Mostrar sombra (por defecto true)
  final bool hasShadow;

  /// Color para textos e íconos (por defecto negro)
  final Color textColor;

  /// 👇 NUEVO
  final Widget? center;

  void _handleLeftTap(BuildContext ctx) {
    switch (leftAction) {
      case LeftAction.menu:
        Scaffold.of(ctx).openDrawer();
        break;
      case LeftAction.back:
        Navigator.of(ctx).maybePop();
        break;
      case LeftAction.custom:
        if (onTapIzquierda != null) onTapIzquierda!();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final leftIcon =
        iconoIzquierda ??
        (leftAction == LeftAction.menu ? Icons.menu : Icons.arrow_back);

    final bool hasTitle = (titulo ?? '').isNotEmpty;
    final bool hasSubtitle = (subtitulo ?? '').isNotEmpty;
    final double titleFont = titleSize == TitleSize.big ? 20 : 16;

    final overlayStyle = systemOverlayIsLight
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Container(
        height: preferredSize.height,
        decoration: BoxDecoration(
          color: backgroundColor,
          boxShadow: hasShadow
              ? const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                // Botón izquierdo
                Builder(
                  builder: (ctx) => IconButton(
                    icon: Icon(leftIcon, color: textColor),
                    onPressed: () => _handleLeftTap(ctx),
                  ),
                ),

                // CENTRO: si center != null, lo mostramos; si no, va título/subtítulo de antes
                Expanded(
                  child: Center(
                    child:
                        center ??
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (hasTitle)
                              Text(
                                titulo!,
                                style: TextStyle(
                                  fontSize: titleFont,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                              ),
                            if (hasTitle && hasSubtitle)
                              const SizedBox(height: 2),
                            if (hasSubtitle)
                              Text(
                                subtitulo!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textColor.withOpacity(0.6),
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                              ),
                          ],
                        ),
                  ),
                ),

                // Botón derecho
                if (iconoDerecha != null)
                  IconButton(
                    icon: Icon(iconoDerecha, color: textColor),
                    onPressed: onTapDerecha,
                  )
                else
                  const SizedBox(width: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(100);
}

/* Atributos especiales:
menu → Boton Izquierdo Abre el menú lateral y decides que hacer con el botón derecho.
back → Boton Izquierdo Regresa atras y decides que hacer con el botón derecho.
custom → Tú decides qué hacer con el botón izquierdo y derecho.
*/
/* Se usa así:
/// Ejemplo: menu
drawer: Drawer(), // ← menú lateral
appBar: AppBar1(
  titleSize     : TitleSize.big,
  titulo        : 'Información Requerida',
  subtitulo     : 'Subtítulo opcional',
  backgroundColor: Colors.blueAccent, // Colors.transparent,
  systemOverlayIsLight: true, // hora/batería en blanco
  textColor: Colors.white,
  hasShadow: false, // true con sombra, false sin sombra
  leftAction    : LeftAction.menu, // back, custom, menu
  iconoIzquierda: Icons.menu,
  iconoDerecha  : Icons.settings,
  onTapDerecha  : () => debugPrint('Ajustes'),
),
/// Ejemplo: back
appBar: AppBar1(
  titleSize     : TitleSize.big,
  titulo        : 'Información Requerida',
  subtitulo     : 'Subtítulo opcional',
  backgroundColor: Colors.blueAccent, // Colors.transparent,
  systemOverlayIsLight: true, // hora/batería en blanco
  textColor: Colors.white,
  hasShadow: false, // true con sombra, false sin sombra
  leftAction    : LeftAction.back, // back, custom, menu
  iconoIzquierda: Icons.arrow_back,
  iconoDerecha  : Icons.settings,
  onTapDerecha  : () => debugPrint('Ajustes'),
),
/// Ejemplo: custom
appBar: AppBar1(
  titleSize     : TitleSize.big,
  titulo        : 'Información Requerida',
  subtitulo     : 'Subtítulo opcional',
  backgroundColor: Colors.blueAccent, // Colors.transparent,
  systemOverlayIsLight: true, // hora/batería en blanco
  textColor: Colors.white,
  hasShadow: false, // true con sombra, false sin sombra
  leftAction    : LeftAction.custom, // back, custom, menu
  iconoIzquierda: Icons.menu,
  iconoDerecha  : Icons.settings,
  onTapIzquierda: () => debugPrint('Botón personalizado'),
  onTapDerecha  : () => debugPrint('Ajustes'),
),
*/
