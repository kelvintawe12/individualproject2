import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/browse_screen.dart';
import 'screens/my_listings_screen.dart';
import 'screens/chats_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/post_screen.dart';
import 'screens/auth/sign_in_screen.dart';

class BookSwapApp extends StatefulWidget {
  const BookSwapApp({Key? key}) : super(key: key);

  @override
  State<BookSwapApp> createState() => _BookSwapAppState();
}

class _BookSwapAppState extends State<BookSwapApp> {
  int _selectedIndex = 0;

  static final List<Widget> _screens = <Widget>[
    const BrowseScreen(),
    const MyListingsScreen(),
    const ChatsScreen(),
    const SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BookSwap',
      theme: ThemeData(
        primaryColor: const Color(0xFF0F1724),
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F1724),
          foregroundColor: Colors.white,
          elevation: 2,
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF0F1724)),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF0F1724),
          selectedItemColor: Color(0xFFF0B429),
          unselectedItemColor: Colors.white38,
          showUnselectedLabels: true,
        ),
      ),
      routes: {
        '/post': (context) => const PostScreen(),
      },
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SignInScreen();
          }
          return Scaffold(
            body: SafeArea(child: _screens[_selectedIndex]),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Browse'),
                BottomNavigationBarItem(icon: Icon(Icons.book), label: 'My Listings'),
                BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chats'),
                BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
              ],
            ),
          );
        },
      ),
    );
  }
}
