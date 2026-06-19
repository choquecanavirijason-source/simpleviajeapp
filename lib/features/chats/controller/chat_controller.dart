import 'package:flutter/material.dart';
import '../data/repositories/chat_repository.dart';

class ChatController extends ChangeNotifier {
  final ChatRepository _repository = ChatRepository();
  List<Map<String, dynamic>> chats = [];
  bool loading = true;

  ChatController() {
    loadChats();
  }

  void loadChats() {
    _repository.getUserChats().listen((chatList) {
      chats = chatList;
      loading = false;
      notifyListeners();
    });
  }
}
