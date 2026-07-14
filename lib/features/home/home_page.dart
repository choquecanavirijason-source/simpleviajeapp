import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:buses2/shared/widgets/nav/floating_bottom_nav.dart';
import 'package:buses2/shared/state/drawer_visibility.dart';
import 'package:buses2/shared/state/search_destino_trigger.dart';
import 'package:buses2/shared/theme/app_colors.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  bool _hideNav = false;

  void _syncIndexWithPath() {
    final p = Modular.to.path;
    if (p.contains('/home/perfil')) {
      setState(() => _hideNav = true);
      return;
    }
    if (_hideNav) setState(() => _hideNav = false);

    if (p.endsWith('/home') || p.endsWith('/home/')) {
      setState(() => _currentIndex = 0);
    } else if (p.contains('/home/viajes')) {
      setState(() => _currentIndex = 0);
    } else if (p.contains('/home/historial')) {
      setState(() => _currentIndex = 1);
    } else if (p.contains('/home/lugares') &&
        !p.contains('/home/lugares-guardados')) {
      setState(() => _currentIndex = 2);
    } else if (p.contains('/home/chats')) {
      setState(() => _currentIndex = 3);
    } else {
      // Rutas sin tab propia (detalles, etc.): ningún ítem activo.
      setState(() => _currentIndex = -1);
    }
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
    final wasOnViajes = _currentIndex == 0;
    _onTap(0);
    if (wasOnViajes) {
      SearchDestinoTrigger.fire();
    } else {
      // Da tiempo a que la pestaña de Viajes se monte y quede escuchando.
      Future.delayed(const Duration(milliseconds: 250), () {
        SearchDestinoTrigger.fire();
      });
    }
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
