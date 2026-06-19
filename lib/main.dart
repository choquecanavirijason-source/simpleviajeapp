// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:buses2/features/home_taxi_features/home_taxi/services/DriverOfferCounterOfferListenerService.dart';
import 'package:buses2/shared/services/chat_listener_service.dart';
import 'package:buses2/core/services/notification/notification_service.dart';

import 'package:buses2/features/home/services/passenger_offers_listener_service.dart';
import 'package:buses2/features/home_taxi_features/home_taxi/services/driver_offer_accepted_listener_service.dart';

import 'app_module.dart';
import 'app_widget.dart';
import 'shared/services/firebase_initializer.dart';
import 'core/services/firebase/app_check_service.dart';

// ⬇️ Gate que navega a /sinconexion cuando no hay internet
import 'package:buses2/features/network/connectivity_gate.dart';

/// Handler de mensajes FCM cuando la app está en background / terminada.
/// OJO: aquí no se puede navegar ni mostrar UI.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Asegúrate de inicializar Firebase también aquí
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseInitializer.initialize();

  debugPrint(
    '📩 [BG] FCM message: id=${message.messageId} data=${message.data}',
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 Firebase + .env
  await dotenv.load(fileName: ".env");

  // Inicialización extra que ya tenías
  try {
    await FirebaseInitializer.initialize();
  } catch (e) {
    debugPrint('Error inicializando Firebase: $e');
  }

  // 🔐 Activar Firebase App Check para protección contra abuso
  await AppCheckService.initialize();

  // 🔔 Registrar handler para mensajes en segundo plano / app terminada
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 🔔 Pedir permisos de notificación (iOS / Android 13+)
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);

  // 🔔 Inicializar sistema de notificaciones locales (canales, plugin, listeners FCM).
  // Debe ejecutarse UNA sola vez al inicio, ANTES de iniciar listeners que disparen
  // showNewOfferNotification(), si no el plugin no está inicializado y no se muestra nada.
  await NotificationService().init();

  // Mantener la escucha de chats activa solo cuando hay un usuario autenticado.
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) {
      ChatListenerService.instance.startListening();
      PassengerOffersListenerService.instance.startListening();
      DriverOfferAcceptedListenerService.instance.startListening();
      DriverOfferCounterOfferListenerService.instance.startListening();
    } else {
      ChatListenerService.instance.stopListening();
      PassengerOffersListenerService.instance.stopListening();
      DriverOfferAcceptedListenerService.instance.stopListening();
      DriverOfferCounterOfferListenerService.instance.stopListening();
    }
  });

  runApp(
    // Colocamos el gate arriba del árbol, en modo navegación (usePage: true)
    ConnectivityGate(
      usePage: true, // empuja /sinconexion con Modular
      checkInterval: const Duration(seconds: 8), // re-chequeo periódico
      child: ModularApp(
        module: AppModule(),
        child: const AppWidget(), // tu MaterialApp.router
      ),
    ),
  );
}
