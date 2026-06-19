import 'package:flutter/material.dart';
import 'package:buses2/shared/widgets/cajas/caja_contenedora/caja_contenedora.dart';
import 'package:buses2/shared/widgets/inputs/input_number.dart';

class TarifasServicioBox extends StatelessWidget {
  final NumberEditingController tarifaBaseCtrl;
  final NumberEditingController distBaseCtrl;
  final NumberEditingController porKmCtrl;
  final NumberEditingController porMinCtrl;
  final NumberEditingController horaPicoCtrl;
  final NumberEditingController nocturnoCtrl;
  final NumberEditingController comisionCtrl;

  const TarifasServicioBox({
    super.key,
    required this.tarifaBaseCtrl,
    required this.distBaseCtrl,
    required this.porKmCtrl,
    required this.porMinCtrl,
    required this.horaPicoCtrl,
    required this.nocturnoCtrl,
    required this.comisionCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return CajaContenedora(
      titulo: 'Tarifas del Servicio',
      iconoTitulo: Icons.local_taxi,
      tituloAlign: TituloAlign.center,
      iconoDerecha: Icons.payments_outlined, // tarjeta (sin $)
      padding: const EdgeInsets.all(16),
      borderRadius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TwoCols(
            spacing: 12,
            children: [
              NumberInput2(
                controller: tarifaBaseCtrl,
                label: 'Tarifa base',
                placeholder: '0.00',
                prefixTextAsIcon: 'ARS ', // tarjeta, neutro
                allowDecimal: true,
                decimalPlaces: 2,
              ),
              NumberInput2(
                controller: distBaseCtrl,
                label: 'Distancia base',
                placeholder: '0.00',
                prefixIcon: Icons.straighten,
                allowDecimal: true,
                decimalPlaces: 2,
              ),
              // por cada km extra de la distancia base se cobra este monto
              NumberInput2(
                controller: porKmCtrl,
                label: 'Por cada km',
                placeholder: '0.00',
                prefixTextAsIcon: 'ARS', // ← texto en vez de icono
                allowDecimal: true,
                decimalPlaces: 2,
              ),

              // por cada minuto extra se cobra este monto
              NumberInput2(
                controller: porMinCtrl,
                label: 'Por minuto',
                placeholder: '0.00',
                prefixTextAsIcon: 'ARS', // ← texto en vez de icono
                allowDecimal: true,
                decimalPlaces: 2,
              ),
              // porcentaje extra por hora pico
              NumberInput2(
                controller: horaPicoCtrl,
                label: 'Hora pico (extra)',
                placeholder: '0.00',
                prefixIcon: Icons.percent, // porcentaje
                allowDecimal: true,
                decimalPlaces: 2,
              ),
              // nuevo precio por ser en la noche
              NumberInput2(
                controller: nocturnoCtrl,
                label: 'Precio nocturno',
                placeholder: '0.00',
                prefixIcon: Icons.add,
                allowDecimal: true,
                decimalPlaces: 2,
              ),
              // comisión que se descuenta al taxista
              NumberInput2(
                controller: comisionCtrl,
                label: 'Comisión (%)',
                placeholder: '0.00',
                prefixIcon: Icons.percent,
                allowDecimal: true,
                decimalPlaces: 2,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Helper: acomoda widgets en 2 columnas responsivas usando Wrap.
/// Cada hijo recibe exactamente la mitad del ancho disponible (menos el `spacing`).
class _TwoCols extends StatelessWidget {
  const _TwoCols({required this.children, this.spacing = 12});

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final maxW = c.maxWidth;
        final itemW = (maxW - spacing) / 2; // dos columnas

        return Wrap(
          spacing: spacing, // espacio horizontal entre columnas
          runSpacing: spacing, // espacio vertical entre filas
          children: children.map((w) {
            return SizedBox(width: itemW, child: w);
          }).toList(),
        );
      },
    );
  }
}
