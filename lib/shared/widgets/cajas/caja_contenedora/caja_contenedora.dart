// import 'package:buses2/shared/widgets/cajas/caja_contenedora/caja_contenedora.dart';
import 'package:flutter/material.dart';

enum TituloAlign { start, center, end }

class CajaContenedora extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color color;
  final double borderRadius;
  final String? titulo;
  final IconData? iconoTitulo; // 👈 icono fijo a la izquierda
  final IconData? iconoDerecha; // 👈 icono fijo a la derecha
  final TituloAlign tituloAlign;

  const CajaContenedora({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.color = Colors.white,
    this.borderRadius = 12,
    this.titulo,
    this.iconoTitulo,
    this.iconoDerecha,
    this.tituloAlign = TituloAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (titulo != null) ...[
            Row(
              children: [
                // 👈 Ícono izquierdo con espacio a la derecha (solo si existe)
                if (iconoTitulo != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.grey.shade200,
                      child: Icon(iconoTitulo, size: 18, color: Colors.black87),
                    ),
                  ),

                // 👈 Título
                Expanded(
                  child: Align(
                    alignment: () {
                      switch (tituloAlign) {
                        case TituloAlign.center:
                          return Alignment.center;
                        case TituloAlign.end:
                          return Alignment.centerRight;
                        case TituloAlign.start:
                        default:
                          return Alignment.centerLeft;
                      }
                    }(),
                    child: Text(
                      titulo!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // 👈 Ícono derecho con espacio a la izquierda (solo si existe)
                if (iconoDerecha != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Icon(iconoDerecha, size: 20, color: Colors.black54),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

/* Ejemplo de uso:
final _formKey = GlobalKey<FormState>(); // solo si usas formularios inputs
body: Form(
  key: _formKey,
  child: ListView( // Evita que la sombra de la caja desaparesca
    clipBehavior: Clip.none,           // 👈 esto es lo que evita el corte
    padding: const EdgeInsets.all(16), // padding global
    children: [
      CajaContenedora(
        titulo: 'Datos Generales',
        iconoTitulo: Icons.local_taxi,
        tituloAlign: TituloAlign.center,
        iconoDerecha: Icons.local_taxi,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // tus inputs...
          ],
        ),
      ),
      const SizedBox(height: 10),
      CajaContenedora(
        titulo: 'Campos de Datos',
        child: Boton1(...),
      ),
      const SizedBox(height: 10),
      CajaContenedora(
        titulo: 'Campos de Archivos',
        child: Boton1(...),
      ),
      const SizedBox(height: 20),
      CajaBoton(...),
    ],
  ),
),
*/
/* Detalles de uso:
CajaContenedora(
  titulo: 'Información del Taxi',
  iconoTitulo: Icons.local_taxi,
  tituloAlign: TituloAlign.center, // start, center, end
  iconoDerecha: Icons.info_outline,
  child: ...,
  padding: const EdgeInsets.all(16), // opcional, por defecto 16
  margin: EdgeInsets.zero,           // opcional, por defecto 0
  color: Colors.white,               // opcional, por defecto blanco
  borderRadius: 12,                  // opcional, por defecto 12
),
*/
