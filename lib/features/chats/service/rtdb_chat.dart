import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

final FirebaseAuth _auth = FirebaseAuth.instance;
final DatabaseReference _root = FirebaseDatabase.instance.ref();

/// ID determinista (uidMenor_uidMayor) para chats 1–a–1.
String directChatId(String a, String b) {
  final x = a.compareTo(b) < 0 ? a : b;
  final y = a.compareTo(b) < 0 ? b : a;
  return '${x}_$y';
}

/// Crea (si no existe) un chat directo entre [meUid] y [otherUid].
Future<String> openDirectChat(String meUid, String otherUid) async {
  final chatId = directChatId(meUid, otherUid);
  final chatRef = _root.child('chats/$chatId');

  final snap = await chatRef.get();
  if (!snap.exists) {
    await chatRef.update({
      'participants/$meUid': true,
      'participants/$otherUid': true,
      'createdAt': ServerValue.timestamp,
      'updatedAt': ServerValue.timestamp,
      'lastMessage': null,
      'lastMessageAt': null,
      'unread/$meUid': 0,
      'unread/$otherUid': 0,
    });
  }

  // Asegura mirrors básicos para la lista de chats
  await _root.update({
    'userChats/$meUid/$chatId/otherUid': otherUid,
    'userChats/$otherUid/$chatId/otherUid': meUid,
  });

  return chatId;
}

/// Envía un mensaje de texto con fan-out (messages, chats, userChats, unread).
Future<void> sendText({
  required String chatId,
  required String meUid,
  required String otherUid,
  required String text,
}) async {
  if (text.trim().isEmpty) return;

  final msgKey = _root.child('messages/$chatId').push().key!;
  final now = ServerValue.timestamp;

  final updates = <String, Object?>{
    // mensaje
    'messages/$chatId/$msgKey/senderId': meUid,
    'messages/$chatId/$msgKey/text': text.trim(),
    'messages/$chatId/$msgKey/createdAt': now,

    // cabecera del chat
    'chats/$chatId/lastMessage': text.trim(),
    'chats/$chatId/lastMessageAt': now,
    'chats/$chatId/updatedAt': now,

    // mirrors de ambos usuarios
    'userChats/$meUid/$chatId/otherUid': otherUid,
    'userChats/$meUid/$chatId/lastMessage': text.trim(),
    'userChats/$meUid/$chatId/lastMessageAt': now,

    'userChats/$otherUid/$chatId/otherUid': meUid,
    'userChats/$otherUid/$chatId/lastMessage': text.trim(),
    'userChats/$otherUid/$chatId/lastMessageAt': now,

    // incrementa unread del receptor
    'chats/$chatId/unread/$otherUid': ServerValue.increment(1),
  };

  await _root.update(updates);
}

/// Marca como leído (pone a 0 el contador de [uid] en ese chat).
Future<void> markAsRead(String chatId, String uid) async {
  await _root.child('chats/$chatId/unread/$uid').set(0);
}

/// Crea/actualiza el perfil mínimo del usuario en RTDB (para foto/nombre en lista).
Future<void> ensureUserProfileInRTDB(User user) async {
  await _root.child('users/${user.uid}').update({
    'displayName': user.displayName ?? 'Usuario',
    'photoUrl': user.photoURL ?? '',
  });
}

/// (Opcional) Seed rápido de un chat con “Hola”
Future<void> seedDirectChatWithHello(String meUid, String otherUid) async {
  final chatId = await openDirectChat(meUid, otherUid);
  await sendText(
    chatId: chatId,
    meUid: meUid,
    otherUid: otherUid,
    text: 'Hola',
  );
}
