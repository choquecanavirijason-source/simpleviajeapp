import 'package:flutter/material.dart';
import 'menu_nav_item.dart';

class MenuNavegacion1 extends StatelessWidget {
  final String? urlFotoPerfil;
  final String? userName;
  final List<DrawerItem> itemsMenu;
  final List<Widget> botonesInferiores;
  final VoidCallback? onTapFotoPerfil;

  /// Color base (verde)
  final Color colorBase;

  const MenuNavegacion1({
    super.key,
    this.urlFotoPerfil,
    required this.itemsMenu,
    this.botonesInferiores = const [],
    this.colorBase = Colors.green,
    this.onTapFotoPerfil,
    this.userName,
  });

  @override
  Widget build(BuildContext context) {
    final Color greenDark = colorBase; // Verde principal
    final Color greenLight = Colors.green.shade200; // Verde claro profesional

    return Drawer(
      child: Column(
        children: [
          // ✅ Encabezado con degradado
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [greenDark, greenLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Avatar redondeado moderno
                InkWell(
                  onTap: onTapFotoPerfil,
                  borderRadius: BorderRadius.circular(50),
                  child: CircleAvatar(
                    radius: 38,
                    backgroundColor: Colors.white.withOpacity(0.9),
                    child: ClipOval(
                      child: SizedBox(
                        width: 76,
                        height: 76,
                        child:
                            (urlFotoPerfil != null && urlFotoPerfil!.isNotEmpty)
                            ? Image.network(
                                urlFotoPerfil!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.person,
                                  size: 42,
                                  color: Colors.black54,
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                size: 42,
                                color: Colors.black54,
                              ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ✅ Nombre del menú o frase personalizada
                Text(
                  userName ?? 'Bienvenido',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 4),
                Text(
                  'Tu seguridad, nuestro camino',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // ✅ Lista de opciones con estilo moderno
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: itemsMenu.map((item) {
                return ListTile(
                  leading: Icon(item.icon, color: greenDark),
                  title: Text(
                    item.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    size: 22,
                    color: Colors.black54,
                  ),
                  onTap: item.onTap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                );
              }).toList(),
            ),
          ),

          // ✅ Botones inferiores con borde superior elegante
          if (botonesInferiores.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.withOpacity(0.3),
                    width: 1,
                  ),
                ),
              ),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: botonesInferiores,
              ),
            ),
        ],
      ),
    );
  }
}

/*Metodo de Uso:
drawer: MenuNavegacion1(
  headerColor: Colors.redAccent,
  urlFotoPerfil: 'https://tu-servidor.com/foto.jpg',
  itemsMenu: [
    DrawerItem(
      icon: Icons.home,
      label: 'Inicio',
      onTap: () {
        Navigator.pop(context);
        debugPrint('Navegar a Inicio');
      },
    ),
    DrawerItem(
      icon: Icons.history,
      label: 'Historial',
      onTap: () {
        Navigator.pop(context);
        debugPrint('Navegar a Historial');
      },
    ),
  ],
  botonesInferiores: [
    ElevatedButton.icon(
      onPressed: () {
        Navigator.pop(context);
        debugPrint('Cerrar sesión');
      },
      icon: const Icon(Icons.logout),
      label: const Text('Cerrar sesión'),
    ),
    const SizedBox(height: 10),
    ElevatedButton.icon(
      onPressed: () {
        Navigator.pop(context);
        debugPrint('Cerrar sesión');
      },
      icon: const Icon(Icons.logout),
      label: const Text('Cerrar sesión'),
    ),
  ],
),
*/
