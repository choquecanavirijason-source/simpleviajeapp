import 'package:cloud_firestore/cloud_firestore.dart';

final _db = FirebaseFirestore.instance;

/// ChatId determinista 1-a-1
String directChatId(String a, String b) {
  final x = a.compareTo(b) < 0 ? a : b;
  final y = a.compareTo(b) < 0 ? b : a;
  return '${x}_$y';
}

DocumentReference<Map<String, dynamic>> _chatRef(String chatId) =>
    _db.collection('chats').doc(chatId);

CollectionReference<Map<String, dynamic>> _msgCol(String chatId) =>
    _chatRef(chatId).collection('messages');

/// Crea el chat si no existe (exactamente 2 participantes)
Future<String> openDirectChat(String meUid, String otherUid) async {
  final id = directChatId(meUid, otherUid);
  final ref = _chatRef(id);

  await _db.runTransaction((tx) async {
    final snap = await tx.get(ref);
    if (!snap.exists) {
      tx.set(ref, {
        'participants': [meUid, otherUid],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessage': null,
        'lastMessageAt': null,
      });
    }
  });

  return id;
}

/// Enviar mensaje barato: 2 writes (mensaje + cabecera) en batch, 0 reads
Future<void> sendText({
  required String chatId,
  required String senderId,
  required String text,
}) async {
  final batch = _db.batch();
  final now = FieldValue.serverTimestamp();

  final msgRef = _msgCol(chatId).doc();
  batch.set(msgRef, {'senderId': senderId, 'text': text, 'createdAt': now});

  final cRef = _chatRef(chatId);
  batch.update(cRef, {
    'lastMessage': text,
    'lastMessageAt': now,
    'updatedAt': now,
  });

  await batch.commit();
}

/// Stream: todos mis chats (ordenados por actividad)
Stream<QuerySnapshot<Map<String, dynamic>>> userChatsStream(String uid) {
  return _db
      .collection('chats')
      .where('participants', arrayContains: uid)
      .orderBy('updatedAt', descending: true)
      .snapshots();
}

/// Stream: mensajes de un chat (más nuevos primero)
Stream<QuerySnapshot<Map<String, dynamic>>> chatMessagesStream(
  String chatId, {
  int limit = 60,
}) {
  return _msgCol(
    chatId,
  ).orderBy('createdAt', descending: true).limit(limit).snapshots();
}
