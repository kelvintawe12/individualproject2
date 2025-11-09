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
        leading: const BackButton(color: Colors.white),
        // FAB is used instead of AppBar action for starting new chats
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
                  // Prefer an explicit chat name when present (set during group creation)
                    final chatName = (chat['name'] as String?)?.trim();
                    String displayName;
                    String? otherUserId;
                    if (chatName != null && chatName.isNotEmpty) {
                      displayName = chatName;
                      // If it's a direct chat (two participants) keep otherUserId for actions
                      otherUserId = participants.length == 2 ? other : null;
                    } else if (participants.length > 2) {
                      displayName = 'Group (${participants.length})';
                      otherUserId = null;
                    } else {
                      final userData = users.firstWhere((u) => u['id'] == other, orElse: () => {'displayName': other, 'avatarUrl': ''});
                      displayName = (userData['displayName'] as String?) ?? other;
                      otherUserId = other;
                    }
                    debugPrint('[ChatsScreen] Rendering chat tile for: $displayName (other: $other)');

                    // Build avatar (single avatar or a small cluster for groups)
                    Widget avatarWidget;
                    if (participants.length == 1 || (participants.length == 2 && otherUserId != null)) {
                      // single other user avatar if we have it in users list
            final u = users.firstWhere((u) => u['id'] == other, orElse: () => {'displayName': other, 'avatarUrl': ''});
            final avatarUrl = (u['avatarUrl'] as String?) ?? '';
            final av = (avatarUrl.isNotEmpty)
              ? CircleAvatar(backgroundImage: NetworkImage(avatarUrl), backgroundColor: const Color(0xFFF0B429))
              : CircleAvatar(backgroundColor: const Color(0xFFF0B429), child: Text(displayName.isNotEmpty ? displayName[0] : '?', style: const TextStyle(color: Colors.black87)));
                      avatarWidget = av;
                    } else {
                      // participant cluster: show up to 3 avatars overlapping
                      final pics = <Widget>[];
                      for (var p in participants.take(3)) {
                        if (p == FirebaseAuth.instance.currentUser?.uid) continue;
            final u = users.firstWhere((u) => u['id'] == p, orElse: () => {'displayName': p, 'avatarUrl': ''});
            final avatarUrl = (u['avatarUrl'] as String?) ?? '';
            final avatar = (avatarUrl.isNotEmpty)
              ? CircleAvatar(radius: 12, backgroundImage: NetworkImage(avatarUrl))
              : CircleAvatar(radius: 12, backgroundColor: const Color(0xFFF0B429), child: Text(((u['displayName'] as String?) ?? p).isNotEmpty ? ((u['displayName'] as String?) ?? p)[0] : '?', style: const TextStyle(color: Colors.black87, fontSize: 10)));
                        pics.add(avatar);
                      }
                      avatarWidget = SizedBox(
                        width: 44,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: pics.asMap().entries.map((e) {
                            final idx = e.key;
                            return Positioned(left: idx * 16.0, child: e.value);
                          }).toList(),
                        ),
                      );
                    }

                    return _ChatTile(
                      avatar: avatarWidget,
                      name: displayName,
                      lastMessage: lastMessage,
                      time: timeLabel,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatDetailScreen(chatId: chat['id'], otherUserName: displayName, otherUserId: otherUserId))),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Improved multi-select dialog with optional group name
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid == null) return;
          final selected = <String>{};
          final groupNameCtrl = TextEditingController();

          final result = await showDialog<bool>(
            context: context,
            builder: (ctx) {
              return StatefulBuilder(builder: (ctx, setState) {
                return AlertDialog(
                  title: const Text('Create chat'),
                  content: SizedBox(
                    width: double.maxFinite,
                    height: 420,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: groupNameCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Optional group name (for multiple users)',
                            prefixIcon: Icon(Icons.group),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text('Select users', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Material(
                              color: Colors.transparent,
                              child: ListView.builder(
                                itemCount: users.length,
                                itemBuilder: (c, i) {
                                  final user = users[i];
                                  final userId = user['id'] as String?;
                                  final displayName = user['displayName'] as String? ?? 'Unknown';
                                  if (userId == uid) return const SizedBox.shrink();
                                  final checked = selected.contains(userId);
                                  return CheckboxListTile(
                                    value: checked,
                                    title: Text(displayName),
                                    secondary: CircleAvatar(
                                      backgroundColor: const Color(0xFFF0B429),
                                      child: Text(displayName.isNotEmpty ? displayName[0] : '?', style: const TextStyle(color: Colors.black87)),
                                    ),
                                    onChanged: (v) {
                                      setState(() {
                                        if (v == true) selected.add(userId!);
                                        else selected.remove(userId);
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () { groupNameCtrl.dispose(); Navigator.of(ctx).pop(false); }, child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: selected.isEmpty
                          ? null
                          : () {
                              Navigator.of(ctx).pop(true);
                            },
                      child: const Text('Create'),
                    ),
                  ],
                );
              });
            },
          );

          final groupName = groupNameCtrl.text.trim();
          groupNameCtrl.dispose();

          if (result == true && selected.isNotEmpty) {
            try {
              final participants = [uid, ...selected];
              final metadata = groupName.isNotEmpty ? {'name': groupName} : null;
              final chatId = await FirebaseService.createChatWithParticipants(participants, metadata: metadata);
              final title = groupName.isNotEmpty
                  ? groupName
                  : (participants.length > 2 ? 'Group (${participants.length})' : users.firstWhere((u) => u['id'] == selected.first)['displayName'] as String? ?? 'Chat');
              if (context.mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatDetailScreen(chatId: chatId, otherUserName: title, otherUserId: null)));
            } catch (e) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create chat: $e')));
            }
          }
        },
        backgroundColor: const Color(0xFFF0B429),
        child: const Icon(Icons.group_add, color: Colors.black87),
      ),
    );
  }
}

// ── Chat List Tile ─────────────────────────────────────
class _ChatTile extends StatelessWidget {
  final Widget? avatar;
  final String name;
  final String lastMessage;
  final String time;
  final VoidCallback onTap;

  const _ChatTile({
    this.avatar,
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
        leading: avatar ?? CircleAvatar(
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


