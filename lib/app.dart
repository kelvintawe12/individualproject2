import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'presentation/bloc/app_cubit.dart';
import 'presentation/bloc/listing_cubit.dart';
import 'screens/browse_screen.dart' hide StreamBuilder;
import 'screens/my_listings_screen.dart';
import 'screens/chats_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/post_screen.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/library_screen.dart';
import 'screens/notifications_screen.dart';

class BookSwapApp extends StatelessWidget {
  const BookSwapApp({super.key});

  static final List<Widget> _screens = <Widget>[
    const ListingsScreen(),
    const MyListingsScreen(),
    const ChatsScreen(),
    const NotificationsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Provide AppCubit above the MaterialApp so routes and the whole app
    // can read and modify the selected index without calling setState.
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AppCubit()),
        BlocProvider(create: (_) => ListingCubit()),
      ],
      child: MaterialApp(
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
        '/browse': (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<AppCubit>().goToBrowse();
            Navigator.of(context).pop();
          });
          return const SizedBox.shrink();
        },
        // When a top-level route requests a tab (e.g. '/chats' or '/library')
        // we temporarily push a blank route which, on the next frame, tells
        // the app shell to switch tabs and then immediately pops the blank
        // route. This preserves the global BottomNavigationBar which lives
        // in the app shell (IndexedStack).
        '/library': (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<AppCubit>().goToLibrary();
            Navigator.of(context).pop();
          });
          return const SizedBox.shrink();
        },
        '/notifications': (context) => const NotificationsScreen(),
        '/chats': (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<AppCubit>().goToChats();
            Navigator.of(context).pop();
          });
          return const SizedBox.shrink();
        },
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
            // Use extendBody:true so floating action buttons can float over
            // the navigation bar properly when child screens use a center docked FAB.
            extendBody: true,
            // Use IndexedStack to preserve each tab's state (scroll position,
            // animation controllers, etc.) when switching tabs.
            body: SafeArea(
              // Listen to AppCubit for the current selected index and update
              // the IndexedStack index accordingly.
              child: BlocBuilder<AppCubit, int>(
                builder: (context, selectedIndex) {
                  return IndexedStack(
                    index: selectedIndex,
                    children: _screens,
                  );
                },
              ),
            ),
            // Wrap the BottomNavigationBar in a single SafeArea (top:false)
            // and let the bar size itself. Avoid forcing a fixed height which
            // can cause off-by-a-few-pixels overflow on some platforms.
            bottomNavigationBar: SafeArea(
              top: false,
              child: Container(
                color: const Color(0xFF0F1724),
                child: BlocBuilder<AppCubit, int>(
                  builder: (context, selectedIndex) {
                    return BottomNavigationBar(
                      type: BottomNavigationBarType.fixed,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      currentIndex: selectedIndex,
                      onTap: (i) => context.read<AppCubit>().setIndex(i),
                      selectedItemColor: const Color(0xFFF0B429),
                      unselectedItemColor: Colors.white38,
                      items: const [
                        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Browse'),
                        BottomNavigationBarItem(icon: Icon(Icons.library_books), label: 'My Listings'),
                        BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chats'),
                        BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Notifications'),
                        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
}
