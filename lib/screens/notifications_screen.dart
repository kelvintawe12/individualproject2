import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: const Color(0xFF0F1724),
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(
            leading: Icon(Icons.swap_horiz, color: Color(0xFFF0B429)),
            title: Text('Swap request accepted'),
            subtitle: Text('Your swap for "Data Structures & Algorithms" has been accepted!'),
            trailing: Text('2h ago'),
          ),
          ListTile(
            leading: Icon(Icons.message, color: Color(0xFFF0B429)),
            title: Text('New message'),
            subtitle: Text('Alice sent you a message about your listing.'),
            trailing: Text('1d ago'),
          ),
          ListTile(
            leading: Icon(Icons.book, color: Color(0xFFF0B429)),
            title: Text('Listing viewed'),
            subtitle: Text('Someone viewed your "Calculus Textbook" listing.'),
            trailing: Text('3d ago'),
          ),
        ],
      ),
    );
  }
}
