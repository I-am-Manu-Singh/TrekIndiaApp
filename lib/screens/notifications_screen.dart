import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, List<dynamic>> _groupedNotifications = {};

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final profile = await _client.from('profiles').select('role').eq('id', user.id).single();
      final role = profile['role']?.toString().toUpperCase() ?? 'USER';

      dynamic query;
      if (role == 'ADMIN') {
        query = _client.from('notifications').select().order('created_at', ascending: false);
      } else if (role == 'EMPLOYEE' || role == 'STAFF') {
        query = _client.from('notifications').select().or('user_id.eq.${user.id},type.eq.announcement,type.eq.employee,type.eq.staff').order('created_at', ascending: false);
      } else {
        query = _client.from('notifications').select().or('user_id.eq.${user.id},type.eq.announcement').order('created_at', ascending: false);
      }

      final res = await query;
      _groupNotifications(res);
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _groupNotifications(List<dynamic> list) {
    Map<String, List<dynamic>> groups = {};
    for (var n in list) {
      DateTime dt = DateTime.parse(n['created_at']);
      String key = _getDateKey(dt);
      if (!groups.containsKey(key)) groups[key] = [];
      groups[key]!.add(n);
    }
    _groupedNotifications = groups;
  }

  String _getDateKey(DateTime dt) {
    DateTime now = DateTime.now();
    DateTime yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) return 'TODAY';
    if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) return 'YESTERDAY';
    return DateFormat('EEEE, MMM dd').format(dt).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        backgroundColor: const Color(0xFF2E7B32),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _fetchNotifications),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 20),
            itemCount: _groupedNotifications.keys.length,
            itemBuilder: (ctx, idx) {
              String key = _groupedNotifications.keys.elementAt(idx);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Text(key, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                  ),
                  ..._groupedNotifications[key]!.map((n) => _buildNotificationCard(n)).toList(),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
    );
  }

  Widget _buildNotificationCard(dynamic n) {
    final type = (n['type'] ?? 'announcement').toString().toUpperCase();
    final dt = DateTime.parse(n['created_at']);
    final timeAgo = _getTimeAgo(dt);

    Color themeColor = const Color(0xFF2E7B32);
    Color bgColor = const Color(0xFFE8F5E9);
    IconData icon = Icons.notifications_outlined;

    if (type == 'BOOKING') {
      themeColor = const Color(0xFF4CAF50);
      bgColor = const Color(0xFFE8F5E9);
      icon = Icons.local_activity_outlined;
    } else if (type == 'ADMIN_BOOKING') {
      themeColor = const Color(0xFF009688);
      bgColor = const Color(0xFFE0F2F1);
      icon = Icons.receipt_long_outlined;
    } else if (type == 'RENTAL') {
      themeColor = const Color(0xFF673AB7);
      bgColor = const Color(0xFFEDE7F6);
      icon = Icons.inventory_2_outlined;
    } else if (type == 'SUPPORT') {
      themeColor = const Color(0xFFFB8C00);
      bgColor = const Color(0xFFFFF3E0);
      icon = Icons.face_outlined;
    } else if (type == 'ANNOUNCEMENT') {
      themeColor = const Color(0xFF1E88E5);
      bgColor = const Color(0xFFE3F2FD);
      icon = Icons.campaign_outlined;
    } else if (type == 'ACHIEVEMENT') {
      themeColor = const Color(0xFFFFB300);
      bgColor = const Color(0xFFFFF9C4);
      icon = Icons.emoji_events_outlined;
    }

    return SlideInUp(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10)],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: themeColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(n['title'] ?? 'Official Alert', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      Text(timeAgo, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(n['message'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.4)),
                  const SizedBox(height: 12),
                  _typeTag(type, themeColor, bgColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeTag(String type, Color theme, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(type, style: TextStyle(color: theme, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    );
  }

  String _getTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
