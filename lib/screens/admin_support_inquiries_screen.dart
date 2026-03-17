import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../services/database_service.dart';
import 'package:intl/intl.dart';
import '../widgets/user_avatar.dart';

class AdminSupportInquiriesScreen extends StatefulWidget {
  const AdminSupportInquiriesScreen({super.key});

  @override
  State<AdminSupportInquiriesScreen> createState() => _AdminSupportInquiriesScreenState();
}

class _AdminSupportInquiriesScreenState extends State<AdminSupportInquiriesScreen> {
  final _db = DatabaseService();
  List<Map<String, dynamic>> _inquiries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInquiries();
  }

  Future<void> _loadInquiries() async {
    final inquiries = await _db.fetchSupportInquiries();
    if (mounted) {
      setState(() {
        _inquiries = inquiries;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('MISSION SUPPORT BRIDGE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 16)),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orangeAccent))
          : RefreshIndicator(
              onRefresh: _loadInquiries,
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _inquiries.length,
                itemBuilder: (context, index) {
                  final inquiry = _inquiries[index];
                  return _inquiryCard(inquiry);
                },
              ),
            ),
    );
  }

  Widget _inquiryCard(Map<String, dynamic> inquiry) {
    final bool isResolved = inquiry['status'] == 'Resolved';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10)],
          border: Border.all(color: isResolved ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.all(20),
              leading: UserAvatar(
                imageUrl: inquiry['profiles']?['avatar_url'],
                name: inquiry['profiles']?['full_name'] ?? 'Expeditioner',
                radius: 25,
              ),
              title: Text(
                inquiry['subject'] ?? 'General Inquiry',
                style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    '${inquiry['profiles']?['full_name'] ?? 'Personnel'} • ${DateFormat('MMM dd, HH:mm').format(DateTime.parse(inquiry['created_at']))}',
                    style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isResolved ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      inquiry['status'].toString().toUpperCase(),
                      style: TextStyle(
                        color: isResolved ? Colors.greenAccent : Colors.orangeAccent,
                        fontSize: 9, 
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    const Text('TACTICAL SITUATION:', style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    Text(inquiry['message'] ?? '', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13)),
                    if (inquiry['ai_context'] != null) ...[
                      const SizedBox(height: 16),
                      const Text('AI COMMS LOG:', style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        width: double.infinity,
                        decoration: BoxDecoration(color: (isDark ? Colors.black : Colors.grey).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: Text(inquiry['ai_context'], style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 11, fontStyle: FontStyle.italic)),
                      ),
                    ],
                  if (inquiry['admin_reply'] != null) ...[
                    const SizedBox(height: 16),
                    const Text('COMMAND RESPONSE:', style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    Text(inquiry['admin_reply'], style: const TextStyle(color: Colors.greenAccent, fontSize: 13)),
                  ],
                  const SizedBox(height: 24),
                  if (!isResolved)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _respondDialog(inquiry['id']),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orangeAccent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: const Text('ENGAGE & RESOLVE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _respondDialog(String id) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('TRANSMIT RESPONSE', style: TextStyle(color: Theme.of(context).textTheme.titleLarge?.color, fontWeight: FontWeight.w900, letterSpacing: 1)),
        content: TextField(
          controller: controller,
          maxLines: 4,
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
          decoration: const InputDecoration(
            hintText: 'Enter mission outcome or response...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('CANCEL', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isEmpty) return;
              await _db.respondToInquiry(id, controller.text);
              Navigator.pop(c);
              _loadInquiries();
            },
            child: const Text('SEND'),
          ),
        ],
      ),
    );
  }
}
