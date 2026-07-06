import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  void _syncIndexWithPath() {
    final p = Modular.to.path;
    if (p.endsWith('/home') || p.endsWith('/home/')) {
      setState(() => _currentIndex = 0);
    } else if (p.contains('/home/viajes')) {
      setState(() => _currentIndex = 0);
    } else if (p.contains('/home/historial')) {
      setState(() => _currentIndex = 1);
    } else if (p.contains('/home/lugares') && !p.contains('/home/lugares-guardados')) {
      setState(() => _currentIndex = 2);
    } else if (p.contains('/home/chats')) {
      setState(() => _currentIndex = 3);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const RouterOutlet(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTap,
        selectedItemColor: const Color(0xFF1B5E20),
        unselectedItemColor: Colors.black54,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
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
            icon: Icon(Icons.place_rounded),
            label: 'Lugares',
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
