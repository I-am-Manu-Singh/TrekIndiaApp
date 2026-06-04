import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';

class AdminSupportInquiriesScreen extends StatefulWidget {
  const AdminSupportInquiriesScreen({super.key});

  @override
  State<AdminSupportInquiriesScreen> createState() => _AdminSupportInquiriesScreenState();
}

class _AdminSupportInquiriesScreenState extends State<AdminSupportInquiriesScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _inquiries = [];
  List<dynamic> _complaints = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final iRes = await _client.from('support_inquiries').select('*, profiles(id, full_name, avatar_url, role)').order('created_at', ascending: false);
      final cRes = await _client.from('complaints').select('*, profiles(id, full_name, avatar_url, role)').order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _inquiries = iRes;
          _complaints = cRes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        debugPrint('trekwithmussafirr SUPPORT ERROR: $e');
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('UNABLE TO SYNC SUPPORT DATA: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          )
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('SUPPORT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white, letterSpacing: 2)),
          backgroundColor: const Color(0xFFD32F2F),
          elevation: 0,
          actions: [
            IconButton(icon: const Icon(Icons.refresh, color: Colors.blueAccent), onPressed: _loadData),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'ENQUIRIES'),
              Tab(text: 'COMPLAINTS'),
            ],
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1, color: Colors.blueAccent),
          ),
        ),
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : TabBarView(
              children: [
                _buildInquiryView(),
                _buildComplaintView(),
              ],
            ),
      ),
    );
  }

  Widget _buildInquiryView() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildEnquiryAnalytics(),
            const SizedBox(height: 32),
            const Text('TECHNICAL INQUIRIES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
            const SizedBox(height: 16),
            if (_inquiries.isEmpty) _emptyState('NO ACTIVE ENQUIRIES')
            else ..._inquiries.map((q) => _buildEnquiryCard(q)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildComplaintView() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildComplaintAnalytics(),
            const SizedBox(height: 32),
            const Text('FIELD COMPLAINTS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
            const SizedBox(height: 16),
            if (_complaints.isEmpty) _emptyState('NO ACTIVE COMPLAINTS')
            else ..._complaints.map((c) => _buildComplaintCard(c)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildEnquiryAnalytics() {
    final pending = _inquiries.where((i) => i['status']?.toString().toLowerCase() != 'resolved').length;
    final resolved = _inquiries.length - pending;
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: [
        _statCard('$pending', 'AWAITING RESPONSE', Icons.mark_email_unread_outlined, Colors.orange),
        _statCard('$resolved', 'INQUIRIES RESOLVED', Icons.verified_outlined, Colors.green),
        _statCard('${_inquiries.length}', 'TOTAL ENQUIRIES', Icons.analytics_outlined, Colors.blue),
      ],
    );
  }

  Widget _buildComplaintAnalytics() {
    final unresolved = _complaints.where((c) => c['status']?.toString().toLowerCase() != 'resolved').length;
    final resolved = _complaints.length - unresolved;
    final gearIssues = _complaints.where((c) => (c['type'] ?? '').toString().toLowerCase().contains('gear')).length;
    final serviceIssues = _complaints.where((c) => (c['type'] ?? '').toString().toLowerCase().contains('service')).length;
    
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.1,
      children: [
        _statCard('$unresolved', 'PENDING ACTION', Icons.warning_amber_outlined, Colors.red),
        _statCard('$resolved', 'RESOLVED CASES', Icons.check_circle_outlined, Colors.green),
        _statCard('$gearIssues', 'GEAR FAILURES', Icons.shopping_bag_outlined, Colors.orange),
        _statCard('$serviceIssues', 'SERVICE REPORTS', Icons.assignment_outlined, Colors.blue),
        _statCard('${_complaints.length}', 'TOTAL REPORTS', Icons.analytics_outlined, Colors.teal),
        _statCard('${(resolved / (_complaints.isEmpty ? 1 : _complaints.length) * 100).toInt()}%', 'SUCCESS RATE', Icons.speed_outlined, Colors.indigo),
      ],
    );
  }

  Widget _statCard(String val, String label, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withOpacity(0.1))),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(val, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isDark ? Colors.white : Colors.black87)),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 7, color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _emptyState(String text) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 50),
          Icon(Icons.mark_email_read_outlined, size: 48, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text(text, style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildEnquiryCard(dynamic q) {
    final profile = q['profiles'];
    final bool isResolved = q['status']?.toString().toLowerCase() == 'resolved';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: Colors.blue.withOpacity(0.2), child: Text(profile?['full_name']?[0]?.toUpperCase() ?? 'U', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile?['full_name'] ?? 'Trip', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                    Text(DateFormat('MMM dd, HH:mm').format(DateTime.parse(q['created_at'])), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
              _statusBadge(isResolved),
            ],
          ),
          const SizedBox(height: 16),
          Text(q['subject'] ?? 'INQUIRY', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 120),
            child: SingleChildScrollView(
              child: Text(q['message'] ?? '', style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
            ),
          ),
          const SizedBox(height: 24),
          if (isResolved)
            _replyBox(q['admin_reply'] ?? 'Resolved.')
          else
            SizedBox(
              width: double.infinity, height: 45,
              child: ElevatedButton(
                onPressed: () => _resolveEnquiry(q),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('ADD RESPONSE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildComplaintCard(dynamic c) {
    final profile = c['profiles'];
    final bool isResolved = c['status']?.toString().toLowerCase() == 'resolved';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: Colors.red.withOpacity(0.2), child: Text(profile?['full_name']?[0]?.toUpperCase() ?? 'U', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile?['full_name'] ?? 'Trip', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                    Text(DateFormat('MMM dd, HH:mm').format(DateTime.parse(c['created_at'])), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
              _statusBadge(isResolved),
            ],
          ),
          const SizedBox(height: 16),
          Container(
             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
             decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
             child: Text(c['type']?.toUpperCase() ?? 'FIELD ISSUE', style: const TextStyle(color: Colors.red, fontSize: 8, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 150),
            child: SingleChildScrollView(
              child: Text(c['content'] ?? '', style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
            ),
          ),
          const SizedBox(height: 24),
          if (isResolved)
            _replyBox(c['admin_reply'] ?? 'Field issue resolved.')
          else
            SizedBox(
              width: double.infinity, height: 45,
              child: ElevatedButton(
                onPressed: () => _resolveComplaint(c),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('RESOLVE ISSUE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusBadge(bool resolved) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: (resolved ? Colors.green : Colors.orange).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(resolved ? 'CLOSED' : 'OPEN', style: TextStyle(color: resolved ? Colors.green : Colors.orange, fontSize: 8, fontWeight: FontWeight.bold)),
    );
  }

  Widget _replyBox(String reply) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ADMIN RESPONSE:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8, color: Colors.grey)),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 100),
            child: SingleChildScrollView(
              child: Text(reply, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
            ),
          ),
        ],
      ),
    );
  }

  void _resolveEnquiry(dynamic q) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
         final isDark = Theme.of(context).brightness == Brightness.dark;
         return Container(
           padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
           decoration: BoxDecoration(color: isDark ? const Color(0xFF18181B) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
           child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
                const Text('ADD RESPONSE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                const SizedBox(height: 20),
                TextField(controller: ctrl, maxLines: 4, decoration: const InputDecoration(hintText: 'Enter formal response...', border: OutlineInputBorder())),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
                  onPressed: () async {
                    await _client.from('support_inquiries').update({'admin_reply': ctrl.text, 'status': 'Resolved'}).eq('id', q['id']);
                    
                    final db = DatabaseService();
                    await db.createNotification(
                      userId: q['user_id'],
                      title: 'Support Response Received',
                      body: 'An admin has replied to your inquiry: "${q['subject']}"',
                      category: 'support',
                    );

                    Navigator.pop(ctx);
                    _loadData();
                  },
                  child: const Text('SEND RESPONSE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                )),
                const SizedBox(height: 30),
             ],
           ),
         );
      }
    );
  }

  void _resolveComplaint(dynamic c) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
         final isDark = Theme.of(context).brightness == Brightness.dark;
         return Container(
           padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
           decoration: BoxDecoration(color: isDark ? const Color(0xFF18181B) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
           child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
                const Text('FIELD ISSUE RESOLUTION', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                const SizedBox(height: 20),
                TextField(controller: ctrl, maxLines: 4, decoration: const InputDecoration(hintText: 'Enter resolution details...', border: OutlineInputBorder())),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
                  onPressed: () async {
                    await _client.from('complaints').update({'admin_reply': ctrl.text, 'status': 'resolved'}).eq('id', c['id']);
                    
                    final db = DatabaseService();
                    await db.createNotification(
                      userId: c['user_id'],
                      title: 'Complaint Resolved',
                      body: 'Your field complaint has been addressed and resolved.',
                      category: 'support',
                    );

                    Navigator.pop(ctx);
                    _loadData();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  child: const Text('SUBMIT RESOLUTION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )),
                const SizedBox(height: 30),
             ],
           ),
         );
      }
    );
  }
}
