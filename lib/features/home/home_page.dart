import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:buses2/shared/widgets/nav/floating_bottom_nav.dart';
import 'package:buses2/shared/state/drawer_visibility.dart';
import 'package:buses2/shared/theme/app_colors.dart';
import 'package:buses2/shared/services/abrir_busqueda_destino.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  bool _hideNav = false;
  final _destinoController = TextEditingController();

  // El nav solo tiene sentido sobre las 4 secciones raíz. Cualquier otra
  // pantalla (perfil, detalles de viaje, lugares guardados, etc.) es un
  // "detalle" que, por convención de UX, va a pantalla completa sin tab
  // bar persistente.
  void _syncIndexWithPath() {
    final p = Modular.to.path;
    int? index;
    if (p.endsWith('/home') ||
        p.endsWith('/home/') ||
        p.contains('/home/viajes')) {
      index = 0;
    } else if (p.contains('/home/historial')) {
      index = 1;
    } else if (p.contains('/home/lugares') &&
        !p.contains('/home/lugares-guardados')) {
      index = 2;
    } else if (p.contains('/home/chats')) {
      index = 3;
    }
    setState(() {
      _currentIndex = index ?? -1;
      _hideNav = index == null;
    });
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = Modular.to.path;
      if (p == '/home' || p == '/home/') {
        Modular.to.navigate('/home/viajes');
      } else {
        _syncIndexWithPath();
      }
    });

    Modular.to.addListener(_syncIndexWithPath);
  }

  @override
  void dispose() {
    Modular.to.removeListener(_syncIndexWithPath);
    _destinoController.dispose();
    super.dispose();
  }

  void _onTap(int i) {
    setState(() => _currentIndex = i);
    switch (i) {
      case 0:
        Modular.to.navigate('/home/viajes');
        break;
      case 1:
        Modular.to.navigate('/home/historial');
        break;
      case 2:
        Modular.to.navigate('/home/lugares');
        break;
      case 3:
        Modular.to.navigate('/home/chats', arguments: {'mode': 'pasajero'});
        break;
    }
  }

  void _openSearch() {
    // Abre el modal directo, igual que la barra de búsqueda del home,
    // sin cambiar de pestaña ni navegar hacia Viajes primero.
    abrirBusquedaDestino(context, _destinoController);
  }

  static const _navItems = [
    FloatingNavItem(icon: Icons.list_alt_rounded, label: 'Viajes'),
    FloatingNavItem(icon: Icons.bar_chart_rounded, label: 'Historial'),
    FloatingNavItem(icon: Icons.place_rounded, label: 'Lugares'),
    FloatingNavItem(icon: Icons.chat_rounded, label: 'Chats'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          const RouterOutlet(),
          if (!_hideNav)
            Positioned(
              left: 24,
              right: 24,
              bottom: 16 + bottomInset,
              child: ValueListenableBuilder<bool>(
                valueListenable: DrawerVisibility.isOpen,
                builder: (context, drawerOpen, child) {
                  return IgnorePointer(
                    ignoring: drawerOpen,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: drawerOpen ? 0 : 1,
                      child: child,
                    ),
                  );
                },
                child: FloatingBottomNav(
                  floating: true,
                  items: _navItems,
                  currentIndex: _currentIndex,
                  onTap: _onTap,
                  centerAction: _SearchFab(onTap: _openSearch),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Botón circular de búsqueda con su propio espacio dentro del nav: rompe
/// a propósito el patrón de los demás items (fondo azul sólido + contorno
/// blanco grueso, en vez de círculo blanco con ícono navy).
class _SearchFab extends StatelessWidget {
  const _SearchFab({required this.onTap});

  final VoidCallback onTap;

  static const _size = 42.0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.navy,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: const Icon(
            Icons.search_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}
