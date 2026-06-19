import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../data/repositories/chat_repository.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:buses2/core/utils/string_extensions.dart';

class ChatListPage extends StatelessWidget {
  final ChatRepository repository = ChatRepository();
  String mode = ''; //modo taxista o pasajero

  ChatListPage({super.key});
  @override
  Widget build(BuildContext context) {
    final args = Modular.args.data as Map<String, dynamic>;
    mode = args['mode'] ?? 'pasajero';
    return Scaffold(
      appBar: AppBar(title: const Text('Mis Chats'), centerTitle: true),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: repository.getUserChats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No tienes chats aún'));
          }

          final chats = snapshot.data!;

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final chatId = chat['id'] as String?;

              final myUid = FirebaseAuth.instance.currentUser!.uid;

              final otherUid = chat['otherUid'] as String? ?? '';
              final rawName = chat['otherName'];
              final otherName = (rawName is String ? rawName : otherUid)
                  .toTitleCase();
              final otherPhotoUrl = chat['otherPhotoUrl'] as String? ?? '';
              final unreadCount = chat['unreadCount'] as int? ?? 0;

              final rawLastMessage = chat['ultimoMensaje'];
              Map<String, dynamic>? lastMessageMap;
              if (rawLastMessage is Map) {
                lastMessageMap = Map<String, dynamic>.from(
                  rawLastMessage as Map,
                );
              }
              final lastMessage =
                  lastMessageMap?['mensaje'] ?? 'Sin mensajes aún';
              final lastMessageCreator = lastMessageMap?['creador'];

              String subtitleText = lastMessage;
              if (lastMessageCreator == myUid) {
                subtitleText = 'Tú: $lastMessage';
              }
              final lastMessageTimeRaw = lastMessageMap?['creadoEn'];
              String formattedTime = '';
              // ... (lógica de formattedTime)
              if (lastMessageTimeRaw != null) {
                final lastMessageTime = DateTime.tryParse(lastMessageTimeRaw);
                if (lastMessageTime != null) {
                  // Lógica simple para formato:
                  if (lastMessageTime.day == DateTime.now().day) {
                    formattedTime = TimeOfDay.fromDateTime(
                      lastMessageTime,
                    ).format(context);
                  } else {
                    formattedTime =
                        '${lastMessageTime.day}/${lastMessageTime.month}';
                  }
                }
              }
              return ListTile(
                //imagen del otro usuario
                leading: CircleAvatar(
                  backgroundImage: otherPhotoUrl.isNotEmpty
                      ? NetworkImage(otherPhotoUrl)
                      : const AssetImage('assets/icon/profile_icon.png')
                            as ImageProvider,
                ),
                title: Text(otherName), // o el nombre real si lo cargas
                subtitle: Text(subtitleText),
                trailing: Column(
                  // Usar Column para combinar hora e indicador
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formattedTime),
                    if (unreadCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: CircleAvatar(
                          radius: 10,
                          backgroundColor:
                              Colors.green, // Color de notificación
                          child: Text(
                            unreadCount > 9 ? '9+' : unreadCount.toString(),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                onTap: () {
                  final route = mode == 'pasajero'
                      ? '/home/chat/detail'
                      : '/home-taxista/chat/detail';
                  Modular.to.pushNamed(
                    route,
                    arguments: {
                      'chatId': chatId,
                      'otherUid': otherUid,
                      'otherName': otherName,
                      'otherPhotoUrl': otherPhotoUrl,
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
