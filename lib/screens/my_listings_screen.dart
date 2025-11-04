import 'package:flutter/material.dart';
import '../widgets/listing_card.dart';
import '../services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';


class MyListingsScreen extends StatelessWidget {
  const MyListingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Listings'), backgroundColor: const Color(0xFF0F1724)),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirebaseService.listenListings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final items = snapshot.data ?? [];
          // filter owner-owned listings for demo (ownerId would be compared to current user in a real app)
          final ownerItems = items.where((m) => m['ownerId'] == FirebaseAuth.instance.currentUser?.uid).toList();
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: ownerItems.length,
            itemBuilder: (context, i) => ListingCard(listing: ownerItems[i]),
          );
        },
      ),
    );
  }
}
