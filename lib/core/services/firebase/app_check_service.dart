// lib/core/services/firebase/app_check_service.dart
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Servicio para inicializar Firebase App Check
///
/// App Check ayuda a proteger tu backend contra tráfico abusivo
/// validando que las solicitudes provienen de tu app auténtica.
class AppCheckService {
  /// Inicializa Firebase App Check con los proveedores apropiados
  /// según la plataforma y el modo (debug/release)
  static Future<void> initialize() async {
    try {
      debugPrint('🔐 Inicializando Firebase App Check...');

      await FirebaseAppCheck.instance.activate(
        // Para Android en producción usa Play Integrity API
        // En debug usa el proveedor de debug
        androidProvider: kDebugMode
            ? AndroidProvider.debug
            : AndroidProvider.playIntegrity,

        // Para iOS en producción usa DeviceCheck
        // En debug usa el proveedor de debug
        appleProvider: kDebugMode
            ? AppleProvider.debug
            : AppleProvider.deviceCheck,

        // Para Web usa reCAPTCHA v3
        // Nota: Necesitas configurar tu site key en Firebase Console
        webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
      );

      debugPrint('✅ Firebase App Check activado correctamente');

      // En modo debug, obtener el token de debug para registrarlo en Firebase Console
      if (kDebugMode) {
        try {
          final token = await FirebaseAppCheck.instance.getToken();
          if (token != null) {
            debugPrint(
              '🔑 Debug token App Check: ${token.substring(0, 20)}...',
            );
            debugPrint(
              '   Registra este token en Firebase Console → App Check',
            );
          }
        } catch (e) {
          debugPrint('⚠️ No se pudo obtener el debug token: $e');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('⚠️ Error al activar Firebase App Check: $e');
      debugPrint('   Stack trace: $stackTrace');
      debugPrint('   La app continuará sin App Check (no crítico)');
      // No lanzar error, solo logging
      // La app debe continuar funcionando aunque App Check falle
    }
  }

  /// Obtiene el token actual de App Check
  /// Útil para debugging o verificación manual
  static Future<String?> getToken({bool forceRefresh = false}) async {
    try {
      final token = await FirebaseAppCheck.instance.getToken(forceRefresh);
      return token;
    } catch (e) {
      debugPrint('⚠️ Error obteniendo token de App Check: $e');
      return null;
    }
  }

  /// Verifica si App Check está activado
  static Future<bool> isActivated() async {
    try {
      final token = await getToken();
      return token != null && token.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
