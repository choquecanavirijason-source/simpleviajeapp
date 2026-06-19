import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:buses2/features/chats/pages/chat_screen.dart';
import 'package:buses2/features/chats/service/rtdb_chat.dart';

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});
  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  final _auth = FirebaseAuth.instance;
  DatabaseReference get _db => FirebaseDatabase.instance.ref();

  StreamSubscription<DatabaseEvent>? _sub;
  List<_ChatRow> _rows = [];

  @override
  void initState() {
    super.initState();
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      final query = _db
          .child('userChats/$uid')
          .orderByChild('lastMessageAt')
          .limitToLast(100);
      _sub = query.onValue.listen((event) async {
        final data = (event.snapshot.value as Map?) ?? {};
        final entries = data.entries.toList()
          ..sort((a, b) {
            final la = (a.value['lastMessageAt'] ?? 0) as int;
            final lb = (b.value['lastMessageAt'] ?? 0) as int;
            return lb.compareTo(la);
          });

        final next = <_ChatRow>[];
        for (final e in entries) {
          final chatId = e.key;
          final otherUid = e.value['otherUid'] as String?;
          final lastMsg = (e.value['lastMessage'] ?? '') as String;
          final lastAt = (e.value['lastMessageAt'] ?? 0) as int;

          if (otherUid == null) continue;

          // datos del otro usuario
          final userSnap = await _db.child('users/$otherUid').get();
          final name =
              (userSnap.child('displayName').value ?? 'Usuario') as String;
          final photo =
              (userSnap.child('photoUrl').value ??
                      'https://i.pravatar.cc/150?u=$otherUid')
                  as String;

          // unread para mi
          final unreadSnap = await _db
              .child('chats/$chatId/unread/${_auth.currentUser!.uid}')
              .get();
          final unread = (unreadSnap.value ?? 0) as int;

          next.add(
            _ChatRow(
              chatId: chatId,
              otherUid: otherUid,
              title: name,
              subtitle: lastMsg,
              photoUrl: photo,
              lastMessageAt: DateTime.fromMillisecondsSinceEpoch(
                lastAt,
                isUtc: true,
              ).toLocal(),
              unread: unread,
            ),
          );
        }
        if (mounted) setState(() => _rows = next);
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return DateFormat.Hm().format(dt);
    }
    return DateFormat('dd/MM').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: _rows.isEmpty
          ? const Center(child: Text('Sin chats'))
          : ListView.separated(
              itemCount: _rows.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final row = _rows[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(row.photoUrl),
                  ),
                  title: Text(row.title),
                  subtitle: Text(
                    row.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _formatTime(row.lastMessageAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (row.unread > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${row.unread}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  onTap: () async {
                    // Abre chat y marca como leído
                    await markAsRead(
                      row.chatId,
                      FirebaseAuth.instance.currentUser!.uid,
                    );
                    if (!mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          chatId: row.chatId,
                          otherUid: row.otherUid,
                          otherName: row.title,
                          otherPhotoUrl: row.photoUrl,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _ChatRow {
  final String chatId;
  final String otherUid;
  final String title;
  final String subtitle;
  final String photoUrl;
  final DateTime lastMessageAt;
  final int unread;
  _ChatRow({
    required this.chatId,
    required this.otherUid,
    required this.title,
    required this.subtitle,
    required this.photoUrl,
    required this.lastMessageAt,
    required this.unread,
  });
}
