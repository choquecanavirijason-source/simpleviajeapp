import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:buses2/features/home_taxi_features/home_taxi/services/DriverOfferCounterOfferListenerService.dart';
import 'package:buses2/features/home_taxi_features/home_taxi/services/orders_listener.dart';
import 'package:buses2/shared/widgets/menu_navegation/menu_nav.dart';
import 'package:buses2/shared/widgets/menu_navegation/menu_nav_item.dart';
import 'package:buses2/shared/widgets/botones/boton.dart';
import 'package:buses2/shared/services/login_google/login_google_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:buses2/features/home/services/passenger_offers_listener_service.dart';
import '../services/driver_offer_accepted_listener_service.dart';

class TaxiDrawer extends StatefulWidget {
  final String? fotoPerfilUrl;

  const TaxiDrawer({super.key, this.fotoPerfilUrl});

  @override
  State<TaxiDrawer> createState() => _TaxiDrawerState();
}

class _TaxiDrawerState extends State<TaxiDrawer> {
  String _nombreTaxista = 'Bienvenido Taxista';
  String? _fotoTaxista;

  @override
  void initState() {
    super.initState();
    // Pre-populate from Firebase Auth immediately so the drawer renders
    // with real data on first frame — eliminates the 1-second flicker.
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final authName = user.displayName;
      if (authName != null && authName.isNotEmpty) {
        _nombreTaxista = 'Bienvenido ${authName.split(' ').first}';
      }
      if (user.photoURL != null && user.photoURL!.isNotEmpty) {
        _fotoTaxista = user.photoURL;
      }
    }
    _cargarDatosTaxista();
  }

  Future<void> _cargarDatosTaxista() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String? nombre;
    String? foto;

    // Obtener datos del perfil del conductor desde Firestore (donde se registró)
    try {
      final doc = await FirebaseFirestore.instance
          .collection('taxistas')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['perfilTaxista'] is Map) {
          final perfilTaxista = data['perfilTaxista'] as Map<String, dynamic>;

          // Obtener nombre y foto del perfil del taxista
          nombre = perfilTaxista['nombre']?.toString();
          foto = perfilTaxista['fotoPerfil']?.toString();
        }
      }
    } catch (e) {
      debugPrint('Error al cargar datos del taxista desde Firestore: $e');
    }

    // Si hay foto pasada como parámetro, usarla
    if (widget.fotoPerfilUrl != null && widget.fotoPerfilUrl!.isNotEmpty) {
      foto = widget.fotoPerfilUrl;
    }

    // Formatear el nombre para mostrar
    String nombreFormateado = 'Bienvenido Taxista';
    if (nombre != null && nombre.isNotEmpty) {
      final primerNombre = nombre.split(' ').first;
      nombreFormateado = 'Bienvenido $primerNombre';
    } else {
      // Fallback a datos de Google Auth si no hay datos en perfilTaxista
      final displayName = user.displayName;
      if (displayName != null && displayName.isNotEmpty) {
        final primerNombre = displayName.split(' ').first;
        nombreFormateado = 'Bienvenido $primerNombre';
      } else if (user.email != null && user.email!.isNotEmpty) {
        final nombreEmail = user.email!.split('@').first;
        nombreFormateado = 'Bienvenido $nombreEmail';
      }
    }

    if (mounted) {
      setState(() {
        _nombreTaxista = nombreFormateado;
        _fotoTaxista = foto;
      });
    }
  }

  /// Verifica si existe cuenta de pasajero completa antes de cambiar de modo
  Future<void> _cambiarAModoPasajero(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final pasajeroDoc = await FirebaseFirestore.instance
          .collection('pasajeros')
          .doc(user.uid)
          .get();

      if (!pasajeroDoc.exists) {
        // No existe documento de pasajero - ofrecer crearlo
        if (!mounted) return;
        final resultado = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cuenta de pasajero no encontrada'),
            content: const Text(
              'No tienes una cuenta de pasajero creada. ¿Deseas crear tu cuenta de pasajero ahora?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.orange),
                child: const Text('Crear cuenta'),
              ),
            ],
          ),
        );

        if (resultado == true && mounted) {
          // Navegar al formulario de registro de pasajero
          Modular.to.pushNamed('/passenger-data');
        }
        return;
      }

      final data = pasajeroDoc.data();
      final perfil = data?['perfil'] as Map<String, dynamic>?;
      final datosCompletos = perfil?['datosCompletos'] == true;

      if (!datosCompletos) {
        // Existe documento pero no está completo - ofrecer completarlo
        if (!mounted) return;
        final resultado = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Perfil de pasajero incompleto'),
            content: const Text(
              'Tu perfil de pasajero no está completo. ¿Deseas completar tu información ahora?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.orange),
                child: const Text('Completar perfil'),
              ),
            ],
          ),
        );

        if (resultado == true && mounted) {
          // Navegar al formulario de registro de pasajero
          Modular.to.pushNamed('/passenger-data');
        }
        return;
      }

      // Todo OK: cambiar modo
      try {
        // Actualizar en Firestore primero
        await FirebaseFirestore.instance
            .collection('pasajeros')
            .doc(user.uid)
            .update({'modo': 'pasajero'});

        // Actualizar en SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('modo', 'pasajero');

        // Cambiar listeners: parar driver, iniciar pasajero
        await DriverOfferAcceptedListenerService.instance.stopListening();
        await PassengerOffersListenerService.instance.startListening();
        await OrderService.instance.stopListening();
        await DriverOfferCounterOfferListenerService.instance.stopListening();
      } catch (e) {
        debugPrint('❌ Error al cambiar modo a pasajero: $e');
      }

      if (!mounted) return;
      Modular.to.navigate('/home');
    } catch (e) {
      debugPrint('❌ Error al verificar cuenta de pasajero: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al verificar cuenta de pasajero'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Modular.get<LoginService>();
    return MenuNavegacion1(
      urlFotoPerfil: _fotoTaxista,
      userName: _nombreTaxista,
      colorBase: const Color(0xFF1B5E20),
      colorSecundario: const Color(0xFF2E7D32),
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
          icon: Icons.directions_car,
          label: 'Datos del Vehículo',
          onTap: () => Modular.to.pushNamed('/datos-taxi'),
        ),
        DrawerItem(
          icon: Icons.description,
          label: 'Documentos Respaldo',
          onTap: () => Modular.to.pushNamed('/documentos-respaldo-taxi'),
        ),
        DrawerItem(
          icon: Icons.person,
          label: 'Perfil de Conductor',
          onTap: () => Modular.to.pushNamed('/perfil-conductor'),
        ),
        DrawerItem(
          icon: Icons.chat,
          label: 'Chats',
          onTap: () {
            Navigator.pop(context);
            Modular.to.navigate(
              '/home-taxista/chats_taxista',
              arguments: {'mode': 'taxista'},
            );
          },
        ),

        // ✅ (Contáctanos eliminado)
      ],
      botonesInferiores: [
        Boton1(
          label: 'Modo Pasajero',
          color: BotonColor.color1,
          borde: BotonBorde.borde1,
          iconoIzquierdo: Icons.person,
          iconoDerecho: Icons.arrow_forward,
          onPressed: () => _cambiarAModoPasajero(context),
        ),
        const SizedBox(height: 10),
        // Boton1(
        //   label: 'Modo Empresa',
        //   color: BotonColor.color1,
        //   borde: BotonBorde.borde1,
        //   iconoIzquierdo: Icons.business,
        //   iconoDerecho: Icons.arrow_forward,
        //   onPressed: () {
        //     Modular.to.navigate('/startup-empresa');
        //   },
        // ),
        const SizedBox(height: 10),
        Boton1(
          label: 'Cerrar sesión',
          color: BotonColor.color1,
          borde: BotonBorde.borde1,
          iconoIzquierdo: Icons.logout,
          iconoDerecho: Icons.logout,
          onPressed: () async {
            try {
              // Cierra el Drawer primero (para evitar UI "rota")
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
              // Cierra sesión (Google + Firebase)
              await auth.signOut();

              // Navega al login y limpia el historial
              Modular.to.pushNamedAndRemoveUntil('/login', (_) => false);
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('No se pudo cerrar sesión: $e')),
              );
            }
          },
        ),
      ],
    );
  }
}
