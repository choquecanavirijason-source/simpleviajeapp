// lib/features/home_empresa_features/billetera/slide_page/kpi_logic.dart

import 'package:flutter/material.dart';
import 'kpi_ui.dart'; // Importamos el archivo con la UI de los KPIs

class KpiLogic extends StatelessWidget {
  final PageController pageController;
  final int currentIndex;
  final List<String>
  kpiNames; // Recibimos los nombres de los KPIs como una lista
  final int kpiStyle; // Recibimos el estilo (1 o 2)

  KpiLogic({
    required this.pageController,
    required this.currentIndex,
    required this.kpiNames, // Recibimos los nombres de los KPIs
    required this.kpiStyle, // Recibimos el estilo
  });

  // Método para cambiar la pantalla del PageView
  void _cambiarPantalla(int index) {
    pageController.jumpToPage(
      index,
    ); // Cambia la página del PageView al índice seleccionado
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment
          .center, // Centra los KPIs horizontalmente en la fila
      children: List.generate(kpiNames.length, (index) {
        // Generamos dinámicamente los botones KPI con el estilo correspondiente
        return kpiStyle == 1
            ? KpiUI(
                title:
                    kpiNames[index], // Usamos el nombre del KPI desde la lista
                selected: currentIndex == index,
                onTap: () => _cambiarPantalla(
                  index,
                ), // Cambia a la pantalla correspondiente
              )
            : KpiUI2(
                title:
                    kpiNames[index], // Usamos el nombre del KPI desde la lista
                selected: currentIndex == index,
                onTap: () => _cambiarPantalla(
                  index,
                ), // Cambia a la pantalla correspondiente
              );
      }),
    );
  }
}

/* se usa asi:
// Dentro del StatefulWidget principal (BilleteraScreen)
class _BilleteraScreenState extends State<BilleteraScreen> {
  late PageController _pageController;
  int _currentIndex = 0;
  ...
  // Función para obtener los nombres de los KPIs
  List<String> _getKpiNames() {
    return [
      'Todo',
      'Recargas',
      'Comisiones',
      // Puedes agregar tantos como necesites
    ];
  }
  ...
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        KpiLogic(
          pageController: _pageController,
          currentIndex: _currentIndex,
          kpiNames: _getKpiNames(),  // Pasamos los nombres de los KPIs
          kpiStyle: 1,  // Pasamos el estilo que queremos (1 o 2)
        ),
        SizedBox(height: 10),
        SlidePageView(
          pageController: _pageController,
          currentIndex: _currentIndex,
          onPageChanged: (i) {
            setState(() => _currentIndex = i);
          },
          pages: _getPages(),  // Pasamos las pantallas dinámicas
        ),
      ],
    );
  }
}
*/
