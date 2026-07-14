import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:buses2/shared/widgets/cards/app_card.dart';

class UserTypeSelectionPage extends StatefulWidget {
  const UserTypeSelectionPage({Key? key}) : super(key: key);

  @override
  State<UserTypeSelectionPage> createState() => _UserTypeSelectionPageState();
}

class _UserTypeSelectionPageState extends State<UserTypeSelectionPage>
    with RouteAware {
  bool _isLoading = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _isNavigating = false; // Resetear siempre al iniciar
    _checkAuthOnly();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Resetear el flag cuando volvemos a esta pantalla
    setState(() {
      _isNavigating = false;
      _isLoading = false;
    });
  }

  Future<void> _checkAuthOnly() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Si no hay usuario autenticado, redirigir al login
      if (mounted) {
        Modular.to.pushNamedAndRemoveUntil('/login', (_) => false);
      }
    }
    // Si hay usuario, simplemente mostrar las opciones
  }

  Future<void> _handleBackToLogin() async {
    // Mostrar diálogo de confirmación mejorado
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícono
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFF34A853).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.swap_horiz,
                size: 36,
                color: Color(0xFF34A853),
              ),
            ),
            const SizedBox(height: 20),
            // Título
            const Text(
              '¿Cambiar de cuenta?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            // Descripción
            const Text(
              'Se cerrará tu sesión actual y podrás seleccionar otra cuenta de Google',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF666666),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Botones
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: Color(0xFF9C27B0)),
                      foregroundColor: Color(0xFF9C27B0),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF34A853),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cambiar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirm == true && mounted) {
      // Cerrar sesión de Google y Firebase
      await gsi.GoogleSignIn.instance.signOut();
      await FirebaseAuth.instance.signOut();

      // Regresar al login
      Modular.to.pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  Future<void> _selectPasajero() async {
    if (_isLoading || _isNavigating) return;

    setState(() {
      _isLoading = true;
      _isNavigating = true;
    });

    try {
      // Limpiar la bandera de logout manual
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('manual_logout');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isNavigating = false;
          });
          Modular.to.pushNamedAndRemoveUntil('/login', (_) => false);
        }
        return;
      }

      // Verificar si existe un registro de taxista pendiente
      final taxistaDoc = await FirebaseFirestore.instance
          .collection('taxistas')
          .doc(user.uid)
          .get();

      if (taxistaDoc.exists) {
        // Si tiene registro de taxista, verificar si también tiene cuenta de pasajero completa
        final pasajeroDoc = await FirebaseFirestore.instance
            .collection('pasajeros')
            .doc(user.uid)
            .get();

        bool tieneCuentaPasajeroCompleta = false;
        String? modoActual;
        if (pasajeroDoc.exists) {
          final data = pasajeroDoc.data();
          final perfil = data?['perfil'] as Map<String, dynamic>?;
          tieneCuentaPasajeroCompleta = perfil?['datosCompletos'] == true;
          modoActual = data?['modo'] as String?;
        }

        if (!tieneCuentaPasajeroCompleta) {
          // Tiene registro de taxista pero NO tiene cuenta de pasajero completa
          // Mostrar diálogo para que elija: completar registro de pasajero o continuar con taxista
          if (!mounted) return;

          final elegirAccion = await showDialog<String>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Cuenta existente'),
              content: const Text(
                'Tienes un registro como conductor iniciado. ¿Qué deseas hacer?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop('pasajero'),
                  child: const Text('Crear cuenta de pasajero'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop('taxista'),
                  style: TextButton.styleFrom(foregroundColor: Colors.orange),
                  child: const Text('Continuar con registro de conductor'),
                ),
              ],
            ),
          );

          if (!mounted) return;

          setState(() {
            _isLoading = false;
            _isNavigating = false;
          });

          if (elegirAccion == 'taxista') {
            // Ir al flujo de taxista
            Modular.to.pushNamedAndRemoveUntil(
              '/startup-taxista',
              (_) => false,
            );
          } else if (elegirAccion == 'pasajero') {
            // Ir al formulario de registro de pasajero
            Modular.to.pushNamed('/passenger-data');
          }
          return;
        }

        // Tiene registro de taxista Y cuenta de pasajero completa
        // Respetar el campo 'modo' del usuario
        print(
          'DEBUG [user_type_selection]: Usuario tiene registro de taxista y cuenta pasajero. Modo actual: $modoActual',
        );

        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _isNavigating = false;
        });

        // Redirigir según el modo actual del usuario
        if (modoActual == 'taxista') {
          print('DEBUG [user_type_selection]: Redirigiendo a startup-taxista');
          Modular.to.pushNamedAndRemoveUntil('/startup-taxista', (_) => false);
        } else {
          // Modo pasajero o no definido - ir a home de pasajero
          print('DEBUG [user_type_selection]: Redirigiendo a home de pasajero');
          Modular.to.pushNamedAndRemoveUntil('/home', (_) => false);
        }
        return;
      }

      // Verificar si ya existe el documento
      final docRef = FirebaseFirestore.instance
          .collection('pasajeros')
          .doc(user.uid);

      final existingDoc = await docRef.get();

      print(
        'DEBUG [user_type_selection]: Documento pasajero existe? ${existingDoc.exists}',
      );

      if (existingDoc.exists) {
        // Verificar si tiene los datos completos
        final data = existingDoc.data() as Map<String, dynamic>?;
        final perfil = data?['perfil'] as Map<String, dynamic>?;
        final datosCompletos = perfil?['datosCompletos'] == true;

        final telefono = perfil?['telefono'];
        final tieneTelefono =
            telefono != null && telefono.toString().isNotEmpty;

        final genero = perfil?['genero'];
        final tieneGenero = genero != null && genero.toString().isNotEmpty;

        final departamento = perfil?['departamento'];
        final tieneDepartamento =
            departamento != null && departamento.toString().isNotEmpty;

        print(
          'DEBUG [user_type_selection]: datosCompletos=$datosCompletos, telefono=$telefono, genero=$genero, depto=$departamento',
        );

        // Actualizar ultimoLogin
        await docRef.update({
          'perfil.ultimoLogin': FieldValue.serverTimestamp(),
        });

        // Asegurar que el modo esté en 'pasajero'
        await docRef.update({'modo': 'pasajero'});

        // Actualizar SharedPreferences también
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('modo', 'pasajero');

        if (!mounted) return;

        // Si datos incompletos, ir a formulario. Si completos, ir a home
        if (!datosCompletos ||
            !tieneTelefono ||
            !tieneGenero ||
            !tieneDepartamento) {
          print(
            'DEBUG [user_type_selection]: Datos incompletos, redirigiendo a passenger-data',
          );
          setState(() {
            _isLoading = false;
            _isNavigating = false;
          });
          Modular.to.pushNamed('/passenger-data');
        } else {
          print(
            'DEBUG [user_type_selection]: Datos completos, redirigiendo a home',
          );
          Modular.to.pushNamedAndRemoveUntil('/home', (_) => false);
        }
        return;
      }

      // Usuario nuevo sin documento - ir a formulario
      print(
        'DEBUG [user_type_selection]: Usuario nuevo, redirigiendo a passenger-data',
      );

      if (!mounted) return;

      // Resetear flags ANTES de navegar para que los botones no queden bloqueados
      setState(() {
        _isLoading = false;
        _isNavigating = false;
      });

      // Navegar sin await para evitar bloqueos
      Modular.to.pushNamed('/passenger-data');
    } catch (e) {
      print('Error al verificar cuenta de pasajero: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() {
          _isLoading = false;
          _isNavigating = false;
        });
      }
    }
  }

  Future<void> _selectConductor() async {
    if (_isLoading || _isNavigating) return;

    setState(() => _isNavigating = true);

    try {
      // Limpiar la bandera de logout manual
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('manual_logout');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() => _isNavigating = false);
          Modular.to.pushNamedAndRemoveUntil('/login', (_) => false);
        }
        return;
      }

      if (!mounted) return;

      // Actualizar modo a 'taxista' en Firestore antes de navegar
      try {
        // await FirebaseFirestore.instance
        //     .collection('pasajeros')
        //     .doc(user.uid)
        //     .update({'modo': 'taxista'});

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('modo', 'taxista');
      } catch (e) {
        await prefs.setString('modo', 'taxista');
        debugPrint('❌ Error al cambiar modo a taxista: $e');
      }

      // Resetear flag ANTES de navegar
      setState(() => _isNavigating = false);

      // Navegar al flujo de inicio de taxista, que decide si
      // debe ir a registro, documentos o directo al home
      Modular.to.pushNamed('/startup-taxista');
    } catch (e) {
      print('Error: $e');
      if (mounted) {
        setState(() => _isNavigating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _handleBackToLogin();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBackToLogin,
          ),
          title: const Text('Atras'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF5F5F5), Color(0xFFFFFFFF)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: AppCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo o icono
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person_outline,
                          size: 50,
                          color: Color(0xFF34A853),
                        ),
                      ),

                      const SizedBox(height: 32),

                      const Text(
                        '¿Cómo deseas continuar?',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'Selecciona el tipo de cuenta que quieres usar',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF666666),
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 32),

                      // Pasajero y Driver, uno al lado del otro.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _RoleOptionButton(
                              icon: Icons.person,
                              label: 'Pasajero',
                              color: const Color(0xFF34A853),
                              loading: _isLoading,
                              onTap: (_isLoading || _isNavigating)
                                  ? null
                                  : _selectPasajero,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _RoleOptionButton(
                              icon: Icons.local_taxi,
                              label: 'Driver',
                              color: const Color(0xFF00359D),
                              onTap: (_isLoading || _isNavigating)
                                  ? null
                                  : _selectConductor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opción de rol (Pasajero/Driver) pensada para ir una al lado de la otra:
/// ícono arriba, etiqueta corta abajo, en vez de un botón ancho con texto
/// largo en una sola línea.
class _RoleOptionButton extends StatelessWidget {
  const _RoleOptionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
            child: loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: Colors.white, size: 28),
                      const SizedBox(height: 10),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
