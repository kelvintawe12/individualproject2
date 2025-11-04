import 'package:flutter/material.dart';
import '../widgets/listing_card.dart';
import 'post_screen.dart';
import '../services/firebase_service.dart';

class BrowseScreen extends StatelessWidget {
  const BrowseScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse Listings'),
        backgroundColor: const Color(0xFF0F1724),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirebaseService.listenListings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? [];
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) => ListingCard(listing: items[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Custom page transition (slide up)
          Navigator.of(context).push(PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const PostScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final tween = Tween(begin: const Offset(0, 1), end: Offset.zero).chain(CurveTween(curve: Curves.easeOut));
              return SlideTransition(position: animation.drive(tween), child: child);
            },
          ));
        },
        label: const Text('Post'),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFFF0B429),
      ),
    );
  }
}
