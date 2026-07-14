import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:buses2/shared/widgets/menu_navegation/menu_nav.dart';
import 'package:buses2/shared/widgets/menu_navegation/menu_nav_item.dart';
import 'package:buses2/shared/widgets/botones/boton.dart';
import 'package:buses2/shared/services/login_google/login_google_service.dart';
import 'package:buses2/shared/services/save_traer_firebase/save_datos_genericos.dart';
import 'package:buses2/shared/theme/app_colors.dart';
import 'package:buses2/shared/widgets/botones/logout_button.dart';

class EmpresaDrawer extends StatelessWidget {
  final String? fotoPerfilUrl;
  final String? empresaName;

  const EmpresaDrawer({super.key, this.fotoPerfilUrl, this.empresaName});

  // Altura uniforme para los 3 botones inferiores.
  static const double _kBtnHeight = 54;

  void _navegar(BuildContext context, String ruta) {
    // Cierra el drawer antes de navegar para que al volver no quede abierto.
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    Modular.to.pushNamed(ruta);
  }

  @override
  Widget build(BuildContext context) {
    final user = fb.FirebaseAuth.instance.currentUser;
    final nombreMostrado =
        (empresaName != null && empresaName!.trim().isNotEmpty)
        ? empresaName!.trim()
        : (user?.displayName?.trim().isNotEmpty == true
              ? user!.displayName!.trim()
              : (user?.email ?? 'Empresa'));

    return MenuNavegacion1(
      urlFotoPerfil: fotoPerfilUrl,
      userName: nombreMostrado,
      colorBase: AppColors.navy,
      colorSecundario: AppColors.navyLight,
      itemsMenu: [
        DrawerItem(
          icon: Icons.home_rounded,
          label: 'Inicio',
          onTap: () => Navigator.of(context).pop(),
        ),
        DrawerItem(
          icon: Icons.business_rounded,
          label: 'Perfil Empresa',
          onTap: () => _navegar(context, '/datos-empresa'),
        ),
        DrawerItem(
          icon: Icons.local_taxi_rounded,
          label: 'Taxistas Registrados',
          onTap: () => _navegar(context, '/taxistas-registrados'),
        ),
        DrawerItem(
          icon: Icons.miscellaneous_services_rounded,
          label: 'Servicios',
          onTap: () => _navegar(context, '/servicios'),
        ),
        DrawerItem(
          icon: Icons.note_add_rounded,
          label: 'Crear Documentos',
          onTap: () => _navegar(context, '/crear-documentos'),
        ),
        DrawerItem(
          icon: Icons.description_rounded,
          label: 'Documentos Creados',
          onTap: () => _navegar(context, '/ver-documento'),
        ),
      ],
      botonesInferiores: [
        // Label de sección
        const _SeccionLabel(texto: 'CAMBIAR DE MODO'),
        const SizedBox(height: 8),
        SizedBox(
          height: _kBtnHeight,
          child: Boton1(
            label: 'Modo Pasajero',
            color: BotonColor.color2, // azul
            borde: BotonBorde.borde1,
            iconoIzquierdo: Icons.person_rounded,
            iconoDerecho: Icons.arrow_forward_rounded,
            onPressed: () async {
              try {
                await SaveDatosGenericos.guardarCampoEnMap(
                  absoluteDocPath: 'pasajeros/{uid}',
                  nombreMap: '@root',
                  nombreCampo: 'modo',
                  valor: 'pasajero',
                );
              } catch (e) {
                debugPrint('❌ Error al guardar modo: $e');
              }
              Modular.to.navigate('/home');
            },
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: _kBtnHeight,
          child: Boton1(
            label: 'Modo Taxista',
            color: BotonColor.color2, // azul
            borde: BotonBorde.borde1,
            iconoIzquierdo: Icons.local_taxi_rounded,
            iconoDerecho: Icons.arrow_forward_rounded,
            onPressed: () {
              Modular.to.pushNamed('/startup-taxista');
            },
          ),
        ),

        // Separador visual entre "cambiar de modo" y la acción destructiva
        const SizedBox(height: 18),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        const SizedBox(height: 14),

        SizedBox(
          height: _kBtnHeight,
          child: LogoutButton(
            onPressed: () async {
              try {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
                final auth = Modular.get<LoginService>();
                await auth.signOut();
                Modular.to.pushNamedAndRemoveUntil('/login', (_) => false);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('No se pudo cerrar sesión: $e')),
                );
              }
            },
          ),
        ),
      ],
    );
  }
}

/// Etiqueta gris pequeña para encabezar una sección de botones.
class _SeccionLabel extends StatelessWidget {
  const _SeccionLabel({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        texto,
        style: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
