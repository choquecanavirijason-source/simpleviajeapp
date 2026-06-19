import 'package:flutter/material.dart';
import 'package:buses2/features/mapa_destino/modal_programar_viaje/calendar_es_modal.dart';
import 'package:buses2/shared/widgets/modal_inferior/modal_inferior2.dart';
import 'package:buses2/features/mapa_destino/widgets/direccion.dart';
import 'package:buses2/features/mapa_destino/widgets/tarifa_control_card.dart';
// 👇 import del DTO que devuelve tu calendario

/// Panel del Modal inferior 2 (SOLO UI).
/// Extraído del page para reusarlo como widget declarativo.
class ModalInferior2Block extends StatelessWidget {
  const ModalInferior2Block({
    super.key,
    required this.controller,
    required this.initialChildSize,
    required this.minChildSize,
    required this.maxChildSize,
    // datos y callbacks que antes estaban en el State del page:
    required this.tarifa,
    required this.onTarifaChanged,
    required this.servicio,
    this.onTaxiTap,
    this.onMotoTap,
    this.puntoACalle,
    this.puntoACiudad,
    this.puntoAPais,
    required this.bFijado,
    this.fixCalle,
    this.fixCiudad,
    this.fixPais,
    this.puntoBCalle,
    this.puntoBCiudad,
    this.puntoBPais,
    this.onDestinoTap,
    this.precioEstimado,

    // 👇 NUEVO: programación recibida desde MapaDestino
    this.programacion,
  });

  final DraggableScrollableController controller;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;

  final num tarifa;
  final ValueChanged<num> onTarifaChanged;
  final String servicio;
  final VoidCallback? onTaxiTap;
  final VoidCallback? onMotoTap;

  final String? puntoACalle, puntoACiudad, puntoAPais;

  final bool bFijado;
  final String? fixCalle, fixCiudad, fixPais;

  final String? puntoBCalle, puntoBCiudad, puntoBPais;
  final VoidCallback? onDestinoTap;

  final double? precioEstimado;

  // 👇 NUEVO: programación (puede ser null si no se programó)
  final ProgramacionSeleccion? programacion;

  @override
  Widget build(BuildContext context) {
    debugPrint('👶 ModalInferior2Block.build precioEstimado=$precioEstimado');
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: ModalInferior2(
          controller: controller,
          initialChildSize: initialChildSize,
          minChildSize: minChildSize,
          maxChildSize: maxChildSize,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              children: [
                const SizedBox(height: 8),

                // 🔹 Caja de tarifa
                TarifaControlCard(
                  servicio: servicio,
                  precioRecomendado: (precioEstimado ?? 0),
                  valor: tarifa,
                  moneda: 'ARS',
                  step: 1,
                  min: 0,
                  max: 999,
                  accentColor: Colors.green,
                  onChanged: onTarifaChanged,
                ),

                // 👇 NUEVO: chip de "viaje programado" si existe
                if (programacion != null) ...[
                  const SizedBox(height: 8),
                  _ChipProgramacion(programacion: programacion!),
                ],

                const SizedBox(height: 12),

                // Origen
                AddressTile(
                  icono: Icons.my_location_rounded,
                  iconColor: Colors.blue,
                  lineaPrincipal: puntoACalle ?? 'Ubicación desconocida',
                  lineaSecundaria: (puntoACiudad != null && puntoAPais != null)
                      ? '$puntoACiudad - $puntoAPais'
                      : (puntoACiudad ?? puntoAPais ?? '—'),
                ),

                const SizedBox(height: 8),

                // Destino
                AddressTile(
                  icono: Icons.flag,
                  iconColor: Colors.green,
                  lineaPrincipal:
                      (bFijado ? fixCalle : puntoBCalle) ??
                      'Selecciona destino',
                  lineaSecundaria: bFijado
                      ? ((fixCiudad != null && fixPais != null)
                            ? '$fixCiudad - $fixPais'
                            : (fixCiudad ?? fixPais ?? '—'))
                      : ((puntoBCiudad != null && puntoBPais != null)
                            ? '$puntoBCiudad - $puntoBPais'
                            : (puntoBCiudad ?? puntoBPais ?? '—')),
                  onTap: onDestinoTap,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Chip/resumen para mostrar la programación si llegó desde el calendario.
class _ChipProgramacion extends StatelessWidget {
  const _ChipProgramacion({required this.programacion});

  final ProgramacionSeleccion programacion;

  String _fmt() {
    final hh = programacion.timeLocal.hour.toString().padLeft(2, '0');
    final mm = programacion.timeLocal.minute.toString().padLeft(2, '0');
    final hhmm = '$hh:$mm';

    switch (programacion.mode) {
      case 'range':
        final a =
            '${programacion.rangeStartLocal!.day}/${programacion.rangeStartLocal!.month}';
        final b =
            '${programacion.rangeEndLocal!.day}/${programacion.rangeEndLocal!.month}';
        return 'Programado: $a – $b a las $hhmm';
      case 'list':
        final dias = (programacion.datesLocal ?? [])
            .map((d) => '${d.day}/${d.month}')
            .join(', ');
        return 'Programado: $dias a las $hhmm';
      case 'single':
      default:
        final d = (programacion.datesLocal?.isNotEmpty ?? false)
            ? programacion.datesLocal!.first
            : programacion.timeLocal;
        return 'Programado: ${d.day}/${d.month} $hhmm';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFFBF2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF22C55E).withOpacity(.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_available, color: Color(0xFF22C55E), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _fmt(),
              style: const TextStyle(fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
