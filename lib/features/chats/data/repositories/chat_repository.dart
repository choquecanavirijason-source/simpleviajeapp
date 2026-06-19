import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatRepository {
  final _db = FirebaseDatabase.instance.ref('chats');
  final _userChatsDb = FirebaseDatabase.instance.ref('user_chats');
  final _auth = FirebaseAuth.instance;

  String get currentUserId => _auth.currentUser?.uid ?? '';

  /// Lista de chats del usuario leyendo solo el índice `user_chats/$uid`.
  /// Cada elemento expone: id, otherUid, otherName, otherPhotoUrl,
  /// ultimoMensaje, unreadCount, actualizadoEn.
  Stream<List<Map<String, dynamic>>> getUserChats() {
    final uid = currentUserId;
    if (uid.isEmpty) {
      // Usuario no autenticado: stream vacío
      return const Stream.empty();
    }

    return _userChatsDb.child(uid).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return <Map<String, dynamic>>[];

      final chatsMap = Map<String, dynamic>.from(data as Map);
      final userChats = <Map<String, dynamic>>[];
      final ahora = DateTime.now();

      chatsMap.forEach((chatId, chatData) {
        final chat = Map<String, dynamic>.from(chatData);

        final otherUid = chat['otherUid'] as String? ?? '';
        final otherName = chat['otherName'] as String? ?? otherUid;
        final otherPhotoUrl = chat['otherPhoto'] as String? ?? '';
        final lastMessage = chat['lastMessage'];
        // --- Lógica de tiempo (1 mes) ---
        final updatedAtStr = chat['updatedAt'] as String? ?? '';
        final updatedAt = DateTime.tryParse(updatedAtStr) ?? DateTime(2000);
        final diferenciaDias = ahora.difference(updatedAt).inDays;
        final estaCerrado = chat['status'] == 'closed';

        // Si ha pasado más de 30 días y el chat NO figura como cerrado:
        if (diferenciaDias > 30 && !estaCerrado) {
          // Llamamos a cerrar, pero sin esperar el await para no bloquear la UI
          closeChat(chatId);
          // Actualizamos localmente para que el usuario ya lo vea como cerrado
          chat['status'] = 'closed';
        }

        userChats.add({
          'id': chatId,
          'otherUid': otherUid,
          'otherName': otherName,
          'otherPhotoUrl': otherPhotoUrl,
          // Para compatibilidad con la UI existente
          'ultimoMensaje': lastMessage,
          'unreadCount': chat['unreadCount'] as int? ?? 0,
          'actualizadoEn': updatedAtStr,
          'status': chat['status'] ?? 'active',
        });
      });

      // Ordenar por actualizadoEn (más reciente primero)
      userChats.sort((a, b) {
        final at =
            DateTime.tryParse(a['actualizadoEn'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bt =
            DateTime.tryParse(b['actualizadoEn'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });

      return userChats;
    });
  }

  Stream<List<Map<String, dynamic>>> getMessages(String chatId) {
    return _db.child(chatId).child('mensajes').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return [];

      final mensajesMap = Map<String, dynamic>.from(data as Map);

      final mensajesList = mensajesMap.entries.map((entry) {
        return {'id': entry.key, ...Map<String, dynamic>.from(entry.value)};
      }).toList();

      mensajesList.sort((a, b) {
        final aTime = DateTime.tryParse(a['creadoEn'] ?? '') ?? DateTime.now();
        final bTime = DateTime.tryParse(b['creadoEn'] ?? '') ?? DateTime.now();
        return aTime.compareTo(bTime);
      });

      return mensajesList;
    });
  }

  // En tu ChatRepository

  Future<String?> createChat(
    String uidA,
    String uidB,
    String nameA,
    String nameB,
    String? photoUrlA,
    String? photoUrlB,
  ) async {
    try {
      if (uidA == uidB)
        throw Exception("No se puede crear un chat consigo mismo");

      // Generar pairId único
      final ids = [uidA, uidB]..sort();
      final pair = "${ids[0]}_${ids[1]}";

      final existingQuery = await _db
          .orderByChild("pairId")
          .equalTo(pair)
          .get();

      if (existingQuery.exists) {
        final chatSnap = existingQuery.children.first;
        final chatId = chatSnap.key!;
        final chatData = Map<String, dynamic>.from(chatSnap.value as Map);

        final participantes = Map<String, dynamic>.from(
          chatData['participantes'] ?? {},
        );
        final participanteA = Map<String, dynamic>.from(
          participantes[uidA] ?? {},
        );
        final participanteB = Map<String, dynamic>.from(
          participantes[uidB] ?? {},
        );

        final otherNameForA = participanteB['name'] ?? nameB ?? uidB;
        final otherPhotoForA = participanteB['photoUrl'] ?? photoUrlB ?? '';
        final otherNameForB = participanteA['name'] ?? nameA ?? uidA;
        final otherPhotoForB = participanteA['photoUrl'] ?? photoUrlA ?? '';

        final ultimoMensaje = chatData['ultimoMensaje'];
        final actualizadoEn =
            chatData['actualizadoEn'] as String? ??
            DateTime.now().toIso8601String();
        final noLeidos = Map<String, dynamic>.from(chatData['noLeidos'] ?? {});

        final unreadA = (noLeidos[uidA] ?? 0) as int;
        final unreadB = (noLeidos[uidB] ?? 0) as int;

        final nowIso = DateTime.now().toIso8601String();

        await _db.child(chatId).update({
          'status':
              'active', // a futuro podría estar eliminado y los chats se vuelven permanentes en firestore
          'actualizadoEn': nowIso,
        });

        // Refrescar índice user_chats para ambos usuarios
        await Future.wait([
          _userChatsDb.child(uidA).child(chatId).update({
            'chatId': chatId,
            'otherUid': uidB,
            'otherName': otherNameForA,
            'otherPhoto': otherPhotoForA,
            'lastMessage': ultimoMensaje,
            'updatedAt': actualizadoEn,
            'unreadCount': unreadA,
            'status': 'active',
          }),
          _userChatsDb.child(uidB).child(chatId).update({
            'chatId': chatId,
            'otherUid': uidA,
            'otherName': otherNameForB,
            'otherPhoto': otherPhotoForB,
            'lastMessage': ultimoMensaje,
            'updatedAt': actualizadoEn,
            'unreadCount': unreadB,
            'status': 'active',
          }),
        ]);

        return chatId;
      }

      final chatRef = _db.push();

      final nowIso = DateTime.now().toIso8601String();

      await chatRef.set({
        'pairId': pair,

        'participantes': {
          uidA: {'name': nameA, 'photoUrl': photoUrlA},
          uidB: {'name': nameB, 'photoUrl': photoUrlB},
        },

        'creadoEn': nowIso,
        'actualizadoEn': nowIso,

        'noLeidos': {uidA: 0, uidB: 0},

        'ultimoMensaje': null,
        'permanente': false,
        'status': 'active',
      });

      final chatId = chatRef.key!;

      // Crear índice en user_chats para ambos usuarios
      await Future.wait([
        _userChatsDb.child(uidA).child(chatId).set({
          'chatId': chatId,
          'otherUid': uidB,
          'otherName': nameB ?? uidB,
          'otherPhoto': photoUrlB ?? '',
          'lastMessage': null,
          'updatedAt': nowIso,
          'unreadCount': 0,
        }),
        _userChatsDb.child(uidB).child(chatId).set({
          'chatId': chatId,
          'otherUid': uidA,
          'otherName': nameA ?? uidA,
          'otherPhoto': photoUrlA ?? '',
          'lastMessage': null,
          'updatedAt': nowIso,
          'unreadCount': 0,
        }),
      ]);

      return chatId;
    } catch (e) {
      return null;
    }
  }

  //delet chat por chat id
  Future<void> cancelPreAcceptedTrip(String chatId) async {
    final snap = await _db.child(chatId).get();
    if (!snap.exists) return;
    final chat = Map<String, dynamic>.from(snap.value as Map);
    final permanente = chat["permanente"] ?? false;

    // Obtener participantes para limpiar índice user_chats
    final participantes = Map<String, dynamic>.from(
      chat['participantes'] ?? {},
    );
    final participantUids = participantes.keys.cast<String>().toList();

    // Si nunca fue permanente y no hay historial → borrar
    if (!permanente) {
      await _db.child(chatId).remove();

      // Eliminar entradas en user_chats
      await Future.wait(
        participantUids.map(
          (uid) => _userChatsDb.child(uid).child(chatId).remove(),
        ),
      );
    } else {
      final nowIso = DateTime.now().toIso8601String();
      await _db.child(chatId).update({"actualizadoEn": nowIso});

      // Actualizar timestamp en user_chats
      await Future.wait(
        participantUids.map(
          (uid) => _userChatsDb.child(uid).child(chatId).update({
            'updatedAt': nowIso,
          }),
        ),
      );
    }
  }

  Future<void> sendMessage({
    required String chatId,
    required String myUid,
    required String text,
  }) async {
    // 1. Validaciones previas (Lecturas rápidas)
    // Usamos Transaction o get para verificar estado.
    // Por rendimiento, un get simple suele bastar, pero idealmente las Rules protegen esto.
    final chatSnapshot = await _db.child(chatId).get();
    if (!chatSnapshot.exists) throw Exception('Chat no existe');

    final chatData = Map<String, dynamic>.from(chatSnapshot.value as Map);
    final status = chatData['status'] as String? ?? 'active';

    if (status != 'active') {
      throw Exception('Este chat está cerrado y es solo de lectura.');
    }

    // 2. Preparar Datos
    final now = DateTime.now();
    final nowIso = now.toIso8601String();

    // Generar ID del mensaje offline (sin await)
    final newMsgKey = _db.child(chatId).child('mensajes').push().key!;

    // Identificar al otro participante (lógica extraída de tu código)
    final participantes = Map<String, dynamic>.from(
      chatData['participantes'] ?? {},
    );
    final otherUid = participantes.keys.firstWhere(
      (uid) => uid != myUid,
      orElse: () => '',
    );

    if (otherUid.isEmpty) throw Exception('Error en participantes del chat');

    final otherInfo = Map<String, dynamic>.from(participantes[otherUid] ?? {});
    final myInfo = Map<String, dynamic>.from(participantes[myUid] ?? {});

    // Datos para actualizar contadores
    final noLeidosMap = Map<String, dynamic>.from(chatData['noLeidos'] ?? {});
    final currentUnreadOther = (noLeidosMap[otherUid] ?? 0) as int;
    final newUnreadOther = currentUnreadOther + 1;

    // Payload del mensaje
    final messageData = {
      'id': newMsgKey,
      'creador': myUid,
      'mensaje': text,
      'creadoEn': nowIso,
      'estado': 'enviado',
      'tipo': 'texto',
    };

    final lastMessagePayload = {
      'mensaje': text,
      'creador': myUid,
      'creadoEn': nowIso,
    };

    // 3. FAN-OUT: Crear mapa de actualizaciones atómicas
    // "root" se refiere a la raíz de la base de datos
    Map<String, dynamic> updates = {};

    // A. Guardar el mensaje en la colección grande
    updates['chats/$chatId/mensajes/$newMsgKey'] = messageData;

    // B. Actualizar metadata del chat principal
    updates['chats/$chatId/ultimoMensaje'] = lastMessagePayload;
    updates['chats/$chatId/actualizadoEn'] = nowIso;
    updates['chats/$chatId/noLeidos/$otherUid'] =
        newUnreadOther; // Incremento manual seguro aquí porque leímos antes

    // C. Actualizar índice user_chats para MI (Emisor) - Reseteo mi contador
    updates['user_chats/$myUid/$chatId/lastMessage'] = lastMessagePayload;
    updates['user_chats/$myUid/$chatId/updatedAt'] = nowIso;
    updates['user_chats/$myUid/$chatId/unreadCount'] = 0;
    updates['user_chats/$myUid/$chatId/otherUid'] =
        otherUid; // Reaseguramos datos
    updates['user_chats/$myUid/$chatId/otherName'] =
        otherInfo['name'] ?? otherUid;
    updates['user_chats/$myUid/$chatId/otherPhoto'] =
        otherInfo['photoUrl'] ?? '';

    // D. Actualizar índice user_chats para EL OTRO (Receptor) - Incremento contador
    updates['user_chats/$otherUid/$chatId/lastMessage'] = lastMessagePayload;
    updates['user_chats/$otherUid/$chatId/updatedAt'] = nowIso;
    updates['user_chats/$otherUid/$chatId/unreadCount'] = newUnreadOther;
    updates['user_chats/$otherUid/$chatId/otherUid'] = myUid;
    updates['user_chats/$otherUid/$chatId/otherName'] = myInfo['name'] ?? myUid;
    updates['user_chats/$otherUid/$chatId/otherPhoto'] =
        myInfo['photoUrl'] ?? '';

    // 4. Ejecutar TODO en una sola petición a la red
    // Usamos update() sobre la referencia raíz para tocar múltiples nodos a la vez
    await FirebaseDatabase.instance.ref().update(updates);
  }

  Future<void> markMessagesAsRead(String chatId, String myUid) async {
    final mensajesRef = _db.child(chatId).child('mensajes');

    // 1. Obtener todos los mensajes
    final snapshot = await mensajesRef.get();
    final mensajesMap = Map<String, dynamic>.from(snapshot.value as Map? ?? {});

    final updates = <String, dynamic>{};

    // 2. Iterar sobre los mensajes
    mensajesMap.forEach((msgId, msgData) {
      final data = Map<String, dynamic>.from(msgData);
      final creador = data['creador'];
      final estado = data['estado'];

      // Solo actualiza si:
      // a) El mensaje fue enviado por la OTRA persona (`creador != myUid`).
      // b) El estado actual es 'enviado' o 'entregado' (no queremos re-marcar si ya está 'leído').
      if (creador != myUid && (estado == 'enviado' || estado == 'entregado')) {
        updates['$msgId/estado'] = 'leído';
      }
    });

    // 3. Aplicar las actualizaciones en lote
    if (updates.isNotEmpty) {
      await mensajesRef.update(updates);
    }
  }

  // Lógica de `resetUnread` mejorada
  Future<void> resetUnread(String chatId, String uid) async {
    // 1. Marcar los mensajes como 'leído' en la colección de mensajes
    await markMessagesAsRead(chatId, uid);

    // 2. Resetear el contador de no leídos para el chat_list (necesario)
    await _db.child(chatId).child('noLeidos').child(uid).set(0);

    // 2b. Resetear contador en el índice user_chats
    await _userChatsDb.child(uid).child(chatId).update({'unreadCount': 0});

    // 3. Opcional: Actualizar el estado del último mensaje enviado por la OTRA persona
    // Esto asegura que la última notificación de lectura global también se actualice.
    final lastMsgSnap = await _db.child(chatId).child('ultimoMensaje').get();
    final lastMsg = Map<String, dynamic>.from(lastMsgSnap.value as Map? ?? {});

    if (lastMsg['creador'] != uid) {
      // Si el último mensaje NO fue creado por el usuario que acaba de entrar (es decir, fue del otro),
      // Podrías actualizar el estado de ese mensaje en la DB a 'leído'.
      // Sin embargo, como `markMessagesAsRead` ya lo hace, esta parte es redundante.
      // Se mantiene la simplicidad de actualizar solo los mensajes individuales.
    }
  }

  // Una vez que un usuario acepta un viaje, entonces el chat asociado se marca como "permanente"
  Future<void> markChatAsPermanent(String chatId) async {
    await _db.child(chatId).update({
      "permanente": true,
      "actualizadoEn": DateTime.now().toIso8601String(),
    });
  }

  /// Marca un chat como cerrado (solo lectura).
  Future<void> closeChat(String chatId) async {
    final snap = await _db.child(chatId).get();
    if (!snap.exists) return;

    final chat = Map<String, dynamic>.from(snap.value as Map);
    final participantes = Map<String, dynamic>.from(
      chat['participantes'] ?? {},
    );
    final participantUids = participantes.keys.cast<String>().toList();

    final nowIso = DateTime.now().toIso8601String();

    await _db.child(chatId).update({
      'status': 'closed',
      'actualizadoEn': nowIso,
    });

    // Reflejar estado también en el índice user_chats
    await Future.wait(
      participantUids.map(
        (uid) => _userChatsDb.child(uid).child(chatId).update({
          'status': 'closed',
          'updatedAt': nowIso,
        }),
      ),
    );
  }
}
