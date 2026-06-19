import 'package:flutter/material.dart';

// Caja genérica para mostrar los detalles de la transacción
class CajaMoney extends StatelessWidget {
  final String titulo;
  final String monto;
  final String fecha;
  final Color color;
  final IconData icono;

  const CajaMoney({
    Key? key,
    required this.titulo,
    required this.monto,
    required this.fecha,
    required this.color,
    required this.icono,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, // Hace que la tarjeta ocupe el 100% del ancho
      margin: EdgeInsets.fromLTRB(0, 0, 0, 0), // Margen entre tarjetas
      padding: EdgeInsets.all(0), //
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.grey.withOpacity(0.9), // Borde gris suave
            width: 0.5, // Ancho del borde
          ),
        ),
        elevation: 6, // Elevación para profundidad
        shadowColor: Colors.black.withOpacity(0.9), // Sombra más fuerte
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 7, 16, 7), // Espaciado interno
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                icono, // Usamos el ícono que pasamos como parámetro
                color: color,
                size: 40,
              ),
              const SizedBox(width: 16), // Espacio entre el ícono y el texto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      monto,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    fecha,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(
                    height: 4,
                  ), // Espacio entre la fecha y la flecha
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* Ejemplo de uso:
CajaMoney(
  titulo: 'Comisiones',
  monto: '\$10.00',
  fecha: '2025-08-02',
  // color: Colors.blue,
  color: Colors.green,
  icono: Icons.monetization_on,
),
*/
