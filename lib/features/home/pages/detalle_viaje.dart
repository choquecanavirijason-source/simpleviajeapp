import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:buses2/shared/widgets/app_bar/app_bar.dart';

// Importamos los widgets actualizados con el nuevo estilo
import '../widgets/detalle_viaje/driver_card.dart';
import '../widgets/detalle_viaje/route_section.dart';
import '../widgets/detalle_viaje/summary_card.dart';

class DetallesViaje extends StatelessWidget {
  const DetallesViaje({super.key});

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

  @override
  Widget build(BuildContext context) {
    final args = Modular.args.data as Map<String, dynamic>;
    final datosTaxista = args['datosTaxista'] as Map<String, dynamic>?;
    final origen = args['origen'] as String;
    final destino = args['destino'] as String;
    final fecha = args['fecha'] as DateTime;
    final distancia = args['distancia'] as double;
    final total = args['total'] as double;
    final estado = args['estado'];

    final nombreConductor =
        datosTaxista?['nombre'] ??
        datosTaxista?['name'] ??
        'Conductor no asignado';
    final fotoPerfilConductor =
        datosTaxista?['fotoPerfil'] ?? datosTaxista?['photoUrl'] as String?;
    final telefonoConductor =
        datosTaxista?['telefono'] ?? datosTaxista?['phone'] as String?;
    final estrellasPConductor =
        datosTaxista?['promedioEstrellas'] as double? ?? 5.0;

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
            // 1. Uso de la Tarjeta de Conductor con el nuevo estilo
            DriverCard(
              name: nombreConductor,
              photoUrl: fotoPerfilConductor,
              phone: telefonoConductor,
              primaryColor: colorPrimario,
              rating: estrellasPConductor,
            ),
            const SizedBox(height: 20),

            // 2. Uso de la Sección de Ruta con el nuevo estilo
            RouteSection(
              origen: origen,
              destino: destino,
              fecha: fecha,
              primaryColor: colorPrimario,
              secondaryColor: colorSecundario,
            ),
            const SizedBox(height: 20),

            // 3. Card de Resumen (Asegúrate de que 'SummaryCard' tiene el BoxShadow)
            SummaryCard(
              distancia: distancia,
              total: total,
              primaryColor: colorPrimario,
            ),
            const SizedBox(height: 20),

            // 4. Estado con el estilo detallado (Se mantiene aquí por sencillez)
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
}
