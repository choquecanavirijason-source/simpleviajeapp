import 'package:flutter/material.dart';
import 'menu_nav_item.dart';
import 'package:buses2/shared/theme/app_colors.dart';

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

  /// Widget opcional anclado arriba a la derecha del encabezado
  /// (ej. un botón de acceso rápido a otro modo).
  final Widget? headerAction;

  const MenuNavegacion1({
    super.key,
    this.urlFotoPerfil,
    required this.itemsMenu,
    this.botonesInferiores = const [],
    this.colorBase = Colors.green,
    this.colorSecundario,
    this.onTapFotoPerfil,
    this.userName,
    this.headerAction,
  });

  @override
  Widget build(BuildContext context) {
    final Color primary = colorBase;

    return Drawer(
      backgroundColor: const Color(0xFFF8F9FA),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Encabezado: azul oscuro sólido.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 28),
            decoration: BoxDecoration(
              color: AppColors.navyDark,
              boxShadow: [
                BoxShadow(
                  color: AppColors.navyDark.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (headerAction != null) ...[
                  Align(alignment: Alignment.topRight, child: headerAction!),
                  const SizedBox(height: 12),
                ],
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
                          child:
                              (urlFotoPerfil != null &&
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

          // Lista de opciones: fondo azul directo para toda la sección.
          Expanded(
            child: ColoredBox(
              color: primary,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: itemsMenu.map((item) {
                  return _AnimatedDrawerItem(item: item);
                }).toList(),
              ),
            ),
          ),

          // ✅ Botones inferiores: mismo azul oscuro que el encabezado.
          if (botonesInferiores.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: AppColors.navyDark,
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12),
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

/// Item de menú con fondo redondeado que, al seleccionarse, se desliza
/// suavemente hacia la derecha antes de disparar la navegación.
class _AnimatedDrawerItem extends StatefulWidget {
  const _AnimatedDrawerItem({required this.item});

  final DrawerItem item;

  @override
  State<_AnimatedDrawerItem> createState() => _AnimatedDrawerItemState();
}

class _AnimatedDrawerItemState extends State<_AnimatedDrawerItem> {
  static const _duration = Duration(milliseconds: 380);

  bool _selected = false;

  Future<void> _handleTap() async {
    if (_selected) return;
    setState(() => _selected = true);
    await Future.delayed(_duration);
    if (!mounted) return;
    widget.item.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _handleTap,
          child: AnimatedContainer(
            duration: _duration,
            curve: Curves.easeOut,
            // Sin fondo propio: el color directo lo aporta la sección.
            transform: Matrix4.translationValues(_selected ? 10 : 0, 0, 0),
            child: ListTile(
              leading: Icon(item.icon, color: Colors.white, size: 19),
              title: Text(
                item.label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              trailing: AnimatedSwitcher(
                duration: _duration,
                child: _selected
                    ? const Icon(
                        Icons.arrow_forward_rounded,
                        key: ValueKey('sel'),
                        size: 20,
                        color: Colors.white,
                      )
                    : Icon(
                        Icons.chevron_right_rounded,
                        key: const ValueKey('unsel'),
                        size: 20,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ),
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
