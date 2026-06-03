import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';

class UserComplaintsScreen extends StatefulWidget {
  const UserComplaintsScreen({super.key});

  @override
  State<UserComplaintsScreen> createState() => _UserComplaintsScreenState();
}

class _UserComplaintsScreenState extends State<UserComplaintsScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _complaints = [];

  @override
  void initState() {
    super.initState();
    _fetchMyComplaints();
  }

  Future<void> _fetchMyComplaints() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    setState(() => _isLoading = true);
    try {
      final res = await _client.from('complaints').select().eq('user_id', user.id).order('created_at', ascending: false);
      if (mounted) setState(() { _complaints = res; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showComplaintModal() {
    final contentCtrl = TextEditingController();
    String selectedType = 'Service Issue';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(30, 30, 30, MediaQuery.of(ctx).viewInsets.bottom + 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('NEW INFO REPORT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
            const SizedBox(height: 24),
            const Text('REPORT CLASSIFICATION', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedType,
              items: ['Service Issue', 'Medical Alert', 'Logistics Gap', 'Emergency Support'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)))).toList(),
              onChanged: (v) => selectedType = v!,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
              ),
            ),
            const SizedBox(height: 24),
            const Text('INFO DETAILS', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            TextField(
              controller: contentCtrl,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Describe the situation for TREKWITHMUSSAFIRR attention...',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () async {
                  if (contentCtrl.text.isEmpty) return;
                  final user = _client.auth.currentUser;
                  if (user == null) return;

                  await _client.from('complaints').insert({
                    'user_id': user.id,
                    'type': selectedType,
                    'content': contentCtrl.text,
                    'created_at': DateTime.now().toIso8601String(),
                  });

                  // Notify Admins
                  try {
                    final admins = await _client.from('profiles').select('id').eq('role', 'admin');
                    final db = DatabaseService();
                    for (var admin in admins) {
                      await db.createNotification(
                        userId: admin['id'],
                        title: 'New Complaint/Report',
                        body: '${user.userMetadata?['full_name'] ?? 'A traveler'} submitted a $selectedType.',
                        category: 'support',
                      );
                    }
                  } catch (e) {
                    debugPrint('Admin notify error: $e');
                  }

                  if (mounted) {
                    Navigator.pop(ctx);
                    _fetchMyComplaints();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted to TREKWITHMUSSAFIRR.')));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 0),
                child: const Text('TRANSMIT TO TREKWITHMUSSAFIRR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('USER COMPLAINTS & REPORTS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        backgroundColor: const Color(0xFFD32F2F),
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _complaints.length,
            itemBuilder: (context, index) {
              final c = _complaints[index];
              return _buildComplaintCard(c);
            },
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showComplaintModal,
        backgroundColor: Colors.black,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('NEW REPORT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildComplaintCard(dynamic c) {
    final bool isResolved = c['status'] == 'resolved' || c['status'] == 'Resolved';
    final date = DateFormat('MMM dd, yyyy').format(DateTime.parse(c['created_at']));

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(c['type']?.toUpperCase() ?? 'SERVICE ISSUE', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Color(0xFF1976D2), letterSpacing: 1.2)),
              Text(date, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 16),
          Text(c['type']?.toUpperCase() ?? 'SITUATION REPORT', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black87)),
          const SizedBox(height: 12),
          Text(c['content'] ?? '', style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.black)),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(isResolved ? Icons.check_circle : Icons.radio_button_unchecked, color: const Color(0xFF2E7B32), size: 16),
              const SizedBox(width: 8),
              Text(isResolved ? 'RESOLVED / COMPLETED' : 'IN REVIEW', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: const Color(0xFF2E7B32))),
            ],
          ),
          if (c['admin_reply'] != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CONTROL RESPONSE:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 8, color: Color(0xFF1976D2), letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(c['admin_reply'], style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.black87)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
