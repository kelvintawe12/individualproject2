import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import 'dart:ui' as ui;
import '../services/firebase_service.dart';
import 'listing_detail_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

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

                  if (_loading)
                    const Center(child: CircularProgressIndicator(color: Color(0xFFF0B429)))
                  else if (_userListings.isEmpty)
                    _EmptyState(message: 'No listings yet', lottie: 'assets/booksShelf.png')
                  else
                    SizedBox(
                      height: 160,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _userListings.length,
                        itemBuilder: (context, i) {
                          return _AnimatedListingThumb(
                            listing: _userListings[i],
                            index: i,
                            controller: _staggerController,
                          );
                        },
                      ),
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

// ── Animated Listing Thumb ─────────────────────────────────────
class _AnimatedListingThumb extends StatelessWidget {
  final Map<String, dynamic> listing;
  final int index;
  final AnimationController controller;

  const _AnimatedListingThumb({required this.listing, required this.index, required this.controller});

  @override
  Widget build(BuildContext context) {
    final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(0.1 * (index % 4), 0.7 + 0.1 * (index % 4), curve: Curves.easeOut),
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
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ListingDetailScreen(listing: listing),
            ));
          },
          borderRadius: BorderRadius.circular(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                (listing['imageUrl'] != null)
                    ? Image.network(listing['imageUrl'], fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                    : Image.asset('assets/bookOpen.png', fit: BoxFit.cover),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                      ),
                    ),
                    child: Text(
                      listing['title'] ?? 'Untitled',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
          ? Image.network(url, width: 50, height: 50, fit: BoxFit.cover)
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
        children: [
          Image.asset(lottie, width: 120, height: 120),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.white70)),
        ],
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
    return BottomNavigationBar(
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
    );
  }
}