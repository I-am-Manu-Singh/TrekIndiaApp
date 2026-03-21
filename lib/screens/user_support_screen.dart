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

class _UserSupportScreenState extends State<UserSupportScreen> {
  final _db = DatabaseService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _inquiries = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _db.fetchMySupportInquiries();
    if (mounted) {
      setState(() {
        _inquiries = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
      appBar: AppBar(
        title: const Text('TREK SUPPORT BRIDGE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 14)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh, size: 20))
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _inquiries.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _inquiries.length,
              itemBuilder: (context, index) {
                final inq = _inquiries[index];
                final bool isResolved = inq['status'] == 'Resolved';
                return FadeInUp(
                  delay: Duration(milliseconds: index * 50),
                  child: Container(
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
                        Text(
                          inq['subject'] ?? 'General Support',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          inq['message'] ?? '',
                          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13),
                        ),
                        if (inq['admin_reply'] != null) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          const Text('COMMAND RESPONSE:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 8, color: Colors.blueAccent)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            width: double.infinity,
                            decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                            child: Text(
                              inq['admin_reply'],
                              style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              onPressed: () => _showFollowUp(inq),
                              icon: const Icon(Icons.reply, size: 16),
                              label: const Text('SUBMIT FOLLOW-UP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                              style: TextButton.styleFrom(foregroundColor: Colors.blueAccent),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('REPLY TO COMMAND', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl, 
              maxLines: 4, 
              style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
              decoration: InputDecoration(hintText: 'Add your follow-up here...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  if (ctrl.text.isEmpty) return;
                  final newMsg = "${q['message']}\n\n[USER FOLLOW-UP]: ${ctrl.text}";
                  await Supabase.instance.client.from('support_inquiries').update({
                    'message': newMsg,
                    'status': 'pending',
                    'updated_at': DateTime.now().toIso8601String(),
                  }).eq('id', q['id']);
                  Navigator.pop(ctx);
                  _loadData();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: const Text('ENGAGE FOLLOW-UP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
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
          Icon(Icons.support_agent, size: 60, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text('NO ACTIVE SUPPORT TICKETS', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Need help? Chat with our AI Guide to escalate a ticket.', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
