// lib/app_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:buses2/shared/services/trip_status_watcher.dart';

import 'shared/theme/app_theme.dart';
import 'core/services/notification/notification_service.dart';

class AppWidget extends StatefulWidget {
  const AppWidget({super.key});

  @override
  State<AppWidget> createState() => _AppWidgetState();
}

class _AppWidgetState extends State<AppWidget> {
  @override
  void initState() {
    super.initState();

    // Inicializar NotificationService (no bloqueante)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // Inicializa plugin local + listeners de FCM (foreground)
        await NotificationService().init();

        // Pide permisos (iOS / Android 13+)
        final granted = await NotificationService().pedirPermisosNotificaciones(
          context,
        );

        // Si tiene permisos, refresca/guarda el token FCM en Firestore
        if (granted) {
          await NotificationService().refreshAndSaveToken();
        }
      } catch (e) {
        debugPrint('Error inicializando notificaciones: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Mi App Modular',
      theme: AppTheme.lightTheme,

      // ▸  A) Fuerza toda la app a español.
      locale: const Locale('es', ''),

      // ▸  B) Idiomas que tu app admite
      supportedLocales: const [
        Locale('es', ''), // Español
        Locale('en', ''), // (opcional) Inglés
      ],

      // ▸  C) Delegados que traen las traducciones de Material/Cupertino
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // ▸  D)  Envuelve cada vista con TripStatusWatcher
      // builder: (context, child) {
      //   // Envolvemos el RouterOutlet (la vista actual) con el Watcher.
      //   return TripStatusWatcher(
      //     child: child ?? const SizedBox.shrink(),
      //   );
      // },

      // Modular ↓
      routeInformationParser: Modular.routeInformationParser,
      routerDelegate: Modular.routerDelegate,
    );
  }
}
