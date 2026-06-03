import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';

class AdminComplaintsScreen extends StatefulWidget {
  const AdminComplaintsScreen({super.key});

  @override
  State<AdminComplaintsScreen> createState() => _AdminComplaintsScreenState();
}

class _AdminComplaintsScreenState extends State<AdminComplaintsScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _complaints = [];

  @override
  void initState() {
    super.initState();
    _fetchComplaints();
  }

  Future<void> _fetchComplaints() async {
    setState(() => _isLoading = true);
    try {
      final res = await _client.from('complaints').select('*, profiles(id, full_name, avatar_url, role)').order('created_at', ascending: false);
      if (mounted) setState(() { _complaints = res; _isLoading = false; });
    } catch (e) {
      debugPrint('ADMIN COMPLAINTS FETCH ERROR: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('ADMIN COMPLAINTS MANAGEMENT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        backgroundColor: const Color(0xFFD32F2F),
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildTopStats(),
              const SizedBox(height: 32),
              const Text('PRIORITY BACKLOG', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
              const SizedBox(height: 16),
              ..._complaints.map((c) => _buildComplaintCard(c)).toList(),
            ],
          ),
    );
  }

  Widget _buildTopStats() {
    final unresolved = _complaints.where((c) => c['status'] != 'resolved').length;
    final resolved = _complaints.where((c) => c['status'] == 'resolved').length;
    final serviceIssues = _complaints.where((c) => (c['type'] ?? 'service').toString().toLowerCase().contains('service')).length;
    final gearIssues = _complaints.where((c) => (c['type'] ?? '').toString().toLowerCase().contains('gear')).length;

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: [
        _statMiniCard('$unresolved', 'PENDING ACTIONS', Icons.warning_amber_outlined, Colors.orange),
        _statMiniCard('$resolved', 'RESOLVED CASES', Icons.check_circle_outlined, Colors.green),
        _statMiniCard('$serviceIssues', 'SERVICE REPORTS', Icons.assignment_outlined, Colors.blue),
        _statMiniCard('$gearIssues', 'GEAR ALERTS', Icons.shopping_bag_outlined, Colors.brown),
        _statMiniCard('0', 'GUIDE REVIEWS', Icons.badge_outlined, Colors.purple),
        _statMiniCard('${_complaints.length}', 'TOTAL LOGS', Icons.analytics_outlined, Colors.teal),
      ],
    );
  }

  Widget _statMiniCard(String val, String label, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withOpacity(0.1))),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color.withOpacity(0.6), size: 16),
          const SizedBox(height: 4),
          Text(val, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isDark ? Colors.white : Colors.black87)),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildComplaintCard(dynamic c) {
    final bool isResolved = c['status'] == 'resolved';
    final profile = c['profiles'];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.02), blurRadius: 10)],
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18, 
                backgroundColor: const Color(0xFFC8E6C9),
                backgroundImage: (profile?['avatar_url'] != null && profile['avatar_url'].toString().isNotEmpty && profile['avatar_url'].toString() != 'null') ? NetworkImage(profile['avatar_url']) : null,
                child: (profile?['avatar_url'] == null || profile['avatar_url'].toString().isEmpty || profile['avatar_url'].toString() == 'null') ? Text(profile?['full_name'] != null && profile['full_name'].toString().trim().isNotEmpty ? profile['full_name'].toString().trim()[0].toUpperCase() : 'T', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2E7B32))) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile?['full_name'] ?? 'Trip', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                    Text(DateFormat('MMM dd, yyyy • HH:mm').format(DateTime.parse(c['created_at'])), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: (isResolved ? Colors.green : Colors.orange).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Text(isResolved ? 'RESOLVED' : 'UNRESOLVED', style: TextStyle(color: isResolved ? Colors.green : Colors.orange, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
            child: Text(c['type']?.toUpperCase() ?? 'SERVICE ISSUE', style: const TextStyle(color: Colors.blue, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
          const SizedBox(height: 12),
          Text('NEW REPORT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 150),
            child: SingleChildScrollView(
              child: Text(c['content'] ?? '', style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87, height: 1.5)),
            ),
          ),
          const SizedBox(height: 24),
          if (c['admin_reply'] != null) 
            _replyBox(c['admin_reply'])
          else
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                onPressed: () => _showResponseModal(c),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                child: const Text('TAKE ACTION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _replyBox(String reply) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ADMIN RESPONSE:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 8, color: Colors.grey, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(reply, style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: isDark ? Colors.white70 : Colors.black87)),
        ],
      ),
    );
  }

  void _showResponseModal(dynamic c) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('OFFICIAL RESPONSE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Enter your response...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.bold))),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.isEmpty) return;
              await _client.from('complaints').update({'admin_reply': ctrl.text, 'status': 'resolved'}).eq('id', c['id']);
              
              // Notify User
              final db = DatabaseService();
              await db.createNotification(
                userId: c['user_id'],
                title: 'Complaint Resolved',
                body: 'TREKWITHMUSSAFIRR has addressed your report: "${c['type']}". Check details in support.',
                category: 'support',
              );

              Navigator.pop(ctx);
              _fetchComplaints();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('SUBMIT RESPONSE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
