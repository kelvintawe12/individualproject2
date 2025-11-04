import 'package:flutter/material.dart';

class ChatDetailScreen extends StatefulWidget {
  final String chatId;
  final String otherUserName;

  const ChatDetailScreen({Key? key, required this.chatId, required this.otherUserName}) : super(key: key);

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageCtrl = TextEditingController();
  final List<Map<String, dynamic>> _messages = [
    {'text': 'Hi, I\'m interested in your book!', 'isMe': false, 'time': '10:30 AM'},
    {'text': 'Sure, when can we meet?', 'isMe': true, 'time': '10:32 AM'},
    {'text': 'Tomorrow at the library?', 'isMe': false, 'time': '10:35 AM'},
  ];

  void _sendMessage() {
    if (_messageCtrl.text.trim().isEmpty) return;
    setState(() {
      _messages.add({
        'text': _messageCtrl.text.trim(),
        'isMe': true,
        'time': TimeOfDay.now().format(context),
      });
    });
    _messageCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUserName),
        backgroundColor: const Color(0xFF0F1724),
        leading: const BackButton(),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final msg = _messages[i];
                final isMe = msg['isMe'] as bool;
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFFF0B429) : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(msg['text'], style: TextStyle(color: isMe ? Colors.black : Colors.black87)),
                        const SizedBox(height: 4),
                        Text(msg['time'], style: const TextStyle(fontSize: 10, color: Colors.black54)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageCtrl,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  mini: true,
                  child: const Icon(Icons.send),
                  backgroundColor: const Color(0xFFF0B429),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
