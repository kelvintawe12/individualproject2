import 'package:flutter/material.dart';

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chats'), backgroundColor: const Color(0xFF0F1724)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(leading: CircleAvatar(child: Text('A')), title: Text('Alice'), subtitle: Text('Yes, I\'m interested!')),
          ListTile(leading: CircleAvatar(child: Text('B')), title: Text('Bob'), subtitle: Text('Can we meet tomorrow?')),
        ],
      ),
    );
  }
}
