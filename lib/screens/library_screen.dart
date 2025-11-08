import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/library_service.dart';
import 'listing_detail_screen.dart';
import 'browse_screen.dart';
import 'my_listings_screen.dart'; // Assuming you have this
import 'chats_screen.dart';     // Assuming you have this

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({Key? key}) : super(key: key);

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with TickerProviderStateMixin {
  late final AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFF0B121E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'My Library',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tip: Books here are saved from the main feed. Tap to view details.'),
                  duration: Duration(seconds: 4),
                ),
              );
            },
          ),
        ],
      ),
      body: uid == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 64, color: Colors.white38),
                  const SizedBox(height: 16),
                  const Text(
                    'Sign in to view your library',
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Navigate to sign-in
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('Sign In'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF0B429),
                      foregroundColor: Colors.black87,
                    ),
                  ),
                ],
              ),
            )
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: LibraryService.listenUserLibraryListings(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFF0B429),
                      strokeWidth: 2.5,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load library',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white60),
                          ),
                          const SizedBox(height: 16),
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

                final listings = snapshot.data ?? [];
                if (listings.isEmpty) {
                  return Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/booksShelf.png', width: 220),
                          const SizedBox(height: 24),
                          const Text(
                            'Your library is empty',
                            style: TextStyle(color: Colors.white70, fontSize: 20, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Save books from the home feed to see them here',
                            style: TextStyle(color: Colors.white60, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const ListingsScreen()),
                            ),
                            icon: const Icon(Icons.explore),
                            label: const Text('Browse Books'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFF0B429),
                              side: const BorderSide(color: Color(0xFFF0B429)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  itemCount: listings.length,
                  itemBuilder: (context, i) {
                    final listing = Map<String, dynamic>.from(listings[i]);
                    return _AnimatedListingCard(
                      listing: listing,
                      index: i,
                      controller: _staggerController,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ListingDetailScreen(listing: listing),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
      bottomNavigationBar: const _BottomNavBar(currentIndex: 3),
    );
  }
}

// ── Animated Card with Tap & Stagger ─────────────────────────────
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
          0.05 * (index % 8),
          0.5 + 0.05 * (index % 8),
          curve: Curves.easeOutCubic,
        ),
      ),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 80 * (1 - animation.value)),
          child: Opacity(
            opacity: animation.value,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: onTap,
        child: ScaleTap(
          scaleMinValue: 0.98,
          child: _GlassLibraryCard(listing: listing),
        ),
      ),
    );
  }
}

// Simple scale-on-tap widget (no extra package)
class ScaleTap extends StatefulWidget {
  final Widget child;
  final double scaleMinValue;
  const ScaleTap({required this.child, this.scaleMinValue = 0.95});

  @override State<ScaleTap> createState() => _ScaleTapState();
}

class _ScaleTapState extends State<ScaleTap> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: widget.scaleMinValue).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

// ── Glass Card with Remove-Only Logic ────────────────────────────
class _GlassLibraryCard extends StatefulWidget {
  final Map<String, dynamic> listing;
  const _GlassLibraryCard({required this.listing});

  @override
  State<_GlassLibraryCard> createState() => _GlassLibraryCardState();
}

class _GlassLibraryCardState extends State<_GlassLibraryCard>
    with AutomaticKeepAliveClientMixin {
  bool _inLibrary = true;
  bool _loading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _inLibrary = true; // Always true in library
  }

  Future<void> _removeFromLibrary() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final id = widget.listing['id'] as String?;
    final title = widget.listing['title'] ?? 'Book';

    if (uid == null || id == null) return;

    HapticFeedback.mediumImpact();
    setState(() => _loading = true);

    try {
      await LibraryService.removeFromLibrary(uid, id);
      if (mounted) {
        setState(() => _inLibrary = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed "$title" from library'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade600,
          ),
        );
        // Optional: Remove card with animation
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() {});
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final listing = widget.listing;
    final title = listing['title'] ?? 'Unknown';
    final author = listing['author'] ?? 'Unknown';
    final condition = listing['condition'] ?? 'Used';
    final timestamp = (listing['timestamp'] as Timestamp?)?.toDate();
    final imageUrl = listing['imageUrl'] as String?;

    final timeAgo = timestamp != null ? _formatTimeAgo(timestamp) : 'Saved';

    return Opacity(
      opacity: _inLibrary ? 1.0 : 0.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: _inLibrary ? null : 0,
        margin: const EdgeInsets.symmetric(vertical: 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.09),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Hero(
                    tag: 'book_${listing['id']}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: imageUrl != null
                          ? Image.network(
                              imageUrl,
                              width: 90,
                              height: 130,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _placeholderCover(title),
                            )
                          : _placeholderCover(title),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          author,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14.5,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _ConditionBadge(condition: condition),
                            const SizedBox(width: 10),
                            Text(
                              timeAgo,
                              style: const TextStyle(color: Colors.white60, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _loading
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation(Color(0xFFF0B429)),
                          ),
                        )
                      : IconButton(
                          icon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Icon(
                              Icons.bookmark,
                              key: const ValueKey(true),
                              color: const Color(0xFFF0B429),
                              size: 28,
                            ),
                          ),
                          onPressed: _removeFromLibrary,
                          tooltip: 'Remove from library',
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholderCover(String title) {
    return Container(
      width: 90,
      height: 130,
      color: Colors.grey[800],
      child: Center(
        child: Text(
          title.isNotEmpty ? title[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays >= 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'now';
  }
}

// ── Condition Badge ─────────────────────────────────────────────
class _ConditionBadge extends StatelessWidget {
  final String condition;
  const _ConditionBadge({required this.condition});

  @override
  Widget build(BuildContext context) {
    final isNew = condition.toLowerCase().contains('new');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isNew ? Colors.green.withOpacity(0.25) : Colors.amber.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isNew ? Colors.green.shade400 : Colors.amber.shade600,
          width: 1.2,
        ),
      ),
      child: Text(
        condition,
        style: TextStyle(
          color: isNew ? Colors.green.shade300 : Colors.amber.shade300,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Bottom Navigation Bar (4 tabs) ──────────────────────────────
class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  const _BottomNavBar({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F1724),
        border: Border(top: BorderSide(color: Colors.white12, width: 1.2)),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        backgroundColor: Colors.transparent,
        unselectedItemColor: Colors.white60,
        selectedItemColor: const Color(0xFFF0B429),
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 13,
        unselectedFontSize: 12,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt_rounded), label: 'My Listings'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_rounded), label: 'Chats'),
          BottomNavigationBarItem(icon: Icon(Icons.library_books_rounded), label: 'Library'),
        ],
        onTap: (index) {
          if (index == currentIndex) return;
          switch (index) {
            case 0:
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const ListingsScreen()),
              );
              return;
            case 1:
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const MyListingsScreen()),
              );
              return;
            case 2:
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const ChatsScreen()),
              );
              return;
            case 3:
              return; // Already here
            default:
              return;
          }
        },
      ),
    ),
  );
  }
}