import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_listing_screen.dart';

class ListingDetailScreen extends StatefulWidget {
  final Map<String, dynamic>? listing;
  final String heroTag;

  const ListingDetailScreen({Key? key, this.listing, this.heroTag = 'coverHero'}) : super(key: key);

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  bool _isPending = false;
  bool _isAccepted = false;

  String _humanStatus(String? s) {
    switch (s) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'rejected':
        return 'Rejected';
      default:
        return s ?? 'Unknown';
    }
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
  final isOwner = user != null && widget.listing != null && widget.listing!['ownerId'] == user.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.listing?['title'] ?? 'Listing'),
        backgroundColor: const Color(0xFF0F1724),
        leading: const BackButton(),
        actions: [
          if (isOwner)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditListingScreen(listing: widget.listing!)));
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit Listing')),
              ],
            ),
          if (isOwner)
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: (widget.listing != null && widget.listing!['id'] != null)
                  ? FirebaseService.listenSwapsForListing(widget.listing!['id'])
                  : const Stream.empty(),
              builder: (context, snap) {
                final pending = (snap.data ?? []).where((s) => s['status'] == 'pending').toList();
                if (pending.isEmpty) return const SizedBox.shrink();
                return IconButton(
                  icon: const Icon(Icons.check_circle_outline),
                  onPressed: () async {
                    final swapId = pending.first['id'] as String;
                    final accept = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Accept Swap'),
                        content: const Text('Do you want to accept this swap and mark as exchanged?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No')),
                          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Yes')),
                        ],
                      ),
                    );
                    if (accept == true) {
                      await FirebaseService.acceptSwap(swapId);
                      if (!mounted) return;
                      setState(() {
                        _isAccepted = true;
                        _isPending = false;
                      });
                      if (!mounted) return;
                      await showDialog<void>(
                        context: context,
                        builder: (_) => AlertDialog(
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(width: 140, height: 140, child: Center(child: Lottie.network('https://assets2.lottiefiles.com/packages/lf20_bm8fr5x3.json'))),
                              const SizedBox(height: 8),
                              const Text('Swap accepted!')
                            ],
                          ),
                          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
                        ),
                      );
                    }
                  },
                );
              },
            )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Hero(
                tag: widget.heroTag,
                child: Container(
                  width: 160,
                  height: 240,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.grey[300]),
                  child: ClipRRect(borderRadius: BorderRadius.circular(8), child: (widget.listing != null && widget.listing!['imageUrl'] != null) ? Image.network(widget.listing!['imageUrl'], fit: BoxFit.cover) : Image.asset('assets/bookOpen.png', fit: BoxFit.cover)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(widget.listing?['title'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('by ${widget.listing?['author'] ?? ''}', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            const Text('Condition: Like New', style: TextStyle(color: Colors.black87)),
            const SizedBox(height: 12),
            const Text('Description', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('This textbook is in very good condition. Pages are clean and cover is intact. Great for semester use.'),

            const SizedBox(height: 18),
            // Swap requests (owner view)
            if (widget.listing != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Swap requests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: FirebaseService.listenSwapsForListing(widget.listing!['id']),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
                      final swaps = snap.data ?? [];
                      if (swaps.isEmpty) return const Text('No swap requests yet.');
                      final requesterIds = swaps.map((s) => s['requesterId'] as String?).whereType<String>().toSet().toList();
                      return FutureBuilder<Map<String, Map<String, dynamic>>>(
                        future: FirebaseService.getUsersByIds(requesterIds),
                        builder: (context, usersSnap) {
                          final users = usersSnap.data ?? {};
                          return Column(
                            children: swaps.map((s) {
                              final sid = s['id'] as String?;
                              final requesterId = s['requesterId'] as String? ?? 'unknown';
                              final requesterProfile = users[requesterId];
                              final requesterName = requesterProfile != null && (requesterProfile['displayName'] as String?)?.isNotEmpty == true
                                  ? requesterProfile['displayName']
                                  : (requesterId.substring(0, 8));
                              final requesterAvatar = requesterProfile != null ? (requesterProfile['avatarUrl'] as String?) : null;
                              final status = s['status'] as String? ?? 'pending';
                              final createdAt = s['createdAt'] as Timestamp?;
                              final isPending = status == 'pending';
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  leading: requesterAvatar != null && requesterAvatar.isNotEmpty
                                      ? SizedBox(width: 48, height: 48, child: ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(requesterAvatar, fit: BoxFit.cover)))
                                      : const CircleAvatar(child: Icon(Icons.person)),
                                  title: Text('$requesterName'),
                                  subtitle: Text('${_humanStatus(status)} • ${_formatTime(createdAt)}'),
                                  trailing: isOwner
                                      ? ElevatedButton(
                                          onPressed: isPending
                                              ? () async {
                                                  final confirm = await showDialog<bool>(
                                                    context: context,
                                                    builder: (_) => AlertDialog(
                                                      title: const Text('Accept swap?'),
                                                      content: const Text('Accept this swap request and mark listing as exchanged?'),
                                                      actions: [
                                                        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No')),
                                                        ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Yes')),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirm == true && sid != null) {
                                                    await FirebaseService.acceptSwap(sid);
                                                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Swap accepted')));
                                                  }
                                                }
                                              : null,
                                          child: Text(isPending ? 'Accept' : status[0].toUpperCase() + status.substring(1)),
                                        )
                                      : Text(status),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            const Spacer(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _isPending
                  ? ElevatedButton(
                      key: const ValueKey('pending'),
                      onPressed: () async {
                        final cancel = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Cancel Offer'),
                            content: const Text('Do you want to cancel this pending offer?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No')),
                              ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Yes')),
                            ],
                          ),
                        );
                                                  if (cancel == true) {
                                                  setState(() => _isPending = false);
                                                  if (!mounted) return;
                                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offer cancelled (mock)')));
                                                }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[600], padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text('Pending — Cancel'))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton(
                          key: const ValueKey('swap'),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Request Swap'),
                                content: const Text('Send a swap request to the owner?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No')),
                                  ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Yes')),
                                ],
                              ),
                            );
                            if (confirm == true) {
                                  setState(() => _isPending = true);
                                  // create swap in Firestore
                                  final listingId = widget.listing?['id'] as String?;
                                  final ownerId = widget.listing?['ownerId'] as String?;
                                  final requesterId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
                                  if (listingId != null && ownerId != null) {
                                    await FirebaseService.createSwap(listingId, requesterId, ownerId);
                                  }

                                  // show Lottie success dialog
                                  if (!mounted) return;
                                  await showDialog<void>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 140,
                                            height: 140,
                                            child: Center(child: Lottie.network('https://assets10.lottiefiles.com/packages/lf20_jbrw3hcz.json')),
                                          ),
                                          const SizedBox(height: 8),
                                          const Text('Swap request sent!')
                                        ],
                                      ),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))
                                      ],
                                    ),
                                  );
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF0B429), padding: const EdgeInsets.symmetric(vertical: 16)),
                          child: const Text('Request Swap'),
                        ),
                        const SizedBox(height: 12),
                        if (_isAccepted)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(color: Colors.green[200], borderRadius: BorderRadius.circular(8)),
                            child: const Center(child: Text('Accepted', style: TextStyle(fontWeight: FontWeight.bold))),
                          )
                      ],
                    ),
            )
          ],
        ),
      ),
    );
  }
}

