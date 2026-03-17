import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';

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

  Future<void> _fileComplaint() async {
    final contentCtrl = TextEditingController();
    String type = 'Gear Issue';
    final types = ['Gear Issue', 'Guide Issue', 'Payment Issue', 'Service Issue', 'Safety Concern', 'Other'];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(c).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('FILE A REPORT', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              value: type,
              decoration: InputDecoration(labelText: 'CATEGORY', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
              items: types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => type = v!,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: contentCtrl,
              maxLines: 5,
              decoration: InputDecoration(hintText: 'Describe the issue in detail...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                if (contentCtrl.text.isEmpty) return;
                final user = _client.auth.currentUser;
                try {
                  await _client.from('complaints').insert({
                    'user_id': user?.id,
                    'type': type,
                    'content': contentCtrl.text,
                    'status': 'unresolved',
                  });
                  if (mounted) Navigator.pop(c);
                  _fetchMyComplaints();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report filed successfully. Command will review soon.')));
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              child: const Text('SUBMIT REPORT', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('MISSION DEBRIEF & REPORTS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.5)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _complaints.length,
            itemBuilder: (context, index) {
              final c = _complaints[index];
              final isResolved = c['status'] == 'resolved';
              return FadeInUp(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
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
                          Text(c['type']?.toUpperCase() ?? 'REPORT', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1, color: Colors.blueAccent)),
                          Text(DateFormat('MMM dd, yyyy').format(DateTime.parse(c['created_at'])), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(c['content'] ?? '', style: const TextStyle(fontSize: 14, height: 1.5)),
                      const Divider(height: 30),
                      Row(
                        children: [
                          Icon(isResolved ? Icons.check_circle : Icons.pending, color: isResolved ? Colors.green : Colors.orange, size: 16),
                          const SizedBox(width: 8),
                          Text(isResolved ? 'RESOLVED' : 'IN REVIEW', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: isResolved ? Colors.green : Colors.orange)),
                        ],
                      ),
                      if (c['admin_reply'] != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          width: double.infinity,
                          decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('COMMAND RESPONSE:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 8, color: Colors.blueAccent)),
                              const SizedBox(height: 4),
                              Text(c['admin_reply'], style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _fileComplaint,
        backgroundColor: Colors.black,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('NEW REPORT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
