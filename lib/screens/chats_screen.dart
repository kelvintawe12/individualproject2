import 'package:flutter/material.dart';
import 'chat_detail_screen.dart';

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chats'), backgroundColor: const Color(0xFF0F1724)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const CircleAvatar(child: Text('A')),
            title: const Text('Alice'),
            subtitle: const Text('Yes, I\'m interested!'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatDetailScreen(chatId: 'chat1', otherUserName: 'Alice'))),
          ),
          ListTile(
            leading: const CircleAvatar(child: Text('B')),
            title: const Text('Bob'),
            subtitle: const Text('Can we meet tomorrow?'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatDetailScreen(chatId: 'chat2', otherUserName: 'Bob'))),
          ),
        ],
      ),
    );
  }
}
