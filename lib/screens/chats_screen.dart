import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import 'package:flutter/services.dart';
import 'chat_detail_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  List<Map<String, dynamic>> users = [];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  void _fetchUsers() {
    debugPrint('[ChatsScreen] Fetching users...');
    FirebaseService.listenAllUsers().listen((data) {
      debugPrint('[ChatsScreen] Received ${data.length} users');
      setState(() {
        users = data;
      });
    }, onError: (error) {
      debugPrint('[ChatsScreen] Error fetching users: $error');
    });
  }

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
                            final selectedUser = await showDialog<Map<String, dynamic>>(
                              context: context,
                              builder: (ctx) {
                                return AlertDialog(
                                  title: const Text('Select user to chat with'),
                                  content: SizedBox(
                                    width: double.maxFinite,
                                    height: 300,
                                    child: ListView.builder(
                                      itemCount: users.length,
                                      itemBuilder: (ctx, i) {
                                        final user = users[i];
                                        final userId = user['id'] as String?;
                                        final displayName = user['displayName'] as String? ?? 'Unknown';
                                        if (userId == uid) return const SizedBox.shrink(); // Skip current user
                                        return ListTile(
                                          title: Text(displayName),
                                          onTap: () => Navigator.of(ctx).pop(user),
                                        );
                                      },
                                    ),
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                                  ],
                                );
                              },
                            );
                            if (selectedUser != null) {
                              final otherUid = selectedUser['id'] as String;
                              debugPrint('[ChatsScreen] Starting chat with user: $otherUid');
                              try {
                                final chatId = await FirebaseService.getOrCreateDirectChat(uid, otherUid);
                                final displayName = selectedUser['displayName'] as String? ?? otherUid;
                                debugPrint('[ChatsScreen] Chat created with ID: $chatId, navigating to ChatDetailScreen');
                                Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatDetailScreen(chatId: chatId, otherUserName: displayName, otherUserId: otherUid)));
                              } catch (e) {
                                debugPrint('[ChatsScreen] Failed to create chat: $e');
                                // Show a dialog with an option to copy diagnostics to clipboard
                                if (context.mounted) {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) {
                                      return AlertDialog(
                                        title: const Text('Failed to create chat'),
                                        content: Text('Error: $e'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(ctx).pop(),
                                            child: const Text('OK'),
                                          ),
                                          TextButton(
                                            onPressed: () async {
                                              Navigator.of(ctx).pop();
                                              try {
                                                final diag = await FirebaseService.getDiagnostics(queryDesc: 'create chat uid=$uid other=$otherUid', error: e);
                                                await Clipboard.setData(ClipboardData(text: diag));
                                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Diagnostics copied to clipboard')));
                                              } catch (err) {
                                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to copy diagnostics: $err')));
                                              }
                                            },
                                            child: const Text('Copy diagnostics'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                }
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
                    // Fetch user data for display name
                    final userData = users.firstWhere((u) => u['id'] == other, orElse: () => {'displayName': other});
                    final displayName = userData['displayName'] as String? ?? other;
                    debugPrint('[ChatsScreen] Rendering chat tile for: $displayName (other: $other)');
                    return _ChatTile(
                      name: displayName,
                      lastMessage: lastMessage,
                      time: timeLabel,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatDetailScreen(chatId: chat['id'], otherUserName: displayName, otherUserId: other))),
                    );
                  },
                );
              },
            ),
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
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFF0B429),
          radius: 20,
          child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        ),
        title: Text(
          name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          lastMessage,
          style: const TextStyle(color: Colors.white70),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
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


