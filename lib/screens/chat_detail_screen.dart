import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/firebase_service.dart';
import 'package:flutter/services.dart';

class ChatDetailScreen extends StatefulWidget {
  final String chatId;
  final String otherUserName;
  final String? otherUserId;

  const ChatDetailScreen({Key? key, required this.chatId, required this.otherUserName, this.otherUserId}) : super(key: key);

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _uploading = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;
    final senderId = FirebaseAuth.instance.currentUser?.uid;
    if (senderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be signed in to send messages')));
      return;
    }
    try {
      _messageCtrl.clear();
      await FirebaseService.sendMessage(widget.chatId, senderId, text: text);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
    }
  }

  Future<void> _sendImage() async {
    final senderId = FirebaseAuth.instance.currentUser?.uid;
    if (senderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to send images')));
      return;
    }
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked == null) return;
      setState(() { _uploading = true; _uploadProgress = 0.0; });
      final url = await FirebaseService.uploadChatImage(File(picked.path), (p) => setState(() => _uploadProgress = p));
      await FirebaseService.sendMessage(widget.chatId, senderId, imageUrl: url);
      if (mounted) setState(() { _uploading = false; _uploadProgress = 0.0; });
    } catch (e) {
      if (mounted) {
        setState(() { _uploading = false; _uploadProgress = 0.0; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image send failed: $e')));
      }
    }
  }

  bool _sameDay(dynamic a, dynamic b) {
    if (a is Timestamp && b is Timestamp) {
      final da = a.toDate();
      final db = b.toDate();
      return da.year == db.year && da.month == db.month && da.day == db.day;
    }
    return false;
  }

  String _formatDateLabel(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF0F1724),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1724),
        elevation: 0,
        title: Text(
          widget.otherUserName,
          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: FirebaseService.listenMessages(widget.chatId),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  // Surface listen errors (permission denied etc.) so the user
                  // sees a helpful message instead of a blank chat view.
                  if (snap.hasError) {
                    final err = snap.error;
                    final isPermDenied = err != null && err.toString().contains('permission-denied');
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(isPermDenied ? Icons.lock_outline : Icons.error_outline, color: Colors.redAccent, size: 56),
                            const SizedBox(height: 12),
                            Text(
                              isPermDenied
                                  ? 'You do not have permission to view this chat.'
                                  : 'Could not load messages: $err',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton(
                                  onPressed: () => setState(() {}),
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF0B429)),
                                  child: const Text('Retry'),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    try {
                                      final diag = await FirebaseService.getDiagnostics(queryDesc: 'messages for chat=${widget.chatId}');
                                      final payload = 'Error: $err\n\n$diag';
                                      await Clipboard.setData(ClipboardData(text: payload));
                                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Diagnostics copied to clipboard')));
                                    } catch (e) {
                                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to copy diagnostics: $e')));
                                    }
                                  },
                                  icon: const Icon(Icons.bug_report_outlined),
                                  label: const Text('Report'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800]),
                                ),
                                if (isPermDenied && widget.otherUserId != null) ...[
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      final requesterId = FirebaseAuth.instance.currentUser?.uid;
                                      if (requesterId == null) {
                                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to request access')));
                                        return;
                                      }
                                        try {
                                          await FirebaseService.requestChatAccess(widget.chatId, requesterId, widget.otherUserId!);
                                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Access request sent')));
                                        } catch (e) {
                                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send request: $e')));
                                      }
                                    },
                                    icon: const Icon(Icons.person_add_alt_1_outlined),
                                    label: const Text('Request access'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final msgs = snap.data ?? [];
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: msgs.length,
                    itemBuilder: (context, i) {
                      final m = msgs[i];
                      final senderId = m['senderId'] as String? ?? '';
                      final isMe = senderId == FirebaseAuth.instance.currentUser?.uid;
                      final created = m['createdAt'];
                      String timeLabel;
                      if (created is Timestamp) {
                        final dt = created.toDate();
                        timeLabel = TimeOfDay.fromDateTime(dt).format(context);
                      } else {
                        timeLabel = TimeOfDay.now().format(context);
                      }
                      // Show a date header when the previous message has a different day
                      final showDate = i == 0 || !_sameDay(msgs[i - 1]['createdAt'], m['createdAt']);
                      return Column(
                        children: [
                          if (showDate)
                            _DateHeader(date: _formatDateLabel(m['createdAt'])),
                          _MessageBubble(text: (m['text'] ?? '') as String, isMe: isMe, time: timeLabel),
                        ],
                      );
                    },
                  );
                },
              ),
            ),

            // Input (pad above keyboard) - use SafeArea and a small extra bottom padding
            SafeArea(
              top: false,
              child: Padding(
                // Add a small extra padding to avoid tiny overflow artifacts
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 8.0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F1724),
                    border: Border(top: BorderSide(color: Colors.white12)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _GlassTextField(
                          controller: _messageCtrl,
                          hint: 'Message',
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_uploading)
                        SizedBox(width: 36, height: 36, child: CircularProgressIndicator(value: _uploadProgress, color: const Color(0xFFF0B429)))
                      else
                        IconButton(
                          icon: const Icon(Icons.attach_file, color: Colors.white70),
                          onPressed: _sendImage,
                        ),
                      const SizedBox(width: 8),
                      FloatingActionButton(
                        onPressed: _sendMessage,
                        mini: true,
                        backgroundColor: const Color(0xFFF0B429),
                        child: const Icon(Icons.send, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNavBar(currentIndex: 1),
    );
  }
}

// ── Date Header ─────────────────────────────────────
class _DateHeader extends StatelessWidget {
  final String date;
  const _DateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(date, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    );
  }
}

// ── Message Bubble ─────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String time;

  const _MessageBubble({required this.text, required this.isMe, required this.time});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFF0B429) : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(color: isMe ? Colors.black87 : Colors.white, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(color: (isMe ? Colors.black54 : Colors.white60), fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

// Typing indicator removed — use server-side presence/typing hooks later if desired.

// ── Glass TextField ─────────────────────────────────────
class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final Function(String)? onSubmitted;

  const _GlassTextField({required this.controller, required this.hint, this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white60),
            filled: true,
            fillColor: Colors.white.withOpacity(0.08),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          onSubmitted: onSubmitted,
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