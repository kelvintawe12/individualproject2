import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../services/firebase_service.dart'; // Assuming this exists
import 'package:flutter_bloc/flutter_bloc.dart';
import '../presentation/bloc/listing_cubit.dart';
import '../presentation/bloc/listing_state.dart';
import '../widgets/listing_card.dart';
import 'post_screen.dart'; // Adjust path

class ListingsScreen extends StatefulWidget {
  const ListingsScreen({super.key});

  @override
  State<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends State<ListingsScreen>
    with TickerProviderStateMixin {
  late final AnimationController _staggerController;
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);
  String _selectedFilter = 'All';
  final List<String> _filters = const ['All', 'New', 'Used', 'Free'];

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
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    setState(() {}); // Trigger rebuild → StreamBuilder will reload
    _refreshController.refreshCompleted();
  }

  Route _createPostRoute() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => const PostScreen(),
      transitionsBuilder: (context, animation, _, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        final tween = Tween(begin: begin, end: end)
            .chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 450),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFF0B121E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'BookSwap',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outline),
            tooltip: 'Library',
            onPressed: () {
              Navigator.of(context).pushNamed('/library');
            },
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Chats',
            onPressed: () {
              Navigator.of(context).pushNamed('/chats');
            },
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              // TODO: Navigate to search
            },
          ),
        ],
      ),
      body: SmartRefresher(
        controller: _refreshController,
        onRefresh: _onRefresh,
        header: const WaterDropHeader(
          waterDropColor: Color(0xFFF0B429),
        ),
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: FirebaseService.listenListings(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                snapshot.data == null) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFF0B429),
                  strokeWidth: 2.5,
                ),
              );
            }

            if (snapshot.hasError) {
              final err = snapshot.error;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.signal_wifi_connected_no_internet_4_rounded,
                          color: Colors.redAccent.shade400, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        'Connection failed',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white70,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$err',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white60),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => setState(() {}),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF0B429),
                              foregroundColor: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                final diag = await FirebaseService.getDiagnostics(
                                    queryDesc: 'listings');
                                final payload = 'Error: $err\\n\\n$diag';
                                await Clipboard.setData(
                                    ClipboardData(text: payload));
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Diagnostics copied to clipboard')),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed: $e')),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.bug_report_outlined),
                            label: const Text('Report'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }

            final items = snapshot.data ?? [];

            if (items.isEmpty) {
              return Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/booksShelf.png',
                        width: 220,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No books yet',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Be the first to post a listing!',
                        style: TextStyle(color: Colors.white60, fontSize: 16),
                      ),
                    ],
                    ),
                ),
              );
            }
            // Apply client-side filter (simple contains check on condition/title)
            final filtered = items.where((m) {
              if (_selectedFilter == 'All') return true;
              final condition = (m['condition'] as String?)?.toLowerCase() ?? '';
              final title = (m['title'] as String?)?.toLowerCase() ?? '';
              final f = _selectedFilter.toLowerCase();
              return condition.contains(f) || title.contains(f);
            }).toList();

            // If filter yields nothing, show a friendly empty state.
            if (filtered.isEmpty) {
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                      child: _buildFilterBar(),
                    ),
                  ),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.search_off, size: 64, color: Colors.white24),
                          const SizedBox(height: 12),
                          Text(
                            'No books match your filters',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 8),
                          const Text('Try a different filter or clear the selection.', style: TextStyle(color: Colors.white60)),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                    child: _buildFilterBar(),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => AnimatedBuilder(
                        animation: _staggerController,
                        builder: (context, child) {
                          final animation = Tween<double>(begin: 0.0, end: 1.0)
                              .animate(CurvedAnimation(parent: _staggerController, curve: Interval(0.05 * (i % 8), 0.5 + 0.05 * (i % 8), curve: Curves.easeOutCubic)));
                          return Transform.translate(
                            offset: Offset(0, 80 * (1 - animation.value)),
                            child: Opacity(opacity: animation.value, child: child),
                          );
                        },
                        child: ListingCard(listing: filtered[i]),
                      ),
                      childCount: filtered.length,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(_createPostRoute()),
        tooltip: 'Post',
        child: const Icon(Icons.add),
        backgroundColor: const Color(0xFFF0B429),
        foregroundColor: Colors.black87,
        elevation: 6,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      // Bottom navigation is provided by the app shell (`app.dart`).
      // Removing the local BottomNavigationBar to avoid a duplicated
      // navigation bar when this screen is used inside the main Scaffold.
    );
  }

  Widget _buildFilterBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedFilter,
                isExpanded: true,
                dropdownColor: const Color(0xFF0B121E),
                items: _filters.map((f) {
                  return DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(color: Colors.white)));
                }).toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _selectedFilter = v);
                },
                iconEnabledColor: Colors.white70,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () {
            setState(() => _selectedFilter = 'All');
          },
          child: const Text('Clear', style: TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }
}

