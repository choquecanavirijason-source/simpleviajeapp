import 'package:flutter/material.dart';
import 'menu_nav_item.dart';

class MenuNavegacion1 extends StatelessWidget {
  final String? urlFotoPerfil;
  final String? userName;
  final List<DrawerItem> itemsMenu;
  final List<Widget> botonesInferiores;
  final VoidCallback? onTapFotoPerfil;

  /// Color principal del encabezado
  final Color colorBase;

  /// Color secundario del degradado (por defecto verde claro)
  final Color? colorSecundario;

  const MenuNavegacion1({
    super.key,
    this.urlFotoPerfil,
    required this.itemsMenu,
    this.botonesInferiores = const [],
    this.colorBase = Colors.green,
    this.colorSecundario,
    this.onTapFotoPerfil,
    this.userName,
  });

  @override
  Widget build(BuildContext context) {
    final Color primary = colorBase;
    final Color secondary = colorSecundario ?? Colors.green.shade200;

    return Drawer(
      backgroundColor: const Color(0xFFF8F9FA),
      child: Column(
        children: [
          // Encabezado con degradado
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primary, secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                InkWell(
                  onTap: onTapFotoPerfil,
                  borderRadius: BorderRadius.circular(50),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.6),
                        width: 2.5,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 38,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      child: ClipOval(
                        child: SizedBox(
                          width: 76,
                          height: 76,
                          child: (urlFotoPerfil != null &&
                                  urlFotoPerfil!.isNotEmpty)
                              ? Image.network(
                                  urlFotoPerfil!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person,
                                    size: 42,
                                    color: Colors.white70,
                                  ),
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 42,
                                  color: Colors.white70,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  userName ?? 'Bienvenido',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),

                const SizedBox(height: 3),
                Text(
                  'Tu seguridad, nuestro camino',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          // Lista de opciones
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: itemsMenu.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(item.icon, color: primary, size: 19),
                    ),
                    title: Text(
                      item.label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: Colors.grey.shade400,
                    ),
                    onTap: item.onTap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
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
