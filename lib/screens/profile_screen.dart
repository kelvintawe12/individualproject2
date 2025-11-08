import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui' as ui;
import '../services/firebase_service.dart';
import '../services/library_service.dart';
import 'listing_detail_screen.dart';
import 'edit_listing_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  int _listingCount = 0;
  Map<String, int> _swapSummary = {};
  List<Map<String, dynamic>> _history = [];
  Map<String, Map<String, dynamic>> _listings = {};
  List<Map<String, dynamic>> _userListings = [];
  bool _loading = true;

  late final AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _load();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      final listings = await FirebaseService.getUserListingCount(user.uid);
      final summary = await FirebaseService.getUserSwapSummary(user.uid);
      final history = await FirebaseService.getUserSwapHistory(user.uid);
      final ids = history.map((e) => e['listingId'] as String?).whereType<String>().toSet().toList();
      final listingsMap = await FirebaseService.getListingsByIds(ids);
      final myListings = await FirebaseService.getListingsForUser(user.uid);

      if (!mounted) return;
      setState(() {
        _listingCount = listings;
        _swapSummary = summary;
        _history = history;
        _listings = listingsMap;
        _userListings = myListings;
      });
      _staggerController.forward(from: 0);
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildShimmer() {
    return Column(
      children: List.generate(3, (i) => Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
  final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1724),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1724),
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: user == null
          ? const Center(child: Text('Not signed in', style: TextStyle(color: Colors.white70)))
          : RefreshIndicator(
              onRefresh: _load,
              color: const Color(0xFFF0B429),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── User Header ─────────────────────────────────────
                  _GlassCard(
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 30,
                        backgroundColor: const Color(0xFFF0B429),
                        child: Text(
                          (user.displayName ?? user.email ?? '?').substring(0, 1).toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ),
                      title: Text(
                        user.displayName ?? 'User',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        user.email ?? '',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Stats Row ─────────────────────────────────────
                  _GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatItem(label: 'Listings', value: _listingCount),
                          _StatItem(label: 'Requested', value: _swapSummary['requested'] ?? 0),
                          _StatItem(label: 'Received', value: _swapSummary['received'] ?? 0),
                          _StatItem(label: 'Accepted', value: _swapSummary['accepted'] ?? 0),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── My Listings ─────────────────────────────────────
                  const Text('My Listings', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),

                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: FirebaseService.listenUserListings(user.uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _buildShimmer();
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Failed to load listings: ${snapshot.error}', style: const TextStyle(color: Colors.white70)),
                        );
                      }
                      final items = snapshot.data ?? [];
                      if (items.isEmpty) {
                        return _EmptyState(message: 'No listings yet', lottie: 'assets/booksShelf.png');
                      }
                      _staggerController.forward(from: 0);
                      return SizedBox(
                        height: 400,
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          itemCount: items.length,
                          itemBuilder: (context, i) {
                            final item = items[i];
                            return _AnimatedListingCard(
                              listing: item,
                              index: i,
                              controller: _staggerController,
                              onDelete: () {}, // no delete in profile
                              onEdit: () {
                                Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditListingScreen(listing: item)));
                              },
                              onAddToLibrary: () async {
                                final user = FirebaseAuth.instance.currentUser;
                                if (user == null) return;
                                try {
                                  await LibraryService.addToLibrary(user.uid, item['id'] as String);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Added to Library')),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to add to library: $e')),
                                  );
                                }
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // ── Recent Activity ─────────────────────────────────
                  const Text('Recent Activity', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),

                  if (_loading)
                    const Center(child: CircularProgressIndicator(color: Color(0xFFF0B429)))
                  else if (_history.isEmpty)
                    _EmptyState(message: 'No recent activity', lottie: 'assets/c.png')
                  else
                    ..._history.map((h) => _ActivityItem(
                          history: h,
                          listing: _listings[h['listingId'] as String?],
                          onTap: () {
                            final lid = h['listingId'] as String?;
                            if (lid != null && _listings.containsKey(lid)) {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => ListingDetailScreen(listing: _listings[lid]!)),
                              );
                            }
                          },
                        )),

                  const SizedBox(height: 24),

                  // ── Resend Verification ─────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await FirebaseService.sendEmailVerification();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Verification email sent')),
                        );
                      },
                      icon: const Icon(Icons.email_outlined),
                      label: const Text('Resend Verification Email'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF0B429),
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
      bottomNavigationBar: _BottomNavBar(currentIndex: 2),
    );
  }
}

// ── Glass Card Wrapper ─────────────────────────────────────
class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ── Stat Item ─────────────────────────────────────
class _StatItem extends StatelessWidget {
  final String label;
  final int value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      ],
    );
  }
}



// ── Activity Item ─────────────────────────────────────
class _ActivityItem extends StatelessWidget {
  final Map<String, dynamic> history;
  final Map<String, dynamic>? listing;
  final VoidCallback onTap;

