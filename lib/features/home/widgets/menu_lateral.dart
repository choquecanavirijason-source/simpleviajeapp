import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:buses2/features/home/modals/hidden_modal.dart';
import 'package:buses2/features/home/widgets/tap_burst.dart';
import 'package:buses2/features/home_taxi_features/home_taxi/services/DriverOfferCounterOfferListenerService.dart';
import 'package:buses2/features/home_taxi_features/home_taxi/services/orders_listener.dart';
import 'package:buses2/shared/state/apis_visibility.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:buses2/shared/widgets/menu_navegation/menu_nav.dart';
import 'package:buses2/shared/widgets/menu_navegation/menu_nav_item.dart';
import 'package:buses2/shared/widgets/botones/boton.dart';
import 'package:buses2/features/home/services/passenger_offers_listener_service.dart';
import 'package:buses2/features/home_taxi_features/home_taxi/services/driver_offer_accepted_listener_service.dart';

class MenuLateral extends StatefulWidget {
  final dynamic auth; // puede ser LoginService o LoginGoogleService
  const MenuLateral({super.key, required this.auth});

  @override
  State<MenuLateral> createState() => _MenuLateralState();
}

class _MenuLateralState extends State<MenuLateral> {
  // ✅ Mantener la ráfaga viva entre rebuilds
  final TapBurst _gate = TapBurst(
    tapsRequired: 4, // cantidad de taps
    window: const Duration(seconds: 3), // ventana de tiempo
  );

  String? _fotoPerfilPasajero;

  @override
  void initState() {
    super.initState();
    _cargarFotoPerfilPasajero();
  }

  Future<void> _cargarFotoPerfilPasajero() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('pasajeros')
          .doc(user.uid)
          .get();

