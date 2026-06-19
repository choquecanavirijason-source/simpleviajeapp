import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:buses2/core/services/notification/notification_service.dart';
import 'package:buses2/core/utils/string_extensions.dart';

class ChatListenerService {
  ChatListenerService._();
  static final ChatListenerService instance = ChatListenerService._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseDatabase.instance.ref('chats');

  /// Chat actualmente abierto
  String? activeChatId;

  /// Almacena los listeners activos para cada chat
  final Map<String, StreamSubscription<DatabaseEvent>> _chatListeners = {};

  /// Llamar al iniciar sesión
  void startListening() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // Escuchamos CUALQUIER cambio en la raíz de 'chats'
    // Esto se dispara para chats viejos y para los que se creen en el futuro
    _db.onChildAdded.listen((event) {
      final chatId = event.snapshot.key;
      if (chatId == null) return;

      final chatData = Map<String, dynamic>.from(event.snapshot.value as Map);
      final participantes = Map<String, dynamic>.from(
        chatData['participantes'] ?? {},
      );

      // REGLA DE ORO: Solo procesamos si el usuario actual es parte de este chat
      if (participantes.containsKey(uid)) {
        // Buscamos el nombre del otro participante
        final otherUserId = participantes.keys.firstWhere(
          (key) => key != uid,
          orElse: () => '',
        );

        String otherUserName = 'Usuario';
        if (otherUserId.isNotEmpty) {
          final otherUserData = Map<String, dynamic>.from(
            participantes[otherUserId],
          );
          otherUserName = (otherUserData['name'] ?? 'Usuario')
              .toString()
              .toTitleCase();
        }

        // Iniciamos la escucha de mensajes para este chat específico
        _listenToChat(chatId, otherUserName);

        if (kDebugMode) {
          debugPrint('Nuevo chat detectado y vinculado: $chatId');
        }
      }
    });
  }

  void _listenToChat(String chatId, String otherUserName) {
    if (_chatListeners.containsKey(chatId)) return;

    final uid = _auth.currentUser!.uid;

    // IMPORTANTE: Apuntamos directo a 'mensajes' dentro del chat
    // Usamos limitToLast(1) para escuchar SOLO lo nuevo que va llegando
    // y no descargar los 30 mensajes viejos que mostraste en tu JSON.
    final chatRef = _db
        .child(chatId)
        .child('mensajes') // Entramos al nodo mensajes
        .limitToLast(1); // ¡El truco de la eficiencia!
    final sub = chatRef.onChildAdded.listen((event) {
      final msg = Map<String, dynamic>.from(event.snapshot.value as Map);

      final creador = msg['creador'] ?? '';
      // Compara timestamp para asegurarte que no es un mensaje viejo "rebotando"
      // Tu JSON usa String ISO8601, así que parseamos:
      final creadoEnStr = msg['creadoEn'];
      if (creadoEnStr == null) return;

      final creadoEn = DateTime.parse(creadoEnStr);
      final diferencia = DateTime.now().difference(creadoEn).inSeconds;

      // Si el mensaje tiene más de 10 segundos de antigüedad, ignóralo (es carga inicial)
      if (diferencia > 10) return;

      if (creador == uid) return;
      if (activeChatId == chatId)
        return; // Si ya estoy viendo el chat, no notificar

      final mensajeTexto = msg['mensaje'] ?? '';
      NotificationService().showLocalNotification(
        chatId,
        mensajeTexto,
        otherUserName,
      );
    });

    _chatListeners[chatId] = sub;
  }

  /// Detener todos los listeners (por logout o cierre de app)
  Future<void> stopListening() async {
    for (final sub in _chatListeners.values) {
      await sub.cancel();
    }
    _chatListeners.clear();
  }
}
