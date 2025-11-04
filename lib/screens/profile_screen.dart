import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import 'listing_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _listingCount = 0;
  Map<String, int> _swapSummary = {};
  List<Map<String, dynamic>> _history = [];
  Map<String, Map<String, dynamic>> _listings = {};
  List<Map<String, dynamic>> _userListings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _loading = true);
    try {
      final listings = await FirebaseService.getUserListingCount(user.uid);
      final summary = await FirebaseService.getUserSwapSummary(user.uid);
      final history = await FirebaseService.getUserSwapHistory(user.uid);
      // lookup listing titles/thumbnails for history
      final ids = history.map((e) => e['listingId'] as String?).whereType<String>().toSet().toList();
      final listingsMap = await FirebaseService.getListingsByIds(ids);
      // also load user's own listings for the grid
      final myListings = await FirebaseService.getListingsForUser(user.uid);
      if (!mounted) return;
      setState(() {
        _listingCount = listings;
        _swapSummary = summary;
        _history = history;
        _listings = listingsMap;
        _userListings = myListings;
      });
    } catch (e) {
      // ignore for now
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: user == null
            ? const Center(child: Text('Not signed in'))
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  children: [
                    ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(user.email ?? 'User'),
                      subtitle: Text('User ID: ${user.uid}'),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _statItem('Listings', _listingCount),
                            _statItem('Requested', _swapSummary['requested'] ?? 0),
                            _statItem('Received', _swapSummary['received'] ?? 0),
                            _statItem('Accepted', _swapSummary['accepted'] ?? 0),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('My listings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (_loading)
                      const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
                    else if (_userListings.isEmpty)
                      const Text('You have no listings yet')
                    else
                      SizedBox(
                        height: 140,
                        child: GridView.builder(
                          scrollDirection: Axis.horizontal,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 1, childAspectRatio: 1.8, mainAxisSpacing: 8),
                          itemCount: _userListings.length,
                          itemBuilder: (context, idx) {
                            final l = _userListings[idx];
                            return InkWell(
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(builder: (_) => ListingDetailScreen(listing: l)));
                              },
                              child: Card(
                                child: Row(
                                  children: [
                                    SizedBox(width: 90, height: 120, child: (l['imageUrl'] != null) ? Image.network(l['imageUrl'], fit: BoxFit.cover) : Image.asset('assets/placeholder.png', fit: BoxFit.cover)),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(l['title'] ?? 'Untitled', maxLines: 3, overflow: TextOverflow.ellipsis)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                    const Text('Recent activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (_loading) const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
                    if (!_loading && _history.isEmpty) const Text('No recent activity'),
                    for (final h in _history)
                      InkWell(
                        onTap: () {
                          final lid = h['listingId'] as String?;
                          if (lid != null && _listings.containsKey(lid)) {
                            final listing = _listings[lid]!;
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => ListingDetailScreen(listing: listing)));
                          }
                        },
                        child: ListTile(
                          leading: _buildThumbnail(h['listingId'] as String?),
                          title: Text(_listings[h['listingId']]?['title'] ?? 'Listing ${h['listingId'] ?? ''}'),
                          subtitle: Text('${_humanStatus(h['status'])} • ${_formatTime(h['createdAt'] as Timestamp?)}'),
                          trailing: _statusChip(h['status'] as String?),
                        ),
                      ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await FirebaseService.sendEmailVerification();
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification email sent')));
                      },
                      icon: const Icon(Icons.email),
                      label: const Text('Resend verification email'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _statItem(String label, int value) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [Text('$value', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(label)],
      );

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

  Widget _statusChip(String? s) {
    final label = _humanStatus(s);
    Color color;
    switch (s) {
      case 'accepted':
        color = Colors.green;
        break;
      case 'pending':
        color = Colors.orange;
        break;
      default:
        color = Colors.grey;
    }
  // use withAlpha to create a translucent version of the chosen color
  final bg = color.withAlpha((0.15 * 255).round());
    return Chip(label: Text(label), backgroundColor: bg);
  }

  Widget _buildThumbnail(String? listingId) {
    final li = listingId != null ? _listings[listingId] : null;
    final url = li != null ? (li['imageUrl'] as String?) : null;
    if (url != null && url.isNotEmpty) {
      return SizedBox(width: 48, height: 48, child: ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(url, fit: BoxFit.cover)));
    }
    return const SizedBox(width: 48, height: 48, child: CircleAvatar(child: Icon(Icons.book)));
  }
}
