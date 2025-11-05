import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import 'package:flutter/services.dart';
import 'chat_detail_screen.dart';

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
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
      body: uid == null
          ? const Center(child: Text('Sign in to see chats', style: TextStyle(color: Colors.white)))
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: FirebaseService.listenChatsForUser(uid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                if (snap.hasError) {
                  final err = snap.error;
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_outline, color: Colors.redAccent, size: 56),
                          const SizedBox(height: 12),
                          Text('Could not load chats: $err', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton(
                                onPressed: () => (context as Element).markNeedsBuild(),
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF0B429)),
                                child: const Text('Retry'),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  try {
                                    final diag = await FirebaseService.getDiagnostics(queryDesc: 'chats for user=$uid');
                                    final payload = 'Error: $err\n\n$diag';
                                    await Clipboard.setData(ClipboardData(text: payload));
                                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Diagnostics copied to clipboard')));
                                  } catch (e) {
                                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to copy diagnostics: $e')));
                                  }
                                },
                                icon: const Icon(Icons.bug_report_outlined),
                                label: const Text('Report'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800]),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final chats = snap.data ?? [];
                if (chats.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('No chats yet', style: TextStyle(color: Colors.white)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final otherUid = await showDialog<String>(
                              context: context,
                              builder: (ctx) {
                                final ctrl = TextEditingController();
                                return AlertDialog(
                                  title: const Text('Start chat'),
                                  content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Other user UID')),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                                    TextButton(onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()), child: const Text('Start')),
                                  ],
                                );
                              },
                            );
                            if (otherUid != null && otherUid.isNotEmpty) {
                              try {
                                final chatId = await FirebaseService.getOrCreateDirectChat(uid, otherUid);
                                Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatDetailScreen(chatId: chatId, otherUserName: otherUid)));
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create chat: $e')));
                              }
                            }
                          },
                          icon: const Icon(Icons.chat),
                          label: const Text('Start a chat'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF0B429)),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: chats.length,
                  itemBuilder: (context, i) {
                    final chat = chats[i];
                    final participants = List<String>.from(chat['participants'] ?? []);
                    final other = participants.firstWhere((p) => p != uid, orElse: () => participants.first);
                    final lastMessage = chat['lastMessage'] ?? '';
                    final lastSent = chat['lastSentAt'];
                    String timeLabel = '';
                    if (lastSent is Timestamp) {
                      timeLabel = TimeOfDay.fromDateTime(lastSent.toDate()).format(context);
                    }
                    return _ChatTile(
                      name: other,
                      lastMessage: lastMessage,
                      time: timeLabel,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatDetailScreen(chatId: chat['id'], otherUserName: other))),
                    );
                  },
                );
              },
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