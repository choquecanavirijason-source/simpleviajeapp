import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_database/firebase_database.dart';

// SI QUIERES, PUEDES BORRAR ESTE HANDLER SI YA USAS EL DE main.dart
// @pragma('vm:entry-point')
// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   if (kDebugMode) {
//     debugPrint('onBackgroundMessage: ${message.messageId} ${message.data}');
//   }
// }

class NotificationService {
  NotificationService._private();
  static final NotificationService _instance = NotificationService._private();
  factory NotificationService() => _instance;

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        'chasky_high_importance',
        'Notificaciones importantes',
        description: 'Canal para notificaciones importantes',
        importance: Importance.high,
      );

  Future<void> init() async {
    // ✅ Inicializar flutter_local_notifications
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    final initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (payload) {
        if (payload.payload != null && payload.payload!.isNotEmpty) {
          _handleNotificationTapPayload(payload.payload!);
        }
      },
    );

    // ✅ Crear canal Android
    if (Platform.isAndroid) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_androidChannel);
    }

    // ✅ Escuchar mensajes FCM (foreground / al tocar notificación)
    _listenFCM();

    // Obtener token y guardarlo si es necesario (puede repetirse luego en refreshAndSaveToken)
    final token = await getToken();
    if (kDebugMode) debugPrint('FCM token (init): $token');
    await _saveTokenToFirestore(token);
  }

  // ---------------------------------------------------------------------------
  // LISTENER FCM → PASO 2
  // ---------------------------------------------------------------------------
  void _listenFCM() {
    // App en FOREGROUND → llega FCM → mostramos notificación local
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint(
          '📩 [FG] FCM message: '
          'id=${message.messageId} data=${message.data}',
        );
      }

      final chatId = message.data['chatId'] ?? '';

      final title = message.notification?.title ?? 'Nuevo mensaje';
      final body = message.notification?.body ?? 'Tienes un nuevo mensaje';

      if (chatId.isNotEmpty) {
        // otherUserName = title, mensaje = body
        showLocalNotification(chatId, body, title);
      }
    });

    // Usuario toca una notificación FCM del sistema
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint('📩 [OPEN] FCM tapped: data=${message.data}');
      }

      final chatId = message.data['chatId'] ?? '';
      if (chatId.isNotEmpty) {
        _handleNotificationTapPayload(chatId);
      }
    });
  }

  Future<void> _handleNotificationTapPayload(String payload) async {
    try {
      // Payload estructurado para distintos tipos de notificación.
      //  - "trip:<id>"          → viaje aceptado (pasajero) → ir a historial
      //  - "offer:<rutaDoc>"   → nueva oferta para pasajero → ir a orden
      //  - "driverTrip:<ruta>" → oferta del taxista aceptada → ir a HomeTaxista
      //  - "driverOrder:<ruta>"→ nueva orden cercana para taxista → ir a HomeTaxista
      //  - "documentConfigChanged" → documentos requeridos nuevos → ir a carga incremental
      //  - "<chatId>"          → compatibilidad hacia atrás con notificaciones de chat

      if (payload.startsWith('trip:')) {
        final tripId = payload.substring('trip:'.length);
        if (kDebugMode) {
          debugPrint('NotificationService: tap en viaje aceptado $tripId');
        }

        Modular.to.pushNamed('/home/historial');
        return;
      }

      if (payload.startsWith('offer:')) {
        final rutaDoc = payload.substring('offer:'.length);
        if (rutaDoc.isEmpty) return;

        if (kDebugMode) {
          debugPrint('NotificationService: tap en oferta nueva para $rutaDoc');
        }

        // Detectamos si la orden es programada a partir de la ruta
        final esProgramado = rutaDoc.contains('ordenesProgramados');

        // Decidimos la navegación según el modo actual (taxista/pasajero)
        final mode = await _resolveUserMode();

        if (mode == 'taxista') {
          // Para el taxista (ej. contraofertas), ir a la pantalla de viajes,
          // diferenciando entre viaje normal y programado.
          Modular.to.pushNamed(
            '/home-taxista/viajes_taxista',
            arguments: {
              'rutaDoc': rutaDoc,
              'esProgramado': esProgramado,
            },
          );
        } else {
          // Para el pasajero, mantener el flujo existente hacia ViajeSolicitado.
          Modular.to.pushNamed(
            '/viaje-solicitado',
            arguments: {
              'rutaDoc': rutaDoc,
              'esProgramado': esProgramado,
            },
          );
        }

        return;
      }

      if (payload.startsWith('driverTrip:')) {
        final rutaDoc = payload.substring('driverTrip:'.length);
        if (rutaDoc.isEmpty) return;

        if (kDebugMode) {
          debugPrint(
            'NotificationService: tap en viaje aceptado por pasajero (taxista) $rutaDoc',
          );
        }

        // Intentamos leer la orden para obtener origen (si está disponible)
        double? oLat;
        double? oLng;
        String origenTexto = 'Origen';

        try {
          final snap = await FirebaseFirestore.instance.doc(rutaDoc).get();
          if (snap.exists) {
            final data =
                (snap.data() ?? const <String, dynamic>{})
                    as Map<String, dynamic>;

            final origen = (data['origen'] is Map)
                ? Map<String, dynamic>.from(data['origen'] as Map)
                : <String, dynamic>{};

            final lat = origen['lat'] ?? data['origenLat'] ?? data['aLat'];
            final lng = origen['lng'] ?? data['origenLng'] ?? data['aLng'];

            if (lat is num) oLat = lat.toDouble();
            if (lng is num) oLng = lng.toDouble();

            final texto = origen['texto']?.toString();
            final calle = origen['calle']?.toString() ?? '';
            final ciudad = origen['ciudad']?.toString() ?? '';
            final pais = origen['pais']?.toString() ?? '';

            if (texto != null && texto.trim().isNotEmpty) {
              origenTexto = texto.trim();
            } else {
              origenTexto = [
                calle,
                ciudad,
                pais,
              ].where((e) => e.isNotEmpty).join(', ');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              'NotificationService: error leyendo orden $rutaDoc → $e',
            );
          }
        }

        final driverUid = fb.FirebaseAuth.instance.currentUser?.uid;

        Modular.to.pushNamed(
          '/home-taxista',
          arguments: {
            if (driverUid != null && driverUid.isNotEmpty)
              'driverUid': driverUid,
            if (oLat != null) 'origenLat': oLat,
            if (oLng != null) 'origenLng': oLng,
            'origenTexto': origenTexto,
            'rutaDoc': rutaDoc,
          },
        );
        return;
      }

      // Handler para nuevas órdenes cercanas al taxista
      if (payload.startsWith('driverOrder:')) {
        final rutaDoc = payload.substring('driverOrder:'.length);
        if (rutaDoc.isEmpty) return;

        if (kDebugMode) {
          debugPrint(
            'NotificationService: tap en nueva orden cercana para taxista $rutaDoc',
          );
        }

        final mode = await _resolveUserMode();
        final esProgramado = rutaDoc.contains('ordenesProgramados');

        if (mode == 'taxista') {
          // Ir directamente a la pestaña de viajes del HomeTaxista.
          // Si es programado, la UI puede cambiar a la pestaña de Programados.
          Modular.to.pushNamed(
            '/home-taxista/viajes_taxista',
            arguments: {'rutaDoc': rutaDoc, 'esProgramado': esProgramado},
          );
        } else {
          // Fallback: vista de pasajero de la orden, si aplica
          Modular.to.pushNamed(
            '/viaje-solicitado',
            arguments: {'rutaDoc': rutaDoc},
          );
        }
        return;
      }

      // Handler para documentos requeridos nuevos
      if (payload == 'documentConfigChanged') {
        if (kDebugMode) {
          debugPrint(
            'NotificationService: tap en notificación de documentos nuevos',
          );
        }

        Modular.to.pushNamed('/documentos-nuevos');
        return;
      }

      final chatId = payload;
      if (chatId.isEmpty) return;

      // Resolver modo desde SharedPreferences
      final mode = await _resolveUserMode();

      final route = mode == 'taxista'
          ? '/home-taxista/chats_taxista'
          : '/home/chats';

      Modular.to.pushNamed(route, arguments: {'chatId': chatId, 'mode': mode});
    } catch (e) {
      if (kDebugMode) debugPrint('Error handling local payload: $e');
    }
  }

  /// Retorna 'taxista' o 'pasajero' (por defecto 'pasajero').
  Future<String> _resolveUserMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('modo');
      if (cached != null && cached.isNotEmpty) {
        return cached.toLowerCase() == 'taxista' ? 'taxista' : 'pasajero';
      }
      return 'pasajero';
    } catch (e) {
      if (kDebugMode) debugPrint('Error resolviendo modo de usuario: $e');
      return 'pasajero';
    }
  }

  /// Pide permisos (iOS y Android 13+) y devuelve true si fueron concedidos
  Future<bool> pedirPermisosNotificaciones(BuildContext? context) async {
    // iOS/macOS
    if (Platform.isIOS || Platform.isMacOS) {
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: true,
      );

      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (kDebugMode) {
        debugPrint(
          'iOS notification permission: ${settings.authorizationStatus}',
        );
      }
      return granted;
    }

    // Android runtime permission (POST_NOTIFICATIONS) en Android 13+
    if (Platform.isAndroid) {
      try {
        final status = await Permission.notification.request();
        final granted = status == PermissionStatus.granted;
        if (kDebugMode) {
          debugPrint('Android notification permission: $status');
        }
        return granted;
      } catch (e) {
        if (kDebugMode) debugPrint('Error pidiendo permiso Android: $e');
        return false;
      }
    }

    // Otras plataformas
    return false;
  }

  Future<String?> getToken() => _fcm.getToken();

  // ---------------------------------------------------------------------------
  // OPCIÓN A (PASO 3): GUARDAR TOKEN EN REALTIME DATABASE
  // ---------------------------------------------------------------------------
  Future<void> _saveTokenToFirestore(String? token) async {
    // (dejamos el nombre para no romper llamadas existentes)
    if (token == null || token.isEmpty) return;

    final uid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    try {
      final db = FirebaseDatabase.instance;

      await db.ref('pasajeros/$uid').update({
        'fcmToken': token,
        // Si quieres timestamp, puedes agregar:
        // 'updatedAt': ServerValue.timestamp,
      });

      if (kDebugMode) {
        debugPrint('✅ Token FCM guardado en RTDB: pasajeros/$uid');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error guardando token FCM en RTDB: $e');
      }
    }
  }

  Future<void> showLocalNotification(
    String chatId,
    String mensaje,
    String otherUserName,
  ) async {
    const android = AndroidNotificationDetails(
      'chasky_high_importance',
      'Notificaciones importantes',
      channelDescription: 'Mensajes nuevos',
      importance: Importance.high,
      priority: Priority.high,
    );

    const ios = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: ios);

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      otherUserName,
      mensaje,
      details,
      payload: chatId,
    );
  }

  /// Notificación cuando el PASAJERO recibe una nueva oferta
  /// de un conductor para una orden en estado 'pedido'.
  /// Al tocarla, se abre la pantalla de la orden (ViajeSolicitado).
  Future<void> showNewOfferNotification({
    required String rutaDocOrden,
    String titulo = 'Has recibido una nueva oferta',
    String cuerpo = 'Un conductor ha enviado una nueva oferta.',
  }) async {
    final android = AndroidNotificationDetails(
      'chasky_high_importance',
      'Notificaciones importantes',
      channelDescription: 'Viajes y mensajes importantes',
      importance: Importance.max,
      priority: Priority.max,
      ticker: 'Nueva oferta',
      category: AndroidNotificationCategory.message,
      visibility: NotificationVisibility.public,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      color: const Color(0xFF16A34A),
      fullScreenIntent: false,
      styleInformation: BigTextStyleInformation(
        cuerpo,
        contentTitle: titulo,
      ),
    );

    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(android: android, iOS: ios);

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      titulo,
      cuerpo,
      details,
      payload: 'offer:$rutaDocOrden',
    );
  }

  /// Notificación local cuando un viaje (normal o programado) pasa a estado
  /// 'aceptado'. Al tocarla, se navega al historial del pasajero.
  Future<void> showTripAcceptedNotification({
    required String tripId,
    required String destinoResumen,
    required bool esProgramado,
  }) async {
    const android = AndroidNotificationDetails(
      'chasky_high_importance',
      'Notificaciones importantes',
      channelDescription: 'Viajes y mensajes importantes',
      importance: Importance.high,
      priority: Priority.high,
    );

    const ios = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: ios);

    final title = esProgramado
        ? 'Viaje programado aceptado'
        : 'Tu viaje fue aceptado';
    final body = 'Un conductor aceptó tu viaje hacia $destinoResumen';

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: 'trip:$tripId',
    );
  }

  /// Notificación cuando el PASAJERO acepta la oferta de un TAXISTA.
  ///
  /// - Si [esProgramado] es false → viaje normal ya está en curso.
  /// - Si [esProgramado] es true  → viaje programado confirmado.
  ///
  /// Al tocarla, se abre el Home del taxista.
  Future<void> showDriverOfferAcceptedNotification({
    required String rutaDocOrden,
    required bool esProgramado,
  }) async {
    const android = AndroidNotificationDetails(
      'chasky_high_importance',
      'Notificaciones importantes',
      channelDescription: 'Viajes y mensajes importantes',
      importance: Importance.high,
      priority: Priority.high,
    );

    const ios = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: ios);

    final title = esProgramado
        ? '¡Tu oferta programada fue confirmada!'
        : '¡Tu oferta ha sido aceptada!';

    final body = esProgramado
        ? 'Tu oferta para el viaje programado fue confirmada.'
        : 'El pasajero te está esperando para iniciar el viaje.';

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: 'driverTrip:$rutaDocOrden',
    );
  }

  /// Notificación local cuando aparecen nuevas órdenes cercanas para el TAXISTA
  /// (modo taxista). Si se pasa [rutaDocOrden], al tocarla se navega
  /// directamente a esa orden.
  Future<void> showNewNearbyOrdersForDriverNotification({
    required int count,
    String? rutaDocOrden,
  }) async {
    try {
      final mode = await _resolveUserMode();
      if (kDebugMode) {
        debugPrint(
          'NotificationService.showNewNearbyOrdersForDriverNotification: solicitado con count=$count, rutaDocOrden=$rutaDocOrden, mode=$mode',
        );
      }

      if (mode != 'taxista') {
        if (kDebugMode) {
          debugPrint(
            'NotificationService.showNewNearbyOrdersForDriverNotification: abortado porque mode!="taxista"',
          );
        }
        return;
      }

      const android = AndroidNotificationDetails(
        'chasky_high_importance',
        'Notificaciones importantes',
        channelDescription: 'Viajes y mensajes importantes',
        importance: Importance.high,
        priority: Priority.high,
      );

      const ios = DarwinNotificationDetails();
      const details = NotificationDetails(android: android, iOS: ios);

      final title = count == 1
          ? 'Nueva solicitud cercana'
          : 'Nuevas solicitudes cercanas';
      final body = count == 1
          ? 'Tienes una nueva solicitud de viaje cerca de ti.'
          : 'Tienes $count nuevas solicitudes de viaje cerca de ti.';

      final payload = (rutaDocOrden != null && rutaDocOrden.isNotEmpty)
          ? 'driverOrder:$rutaDocOrden'
          : 'driverOrders';

        if (kDebugMode) {
          debugPrint(
            'NotificationService.showNewNearbyOrdersForDriverNotification: mostrando notificación -> title="$title", body="$body", payload="$payload"',
          );
        }

        await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
        payload: payload,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'NotificationService: error mostrando notificación de nuevas órdenes cercanas: $e',
        );
      }
    }
  }

  Future<void> refreshAndSaveToken() async {
    final token = await getToken();
    if (kDebugMode) debugPrint('FCM token (refresh): $token');
    await _saveTokenToFirestore(token);
  }
}
