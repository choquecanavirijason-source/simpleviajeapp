import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 🔹 Enum para seleccionar el tipo de línea
enum MarcadorLineType { linea1, linea2 }

class MarcadorAnimado extends StatelessWidget {
  final MarcadorLineType line;
  final double lineHeight;
  final String tiempoTexto;
  final String textoSecundario;
  final dynamic icono;
  final Color iconColor;
  final Color lineColor;
  final double offsetY;
  final bool mostrarTiempo;
  final bool mostrarSecundario;
  final bool mostrarCajaTexto;

  const MarcadorAnimado({
    super.key,
    required this.line,
    required this.lineHeight,
    required this.tiempoTexto,
    required this.textoSecundario,
    required this.icono,
    required this.iconColor,
    required this.lineColor,
    this.offsetY = -150,
    this.mostrarTiempo = false,
    this.mostrarSecundario = false,
    this.mostrarCajaTexto = false,
  });

  @override
  Widget build(BuildContext context) {
    /// 🔍 Detectamos si el icono es un Widget o un IconData
    Widget iconWidget;
    if (icono is IconData) {
      iconWidget = Icon(icono as IconData, color: iconColor, size: 32);
    } else if (icono is Widget) {
      iconWidget = icono as Widget;
    } else {
      throw ArgumentError(
        'El parámetro "icono" debe ser un IconData o un Widget válido.',
      );
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Transform.translate(
            offset: Offset(0, offsetY),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🔷 Caja del ícono + texto
                if (mostrarCajaTexto)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: lineColor, width: 0.6),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: iconWidget,
                        ),
                        if (mostrarTiempo || mostrarSecundario) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (mostrarTiempo)
                                  Text(
                                    tiempoTexto,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                if (mostrarSecundario)
                                  Text(
                                    textoSecundario,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                // 🔷 Línea + punto SOLO cuando la caja está visible
                if (mostrarCajaTexto) ...[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 3,
                    height: lineHeight,
                    decoration: BoxDecoration(
                      color: lineColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),

                  if (line == MarcadorLineType.linea2)
                    Container(
                      margin: const EdgeInsets.only(top: 20),
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: lineColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: lineColor.withOpacity(0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* Ejemplo de uso:
const MarcadorAnimado(
  line: MarcadorLineType.linea1, // o linea2
  lineHeight: 50,
  tiempoTexto: "Duracion del viaje: 4 min",
  textoSecundario: "Bs 12.50",
  icono: WidgetCargandoPro2(size: 28, color: Colors.green),
  //icono: Icons.place, 
  iconColor: Colors.green,
  lineColor: Colors.green,
  offsetY: -155,
  mostrarTiempo: false,
  mostrarSecundario: false,
  mostrarCajaTexto: true,
),
*/

//import 'package:flutter/material.dart';

class WidgetCargandoPro extends StatefulWidget {
  final double size;
  final Color color;
  final double strokeWidth;
  final bool showGlow; // ✨ Brillo suave opcional

  const WidgetCargandoPro({
    super.key,
    this.size = 36,
    this.color = Colors.blueAccent,
    this.strokeWidth = 3,
    this.showGlow = true,
  });

  @override
  State<WidgetCargandoPro> createState() => _WidgetCargandoProState();
}

class _WidgetCargandoProState extends State<WidgetCargandoPro>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glowColor = widget.color.withOpacity(0.4);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ✨ Efecto de halo o brillo suave
          if (widget.showGlow)
            AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                final scale = 1 + 0.3 * (1 - _controller.value);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: widget.size * 1.4,
                    height: widget.size * 1.4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: glowColor,
                      boxShadow: [
                        BoxShadow(
                          color: glowColor,
                          blurRadius: 15,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

          // 🔵 Indicador circular elegante
          RotationTransition(
            turns: _controller,
            child: CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _ArcPainter(
                color: widget.color,
                strokeWidth: widget.strokeWidth,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 🎨 Pintor personalizado del arco giratorio
class _ArcPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _ArcPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rect = Offset.zero & size;
    const startAngle = -0.5; // ángulo inicial
    const sweepAngle = 1.6 * 3.1416 / 2; // longitud del arco (≈ 140°)

    canvas.drawArc(
      rect.deflate(strokeWidth / 2),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}

//import 'package:flutter/material.dart';
//import 'dart:math' as math;

class WidgetCargandoPro2 extends StatefulWidget {
  final double size;
  final Color color;
  final double strokeWidth;
  final bool showGlow;

  const WidgetCargandoPro2({
    super.key,
    this.size = 40,
    this.color = Colors.blueAccent,
    this.strokeWidth = 3,
    this.showGlow = true,
  });

  @override
  State<WidgetCargandoPro2> createState() => _WidgetCargandoPro2State();
}

class _WidgetCargandoPro2State extends State<WidgetCargandoPro2>
    with TickerProviderStateMixin {
  late AnimationController _controllerOuter;
  late AnimationController _controllerInner;

  @override
  void initState() {
    super.initState();

    _controllerOuter = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _controllerInner = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controllerOuter.dispose();
    _controllerInner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glowColor = widget.color.withOpacity(0.3);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.showGlow)
            Container(
              width: widget.size * 1.4,
              height: widget.size * 1.4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: glowColor,
                boxShadow: [
                  BoxShadow(color: glowColor, blurRadius: 18, spreadRadius: 4),
                ],
              ),
            ),

          // 🔷 Anillo exterior rotando en sentido horario
          RotationTransition(
            turns: _controllerOuter,
            child: CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _OrbitPainter(
                color: widget.color,
                strokeWidth: widget.strokeWidth,
                sweepAngle: 270,
                startAngle: 0,
              ),
            ),
          ),

          // 🔷 Anillo interior rotando en sentido antihorario
          RotationTransition(
            turns: Tween(begin: 0.0, end: -1.0).animate(_controllerInner),
            child: CustomPaint(
              size: Size(widget.size * 0.6, widget.size * 0.6),
              painter: _OrbitPainter(
                color: widget.color.withOpacity(0.8),
                strokeWidth: widget.strokeWidth * 0.8,
                sweepAngle: 210,
                startAngle: 1.0,
              ),
            ),
          ),

          // ⚪ Centro sólido
          Container(
            width: widget.size * 0.15,
            height: widget.size * 0.15,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: widget.color.withOpacity(0.5), blurRadius: 5),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 🎨 Pintor personalizado para los anillos orbitantes
class _OrbitPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double sweepAngle;
  final double startAngle;

  _OrbitPainter({
    required this.color,
    required this.strokeWidth,
    required this.sweepAngle,
    required this.startAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect.deflate(strokeWidth / 2),
      startAngle,
      math.pi * sweepAngle / 180,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.sweepAngle != sweepAngle;
}
