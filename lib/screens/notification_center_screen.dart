import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'my_trips_screen.dart';
import 'admin_bookings_screen.dart';
import 'admin_support_inquiries_screen.dart';
import 'user_gear_rental_screen.dart';
import 'trip_training_hub.dart';

class NotificationCenterScreen extends StatefulWidget {
  final String role;
  const NotificationCenterScreen({super.key, this.role = 'user'});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<_AppNotification> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final res = await _client.from('notifications').select().eq('user_id', user.id).order('created_at', ascending: false).limit(50);
      final List<_AppNotification> items = [];
      for (var n in res) {
        items.add(_AppNotification(
          id: n['id'],
          icon: _getIcon(n['category']),
          color: _getColor(n['category']),
          title: n['title'] ?? 'Notification',
          body: n['body'] ?? '',
          time: DateTime.tryParse(n['created_at'] ?? '') ?? DateTime.now(),
          category: n['category'] ?? 'general',
          isRead: n['is_read'] ?? false,
        ));
      }

      if (mounted) {
        setState(() {
          _notifications = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Notification fetch error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _getIcon(String? category) {
    switch (category) {
      case 'booking': return Icons.confirmation_num_outlined;
      case 'billing': return Icons.account_balance_wallet_outlined;
      case 'achievement': return Icons.emoji_events;
      case 'rental': return Icons.inventory_2_outlined;
      case 'announcement': return Icons.campaign_outlined;
      case 'admin_booking': return Icons.receipt_long;
      case 'support': return Icons.support_agent;
      case 'training': return Icons.fitness_center;
      default: return Icons.notifications_none;
    }
  }

  Color _getColor(String? category) {
    switch (category) {
      case 'booking': return Colors.green;
      case 'billing': return Colors.blue;
      case 'achievement': return Colors.amber;
      case 'rental': return Colors.deepPurple;
      case 'announcement': return Colors.orange;
      case 'admin_booking': return Colors.teal;
      case 'support': return Colors.deepOrange;
      case 'training': return Colors.pink;
      default: return Colors.grey;
    }
  }

  Future<void> _deleteNotification(String id) async {
    await _client.from('notifications').delete().eq('id', id);
  }

  Future<void> _markAsRead(String id) async {
    await _client.from('notifications').update({'is_read': true}).eq('id', id);
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM dd').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      final showDateHeader = index == 0 ||
                          _formatDateHeader(n.time) != _formatDateHeader(_notifications[index - 1].time);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showDateHeader)
                            Padding(
                              padding: const EdgeInsets.only(top: 16, bottom: 8),
                              child: Text(
                                _formatDateHeader(n.time),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white54 : Colors.grey,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          Dismissible(
                            key: Key(n.id ?? index.toString()),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(16)),
                              child: const Icon(Icons.delete_outline, color: Colors.white),
                            ),
                            onDismissed: (_) {
                              if (n.id != null) _deleteNotification(n.id!);
                              setState(() => _notifications.removeAt(index));
                            },
                            child: FadeInUp(
                              duration: const Duration(milliseconds: 200),
                              child: GestureDetector(
                                onTap: () {
                                  if (n.id != null) _markAsRead(n.id!);
                                  setState(() => n.isRead = true);
                                  _showNotificationDetail(n);
                                },
                                child: _notificationTile(n, isDark),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
    );
  }

  String _formatDateHeader(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    if (date == today) return 'TODAY';
    if (date == today.subtract(const Duration(days: 1))) return 'YESTERDAY';
    return DateFormat('EEEE, MMM dd').format(dt).toUpperCase();
  }

  void _showNotificationDetail(_AppNotification n) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.45,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
        ),
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: n.color.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(n.icon, color: n.color, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.category.toUpperCase(), style: TextStyle(color: n.color, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2)),
                      Text(DateFormat('MMM dd, yyyy | HH:mm').format(n.time), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 30),
            Text(n.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Text(n.body, style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.blueGrey)),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (n.category == 'booking' || n.category == 'achievement') {
                      Navigator.push(context, MaterialPageRoute(builder: (c) => const MyTripsScreen()));
                  } else if (n.category == 'admin_booking') {
                      Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminBookingsScreen()));
                  } else if (n.category == 'support') {
                      Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminSupportInquiriesScreen()));
                  } else if (n.category == 'rental') {
                      Navigator.push(context, MaterialPageRoute(builder: (c) => const UserGearRentalScreen()));
                  } else if (n.category == 'training') {
                      Navigator.push(context, MaterialPageRoute(builder: (c) => const TripTrainingHub()));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: n.color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text('PROCEED TO ACTION', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notificationTile(_AppNotification n, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: n.isRead ? n.color.withOpacity(0.05) : n.color.withOpacity(0.2), width: n.isRead ? 1 : 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Opacity(
        opacity: n.isRead ? 0.6 : 1.0,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: n.color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(n.icon, color: n.color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: TextStyle(
                            fontWeight: n.isRead ? FontWeight.bold : FontWeight.w900,
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        _relativeTime(n.time),
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    n.body,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!n.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(left: 8, top: 4),
                decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FadeInDown(
            child: Icon(
              Icons.notifications_off_outlined,
              size: 80,
              color: Colors.grey.withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'ALL CLEAR',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2),
          ),
          const SizedBox(height: 8),
          const Text(
            'No notifications right now.\nBook a trip or complete a workout to see updates here!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: _loadNotifications,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh'),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppNotification {
  final String? id;
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final DateTime time;
  final String category;
  bool isRead;

  _AppNotification({
    this.id,
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.time,
    required this.category,
    this.isRead = false,
  });
}
