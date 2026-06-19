import 'package:flutter/material.dart';

class RouteSection extends StatelessWidget {
  final String origen;
  final String destino;
  final DateTime fecha;
  final Color primaryColor;
  final Color secondaryColor;

  const RouteSection({
    super.key,
    required this.origen,
    required this.destino,
    required this.fecha,
    required this.primaryColor,
    required this.secondaryColor,
  });

  // Funciones de formato integradas para la fecha
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        // ESTILO CLAVE: BoxShadow para el efecto "elevado"
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
          _buildLocationRow(
            icon: Icons.my_location,
            label: 'Origen',
            address: origen,
            color: primaryColor,
          ),
          const SizedBox(height: 16),
          // Línea divisoria
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Container(width: 2, height: 30, color: Colors.grey[300]),
          ),
          const SizedBox(height: 16),
          // Destino
          _buildLocationRow(
            icon: Icons.location_on,
            label: 'Destino',
            address: destino,
            color: secondaryColor,
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          // Fecha y Hora
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

  Widget _buildLocationRow({
    required IconData icon,
    required String label,
    required String address,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                address,
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
    );
  }
}
