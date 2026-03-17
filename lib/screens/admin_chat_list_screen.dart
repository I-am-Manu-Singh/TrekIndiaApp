import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_screen.dart';
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
      // Find all unique developers/users who sent a message. Using a distinct select on messages
      final response = await Supabase.instance.client
          .from('messages')
          .select('room_id, profiles(full_name)')
          .order('created_at', ascending: false);

      if (mounted) {
        // We will just unique them in dart
        final Set<String> roomIds = {};
        final List<Map<String, dynamic>> uniqueRooms = [];

        for (var msg in response) {
          final roomId = msg['room_id'] as String;
          if (!roomIds.contains(roomId)) {
            roomIds.add(roomId);
            uniqueRooms.add({
              'room_id': roomId,
              'name': msg['profiles'] != null ? msg['profiles']['full_name'] : 'Customer $roomId',
            });
          }
        }

        setState(() {
          _rooms = uniqueRooms;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print('Error fetching rooms: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Support Chats', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
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
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                      child: Icon(Icons.person, color: Theme.of(context).primaryColor),
                    ),
                    title: Text(room['name'] ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Tap to view messages'),
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
