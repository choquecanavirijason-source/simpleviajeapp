import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────
// Paleta de colores
// ─────────────────────────────────────────────────────────────────────────
class _Palette {
  static const bg1 = Color(0xFFF3F6FB);
  static const ink = Color(0xFF1F2733);
  static const inkSoft = Color(0xFF6B7684);
  static const accent = Color(0xFF9C6ADE);

  static const pasajeroA = Color(0xFF12896B);
  static const pasajeroB = Color(0xFF1FAE8A);
  static const driverA = Color(0xFF1B2A6B);
  static const driverB = Color(0xFF2E4AA8);
}

// ─────────────────────────────────────────────────────────────────────────
// Pantalla principal
// ─────────────────────────────────────────────────────────────────────────
class UserTypeSelectionPage extends StatefulWidget {
  const UserTypeSelectionPage({Key? key}) : super(key: key);

  @override
  State<UserTypeSelectionPage> createState() => _UserTypeSelectionPageState();
}

class _UserTypeSelectionPageState extends State<UserTypeSelectionPage>
    with RouteAware, SingleTickerProviderStateMixin { // ← Añadido SingleTickerProviderStateMixin
  // Controlador de la animación de expansión
  late final AnimationController _controller;
  late final Animation<double> _animation;

  // Estado
  String? _selectedRole; // 'pasajero' o 'conductor'
  bool _isAnimating = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState(); // ← Llamada a super
    _controller = AnimationController(
      vsync: this, // Ahora this es un TickerProvider
      duration: const Duration(milliseconds: 550),
      reverseDuration: const Duration(milliseconds: 400),
    );
    _animation = _controller.drive(CurveTween(curve: Curves.easeOutCubic));
    _checkAuthOnly();
  }

  @override
  void dispose() {
    _controller.dispose(); // ← Liberar el controlador
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────
  //  Lógica de autenticación (sin cambios)
  // ──────────────────────────────────────────────────────────────────────

  Future<void> _checkAuthOnly() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        Modular.to.pushNamedAndRemoveUntil('/login', (_) => false);
      }
    }
  }

  Future<void> _handleBackToLogin() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _Palette.accent.withOpacity(0.18),
                      _Palette.accent.withOpacity(0.08),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.swap_horiz_rounded,
                  size: 32,
                  color: _Palette.accent,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '¿Cambiar de cuenta?',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: _Palette.ink,
                  letterSpacing: -0.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Se cerrará tu sesión actual y podrás\nseleccionar otra cuenta de Google',
                style: TextStyle(
                  fontSize: 14,
                  color: _Palette.inkSoft,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: const BorderSide(color: Color(0xFFE1E5EC)),
                        foregroundColor: _Palette.inkSoft,
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [_Palette.pasajeroA, _Palette.pasajeroB],
                        ),
                      ),
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Cambiar',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true && mounted) {
      await gsi.GoogleSignIn.instance.signOut();
      await FirebaseAuth.instance.signOut();
      Modular.to.pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  //  Lógica de selección de rol (sin cambios)
  // ──────────────────────────────────────────────────────────────────────

  Future<void> _selectPasajero() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('manual_logout');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          Modular.to.pushNamedAndRemoveUntil('/login', (_) => false);
        }
        return;
      }

      final taxistaDoc = await FirebaseFirestore.instance
          .collection('taxistas')
          .doc(user.uid)
          .get();

      if (taxistaDoc.exists) {
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
          if (!mounted) return;

          final elegirAccion = await showDialog<String>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Cuenta existente',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              content: const Text(
                'Tienes un registro como conductor iniciado. ¿Qué deseas hacer?',
                style: TextStyle(color: _Palette.inkSoft, height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop('pasajero'),
                  child: const Text(
                    'Crear cuenta de pasajero',
                    style: TextStyle(
                      color: _Palette.pasajeroA,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop('taxista'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFB4720A),
                  ),
                  child: const Text(
                    'Continuar con registro de conductor',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          );

          if (!mounted) return;

          setState(() => _isLoading = false);

          if (elegirAccion == 'taxista') {
            Modular.to.pushNamedAndRemoveUntil(
              '/startup-taxista',
              (_) => false,
            );
          } else if (elegirAccion == 'pasajero') {
            Modular.to.pushNamed('/passenger-data');
          }
          return;
        }

        if (!mounted) return;
        setState(() => _isLoading = false);

        if (modoActual == 'taxista') {
          Modular.to.pushNamedAndRemoveUntil('/startup-taxista', (_) => false);
        } else {
          Modular.to.pushNamedAndRemoveUntil('/home', (_) => false);
        }
        return;
      }

      final docRef = FirebaseFirestore.instance
          .collection('pasajeros')
          .doc(user.uid);

      final existingDoc = await docRef.get();

      if (existingDoc.exists) {
        final data = existingDoc.data() as Map<String, dynamic>?;
        final perfil = data?['perfil'] as Map<String, dynamic>?;
        final datosCompletos = perfil?['datosCompletos'] == true;
        final telefono = perfil?['telefono'];
        final tieneTelefono = telefono != null && telefono.toString().isNotEmpty;
        final genero = perfil?['genero'];
        final tieneGenero = genero != null && genero.toString().isNotEmpty;
        final departamento = perfil?['departamento'];
        final tieneDepartamento =
            departamento != null && departamento.toString().isNotEmpty;

        await docRef.update({
          'perfil.ultimoLogin': FieldValue.serverTimestamp(),
        });
        await docRef.update({'modo': 'pasajero'});

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('modo', 'pasajero');

        if (!mounted) return;

        if (!datosCompletos ||
            !tieneTelefono ||
            !tieneGenero ||
            !tieneDepartamento) {
          setState(() => _isLoading = false);
          Modular.to.pushNamed('/passenger-data');
        } else {
          Modular.to.pushNamedAndRemoveUntil('/home', (_) => false);
        }
        return;
      }

      // Usuario nuevo
      if (!mounted) return;
      setState(() => _isLoading = false);
      Modular.to.pushNamed('/passenger-data');
    } catch (e) {
      print('Error al verificar cuenta de pasajero: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Text('Error: $e'),
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectConductor() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('manual_logout');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          Modular.to.pushNamedAndRemoveUntil('/login', (_) => false);
        }
        return;
      }

      try {
        await prefs.setString('modo', 'taxista');
      } catch (e) {
        debugPrint('❌ Error al cambiar modo a taxista: $e');
      }

      setState(() => _isLoading = false);
      Modular.to.pushNamed('/startup-taxista');
    } catch (e) {
      print('Error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  //  Inicio de la animación al tocar un lado
  // ──────────────────────────────────────────────────────────────────────

  void _startSelection(String role) {
    if (_isAnimating || _isLoading) return;
    setState(() {
      _selectedRole = role;
      _isAnimating = true;
    });
    _controller.forward().then((_) {
      if (!mounted) return;
      setState(() => _isAnimating = false);
      if (role == 'pasajero') {
        _selectPasajero();
      } else {
        _selectConductor();
      }
    });
  }

  // ──────────────────────────────────────────────────────────────────────
  //  Build
  // ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _handleBackToLogin();
        return false;
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: _handleBackToLogin,
          ),
          title: const Text(
            'Elige tu perfil',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 17,
              shadows: [
                Shadow(offset: Offset(0, 2), blurRadius: 6, color: Colors.black26),
              ],
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;

            double leftWidth, rightWidth;
            final animValue = _animation.value;

            if (_selectedRole == null) {
              leftWidth = 0.5;
              rightWidth = 0.5;
            } else if (_selectedRole == 'pasajero') {
              leftWidth = 0.5 + 0.5 * animValue;
              rightWidth = 0.5 - 0.5 * animValue;
            } else {
              leftWidth = 0.5 - 0.5 * animValue;
              rightWidth = 0.5 + 0.5 * animValue;
            }

            leftWidth = leftWidth.clamp(0.0, 1.0);
            rightWidth = rightWidth.clamp(0.0, 1.0);

            return Stack(
              children: [
                // Lado izquierdo: Pasajero
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: screenWidth * leftWidth,
                  child: _buildRoleSide(
                    role: 'pasajero',
                    label: 'Pasajero',
                    icon: Icons.person_rounded,
                    gradientColors: const [
                      _Palette.pasajeroA,
                      _Palette.pasajeroB,
                    ],
                    imageUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800&fit=crop&crop=face',
                    isSelected: _selectedRole == 'pasajero',
                    isAnimating: _isAnimating,
                    isLoading: _isLoading,
                    onTap: () => _startSelection('pasajero'),
                  ),
                ),

                // Lado derecho: Driver
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: screenWidth * rightWidth,
                  child: _buildRoleSide(
                    role: 'conductor',
                    label: 'Driver',
                    icon: Icons.local_taxi_rounded,
                    gradientColors: const [
                      _Palette.driverA,
                      _Palette.driverB,
                    ],
                    imageUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800&fit=crop&crop=face',
                    isSelected: _selectedRole == 'conductor',
                    isAnimating: _isAnimating,
                    isLoading: _isLoading,
                    onTap: () => _startSelection('conductor'),
                  ),
                ),

                // Overlay de carga
                if (_isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.35),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  //  Widget para cada mitad
  // ──────────────────────────────────────────────────────────────────────

  Widget _buildRoleSide({
    required String role,
    required String label,
    required IconData icon,
    required List<Color> gradientColors,
    required String imageUrl,
    required bool isSelected,
    required bool isAnimating,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    final bool enabled = !isAnimating && !isLoading && !isSelected;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(imageUrl),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.40),
                Colors.black.withOpacity(0.70),
              ],
              stops: const [0.0, 1.0],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.15),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(offset: Offset(0, 3), blurRadius: 10, color: Colors.black45),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  role == 'pasajero' ? 'Viaja fácil' : 'Conduce y gana',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                    shadows: [
                      Shadow(offset: Offset(0, 2), blurRadius: 6, color: Colors.black45),
                    ],
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