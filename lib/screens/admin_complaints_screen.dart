import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import '../widgets/user_avatar.dart';

class AdminComplaintsScreen extends StatefulWidget {
  final bool showAppBar;
  const AdminComplaintsScreen({super.key, this.showAppBar = false});

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
      final response = await _client
          .from('complaints')
          .select('*, profiles(full_name, avatar_url, email)')
          .order('created_at', ascending: false);
      if (mounted) setState(() { _complaints = response; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resolveComplaint(String id, String reply) async {
    try {
      await _client.from('complaints').update({
        'status': 'resolved',
        'admin_reply': reply,
      }).eq('id', id);
      _fetchComplaints();
    } catch (_) {}
  }

  void _showReplyDialog(String id) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('OFFICIAL RESPONSE'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Enter your response...', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.isEmpty) return;
              _resolveComplaint(id, ctrl.text);
              Navigator.pop(c);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
            child: const Text('SUBMIT RESPONSE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: widget.showAppBar ? AppBar(
        title: const Text('COMPLAINTS CENTER', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 14)),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ) : null,
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _complaints.isEmpty 
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text('No complaints filed', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
            ]))
          : RefreshIndicator(
              onRefresh: _fetchComplaints,
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _complaints.length,
                itemBuilder: (context, index) {
                  final c = _complaints[index];
                  final isResolved = c['status'] == 'resolved';
                  final statusColor = isResolved ? Colors.green : Colors.orange;
                  
                  return FadeInUp(
                    delay: Duration(milliseconds: index * 50),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.2)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              UserAvatar(imageUrl: c['profiles']?['avatar_url'], name: c['profiles']?['full_name'], radius: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c['profiles']?['full_name'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text(c['profiles']?['email'] ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                child: Text(c['status'].toString().toUpperCase(), style: TextStyle(color: statusColor, fontSize: 8, fontWeight: FontWeight.w900)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (c['type'] != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                              child: Text(c['type']?.toUpperCase() ?? '', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                            ),
                          Text(c['content'] ?? '', style: const TextStyle(fontSize: 14, height: 1.5)),
                          const SizedBox(height: 8),
                          Text(DateFormat('MMM dd, yyyy • HH:mm').format(DateTime.parse(c['created_at']).toLocal()), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          const SizedBox(height: 16),
                          if (!isResolved)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _showReplyDialog(c['id']),
                                icon: const Icon(Icons.reply, size: 16),
                                label: const Text('RESPOND & RESOLVE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).primaryColor, 
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          if (c['admin_reply'] != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              width: double.infinity,
                              decoration: BoxDecoration(color: Colors.green.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('ADMIN RESPONSE:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 8, color: Colors.green, letterSpacing: 1)),
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
            ),
    );
  }
}
