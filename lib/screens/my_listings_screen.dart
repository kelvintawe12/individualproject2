import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui' as ui;
import '../services/firebase_service.dart';
import '../services/library_service.dart';
import 'post_screen.dart';
import 'edit_listing_screen.dart';
import 'browse_screen.dart';

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});
  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> with TickerProviderStateMixin {
  late final AnimationController _staggerController;
  final User? _user = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>>? _manualItems;
  bool _loadingManual = false;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
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

  Future<void> _deleteListing(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDialog(),
    );
    if (confirm != true) return;

    try {
      await FirebaseService.deleteListing(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Listing deleted'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
          'My Listings',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined, color: Colors.white),
            tooltip: 'Browse',
            onPressed: () {
              // Navigate back to the main listings/browse screen
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ListingsScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_outline, color: Colors.white),
            tooltip: 'Library',
            onPressed: () => Navigator.of(context).pushNamed('/library'),
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
            tooltip: 'Chats',
            onPressed: () => Navigator.of(context).pushNamed('/chats'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: const Color(0xFFF0B429),
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: FirebaseService.listenUserListings(_user!.uid),
          builder: (context, snapshot) {
            // Loading
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildShimmer();
            }

            // Error
              if (snapshot.hasError) {
                // Show a more actionable error UI (diagnostics + one-shot fetch fallback)
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 64),
                        const SizedBox(height: 16),
                        Text('Failed to load listings: ${snapshot.error}', style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF0B429)),
                              onPressed: () async {
                                // show diagnostics
                                final diag = await FirebaseService.getDiagnostics(queryDesc: 'listenUserListings for ${_user?.uid}');
                                if (!mounted) return;
                                await showDialog<void>(context: context, builder: (_) => AlertDialog(title: const Text('Diagnostics'), content: SingleChildScrollView(child: Text(diag)), actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))]));
                              },
                              child: const Text('Show diagnostics'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700]),
                              onPressed: _loadingManual
                                  ? null
                                  : () async {
                                      // Try a one-time fetch (may surface a clearer error)
                                      setState(() {
                                        _loadingManual = true;
                                        _manualItems = null;
                                      });
                                      try {
                                        final items = await FirebaseService.getListingsForUser(_user!.uid);
                                        if (!mounted) return;
                                        setState(() {
                                          _manualItems = items;
                                        });
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fetch failed: $e')));
                                      } finally {
                                        if (mounted) setState(() => _loadingManual = false);
                                      }
                                    },
                              child: _loadingManual ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Try fetch once'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        // If manual fetch produced items, show a small preview list
                        if (_manualItems != null)
                          SizedBox(
                            height: 300,
                            child: ListView.builder(
                              itemCount: _manualItems!.length,
                              itemBuilder: (ctx, i) {
                                final it = _manualItems![i];
                                return ListTile(
                                  leading: it['imageUrl'] != null ? SizedBox(width: 48, height: 48, child: Image.network(it['imageUrl'], fit: BoxFit.cover)) : const CircleAvatar(child: Icon(Icons.book)),
                                  title: Text(it['title'] ?? 'Untitled', style: const TextStyle(color: Colors.white)),
                                  subtitle: Text(it['author'] ?? '', style: const TextStyle(color: Colors.white70)),
                                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditListingScreen(listing: it))),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }

            final items = snapshot.data ?? [];

            // Empty
            if (items.isEmpty) {
              return _EmptyState(onAdd: () => Navigator.of(context).push(_slideRoute()));
            }

            // Animate in
            _staggerController.forward(from: 0);

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                return _AnimatedListingCard(
                  listing: item,
                  index: i,
                  controller: _staggerController,
                  onDelete: () => _deleteListing(item['id'] as String),
                  onEdit: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditListingScreen(listing: item)));
                  },
                  onAddToLibrary: () {
                    // TODO: Implement add to library functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Add to Library not implemented yet')),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(_slideRoute()),
        backgroundColor: const Color(0xFFF0B429),
        child: const Icon(Icons.add, color: Colors.black87),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Route _slideRoute() {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => const PostScreen(),
      transitionsBuilder: (_, animation, __, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeOut;
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              _ShimmerBox(width: 80, height: 110),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerBox(width: 180, height: 20),
                    SizedBox(height: 8),
                    _ShimmerBox(width: 120, height: 16),
                    SizedBox(height: 16),
                    Row(children: [_ShimmerBox(width: 60, height: 24), SizedBox(width: 8), _ShimmerBox(width: 80, height: 16)]),
                  ],
                ),
              ),
            ],
          ),
        ),
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
      child: Dismissible(
        key: Key(listing['id'] as String),
        direction: DismissDirection.endToStart,
        background: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: const Icon(Icons.delete, color: Colors.white, size: 28),
        ),
        onDismissed: (_) => onDelete(),
        child: _GlassListingCard(listing: listing, onEdit: onEdit, onAddToLibrary: onAddToLibrary),
      ),
    );
  }
}

// ── Glassmorphism Listing Card ─────────────────────────────────────
class _GlassListingCard extends StatefulWidget {
  final Map<String, dynamic> listing;
  final VoidCallback onEdit;
  final VoidCallback onAddToLibrary;

  const _GlassListingCard({required this.listing, required this.onEdit, required this.onAddToLibrary});

  @override
  State<_GlassListingCard> createState() => _GlassListingCardState();
}

class _GlassListingCardState extends State<_GlassListingCard> {
  bool _inLibrary = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final id = widget.listing['id'] as String?;
      if (uid == null || id == null) return;
      final exists = await LibraryService.isInLibrary(uid, id);
      if (mounted) setState(() => _inLibrary = exists);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
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
                  onPressed: widget.onEdit,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
                // Add to Library
                IconButton(
                  icon: _loading
                      ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70))
                      : Icon(_inLibrary ? Icons.bookmark : Icons.library_add, color: _inLibrary ? const Color(0xFFF0B429) : Colors.white70),
                  onPressed: () async {
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    final id = widget.listing['id'] as String?;
                    if (uid == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to save to your library')));
                      return;
                    }
                    if (id == null) return;
                    setState(() => _loading = true);
                    try {
                      if (!_inLibrary) {
                        await LibraryService.addToLibrary(uid, id);
                        if (mounted) setState(() => _inLibrary = true);
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added "${title}" to your library'), backgroundColor: const Color(0xFFF0B429)));
                      } else {
                        await LibraryService.removeFromLibrary(uid, id);
                        if (mounted) setState(() => _inLibrary = false);
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed from your library')));
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                    } finally {
                      if (mounted) setState(() => _loading = false);
                    }
                  },
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
}

String _formatTimeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inDays > 0) return '${diff.inDays}d ago';
  if (diff.inHours > 0) return '${diff.inHours}h ago';
  if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
  return 'Just now';
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

// ── Empty State ─────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/booksShelf.png', width: 180, height: 180),
          const SizedBox(height: 16),
          const Text('No listings yet', style: TextStyle(color: Colors.white70, fontSize: 18)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, color: Colors.black87),
            label: const Text('Post a Book'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF0B429),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Delete Dialog ─────────────────────────────────────
class _DeleteDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Delete Listing?'),
      content: const Text('This action cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

// Bottom navigation is handled by the app shell (app.dart). This file
// intentionally does not declare its own BottomNavigationBar to avoid
// showing two navigation bars when embedded in the main scaffold.
