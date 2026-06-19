// import 'package:buses2/shared/widgets/menu_inferior_nav/bottom_nav_bar.dart';
// import 'package:buses2/shared/widgets/menu_inferior_nav/bottom_nav_item.dart';
import 'package:flutter/material.dart';
import 'bottom_nav_item.dart';

class BottomNavBar1 extends StatelessWidget {
  final List<BottomNavItem> items;
  final int currentIndex;

  const BottomNavBar1({
    super.key,
    required this.items,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex,
      items: items
          .map(
            (item) => BottomNavigationBarItem(
              icon: Icon(item.icon),
              label: item.label,
            ),
          )
          .toList(),
      onTap: (index) => items[index].onTap(),
    );
  }
}

/*Ejemplo de uso:
bottomNavigationBar: BottomNavBar1(
  currentIndex: 0, // item activo
  items: [
    BottomNavItem(
      icon: Icons.map,
      label: 'Mapa',
      onTap: () {
        debugPrint('Ir a Mapa');
      },
    ),
    BottomNavItem(
      icon: Icons.bar_chart,
      label: 'Reportes',
      onTap: () {
        debugPrint('Ir a Reportes');
      },
    ),
    BottomNavItem(
      icon: Icons.directions_car,
      label: 'Conductores',
      onTap: () {
        debugPrint('Ir a Conductores');
      },
    ),
  ],
),
*/
