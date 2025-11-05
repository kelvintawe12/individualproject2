import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'chat_detail_screen.dart';

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1724),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1724),
        elevation: 0,
        title: const Text(
          'Chats',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ChatTile(
            name: 'Alice',
            lastMessage: 'Yes, I\'m interested!',
            time: 'May 20',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ChatDetailScreen(chatId: 'chat1', otherUserName: 'Alice'),
              ),
            ),
          ),
          _ChatTile(
            name: 'Bob',
            lastMessage: 'Can we meet tomorrow?',
            time: 'May 19',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ChatDetailScreen(chatId: 'chat2', otherUserName: 'Bob'),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomNavBar(currentIndex: 1),
    );
  }
}

// ── Chat List Tile ─────────────────────────────────────
class _ChatTile extends StatelessWidget {
  final String name;
  final String lastMessage;
  final String time;
  final VoidCallback onTap;

  const _ChatTile({
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFF0B429),
          child: Text(name[0], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        ),
        title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Text(lastMessage, style: const TextStyle(color: Colors.white70)),
        trailing: Text(time, style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ),
    );
  }
}

// ── Glass Card ─────────────────────────────────────
class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
        child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ── Bottom Nav ─────────────────────────────────────
class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  const _BottomNavBar({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      backgroundColor: const Color(0xFF0F1724),
      unselectedItemColor: Colors.white60,
      selectedItemColor: const Color(0xFFF0B429),
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'Chats'),
        BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Notif'),
      ],
      onTap: (i) {
        if (i == 0) Navigator.of(context).popUntil((r) => r.isFirst);
      },
    );
  }
}