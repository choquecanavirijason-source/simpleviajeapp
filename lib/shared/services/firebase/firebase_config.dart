import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

class FirebaseConfig {
  static FirebaseOptions get current {
    // ========= SELECCIÓN: DESCOMENTA SOLO UNO =========
    return _dev(); // 👈 ACTIVO (desarrollo)
    // return _prod(); // 👈 ACTÍVALO para producción
    // ==================================================
  }

  // --------------------- DEV ---------------------
  static FirebaseOptions _dev() {
    // 📦 Proyecto: 
    const projectId = 'buses-f66da'; // ✅ Project ID
    const senderId = '439845573858'; // = Project Number
    const bucket = 'buses-f66da.firebasestorage.app';

    if (kIsWeb) {
      // WEB (DEV)
      return const FirebaseOptions(
        apiKey: 'AIzaSyDl4WDw1SnIgnWkVLwVxrtqYBhzMu8VgvY', // ✅ Clave de API web
        appId:
            '<WEB_APP_ID_DEV>', // 🔴 TODO: formato 1:439845573858:web:xxxxxxxx
        messagingSenderId: senderId, // ✅ 439845573858
        projectId: projectId, // ✅ buses-f66da
        storageBucket: bucket, // ✅ buses-f66da.firebasestorage.app
        authDomain: 'buses-f66da.firebaseapp.com', // ✅ dominio típico
        // measurementId: 'G-XXXXXXX',                     // (opcional) si usas Analytics
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // ANDROID (DEV) – paquete de ejemplo: com.mujerv.pasajero
        return const FirebaseOptions(
          apiKey:
              '<ANDROID_API_KEY_DEV>', // 🔴 TODO: en android/app/google-services.json → "current_key"
          appId:
              '1:439845573858:android:f0735de8d4f74a92e33abb', // ✅ App ID Android que pasaste
          messagingSenderId: senderId, // ✅
          projectId: projectId, // ✅
          storageBucket: bucket, // ✅
        );

      case TargetPlatform.iOS:
        // iOS (DEV) – no compartiste app iOS; deja TODOs o añade tu Bundle ID si ya lo tienes
        return const FirebaseOptions(
          apiKey:
              '<IOS_API_KEY_DEV>', // 🔴 TODO: en ios/Runner/GoogleService-Info.plist → API_KEY
          appId:
              '<IOS_APP_ID_DEV>', // 🔴 TODO: GOOGLE_APP_ID (1:439845573858:ios:xxxx)
          messagingSenderId: senderId, // ✅
          projectId: projectId, // ✅
          storageBucket: bucket, // ✅
          iosBundleId:
              '<IOS_BUNDLE_ID>', // 🔴 TODO: tu bundleId real si registras iOS
        );

      // Si no usas desktop, este fallback ayuda a compilar.
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      default:
        return const FirebaseOptions(
          apiKey: '<ANDROID_API_KEY_DEV>',
          appId: '1:439845573858:android:f0735de8d4f74a92e33abb',
          messagingSenderId: senderId,
          projectId: projectId,
          storageBucket: bucket,
        );
    }
  }

  // -------------------- PROD --------------------
  static FirebaseOptions _prod() {
    if (kIsWeb) {
      // WEB (PROD)
      return const FirebaseOptions(
        apiKey: 'PROD_WEB_API_KEY',
        appId: 'PROD_WEB_APP_ID',
        messagingSenderId: 'PROD_SENDER_ID',
        projectId: 'PROD_PROJECT_ID',
        storageBucket: 'PROD_BUCKET',
        authDomain: 'prod-project.firebaseapp.com',
        measurementId: 'G-YYYYYYY',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // ANDROID (PROD)
        return const FirebaseOptions(
          apiKey: 'PROD_ANDROID_API_KEY',
          appId: 'PROD_ANDROID_APP_ID',
          messagingSenderId: 'PROD_SENDER_ID',
          projectId: 'PROD_PROJECT_ID',
          storageBucket: 'PROD_BUCKET',
        );
      case TargetPlatform.iOS:
        // iOS (PROD)
        return const FirebaseOptions(
          apiKey: 'PROD_IOS_API_KEY',
          appId: 'PROD_IOS_APP_ID',
          messagingSenderId: 'PROD_SENDER_ID',
          projectId: 'PROD_PROJECT_ID',
          storageBucket: 'PROD_BUCKET',
          iosBundleId: 'com.tu.paquete',
        );
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        // Desktop (PROD)
        return const FirebaseOptions(
          apiKey: 'PROD_DESKTOP_API_KEY',
          appId: 'PROD_DESKTOP_APP_ID',
          messagingSenderId: 'PROD_SENDER_ID',
          projectId: 'PROD_PROJECT_ID',
          storageBucket: 'PROD_BUCKET',
        );
      default:
        // Fallback
        return const FirebaseOptions(
          apiKey: 'PROD_ANDROID_API_KEY',
          appId: 'PROD_ANDROID_APP_ID',
          messagingSenderId: 'PROD_SENDER_ID',
          projectId: 'PROD_PROJECT_ID',
          storageBucket: 'PROD_BUCKET',
        );
    }
  }
}
