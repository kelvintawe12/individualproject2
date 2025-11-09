import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import 'listing_detail_screen.dart';
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with TickerProviderStateMixin {
  // Notifications are loaded from Firestore per-user.

  late final AnimationController _staggerController;
  // Hold the latest notifications snapshot for debug actions (not used for build updates).
  List<Map<String, dynamic>> _lastNotifications = [];
  // Hold latest error message from the notifications stream so debug actions can copy it.
  String? _lastNotificationsError;
  // Toggle whether the debug mini-FABs are visible
  bool _debugFabOpen = false;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _staggerController.forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Future<void> _markAsReadById(String notificationId) async {
    try {
      await FirebaseService.markNotificationRead(notificationId);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to mark read: $e')));
    }
  }

  Future<void> _deleteNotificationById(String notificationId) async {
    try {
      await FirebaseService.deleteNotification(notificationId);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: const Color(0xFF0F1724),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1724),
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Refreshed!'), backgroundColor: Color(0xFFF0B429)));
        },
        color: const Color(0xFFF0B429),
        child: uid == null
            ? Center(child: Text('Sign in to see notifications', style: TextStyle(color: Colors.white70)))
            : StreamBuilder<List<Map<String, dynamic>>>(
                stream: FirebaseService.listenNotificationsForUser(uid),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (snap.hasError) {
                    // cache the error text so debug actions can copy it
                    try {
                      _lastNotificationsError = snap.error?.toString();
                    } catch (_) {
                      _lastNotificationsError = '${snap.error}';
                    }
                    return Center(child: Text('Failed to load notifications: ${snap.error}', style: const TextStyle(color: Colors.white70)));
                  }
                  final items = snap.data ?? [];
                  // cache latest items for debug buttons (no setState to avoid rebuild loops)
                  try {
                    _lastNotifications = List<Map<String, dynamic>>.from(items);
                    _lastNotificationsError = null;
                  } catch (_) {
                    _lastNotifications = items.cast<Map<String, dynamic>>();
                    _lastNotificationsError = null;
                  }
                  if (items.isEmpty) return _EmptyState();
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final doc = items[i];
                      // Map backend notification to UI fields expected by the card
                      final payload = Map<String, dynamic>.from(doc['payload'] ?? {});
                      final type = doc['type'] as String? ?? 'generic';
                      final read = doc['read'] as bool? ?? false;
                      final createdAt = doc['createdAt'];
                      String timeLabel = '';
                      try {
                        if (createdAt is Timestamp) {
                          final dt = createdAt.toDate();
                          final diff = DateTime.now().difference(dt);
                          if (diff.inDays > 0) timeLabel = '${diff.inDays}d ago';
                          else if (diff.inHours > 0) timeLabel = '${diff.inHours}h ago';
                          else if (diff.inMinutes > 0) timeLabel = '${diff.inMinutes}m ago';
                          else timeLabel = 'Just now';
                        }
                      } catch (_) {}

                      String title = '';
                      String subtitle = '';
                      IconData icon = Icons.notifications;

                      if (type == 'login') {
                        icon = Icons.login;
                        title = 'Signed in';
                        subtitle = payload['email'] ?? payload['message'] ?? 'Recent sign-in';
                      } else if (type == 'swap_request') {
                        icon = Icons.swap_horiz;
                        title = 'Swap request';
                        subtitle = 'User ${payload['requesterId'] ?? ''} requested your listing';
                      } else {
                        title = payload['title'] ?? payload['message'] ?? 'Notification';
                        subtitle = (payload['body'] ?? '').toString();
                      }

                      final uiNotif = {
                        'id': doc['id'],
                        'icon': icon,
                        'title': title,
                        'subtitle': subtitle,
                        'time': timeLabel,
                        'unread': !read,
                      };

                      // Build the notification card and optional actions (for owners)
                      final widgetCard = _AnimatedNotificationCard(
                        notification: uiNotif,
                        index: i,
                        controller: _staggerController,
                        onTap: () async {
                          final nid = doc['id'] as String;
                          await _markAsReadById(nid);
                          // Navigate to related listing if present
                          if (type == 'swap_request' || type == 'swap_accepted') {
                            final listingId = payload['listingId'] as String?;
                            if (listingId != null && listingId.isNotEmpty) {
                              try {
                                final listing = await FirebaseService.getListingById(listingId);
                                if (listing != null) {
                                  if (!mounted) return;
                                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ListingDetailScreen(listing: listing, heroTag: 'coverHero-${listingId}-${listing['title'] ?? ''}')));
                                }
                              } catch (e) {
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to open listing: $e')));
                              }
                            }
                          }
                        },
                        onDelete: () => _deleteNotificationById(doc['id'] as String),
                      );

                      // If this is a swap_request and the current user is the recipient (owner), show accept/reject actions inline.
                      final isSwapRequest = type == 'swap_request';
                      final swapId = payload['swapId'] as String?;

                      if (!isSwapRequest || swapId == null) return widgetCard;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          widgetCard,
                          Padding(
                            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton(
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text('Reject swap request'),
                                        content: const Text('Are you sure you want to reject this swap request?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No')),
                                          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Yes')),
                                        ],
                                      ),
                                    );
                                    if (confirm != true) return;
                                    try {
                                      await FirebaseService.rejectSwap(swapId);
                                      await _markAsReadById(doc['id'] as String);
                                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Swap request rejected')));
                                    } catch (e) {
                                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to reject: $e')));
                                    }
                                  },
                                  child: const Text('Reject'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text('Accept swap request'),
                                        content: const Text('Accept this swap request and mark listing as exchanged?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No')),
                                          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Yes')),
                                        ],
                                      ),
                                    );
                                    if (confirm != true) return;
                                    try {
                                      await FirebaseService.acceptSwap(swapId);
                                      await _markAsReadById(doc['id'] as String);
                                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Swap accepted')));
                                    } catch (e) {
                                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to accept: $e')));
                                    }
                                  },
                                  child: const Text('Accept'),
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF0B429)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
      ),
      floatingActionButton: kDebugMode
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_debugFabOpen) ...[
                  // Print action with label
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                        child: const Text('Print', style: TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      FloatingActionButton.small(
                        heroTag: 'debug_print',
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        onPressed: () {
                          if (_lastNotifications.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No notifications to print'), backgroundColor: Color(0xFFF0B429)));
                            return;
                          }
                          try {
                            final jsonText = const JsonEncoder.withIndent('  ').convert(_lastNotifications);
                            debugPrint(jsonText);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications printed to console'), backgroundColor: Color(0xFF4CAF50)));
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to print: $e')));
                          }
                        },
                        child: const Icon(Icons.print, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Copy action with label
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                        child: const Text('Copy', style: TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      FloatingActionButton.small(
                        heroTag: 'debug_copy',
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        onPressed: () async {
                          try {
                            if (_lastNotifications.isNotEmpty) {
                              final jsonText = const JsonEncoder.withIndent('  ').convert(_lastNotifications);
                              await Clipboard.setData(ClipboardData(text: jsonText));
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications copied to clipboard'), backgroundColor: Color(0xFF4CAF50)));
                              return;
                            }
                            if (_lastNotificationsError != null && _lastNotificationsError!.isNotEmpty) {
                              await Clipboard.setData(ClipboardData(text: _lastNotificationsError ?? ''));
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error copied to clipboard'), backgroundColor: Color(0xFF4CAF50)));
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No notifications to copy'), backgroundColor: Color(0xFFF0B429)));
                          } catch (e) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to copy: $e')));
                          }
                        },
                        child: const Icon(Icons.copy, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                FloatingActionButton(
                  backgroundColor: const Color(0xFFF0B429),
                  child: Icon(_debugFabOpen ? Icons.close : Icons.bug_report),
                  onPressed: () => setState(() => _debugFabOpen = !_debugFabOpen),
                ),
              ],
            )
          : null,
      // Bottom navigation handled by the app shell's global BottomNavigationBar.
    );
  }
}

// ── Animated Notification Card with Swipe ─────────────────────────────────────
class _AnimatedNotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final int index;
  final AnimationController controller;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _AnimatedNotificationCard({
    required this.notification,
    required this.index,
    required this.controller,
    required this.onTap,
    required this.onDelete,
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
        key: Key(notification['title']),
        direction: DismissDirection.endToStart,
        background: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: const Icon(Icons.delete, color: Colors.white, size: 28),
        ),
        onDismissed: (_) => onDelete(),
        child: _GlassNotificationCard(
          icon: notification['icon'],
          title: notification['title'],
          subtitle: notification['subtitle'],
          time: notification['time'],
          unread: notification['unread'],
          onTap: onTap,
        ),
      ),
    );
  }
}

// ── Glassmorphism Notification Card ─────────────────────────────────────
class _GlassNotificationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final bool unread;
  final VoidCallback onTap;

  const _GlassNotificationCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.unread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
        child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: unread ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: unread ? const Color(0xFFF0B429) : Colors.white.withOpacity(0.1), width: unread ? 1.5 : 1),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Row(
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0B429),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.black87, size: 24),
                  ),
                  const SizedBox(width: 16),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: unread ? FontWeight.w600 : FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Time + Unread Dot
                  Column(
                    children: [
                      Text(time, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                      if (unread) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF0B429),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty State ─────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/empty_notifications.json', // optional: add this
            width: 180,
            height: 180,
            repeat: true,
          ),
          const SizedBox(height: 16),
          const Text(
            'No notifications yet',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'You\'ll be notified when someone interacts with your listings.',
            style: TextStyle(color: Colors.white60, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Navigation is provided by the app shell; local BottomNavBar removed to avoid
// duplicate navigation bars.