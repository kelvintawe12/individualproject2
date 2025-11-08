import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/browse_screen.dart' hide StreamBuilder;
import 'screens/my_listings_screen.dart';
import 'screens/chats_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/post_screen.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/library_screen.dart';

class BookSwapApp extends StatefulWidget {
  const BookSwapApp({Key? key}) : super(key: key);

  @override
  State<BookSwapApp> createState() => _BookSwapAppState();
}

class _BookSwapAppState extends State<BookSwapApp> {
  int _selectedIndex = 0;

  static final List<Widget> _screens = <Widget>[
    const ListingsScreen(),
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
        '/library': (context) => const LibraryScreen(),
        '/chats': (context) => const ChatsScreen(),
      },
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SignInScreen();
          }
          return Scaffold(
            // Draw a solid dark background behind the navigation bar so it
            // always appears as a dark footer (including the bottom safe area).
            extendBody: false,
            body: SafeArea(child: _screens[_selectedIndex]),
            // Wrap the BottomNavigationBar in a single SafeArea (top:false)
            // and let the bar size itself. Avoid forcing a fixed height which
            // can cause off-by-a-few-pixels overflow on some platforms.
            bottomNavigationBar: SafeArea(
              top: false,
              child: Container(
                color: const Color(0xFF0F1724),
                child: BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  currentIndex: _selectedIndex,
                  onTap: _onItemTapped,
                  selectedItemColor: const Color(0xFFF0B429),
                  unselectedItemColor: Colors.white38,
                  items: const [
                    BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Browse'),
                    BottomNavigationBarItem(icon: Icon(Icons.book), label: 'My Listings'),
                    BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chats'),
                    BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
