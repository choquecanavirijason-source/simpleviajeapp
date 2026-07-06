import 'package:flutter/material.dart';
import 'package:buses2/shared/widgets/cajas/caja_fecha_ini_fin/caja_fecha_ini_fin.dart';

// Caja modular para mostrar el saldo disponible
class SaldoDisponible extends StatelessWidget {
  final String moneda; // Ej: "ARS"
  final String monto; // Ej: "150.00"

  // ====== control del selector de fechas ======
  final bool mostrarSelectorFechas;
  final DateTime? fechaIni;
  final DateTime? fechaFin;
  final ValueChanged<DateTime?>? onFechaIniChanged;
  final ValueChanged<DateTime?>? onFechaFinChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const SaldoDisponible({
    Key? key,
    required this.moneda,
    required this.monto,
    this.mostrarSelectorFechas = false,
    this.fechaIni,
    this.fechaFin,
    this.onFechaIniChanged,
    this.onFechaFinChanged,
    this.firstDate,
    this.lastDate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final contenido = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Saldo disponible',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment:
              CrossAxisAlignment.baseline, // ← AQUÍ el CrossAxisAlignment
          textBaseline: TextBaseline.alphabetic, // ← y aquí el TextBaseline
          children: [
            Text(
              moneda,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Text(
              monto,
              style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      decoration: BoxDecoration(
        color: Colors.indigo,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      // Usamos Stack para superponer los botones arriba a la derecha
      child: Stack(
        children: [
          // Contenido base (título + monto)
          contenido,

          // Selector (opcional)
          if (mostrarSelectorFechas)
            Positioned(
              top: 7,
              right: 0,
              child: CajaFechaIniFin(
                fechaIni: fechaIni,
                fechaFin: fechaFin,
                onFechaIniChanged: onFechaIniChanged,
                onFechaFinChanged: onFechaFinChanged,
                firstDate: firstDate,
                lastDate: lastDate,
                // margin ya lo controla el Positioned
              ),
            ),
        ],
      ),
    );
  }
}

/* Ejemplo de uso:
SaldoDisponible(
  moneda: "ARS",
  monto: saldoDisponible,
  mostrarSelectorFechas: true,         // <- lo muestras
  onFechaIniChanged: (d) {
    // aquí puedes filtrar tu lista por fecha inicial
  },
  onFechaFinChanged: (d) {
    // aquí puedes filtrar por fecha final
  },
  // Opcional: límites del date picker
  firstDate: DateTime(2024, 1, 1),
  lastDate: DateTime.now(),
),
*/
