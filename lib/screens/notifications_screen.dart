import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:ui' as ui;
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with TickerProviderStateMixin {
  final List<Map<String, dynamic>> _notifications = [
    {
      'icon': Icons.swap_horiz,
      'title': 'Swap request accepted',
      'subtitle': 'Your swap for "Data Structures & Algorithms" has been accepted!',
      'time': '2h ago',
      'unread': true,
    },
    {
      'icon': Icons.message,
      'title': 'New message',
      'subtitle': 'Alice sent you a message about your listing.',
      'time': '1d ago',
      'unread': true,
    },
    {
      'icon': Icons.book,
      'title': 'Listing viewed',
      'subtitle': 'Someone viewed your "Calculus Textbook" listing.',
      'time': '3d ago',
      'unread': false,
    },
  ];

  late final AnimationController _staggerController;

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

  void _markAsRead(int index) {
    setState(() {
      _notifications[index]['unread'] = false;
    });
  }

  void _deleteNotification(int index) {
    setState(() {
      _notifications.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Refreshed!'), backgroundColor: Color(0xFFF0B429)),
          );
        },
        color: const Color(0xFFF0B429),
        child: _notifications.isEmpty
            ? _EmptyState()
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: _notifications.length,
                itemBuilder: (context, i) {
                  final notif = _notifications[i];
                  return _AnimatedNotificationCard(
                    notification: notif,
                    index: i,
                    controller: _staggerController,
                    onTap: () => _markAsRead(i),
                    onDelete: () => _deleteNotification(i),
                  );
                },
              ),
      ),
      bottomNavigationBar: _BottomNavBar(currentIndex: 2),
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

// ── Bottom Navigation Bar ─────────────────────────────────────
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
        BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Listings'),
        BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Notif'),
      ],
      onTap: (i) {
        if (i == 0) Navigator.of(context).popUntil((r) => r.isFirst);
      },
    );
  }
}