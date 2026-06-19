// lib/features/home_empresa_features/billetera/slide_page/slide_page.dart

import 'package:flutter/material.dart';

class SlidePageView extends StatelessWidget {
  final PageController pageController;
  final int currentIndex;
  final Function(int) onPageChanged;
  final List<Widget> pages; // Recibimos una lista de widgets (pantallas)

  const SlidePageView({
    Key? key,
    required this.pageController,
    required this.currentIndex,
    required this.onPageChanged,
    required this.pages, // Recibimos las pantallas aquí
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: PageView(
        controller: pageController,
        onPageChanged: onPageChanged,
        children: pages, // Usamos la lista de widgets que pasamos
      ),
    );
  }
}

/* se usa asi:
// Función para obtener las pantallas dinámicamente
List<Widget> _getPages() {
  return [
    Container(
      color: Colors.red[100],
      child: Center(child: Text('Pantalla Todo: 123', style: TextStyle(fontSize: 24))),
    ),
    Container(
      color: Colors.blue[100],
      child: Center(child: Text('Pantalla Recargas: 50', style: TextStyle(fontSize: 24))),
    ),
    // Puedes agregar más pantallas según lo necesites
  ];
}
...
// dentro del ui
SlidePageView(
  pageController: _pageController,
  currentIndex: _currentIndex,
  onPageChanged: (i) {
    setState(() => _currentIndex = i);
  },
  pages: _getPages(),  // Pasamos las pantallas dinámicas
),
*/