// ── Sophisticated Glass Card with Save Logic ─────────────────────
class _GlassListingCard extends StatefulWidget {
  final Map<String, dynamic> listing;
  const _GlassListingCard({required this.listing});

  @override
  State<_GlassListingCard> createState() => _GlassListingCardState();
}

class _GlassListingCardState extends State<_GlassListingCard>
  with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Load initial per-listing flags into ListingCubit (bookmark/pending)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = widget.listing['id'] as String?;
      if (id != null) {
        try {
          context.read<ListingCubit>().loadInitial(id);
        } catch (_) {}
      }
    });
  }

  // library status is managed by ListingCubit; we no longer keep local copy here.

  Future<void> _toggleLibrary() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final id = widget.listing['id'] as String?;
    final title = widget.listing['title'] ?? 'Book';

    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to save books')),
      );
      return;
    }
    if (id == null) return;

    HapticFeedback.mediumImpact();

    try {
      // Delegate add/remove to ListingCubit which will manage libLoading flag.
      await context.read<ListingCubit>().toggleInLibrary(id);
      // After the cubit completes, read the new state and show UX feedback.
      final updated = context.read<ListingCubit>().state[id] ?? const ListingState();
      if (mounted) {
        if (updated.inLibrary) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added "$title" to your library'),
              backgroundColor: const Color(0xFFF0B429),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Removed from library'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
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

    final timeAgo = timestamp != null ? _formatTimeAgo(timestamp) : 'Just now';

    return Container(
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
                          // Allow the time text to shrink/ellipsis so the Row
                          // doesn't force an overflow when available width is small.
                          Flexible(
                            child: Text(
                              timeAgo,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Constrain trailing control to a fixed width so that if an
                // ancestor provides a very small max width (web rendering
                // oddities), the row's children won't attempt to overflow
                // horizontally.
                SizedBox(
                  width: 48,
                  child: Center(
                      child: Builder(builder: (context) {
                        final id = widget.listing['id'] as String?;
                        final listingState = (id != null) ? (context.watch<ListingCubit>().state[id] ?? const ListingState()) : const ListingState();
                        return listingState.libLoading
                            ? const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation(Color(0xFFF0B429)),
                                ),
                              )
                            : IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: Icon(
                                    listingState.inLibrary ? Icons.bookmark : Icons.bookmark_border,
                                    key: ValueKey(listingState.inLibrary),
                                    color: listingState.inLibrary ? const Color(0xFFF0B429) : Colors.white70,
                                    size: 28,
                                  ),
                                ),
                                onPressed: _toggleLibrary,
                              );
                      }),
                  ),
                ),
              ],
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
          style: const TextStyle(
            color: Colors.white,
            fontSize: 40,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays >= 30) {
      return '${(diff.inDays / 30).floor()} mo ago';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    }
    return 'now';
  }
}

// (Animations handled inline where ListingCard is used.)

// ── Condition Badge (unchanged but polished) ─────────────────────
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
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}