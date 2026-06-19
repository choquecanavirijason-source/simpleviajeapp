import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  // Mantén sincronizado el índice aunque cambies de ruta con back/links
  void _syncIndexWithPath() {
    final p = Modular.to.path;
    if (p.endsWith('/home') || p.endsWith('/home/')) {
      setState(() => _currentIndex = 0); // default -> viajes
    } else if (p.contains('/home/viajes')) {
      setState(() => _currentIndex = 0);
    } else if (p.contains('/home/historial')) {
      setState(() => _currentIndex = 1);
    } else if (p.contains('/home/chats')) {
      setState(() => _currentIndex = 2);
    }
    // Billetera eliminada - solo para taxistas
  }

  @override
  void initState() {
    super.initState();

    // Ir al hijo por defecto al entrar a /home
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
        Modular.to.navigate('/home/chats', arguments: {'mode': 'pasajero'});
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AQUÍ se pintan los hijos de /home
      body: const RouterOutlet(),

      // Nav inferior
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTap,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_rounded),
            label: 'Viajes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Historial',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_rounded),
            label: 'Chats',
          ),
        ],
      ),
    );
  }
}
