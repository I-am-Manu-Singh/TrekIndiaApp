import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'my_trips_screen.dart';
import 'admin_bookings_screen.dart';
import 'admin_support_inquiries_screen.dart';
import 'user_gear_rental_screen.dart';
import 'trek_training_hub.dart';

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

    final List<_AppNotification> items = [];

    try {
      // 1. Booking confirmations & updates (user & admin)
      final bookings = await _client
          .from('bookings')
          .select('id, booking_date, status, payment_status, total_price, treks(title)')
          .eq('user_id', user.id)
          .order('booking_date', ascending: false)
          .limit(10);

      for (var b in bookings) {
        final trekTitle = b['treks']?['title'] ?? 'Trek';
        final date = DateTime.tryParse(b['booking_date'] ?? '') ?? DateTime.now();
        final status = b['status'] ?? 'Confirmed';

        if (status == 'Completed') {
          items.add(_AppNotification(
            icon: Icons.emoji_events,
            color: Colors.amber,
            title: 'Trek Completed!',
            body: 'Congratulations on completing $trekTitle. Check your profile for the achievement badge.',
            time: date,
            category: 'achievement',
          ));
        } else {
          items.add(_AppNotification(
            icon: Icons.confirmation_num_outlined,
            color: Colors.green,
            title: 'Booking $status',
            body: '$trekTitle — ₹${b['total_price']} • ${b['payment_status'] ?? 'Paid'}',
            time: date,
            category: 'booking',
          ));
        }
      }

      // 2. Global announcements
      final announcements = await _client
          .from('global_announcements')
          .select()
          .order('created_at', ascending: false)
          .limit(10);

      for (var a in announcements) {
        items.add(_AppNotification(
          icon: Icons.campaign,
          color: Colors.blue,
          title: a['title'] ?? 'Announcement',
          body: a['content'] ?? '',
          time: DateTime.tryParse(a['created_at'] ?? '') ?? DateTime.now(),
          category: 'announcement',
        ));
      }

      // 3. Admin-specific: new support inquiries
      if (widget.role == 'admin') {
        try {
          final inquiries = await _client
              .from('support_inquiries')
              .select('id, subject, message, status, created_at, profiles(full_name)')
              .order('created_at', ascending: false)
              .limit(10);

          for (var inq in inquiries) {
            items.add(_AppNotification(
              icon: Icons.support_agent,
              color: Colors.orange,
              title: 'Support: ${inq['subject'] ?? 'User Inquiry'}',
              body: '${inq['profiles']?['full_name'] ?? 'User'}: ${inq['message'] ?? ''}',
              time: DateTime.tryParse(inq['created_at'] ?? '') ?? DateTime.now(),
              category: 'support',
            ));
          }
        } catch (_) {}

        // 4. Admin: recent bookings from all users
        try {
          final allBookings = await _client
              .from('bookings')
              .select('id, booking_date, total_price, payment_status, treks(title), profiles!inner(full_name)')
              .order('booking_date', ascending: false)
              .limit(10);

          for (var b in allBookings) {
            items.add(_AppNotification(
              icon: Icons.receipt_long,
              color: Colors.teal,
              title: 'New Booking',
              body: '${b['profiles']?['full_name'] ?? 'User'} booked ${b['treks']?['title'] ?? 'a trek'} — ₹${b['total_price']}',
              time: DateTime.tryParse(b['booking_date'] ?? '') ?? DateTime.now(),
              category: 'admin_booking',
            ));
          }
        } catch (_) {}

        // 5. Admin: rental requests
        try {
          final rentals = await _client
              .from('user_rentals')
              .select('id, status, issue_date, total_price, gear:gears(name), profiles!inner(full_name)')
              .order('issue_date', ascending: false)
              .limit(5);
          for (var r in rentals) {
            items.add(_AppNotification(
              icon: Icons.inventory_2,
              color: Colors.deepPurple,
              title: 'Gear ${r['status'] == 'returned' ? 'Returned' : 'Issued'}',
              body: '${r['profiles']?['full_name'] ?? 'User'} — ${r['gear']?['name'] ?? 'Gear'} • ₹${r['total_price']}',
              time: DateTime.tryParse(r['issue_date'] ?? '') ?? DateTime.now(),
              category: 'rental',
            ));
          }
        } catch (_) {}
      } else if (widget.role == 'employee' || widget.role == 'guide' || widget.role == 'staff') {
        // 5a. Employee: recent attendance logs
        try {
          final att = await _client.from('attendance_logs').select().eq('user_id', user.id).order('date', ascending: false).limit(5);
          for (var a in att) {
            items.add(_AppNotification(
              icon: Icons.today_outlined,
              color: Colors.blue,
              title: 'Attendance: ${a['status']?.toUpperCase() ?? 'PRESENT'}',
              body: 'Trek record updated for ${a['date']}.',
              time: DateTime.tryParse(a['date'] ?? '') ?? DateTime.now(),
              category: 'attendance',
            ));
          }
        } catch (_) {}

        // 5b. Employee: assigned trek groups
        try {
          final groups = await _client.from('bookings').select('*, treks(*)').eq('user_id', user.id).order('trek_date', ascending: false).limit(5); // This is a proxy for assigned squads for now
          for (var g in groups) {
            items.add(_AppNotification(
              icon: Icons.groups,
              color: Colors.green,
              title: 'Squad Assignment',
              body: 'Sector ${g['treks']?['title'] ?? 'Trek'} — Assignment: ${g['trek_date']}',
              time: DateTime.tryParse(g['booking_date'] ?? '') ?? DateTime.now(),
              category: 'assignment',
            ));
          }
        } catch (_) {}

        // 5c. Employee: Payment/Payout logs
        try {
          final payouts = await _client.from('payment_logs').select().eq('user_id', user.id).order('created_at', ascending: false).limit(5);
          for (var p in payouts) {
            items.add(_AppNotification(
              icon: Icons.account_balance_wallet,
              color: Colors.teal,
              title: 'Fiscal Settlement',
              body: 'Settlement amount: ₹${p['amount']} — Status: Processed',
              time: DateTime.tryParse(p['created_at'] ?? '') ?? DateTime.now(),
              category: 'payout',
            ));
          }
        } catch (_) {}
      } else {
        // 6. User: own rental status
        try {
          final myRentals = await _client
              .from('user_rentals')
              .select('id, status, issue_date, total_price, gear:gears(name)')
              .eq('user_id', user.id)
              .order('issue_date', ascending: false)
              .limit(5);

          for (var r in myRentals) {
            items.add(_AppNotification(
              icon: Icons.shopping_bag,
              color: Colors.deepPurple,
              title: 'Gear Rental ${r['status']?.toString().toUpperCase() ?? ''}',
              body: '${r['gear']?['name'] ?? 'Gear item'} — ₹${r['total_price']}',
              time: DateTime.tryParse(r['issue_date'] ?? '') ?? DateTime.now(),
              category: 'rental',
            ));
          }
        } catch (_) {}

        // 7. User: training logs (recent)
        try {
          final logs = await _client
              .from('training_logs')
              .select('workout_title, completed_at, duration_seconds, calories_burned')
              .eq('user_id', user.id)
              .order('completed_at', ascending: false)
              .limit(3);

          for (var l in logs) {
            final mins = ((l['duration_seconds'] ?? 0) / 60).round();
            items.add(_AppNotification(
              icon: Icons.fitness_center,
              color: Colors.orangeAccent,
              title: 'Workout Logged',
              body: '${l['workout_title']} — ${mins}min • ${l['calories_burned'] ?? 0} cal',
              time: DateTime.tryParse(l['completed_at'] ?? '') ?? DateTime.now(),
              category: 'training',
            ));
          }
        } catch (_) {}
      }

      // Sort all by time descending
      items.sort((a, b) => b.time.compareTo(a.time));
    } catch (e) {
      debugPrint('Notification fetch error: $e');
    }

    if (mounted) {
      setState(() {
        _notifications = items;
        _isLoading = false;
      });
    }
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
                          FadeInUp(
                            duration: const Duration(milliseconds: 200),
                            child: GestureDetector(
                              onTap: () => _showNotificationDetail(n),
                              child: _notificationTile(n, isDark),
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
                      Navigator.push(context, MaterialPageRoute(builder: (c) => MyTripsScreen()));
                  } else if (n.category == 'admin_booking' || n.category == 'booking_update') {
                      Navigator.push(context, MaterialPageRoute(builder: (c) => AdminBookingsScreen()));
                  } else if (n.category == 'support') {
                      Navigator.push(context, MaterialPageRoute(builder: (c) => AdminSupportInquiriesScreen()));
                  } else if (n.category == 'announcement') {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Announcement details displayed above.')));
                  } else if (n.category == 'rental') {
                      Navigator.push(context, MaterialPageRoute(builder: (c) => UserGearRentalScreen()));
                  } else if (n.category == 'training') {
                      Navigator.push(context, MaterialPageRoute(builder: (c) => TrekTrainingHub()));
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
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: n.color.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
                          fontWeight: FontWeight.bold,
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
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: n.color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    n.category.toUpperCase(),
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: n.color,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
            'No notifications right now.\nBook a trek or complete a workout to see updates here!',
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
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final DateTime time;
  final String category;

  _AppNotification({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.time,
    required this.category,
  });
}
