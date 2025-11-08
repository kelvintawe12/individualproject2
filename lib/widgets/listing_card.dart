import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/library_service.dart';
import '../services/firebase_service.dart';
import 'dart:ui' as ui; // Required for ImageFilter
import '../screens/listing_detail_screen.dart';

class ListingCard extends StatefulWidget {
  const ListingCard({Key? key, required this.listing}) : super(key: key);
  final Map<String, dynamic> listing;

  @override
  State<ListingCard> createState() => _ListingCardState();
}

class _ListingCardState extends State<ListingCard> with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.98,
      upperBound: 1.0,
    );
    _scaleAnimation = CurvedAnimation(parent: _scaleController, curve: Curves.easeOut);
    _scaleController.value = 1.0;
    // initialize library state
    _initLibraryState();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  bool _inLibrary = false;
  bool _libLoading = false;

  Future<void> _initLibraryState() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final id = widget.listing['id']?.toString();
      if (uid == null || id == null) return;
      final exists = await LibraryService.isInLibrary(uid, id);
      if (mounted) setState(() => _inLibrary = exists);
    } catch (_) {
      // ignore errors for initial state
    }
  }

  void _onTapDown(TapDownDetails _) => _scaleController.reverse();
  void _onTapUp(TapUpDetails _) => _scaleController.forward();
  void _onTapCancel() => _scaleController.forward();

  @override
  Widget build(BuildContext context) {
    final id = widget.listing['id']?.toString() ?? UniqueKey().toString();
    final title = widget.listing['title']?.toString() ?? 'Untitled';
    final author = widget.listing['author']?.toString() ?? 'Unknown';
    final imageUrl = widget.listing['imageUrl']?.toString();
    final condition = widget.listing['condition']?.toString() ?? 'Used';
    final rawTimestamp = widget.listing['timestamp'];
    DateTime? timestamp;
    if (rawTimestamp is DateTime) {
      timestamp = rawTimestamp;
    } else if (rawTimestamp is Timestamp) {
      timestamp = rawTimestamp.toDate();
    } else {
      timestamp = null;
    }
    final timeAgo = timestamp != null ? _formatTimeAgo(timestamp) : 'Just now';
    final heroTag = 'coverHero-$id-$title';

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => ListingDetailScreen(listing: widget.listing, heroTag: heroTag),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(scale: _scaleAnimation.value, child: child),
        child: Container(
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
                    // Book Cover + Hero
                    Hero(
                      tag: heroTag,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: imageUrl != null && imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                width: 80,
                                height: 110,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _placeholderCover(),
                              )
                            : _placeholderCover(),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
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

                    // Library / Swap Column
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Bookmark / Library toggle
                        IconButton(
                          icon: _libLoading
                              ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70))
                              : Icon(_inLibrary ? Icons.bookmark : Icons.bookmark_border, color: _inLibrary ? const Color(0xFFF0B429) : Colors.white70),
                          onPressed: () async {
                            final uid = FirebaseAuth.instance.currentUser?.uid;
                            final id = widget.listing['id']?.toString();
                            if (uid == null) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to save to your library')));
                              return;
                            }
                            if (id == null) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing has no id')));
                              return;
                            }

                            setState(() => _libLoading = true);
                            try {
                              if (!_inLibrary) {
                                await LibraryService.addToLibrary(uid, id);
                                if (mounted) setState(() => _inLibrary = true);
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added "$title" to your library'), backgroundColor: const Color(0xFFF0B429)));
                              } else {
                                await LibraryService.removeFromLibrary(uid, id);
                                if (mounted) setState(() => _inLibrary = false);
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed from your library')));
                              }
                            } catch (e) {
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                            } finally {
                              if (mounted) setState(() => _libLoading = false);
                            }
                          },
                          tooltip: _inLibrary ? 'Remove from library' : 'Add to library',
                        ),

                        const SizedBox(height: 8),

                        // Swap Button — create a real swap request and notification
                        ElevatedButton(
                          onPressed: () async {
                            final uid = FirebaseAuth.instance.currentUser?.uid;
                            final listingId = widget.listing['id'] as String?;
                            final ownerId = widget.listing['ownerId'] as String?;
                            if (uid == null) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to request a swap')));
                              return;
                            }
                            if (ownerId == uid) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You cannot request your own listing')));
                              return;
                            }
                            if (listingId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing has no id')));
                              return;
                            }

                            // Confirm
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Request Swap'),
                                content: Text('Send a swap request to the owner for "${title}"?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No')),
                                  ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Yes')),
                                ],
                              ),
                            );
                            if (confirm != true) return;

                            try {
                              await FirebaseService.createSwap(listingId, uid, ownerId ?? '');
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Swap request sent for "$title"'), backgroundColor: const Color(0xFFF0B429)));
                            } catch (e) {
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send swap request: $e')));
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF0B429),
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: const Text('Swap', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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

// ── Condition Badge (Reusable) ─────────────────────────────────────
class _ConditionBadge extends StatelessWidget {
  final String condition;
  const _ConditionBadge({required this.condition});

  @override
  Widget build(BuildContext context) {
    final isNew = condition.toLowerCase().contains('new');
    final color = isNew ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        condition,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}