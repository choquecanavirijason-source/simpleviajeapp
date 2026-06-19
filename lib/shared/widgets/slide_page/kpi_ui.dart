import 'package:flutter/material.dart';

class KpiUI extends StatelessWidget {
  final String title;
  final bool selected;
  final void Function() onTap;

  KpiUI({required this.title, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double kpiWidth = screenWidth * 0.25;
    double kpiHeight = 30.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: kpiWidth,
        height: kpiHeight,
        margin: EdgeInsets.symmetric(horizontal: 8.0),
        decoration: BoxDecoration(
          color: selected
              ? Colors.blue[50]
              : Colors.white, // Color diferente si está seleccionado
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.9),
              spreadRadius: 1,
              blurRadius: 2,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: selected
                    ? Colors.black
                    : Colors.black54, // Texto blanco si seleccionado
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

// lib/features/home_empresa_features/billetera/slide_page/kpi_ui.dart

class KpiUI2 extends StatelessWidget {
  final String title;
  final bool selected;
  final void Function() onTap;

  KpiUI2({required this.title, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double kpiWidth = screenWidth * 0.25;
    double kpiHeight = 40.0; // Ajustamos la altura

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: kpiWidth,
        height: kpiHeight,
        margin: EdgeInsets.symmetric(horizontal: 8.0),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected
                  ? Colors.blue
                  : Colors
                        .transparent, // Línea que aparece cuando está seleccionado
              width: 2,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 6.0,
          ), // Espaciado simple
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16, // Tamaño de fuente
                fontWeight: FontWeight.bold, // Negrita para mayor énfasis
                color: selected
                    ? Colors.blue
                    : Colors.black, // Cambio de color de texto
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