  const _ActivityItem({required this.history, required this.listing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = history['status'] as String?;
    final timestamp = (history['createdAt'] as Timestamp?)?.toDate();
    final timeAgo = timestamp != null ? _formatTimeAgo(timestamp) : 'Just now';

    return _GlassCard(
      child: ListTile(
        onTap: onTap,
        leading: _buildThumbnail(listing?['imageUrl']),
        title: Text(
          listing?['title'] ?? 'Unknown Listing',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          maxLines: 1,
        ),
        subtitle: Text(
          '${_humanStatus(status)} • $timeAgo',
          style: const TextStyle(color: Colors.white70),
        ),
        trailing: _StatusChip(status: status),
      ),
    );
  }

  Widget _buildThumbnail(String? url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: url != null && url.isNotEmpty
          ? Image.network(
              url,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) => Image.asset('assets/bookOpen.png', width: 50, height: 50, fit: BoxFit.cover),
            )
          : Image.asset('assets/bookOpen.png', width: 50, height: 50, fit: BoxFit.cover),
    );
  }

  String _humanStatus(String? s) {
    switch (s) {
      case 'pending': return 'Pending';
      case 'accepted': return 'Accepted';
      case 'rejected': return 'Rejected';
      default: return s ?? 'Unknown';
    }
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}

// ── Status Chip ─────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final String? status;
  const _StatusChip({this.status});

  @override
  Widget build(BuildContext context) {
    final label = _ActivityItem(history: {}, listing: null, onTap: () {}). _humanStatus(status);
    Color color;
    switch (status) {
      case 'accepted': color = Colors.green; break;
      case 'pending': color = Colors.orange; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }
}

// ── Empty State ─────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String message;
  final String lottie;
  const _EmptyState({required this.message, required this.lottie});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            lottie,
            width: 120,
            height: 120,
            errorBuilder: (ctx, err, stack) => const SizedBox(width: 120, height: 120),
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

// ── Shimmer Placeholder ─────────────────────────────────────
class _ShimmerBox extends StatelessWidget {
  final double width, height;
  const _ShimmerBox({required this.width, required this.height});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

// ── Animated Card with Swipe ─────────────────────────────────────
class _AnimatedListingCard extends StatelessWidget {
  final Map<String, dynamic> listing;
  final int index;
  final AnimationController controller;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onAddToLibrary;

  const _AnimatedListingCard({
    required this.listing,
    required this.index,
    required this.controller,
    required this.onDelete,
    required this.onEdit,
    required this.onAddToLibrary,
  });

  @override
  Widget build(BuildContext context) {
    final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(0.1 * (index % 5), 0.6 + 0.1 * (index % 5), curve: Curves.easeOut),
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
      child: _GlassListingCard(listing: listing, onEdit: onEdit, onAddToLibrary: onAddToLibrary),
    );
  }
}

// ── Glassmorphism Listing Card ─────────────────────────────────────
class _GlassListingCard extends StatelessWidget {
  final Map<String, dynamic> listing;
  final VoidCallback onEdit;
  final VoidCallback onAddToLibrary;

  const _GlassListingCard({required this.listing, required this.onEdit, required this.onAddToLibrary});

  @override
  Widget build(BuildContext context) {
    final title = listing['title'] ?? 'Untitled';
    final author = listing['author'] ?? 'Unknown';
    final condition = listing['condition'] ?? 'Used';
    final imageUrl = listing['imageUrl'] as String?;
    final rawTs = listing['timestamp'];
    DateTime timestamp;
    if (rawTs is Timestamp) {
      timestamp = rawTs.toDate();
    } else if (rawTs is DateTime) {
      timestamp = rawTs;
    } else {
      timestamp = DateTime.now();
    }
    final timeAgo = _formatTimeAgo(timestamp);

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
                // Cover
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: imageUrl != null
                      ? Image.network(imageUrl, width: 80, height: 110, fit: BoxFit.cover)
                      : _placeholderCover(),
                ),
                const SizedBox(width: 16),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(author, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _ConditionBadge(condition: condition),
                          const SizedBox(width: 8),
                          Text(timeAgo, style: const TextStyle(color: Colors.white60, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),

                // Edit (use compact padding and constraints to avoid tiny overflows)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                  onPressed: onEdit,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
                // Add to Library
                IconButton(
                  icon: const Icon(Icons.library_add, color: Colors.white70),
                  onPressed: onAddToLibrary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholderCover() {
    return Container(
      width: 80,
      height: 110,
      color: Colors.grey[800],
      child: const Icon(Icons.book, color: Colors.white70, size: 36),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}

// ── Condition Badge ─────────────────────────────────────
class _ConditionBadge extends StatelessWidget {
  final String condition;
  const _ConditionBadge({required this.condition});

  @override
  Widget build(BuildContext context) {
    final isNew = condition.toLowerCase().contains('new');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isNew ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isNew ? Colors.green : Colors.orange, width: 1),
      ),
      child: Text(
        condition,
        style: TextStyle(color: isNew ? Colors.green : Colors.orange, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ── Bottom Nav Bar ─────────────────────────────────────
class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  const _BottomNavBar({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: BottomNavigationBar(
      currentIndex: currentIndex,
      backgroundColor: const Color(0xFF0F1724),
      unselectedItemColor: Colors.white60,
      selectedItemColor: const Color(0xFFF0B429),
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'My Listings'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
      onTap: (i) {
        if (i == 0) Navigator.of(context).popUntil((r) => r.isFirst);
      },
      ),
    );
  }
}
