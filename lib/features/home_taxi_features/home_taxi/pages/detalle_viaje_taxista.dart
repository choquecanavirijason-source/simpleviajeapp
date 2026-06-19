import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:buses2/shared/widgets/app_bar/app_bar.dart';

class DetallesViajeTaxista extends StatelessWidget {
  const DetallesViajeTaxista({super.key});

  @override
  Widget build(BuildContext context) {
    final args = Modular.args.data as Map<String, dynamic>;
    final datosPasajero = args['datosPasajero'] as Map<String, dynamic>?;
    final idViaje = args['idViaje'];
    final origen = args['origen'] as String;
    final destino = args['destino'] as String;
    final fecha = args['fecha'] as DateTime;
    final distancia = args['distancia'] as double;
    final total = args['total'] as double;
    final estado = args['estado'];

    // Extraer datos del pasajero - pueden estar en 'perfil' o en la raíz
    final perfil = datosPasajero?['perfil'] as Map<String, dynamic>?;
    final nombrePasajero =
        perfil?['name'] ??
        datosPasajero?['name'] ??
        datosPasajero?['nombre'] ??
        'Pasajero';
    final fotoPasajero =
        perfil?['photoUrl'] ??
        datosPasajero?['photoUrl'] ??
        datosPasajero?['fotoPerfil'] as String?;
    final telefonoPasajero =
        perfil?['phone'] ??
        datosPasajero?['phone'] ??
        datosPasajero?['telefono'] as String?;
    final estrellasPasajero =
        datosPasajero?['promedioEstrellas'] as double? ?? 5.0;

    final colorPrimario = Colors.green[700]!;
    final colorSecundario = Colors.red[700]!;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar1(
        titleSize: TitleSize.big,
        titulo: 'Detalles del Viaje',
        backgroundColor: colorPrimario,
        textColor: Colors.white,
        hasShadow: false,
        leftAction: LeftAction.back,
        iconoIzquierda: Icons.arrow_back,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card del Pasajero
            _buildPasajeroCard(
              nombrePasajero,
              fotoPasajero,
              telefonoPasajero,
              estrellasPasajero,
              colorPrimario,
            ),
            const SizedBox(height: 20),

            // Ruta del viaje
            _buildRouteSection(
              origen,
              destino,
              fecha,
              colorPrimario,
              colorSecundario,
            ),
            const SizedBox(height: 20),
            // Resumen
            _buildSummaryCard(distancia, total, colorPrimario),
            const SizedBox(height: 20),
            // Estado
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _getEstadoColor(estado.toString()).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getEstadoColor(estado.toString()),
                    width: 2,
                  ),
                ),
                child: Text(
                  'Estado: ${_getEstadoTexto(estado.toString())}',
                  style: TextStyle(
                    fontSize: 16,
                    color: _getEstadoColor(estado.toString()),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasajeroCard(
    String nombre,
    String? fotoUrl,
    String? telefono,
    double rating,
    Color primaryColor,
  ) {
    // double rating =
    // rating = rating.clamp(0.0, 5.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar del pasajero
          CircleAvatar(
            radius: 35,
            backgroundColor: primaryColor.withOpacity(0.1),
            backgroundImage: fotoUrl != null && fotoUrl.isNotEmpty
                ? NetworkImage(fotoUrl)
                : null,
            child: fotoUrl == null || fotoUrl.isEmpty
                ? Icon(Icons.person, size: 35, color: primaryColor)
                : null,
          ),
          const SizedBox(width: 16),
          // Información del pasajero
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pasajero',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  nombre,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                // ⭐ Widget de Estrellas Agregado Aquí
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: 18,
                      color: Colors.amber, // Color típico de las estrellas
                    ),
                    const SizedBox(width: 4),
                    Text(
                      rating.toStringAsFixed(
                        1,
                      ), // Muestra la calificación con un decimal
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                // Fin del Widget de Estrellas
                if (telefono != null && telefono.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.phone, size: 16, color: primaryColor),
                      const SizedBox(width: 6),
                      Text(
                        telefono,
                        style: TextStyle(
                          fontSize: 14,
                          color: primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteSection(
    String origen,
    String destino,
    DateTime fecha,
    Color primaryColor,
    Color secondaryColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ruta del Viaje',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          // Origen
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.my_location, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Origen',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      origen,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Línea divisoria
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Container(width: 2, height: 30, color: Colors.grey[300]),
          ),
          const SizedBox(height: 16),
          // Destino
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: secondaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.location_on, color: secondaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Destino',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      destino,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          // Fecha
          Row(
            children: [
              Icon(Icons.calendar_today, size: 18, color: primaryColor),
              const SizedBox(width: 8),
              Text(
                _formatFecha(fecha),
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(double distancia, double total, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen del Viaje',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoItem(
                Icons.route,
                'Distancia',
                '${distancia.toStringAsFixed(2)} km',
                primaryColor,
              ),
              Container(width: 1, height: 40, color: Colors.grey[300]),
              _buildInfoItem(
                Icons.attach_money,
                'Total',
                'ARS ${total.toStringAsFixed(2)}',
                primaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatFecha(DateTime fecha) {
    final meses = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return '${fecha.day} ${meses[fecha.month - 1]} ${fecha.year} - ${_formatHora(fecha)}';
  }

  String _formatHora(DateTime fecha) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(fecha.hour)}:${pad(fecha.minute)}';
  }

  Color _getEstadoColor(String estado) {
    final e = estado.toLowerCase();
    if (e.contains('completado')) return Colors.green[700]!;
    if (e.contains('cancelado')) return Colors.red[700]!;
    if (e.contains('curso') || e.contains('camino')) return Colors.blue[700]!;
    return Colors.orange[700]!;
  }

  String _getEstadoTexto(String estado) {
    return estado.toString().split('.').last;
  }
}