      final data = snap.data();
      final perfil =
          (data?['perfil'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};

      final fotoUrl = (perfil['photoUrl']?.toString() ?? '').trim();

      if (!mounted) return;
      setState(() {
        _fotoPerfilPasajero = fotoUrl.isNotEmpty
            ? fotoUrl
            : (user.photoURL ?? '');
      });

      debugPrint('Foto de perfil de pasajero cargada: $_fotoPerfilPasajero');
    } catch (e) {
      debugPrint('Error al cargar foto de perfil de pasajero: $e');
      final user = FirebaseAuth.instance.currentUser;
      if (!mounted) return;
      setState(() {
        _fotoPerfilPasajero = user?.photoURL;
      });
    }
  }

  String _obtenerPrimerNombre() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Bienvenido';

    // Intentar obtener el displayName
    final displayName = user.displayName;
    if (displayName != null && displayName.isNotEmpty) {
      // Tomar solo el primer nombre y agregar "Bienvenido"
      final primerNombre = displayName.split(' ').first;
      return 'Bienvenido $primerNombre';
    }

    // Si no hay displayName, usar el email
    final email = user.email;
    if (email != null && email.isNotEmpty) {
      final nombre = email.split('@').first;
      return 'Bienvenido $nombre';
    }

    return 'Bienvenido';
  }

  String? _obtenerFotoPerfil() {
    if (_fotoPerfilPasajero != null && _fotoPerfilPasajero!.isNotEmpty) {
      return _fotoPerfilPasajero;
    }

    final user = FirebaseAuth.instance.currentUser;
    return user?.photoURL;
  }

  Future<void> _handleFotoPerfilTap() async {
    HapticFeedback.selectionClick();
    if (_gate.registerTap()) {
      // 1) Al completar la ráfaga, SOLO mostramos el botón “Modo Empresa”
      ApisVisibility.notifier.value = true;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🔓 Botón “Modo Empresa” habilitado')),
      );
    }
  }

  Future<void> _abrirLoginYEntrarEmpresa() async {
    // 2) Desde el botón, abrir el modal oculto
    final result = await showHiddenLoginBottomSheet(
      context,
      title: 'Acceso avanzado',
    );

    if (!mounted) return;

    // 3) Si login OK -> ir a startup-empresa
    if (result != null && result['status'] == 'ok') {
      Modular.to.pushNamed('/startup-empresa');
    } else {
      // Si cancela o falla, opcional: volver a ocultar el botón
      // ApisVisibility.notifier.value = false;
    }
  }

  Future<void> _cerrarSesion() async {
    try {
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      // 4) Al cerrar sesión, ocultar el botón
      ApisVisibility.notifier.value = false;

      // Marcar que el usuario cerró sesión manualmente
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('manual_logout', true);

      await widget.auth.signOut();
      Modular.to.pushNamedAndRemoveUntil('/login', (_) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo cerrar sesión: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MenuNavegacion1(
      colorBase: Colors.green,
      urlFotoPerfil: _obtenerFotoPerfil(),
      userName: _obtenerPrimerNombre(),

      // 👇 Conecta el TapBurst al avatar (solo muestra el botón)
      // onTapFotoPerfil: _handleFotoPerfilTap,
      itemsMenu: [
        DrawerItem(
          icon: Icons.home,
          label: 'Inicio',
          onTap: () {
            Navigator.pop(context);
            Modular.to.navigate('/home/viajes');
          },
        ),
        DrawerItem(
          icon: Icons.history,
          label: 'Historial',
          onTap: () {
            Navigator.pop(context);
            Modular.to.navigate('/home/historial');
          },
        ),
        DrawerItem(
          icon: Icons.location_on,
          label: 'Mis Lugares',
          onTap: () {
            Navigator.pop(context);
            Modular.to.navigate('/home/lugares-guardados');
          },
        ),
        DrawerItem(
          icon: Icons.chat,
          label: 'Chats',
          onTap: () {
            Navigator.pop(context);
            Modular.to.pushNamed(
              '/home/chats',
              arguments: {'mode': 'pasajero'},
            );
          },
        ),
        DrawerItem(
          icon: Icons.person,
          label: 'Perfil',
          onTap: () {
            Navigator.pop(context);
            Modular.to.navigate('/home/perfil');
          },
        ),

        // ✅ (Contáctanos eliminado)
      ],

      botonesInferiores: [
        // 👇 Botón “Modo Empresa” controlado por ValueListenable
        ValueListenableBuilder<bool>(
          valueListenable: ApisVisibility.notifier,
          builder: (context, isVisible, _) {
            return Offstage(
              offstage: !isVisible, // visible solo si TapBurst lo habilitó
              child: Boton1(
                label: 'Modo Empresa',
                iconoIzquierdo: Icons.business,
                iconoDerecho: Icons.arrow_forward_ios,
                color: BotonColor.color1,
                borde: BotonBorde.borde1,
                onPressed:
                    _abrirLoginYEntrarEmpresa, // abre modal y luego navega si ok
              ),
            );
          },
        ),
        const SizedBox(height: 10),

        Boton1(
          label: 'Modo Driver',
          iconoIzquierdo: Icons.local_taxi,
          iconoDerecho: Icons.arrow_forward_ios,
          color: BotonColor.color1,
          borde: BotonBorde.borde1,
          onPressed: () async {
            // Actualizar modo en Firestore y SharedPreferences
            try {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await FirebaseFirestore.instance
                    .collection('pasajeros')
                    .doc(user.uid)
                    .update({'modo': 'taxista'});
              }

              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('modo', 'taxista');

              // Cambiar listeners: parar pasajero, iniciar driver
              await PassengerOffersListenerService.instance.stopListening();
              await DriverOfferAcceptedListenerService.instance
                  .startListening();
              await DriverOfferCounterOfferListenerService.instance
                  .startListening();
            } catch (e) {
              debugPrint('❌ Error al cambiar modo a taxista: $e');
            }
            Modular.to.pushNamed('/startup-taxista');
          },
        ),
        const SizedBox(height: 10),

        Boton1(
          label: 'Cerrar sesión',
          color: BotonColor.color1,
          borde: BotonBorde.borde1,
          iconoIzquierdo: Icons.logout,
          iconoDerecho: Icons.logout,
          onPressed: _cerrarSesion,
        ),
      ],
    );
  }
}
