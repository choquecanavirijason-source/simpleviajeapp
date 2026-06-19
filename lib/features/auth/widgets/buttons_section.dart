import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;

class ButtonsSection extends StatefulWidget {
  const ButtonsSection({Key? key}) : super(key: key);

  @override
  State<ButtonsSection> createState() => _ButtonsSectionState();
}

class _ButtonsSectionState extends State<ButtonsSection> {
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      // ✅ google_sign_in v7.x
      final googleSignIn = gsi.GoogleSignIn.instance;

      // Obligatorio en v7: inicializar ANTES de usar el plugin
      await googleSignIn.initialize();

      // (Opcional) fuerza selector de cuenta
      await googleSignIn.signOut();

      // ✅ Nuevo método en v7
      final gsi.GoogleSignInAccount googleUser = await googleSignIn
          .authenticate();

      final gsi.GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // ✅ Para Firebase, con idToken es suficiente (evita accessToken en v7)
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      final User? user = userCredential.user;
      if (user == null) return;

      // 2) Verificar si el usuario YA existe en pasajeros o taxistas
      final pasajeroDoc = await FirebaseFirestore.instance
          .collection('pasajeros')
          .doc(user.uid)
          .get();

      final taxistaDoc = await FirebaseFirestore.instance
          .collection('taxistas')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      if (pasajeroDoc.exists || taxistaDoc.exists) {
        Modular.to.pushNamedAndRemoveUntil('/', (_) => false);
      } else {
        Modular.to.pushNamedAndRemoveUntil(
          '/user-type-selection',
          (_) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException: ${e.code} | ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo iniciar sesión (${e.code})'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Google Sign-In ERROR: $e');

      final msg = e.toString().toLowerCase();
      final isCanceled =
          msg.contains('canceled') ||
          msg.contains('cancelled') ||
          msg.contains('cancelado');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCanceled
                  ? 'Inicio de sesión cancelado'
                  : 'No se pudo iniciar sesión',
            ),
            backgroundColor: isCanceled ? Colors.orange : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF34A853),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF34A853).withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleGoogleSignIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Image.asset(
                          'assets/icon/google_logo.png',
                          height: 20,
                          width: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Continuar con Google',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
