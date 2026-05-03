import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/database_service.dart';

class UserSupportScreen extends StatefulWidget {
  const UserSupportScreen({super.key});

  @override
  State<UserSupportScreen> createState() => _UserSupportScreenState();
}

class _UserSupportScreenState extends State<UserSupportScreen> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  final _db = DatabaseService();
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _inquiries = [];
  List<dynamic> _complaints = [];

  @override
  void initState() {
    super.initState();
    final controller = TabController(length: 2, vsync: this);
    _tabController = controller;
    _loadAllData();
    controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    final inquiriesData = await _db.fetchMySupportInquiries();
    
    final user = _client.auth.currentUser;
    List<dynamic> complaintsData = [];
    if (user != null) {
      try {
        final res = await _client.from('complaints').select().eq('user_id', user.id).order('created_at', ascending: false);
        complaintsData = res;
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _inquiries = inquiriesData;
        _complaints = complaintsData;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
      appBar: AppBar(
        title: const Text('CENTRAL SUPPORT HUB', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
        backgroundColor: const Color(0xFFD32F2F),
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _loadAllData, icon: const Icon(Icons.refresh, size: 20))
        ],
        bottom: _tabController == null ? null : TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1),
          tabs: const [
            Tab(text: 'TICKET BRIDGE'),
            Tab(text: 'SITREPS'),
          ],
        ),
      ),
      body: (_isLoading || _tabController == null)
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: _tabController,
            children: [
              _buildInquiriesList(isDark),
              _buildComplaintsList(isDark),
            ],
          ),
      floatingActionButton: (_tabController == null) ? null : FloatingActionButton.extended(
        onPressed: () {
          if (_tabController!.index == 0) {
            _showNewSupportInquiry();
          } else {
            _showComplaintModal();
          }
        },
        backgroundColor: const Color(0xFFD32F2F),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(_tabController!.index == 0 ? 'NEW TICKET' : 'NEW SITREP', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 10)),
      ),
    );
  }

  Widget _buildInquiriesList(bool isDark) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_inquiries.isEmpty) return _buildEmptyState('NO ACTIVE TICKETS', Icons.support_agent);
    
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _inquiries.length,
      itemBuilder: (context, index) {
        final inq = _inquiries[index];
        final bool isResolved = inq['status'] == 'Resolved';
        return FadeInUp(
          delay: Duration(milliseconds: index * 50),
          child: _buildTicketCard(inq, isResolved, isDark),
        );
      },
    );
  }

  Widget _buildComplaintsList(bool isDark) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_complaints.isEmpty) return _buildEmptyState('NO ACTIVE SITREPS', Icons.report_problem);
    
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _complaints.length,
      itemBuilder: (context, index) {
        final comp = _complaints[index];
        return FadeInUp(
          delay: Duration(milliseconds: index * 50),
          child: _buildComplaintCard(comp, isDark),
        );
      },
    );
  }

  Widget _buildTicketCard(dynamic inq, bool isResolved, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
        border: Border.all(color: (isResolved ? Colors.green : Colors.orange).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isResolved ? Colors.green : Colors.orange).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  inq['status']?.toUpperCase() ?? 'PENDING',
                  style: TextStyle(color: isResolved ? Colors.greenAccent : Colors.orangeAccent, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                DateFormat('MMM dd, HH:mm').format(DateTime.parse(inq['created_at'])),
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(inq['subject'] ?? 'General Support', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 150),
            child: SingleChildScrollView(
              child: Text(inq['message'] ?? '', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13)),
            ),
          ),
          if (inq['admin_reply'] != null) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text('CONTROL RESPONSE:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 8, color: Colors.blueAccent)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                  child: Text(inq['admin_reply'], style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: isDark ? Colors.white70 : Colors.black87)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => _showFollowUp(inq),
                icon: const Icon(Icons.reply, size: 16),
                label: const Text('SUBMIT FOLLOW-UP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComplaintCard(dynamic comp, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                child: Text(comp['type']?.toUpperCase() ?? 'REPORT', style: const TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
              Text(DateFormat('MMM dd, HH:mm').format(DateTime.parse(comp['created_at'])), style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
              child: Text(comp['content'] ?? '', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14)),
            ),
          ),
          if (comp['status'] != null) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text('STATUS: ${comp['status'].toString().toUpperCase()}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          ],
        ],
      ),
    );
  }

  void _showNewSupportInquiry() {
    final subjectCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(30, 30, 30, MediaQuery.of(ctx).viewInsets.bottom + 30),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('NEW SUPPORT TICKET', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            const SizedBox(height: 20),
            TextField(controller: subjectCtrl, decoration: InputDecoration(hintText: 'Subject', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
            const SizedBox(height: 12),
            TextField(controller: messageCtrl, maxLines: 5, decoration: InputDecoration(hintText: 'Describe your issue...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                   final user = _client.auth.currentUser;
                   if (user == null || subjectCtrl.text.isEmpty) return;
                   await _client.from('support_inquiries').insert({
                     'user_id': user.id,
                     'subject': subjectCtrl.text,
                     'message': messageCtrl.text,
                   });
                   Navigator.pop(ctx);
                   _loadAllData();
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: const Text('SUBMIT TICKET', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComplaintModal() {
    final contentCtrl = TextEditingController();
    String selectedType = 'Service Issue';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(30, 30, 30, MediaQuery.of(ctx).viewInsets.bottom + 30),
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('NEW SITUATION REPORT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selectedType,
                items: ['Service Issue', 'Medical Alert', 'Logistics Gap', 'Emergency Support'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setModalState(() => selectedType = v!),
                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
              ),
              const SizedBox(height: 12),
              TextField(controller: contentCtrl, maxLines: 5, decoration: InputDecoration(hintText: 'Describe the situation...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    final user = _client.auth.currentUser;
                    if (user == null || contentCtrl.text.isEmpty) return;
                    await _client.from('complaints').insert({
                      'user_id': user.id,
                      'type': selectedType,
                      'content': contentCtrl.text,
                    });
                    Navigator.pop(ctx);
                    _loadAllData();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  child: const Text('SUBMIT REPORT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFollowUp(dynamic q) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(30, 30, 30, MediaQuery.of(ctx).viewInsets.bottom + 30),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('FOLLOW-UP', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 16),
            TextField(controller: ctrl, maxLines: 3, decoration: InputDecoration(hintText: 'Message...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                   if (ctrl.text.isEmpty) return;
                   final newMsg = "${q['message']}\n\n[FOLLOW-UP]: ${ctrl.text}";
                   await _client.from('support_inquiries').update({'message': newMsg, 'status': 'pending'}).eq('id', q['id']);
                   Navigator.pop(ctx);
                   _loadAllData();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                child: const Text('SUBMIT', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.grey.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(msg, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
