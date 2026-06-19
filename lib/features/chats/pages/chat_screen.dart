import 'package:flutter/material.dart';
import '../data/repositories/chat_repository.dart';
import 'package:buses2/core/utils/string_extensions.dart';
import 'package:buses2/shared/services/chat_listener_service.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String? otherUid;
  final String? otherName;
  final String? otherPhotoUrl;
  // El repositorio se inicializa aquí para que esté disponible en el State
  final ChatRepository repository = ChatRepository();

  ChatScreen({
    super.key,
    required this.chatId,
    this.otherUid,
    this.otherName,
    this.otherPhotoUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late String myUid;

  @override
  void initState() {
    super.initState();
    ChatListenerService.instance.activeChatId = widget.chatId;
    myUid = widget.repository.currentUserId;

    if (myUid.isNotEmpty) {
      // ESTO AHORA LLAMA A markMessagesAsRead Y PONE LOS TICKS AZULES
      widget.repository.resetUnread(widget.chatId, myUid);
    }
  }

  @override
  void dispose() {
    ChatListenerService.instance.activeChatId = null;
    super.dispose();
  }

  // Lógica de envío de mensaje (sin cambios)
  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    try {
      await widget.repository.sendMessage(
        chatId: widget.chatId,
        myUid: myUid,
        text: text,
        // Nota: El repository debe manejar la adición de estado: 'enviado' por defecto.
      );
    } catch (e) {
      // Si el chat está cerrado o hay otro error, mostramos feedback
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo enviar el mensaje. El chat puede estar cerrado.',
          ),
        ),
      );
    }

    _scrollToBottom();
  }

  // Lógica de scroll (sin cambios)
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Lógica de formato de día (sin cambios)
  String formatDay(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(date.year, date.month, date.day);

    final difference = today.difference(msgDay).inDays;

    if (difference == 0) return "Hoy";
    if (difference == 1) return "Ayer";

    return "${date.day}/${date.month}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    final otherPhotoUrl = (widget.otherPhotoUrl ?? '').isNotEmpty
        ? widget.otherPhotoUrl
        : null;
    //primeas letras en mayudculas no tdo en mayucula
    final String displayName =
        widget.otherName?.toTitleCase() ?? 'Usuario Desconocido';

    return Scaffold(
      appBar: AppBar(
        // La imagen y el nombre van dentro del 'title' para aparecer a la izquierda
        title: Row(
          children: [
            // 1. Imagen de Perfil
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: CircleAvatar(
                backgroundImage:
                    otherPhotoUrl != null && otherPhotoUrl.isNotEmpty
                    ? NetworkImage(otherPhotoUrl) as ImageProvider
                    // Usar el asset de fallback
                    : const AssetImage('assets/icon/profile_icon.png')
                          as ImageProvider,
                child: otherPhotoUrl == null || otherPhotoUrl.isEmpty
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
            ),

            // 2. Nombre y estado (si aplica)
            Expanded(
              // <--- ¡Esta es la clave!
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(fontSize: 18),
                    // Ahora esto truncará el texto si es más largo que el espacio disponible
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),

        // Debe ser false para que el título no se centre y se alinee al botón de regreso
        centerTitle: false,

        // El resto de los iconos (ej. llamadas, menú) van en 'actions'
        actions: const [
          // Ejemplo de un ícono de acción
          // IconButton(
          //   icon: Icon(Icons.call),
          //   onPressed: () {},
          // ),
          // Padding(
          //   padding: EdgeInsets.only(right: 12.0),
          //   child: Icon(Icons.more_vert),
          // ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: widget.repository.getMessages(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No hay mensajes aún'));
                }

                final mensajes = snapshot.data!;
                // Marcar como leídos cada vez que llegan mensajes nuevos
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  widget.repository.resetUnread(widget.chatId, myUid);
                  widget.repository.markMessagesAsRead(widget.chatId, myUid);
                });
                // Scroll automático
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _scrollToBottom(),
                );

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: mensajes.length,
                  itemBuilder: (context, index) {
                    final msg = mensajes[index];
                    final isMe = msg['creador'] == myUid;

                    final timestamp = msg['creadoEn'];
                    final date = DateTime.parse(timestamp).toLocal();
                    final hora =
                        "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";

                    // Lógica para el separador de fecha
                    bool showDateSeparator = false;
                    String dateLabel = '';

                    if (index == 0) {
                      showDateSeparator = true;
                    } else {
                      final prevMsg = mensajes[index - 1];
                      final prevDate = DateTime.parse(
                        prevMsg['creadoEn'],
                      ).toLocal();

                      // Compara si el día del mensaje actual es diferente al anterior
                      if (date.day != prevDate.day ||
                          date.month != prevDate.month ||
                          date.year != prevDate.year) {
                        showDateSeparator = true;
                      }
                    }

                    if (showDateSeparator) {
                      dateLabel = formatDay(date);
                    }

                    return Column(
                      children: [
                        // Separador de Fecha
                        if (showDateSeparator)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10.0),
                            child: Chip(
                              label: Text(
                                dateLabel,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                              backgroundColor: Colors.grey[200],
                            ),
                          ),

                        // Burbuja del Mensaje
                        Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75,
                            ),
                            margin: const EdgeInsets.symmetric(
                              vertical: 2,
                              horizontal: 8,
                            ),
                            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.green[400]
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                // Diseño asimétrico para la burbuja
                                bottomLeft: Radius.circular(isMe ? 16 : 4),
                                bottomRight: Radius.circular(isMe ? 4 : 16),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // Contenido del Mensaje
                                Text(
                                  msg['mensaje'] ?? '',
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),

                                // Hora y Estado de Lectura
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      hora,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isMe
                                            ? Colors.white70
                                            : Colors.black54,
                                      ),
                                    ),
                                    if (isMe) ...[
                                      const SizedBox(width: 4),
                                      _buildStatusIcon(
                                        msg['estado'],
                                      ), // Llama a la función para el ícono
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          // Campo de entrada de texto (sin cambios)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                  color: Colors.blue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper para el ícono de estado del mensaje
  Widget _buildStatusIcon(String? status) {
    if (status == 'leído') {
      return const Icon(
        Icons.done_all,
        size: 12,
        color: Colors.lightBlueAccent, // Azul para leído
      );
    } else if (status == 'entregado') {
      return const Icon(
        Icons.done_all,
        size: 12,
        color: Colors.white70, // Gris para entregado
      );
    } else if (status == 'enviado') {
      return const Icon(
        Icons.done,
        size: 12,
        color: Colors.white70, // Gris para enviado
      );
    }
    return const SizedBox.shrink(); // No muestra nada si el estado es nulo/desconocido
  }
}
