import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';
import 'admin_support_inquiries_screen.dart';
import '../widgets/unread_badge.dart';

class AdminChatListScreen extends StatefulWidget {
  const AdminChatListScreen({super.key});

  @override
  State<AdminChatListScreen> createState() => _AdminChatListScreenState();
}

class _AdminChatListScreenState extends State<AdminChatListScreen> {
  List<Map<String, dynamic>> _rooms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchChatRooms();
  }

  Future<void> _fetchChatRooms() async {
    try {
      final response = await Supabase.instance.client
          .from('messages')
          .select('room_id, content, created_at, profiles(full_name)')
          .order('created_at', ascending: false);

      if (mounted) {
        final Set<String> roomIds = {};
        final List<Map<String, dynamic>> uniqueRooms = [];

        for (var msg in response) {
          final roomId = msg['room_id'] as String;
          if (!roomIds.contains(roomId)) {
            roomIds.add(roomId);

            // Fetch group info for date
            final groupInfo = await Supabase.instance.client
                .from('trip_groups')
                .select('departure_date, group_name')
                .eq('id', roomId)
                .maybeSingle();

            uniqueRooms.add({
              'room_id': roomId,
              'name': groupInfo?['group_name'] ?? (msg['profiles'] != null ? msg['profiles']['full_name'] : 'Customer $roomId'),
              'date': groupInfo?['departure_date'],
              'message': msg['content'],
              'sender': msg['profiles']?['full_name'],
              'created_at': msg['created_at'],
            });
          }
        }

        setState(() {
          _rooms = uniqueRooms;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TRIP INDIA SUPPORT CHATS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13, color: Colors.white)),
        backgroundColor: const Color(0xFFD32F2F),
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminSupportInquiriesScreen())),
        backgroundColor: const Color(0xFFD32F2F),
        icon: const Icon(Icons.support_agent, color: Colors.white),
        label: const Text('TRIP INDIA SUPPORT REGISTRY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : _rooms.isEmpty
          ? const Center(child: Text('No active chats'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _rooms.length,
              itemBuilder: (context, index) {
                final room = _rooms[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      width: 50, height: 50,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                            child: Icon(Icons.person, color: Theme.of(context).primaryColor),
                          ),
                          if (room['date'] != null)
                            Positioned(
                              bottom: 0, right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                                child: Text(
                                  DateFormat('MMM dd').format(DateTime.parse(room['date'])),
                                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    title: Text(room['name'] ?? 'Customer', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(room['date'] != null ? 'Departure: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(room['date']))}' : 'No trip date', style: const TextStyle(fontSize: 11)),
                        const SizedBox(height: 4),
                        Text('Recent Intel: ${room['message'] ?? "No messages"}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        UnreadBadge(key: UniqueKey(), roomId: room['room_id']),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            roomId: room['room_id'],
                            title: room['name'] ?? 'Customer Chat',
                          ),
                        ),
                      );
                      if (mounted) setState(() {});
                    },
                  ),
                );
              },
            ),
    );
  }
}
