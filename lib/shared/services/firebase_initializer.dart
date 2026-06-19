// lib/core/services/firebase_initializer.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../firebase_options.dart';

class FirebaseInitializer {
  static Future<FirebaseApp> initialize() async {
    return await Firebase.initializeApp(
      options: kIsWeb
          ? DefaultFirebaseOptions.web
          : DefaultFirebaseOptions.currentPlatform,
    );
  }
}
