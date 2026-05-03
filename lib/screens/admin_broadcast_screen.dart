import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';

class AdminBroadcastScreen extends StatefulWidget {
  const AdminBroadcastScreen({super.key});

  @override
  State<AdminBroadcastScreen> createState() => _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends State<AdminBroadcastScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _broadcasts = [];

  @override
  void initState() {
    super.initState();
    _loadBroadcasts();
  }

  Future<void> _loadBroadcasts() async {
    setState(() => _isLoading = true);
    try {
      final res = await _client
          .from('global_announcements')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _broadcasts = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCreateModal() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    bool isUrgent = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(30, 30, 30, MediaQuery.of(ctx).viewInsets.bottom + 30),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('NEW OFFICIAL BROADCAST', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 1)),
              const SizedBox(height: 24),
              _modalInput(titleCtrl, 'Intel Headline...', 1),
              const SizedBox(height: 16),
              _modalInput(contentCtrl, 'Trip Briefing Content...', 5),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text('Priority: Urgent', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('Forces popup on all active dashboards', style: TextStyle(color: Colors.white38, fontSize: 10)),
                value: isUrgent,
                activeColor: Colors.redAccent,
                onChanged: (v) => setModalState(() => isUrgent = v),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleCtrl.text.isEmpty) return;
                    final data = {
                      'title': titleCtrl.text.trim(),
                      'content': contentCtrl.text.trim(),
                      'is_urgent': isUrgent,
                      'sender_id': _client.auth.currentUser?.id,
                      'sender_name': 'TRIP INDIA CONTROL',
                      'created_at': DateTime.now().toIso8601String(),
                    };

                    try {
                      await _client.from('global_announcements').insert(data);
                      
                      // Notify all users
                      final usersRes = await _client.from('profiles').select('id');
                      final db = DatabaseService();
                      for (var user in usersRes) {
                        await db.createNotification(
                          userId: user['id'],
                          title: 'New Announcement: ${data['title']}',
                          body: data['content']?.toString() ?? '',
                          category: 'announcement',
                        );
                      }

                      if (mounted) Navigator.pop(ctx);
                      _loadBroadcasts();
                    } catch (e) {
                      if (e.toString().contains('is_urgent')) {
                         // FALLBACK: Schema sync error, retry without is_urgent
                         data.remove('is_urgent');
                         await _client.from('global_announcements').insert(data);
                         if (mounted) Navigator.pop(ctx);
                         _loadBroadcasts();
                      } else if (mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Assignment Error: $e'), backgroundColor: Colors.red));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isUrgent ? Colors.redAccent : Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: Text(isUrgent ? 'ENGAGE EMERGENCY BROADCAST' : 'DEPLOY BROADCAST', style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modalInput(TextEditingController ctrl, String hint, int lines) {
    return TextField(
      controller: ctrl,
      maxLines: lines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'TRIP BROADCAST CENTER',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: Colors.white,
            letterSpacing: 2.5,
          ),
        ),
        backgroundColor: const Color(0xFFD32F2F),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blueAccent),
            onPressed: _loadBroadcasts,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
        : Column(
            children: [
              _buildHeaderStats(),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _broadcasts.length,
                  itemBuilder: (context, index) => _buildBroadcastItem(_broadcasts[index]),
                ),
              ),
            ],
          ),
      floatingActionButton: FloatingActionButton(
  onPressed: _showCreateModal,
  backgroundColor: Colors.redAccent,
  elevation: 8,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  ),
  child: const Icon(
    Icons.campaign,
    color: Colors.white,
    size: 26,
  ),
),
    );
  }

  Widget _buildHeaderStats() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF111827) : Colors.white,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statMini('TOTAL ISSUED', _broadcasts.length.toString()),
          _statMini('URGENT ITEMS', _broadcasts.where((b) => b.containsKey('is_urgent') && b['is_urgent'] == true).length.toString()),
          _statMini('LAST DEPLOY', _broadcasts.isEmpty ? 'N/A' : DateFormat('dd MMM').format(DateTime.parse(_broadcasts[0]['created_at']))),
        ],
      ),
    );
  }

  Widget _statMini(String label, String val) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(val, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w900, fontSize: 18)),
        Text(label, style: TextStyle(color: isDark ? Colors.white38 : Colors.black45, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildBroadcastItem(dynamic b) {
    final bool isUrgent = b['is_urgent'] ?? false;
    final String date = DateFormat('MMM dd, HH:mm').format(DateTime.parse(b['created_at']));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isUrgent ? Colors.redAccent.withOpacity(0.3) : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isUrgent ? Colors.redAccent.withOpacity(0.1) : Colors.white.withOpacity(0.02),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(isUrgent ? Icons.warning_amber_rounded : Icons.info_outline, color: isUrgent ? Colors.redAccent : Colors.blueAccent, size: 14),
                      const SizedBox(width: 8),
                      Text(isUrgent ? 'URGENT PRIORITY' : 'STANDARD INFO', style: TextStyle(color: isUrgent ? Colors.redAccent : Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ],
                  ),
                  Text(date, style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 9)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b['title'] ?? 'NO SUBJECT', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Text(b['content'] ?? '', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13, height: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                       TextButton.icon(
                         onPressed: () async {
                           await _client.from('global_announcements').delete().eq('id', b['id']);
                           _loadBroadcasts();
                         },
                         icon: Icon(Icons.delete_outline, color: isDark ? Colors.white24 : Colors.black26, size: 16),
                         label: Text('RESCIND', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10, fontWeight: FontWeight.bold)),
                       ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
