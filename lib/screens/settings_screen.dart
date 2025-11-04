import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool notifications = true;
  bool emailUpdates = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), backgroundColor: const Color(0xFF0F1724)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (FirebaseAuth.instance.currentUser != null)
            ListTile(
              leading: const Icon(Icons.person),
              title: Text(FirebaseAuth.instance.currentUser!.email ?? 'Account'),
              subtitle: const Text('View profile'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
            ),
          const Divider(),
          SwitchListTile(title: const Text('Notification reminders'), value: notifications, onChanged: (v) => setState(() => notifications = v)),
          SwitchListTile(title: const Text('Email Updates'), value: emailUpdates, onChanged: (v) => setState(() => emailUpdates = v)),
          ListTile(title: const Text('About'), onTap: () {}),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
    );
  }
}
