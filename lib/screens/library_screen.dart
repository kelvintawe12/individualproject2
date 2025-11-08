import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../services/library_service.dart';
import 'listing_detail_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({Key? key}) : super(key: key);

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with TickerProviderStateMixin {
  late final AnimationController _staggerController;
  final User? _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _staggerController.forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 800));
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F1724),
        body: Center(
          child: Text('Please sign in', style: TextStyle(color: Colors.white70, fontSize: 18)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1724),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1724),
        elevation: 0,
        title: const Text(
          'Library',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: const Color(0xFFF0B429),
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: FirebaseService.listenListings(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFF0B429)),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 56),
                      const SizedBox(height: 12),
                      Text('Could not load library: ${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => setState(() {}),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF0B429)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final allItems = snapshot.data ?? [];
            final libraryItems = allItems.where((item) => item['type'] == 'library' || item['ownerId'] == 'library').toList();

            if (libraryItems.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/booksShelf.png', width: 200),
                    const SizedBox(height: 16),
                    const Text(
                      'No library books yet',
                      style: TextStyle(color: Colors.white70, fontSize: 18),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: libraryItems.length,
              itemBuilder: (context, i) {
                final item = libraryItems[i];
                return _AnimatedListingCard(
                  listing: item,
                  index: i,
                  controller: _staggerController,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ListingDetailScreen(listing: item)),
                  ),
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: _BottomNavBar(currentIndex: 3), // Assuming Library is the 4th tab
    );
  }
}

// ── Animated Card with Stagger ─────────────────────────────────────
class _AnimatedListingCard extends StatelessWidget {
  final Map<String, dynamic> listing;
  final int index;
  final AnimationController controller;
  final VoidCallback onTap;

  const _AnimatedListingCard({
    required this.listing,
    required this.index,
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(
          0.1 * (index % 5),
          0.6 + 0.1 * (index % 5),
          curve: Curves.easeOut,
        ),
      ),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - animation.value)),
          child: Opacity(opacity: animation.value, child: child),
        );
      },
      child: GestureDetector(
        onTap: onTap,
        child: _GlassListingCard(listing: listing),
      ),
    );
  }
}

// ── Glassmorphism Listing Card ─────────────────────────────────────
class _GlassListingCard extends StatelessWidget {
  final Map<String, dynamic> listing;

  const _GlassListingCard({required this.listing});

  @override
  Widget build(BuildContext context) {
    final title = listing['title'] ?? 'Unknown';
    final author = listing['author'] ?? 'Unknown';
    final condition = listing['condition'] ?? 'Used';
    final timestamp = (listing['timestamp'] as Timestamp?)?.toDate();
    final imageUrl = listing['imageUrl'] as String?;

    final timeAgo = timestamp != null
        ? _formatTimeAgo(timestamp)
        : 'Just now';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                // Book Cover
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl,
                          width: 80,
                          height: 110,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholderCover(title),
                        )
                      : _placeholderCover(title),
                ),
                const SizedBox(width: 16),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        author,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _ConditionBadge(condition: condition),
                          const SizedBox(width: 8),
                          Text(
                            timeAgo,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Library Icon
                const Icon(Icons.library_books, color: Color(0xFFF0B429)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholderCover(String title) {
    return Container(
      width: 80,
      height: 110,
      color: Colors.grey[800],
      child: Center(
        child: Text(
          title.isNotEmpty ? title[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 0) return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    if (diff.inHours > 0) return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes} min ago';
    return 'Just now';
  }
}

// ── Condition Badge ─────────────────────────────────────
class _ConditionBadge extends StatelessWidget {
  final String condition;
  const _ConditionBadge({required this.condition});

  @override
  Widget build(BuildContext context) {
    final isLikeNew = condition.toLowerCase().contains('new');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isLikeNew ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLikeNew ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Text(
        condition,
        style: TextStyle(
          color: isLikeNew ? Colors.green : Colors.orange,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ── Bottom Navigation Bar ─────────────────────────────────────
class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  const _BottomNavBar({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F1724),
        border: Border(top: BorderSide(color: Colors.white12, width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        backgroundColor: Colors.transparent,
        unselectedItemColor: Colors.white60,
        selectedItemColor: const Color(0xFFF0B429),
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'My Listings'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chats'),
          BottomNavigationBarItem(icon: Icon(Icons.library_books), label: 'Library'),
        ],
        onTap: (index) {
          // TODO: Handle navigation
        },
      ),
    );
  }
}
