import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/preferences_service.dart';

class UnreadBadge extends StatefulWidget {
  final String roomId;
  
  const UnreadBadge({super.key, required this.roomId});

  @override
  State<UnreadBadge> createState() => _UnreadBadgeState();
}

class _UnreadBadgeState extends State<UnreadBadge> {
  DateTime? _lastRead;
  Stream<List<Map<String, dynamic>>>? _messageStream;

  @override
  void initState() {
    super.initState();
    _fetchLastRead();
  }

  Future<void> _fetchLastRead() async {
    final lr = await PreferencesService().getLastRead(widget.roomId);
    if (!mounted) return;
    
    setState(() {
      _lastRead = lr;
      // Filter stream at query level to minimize data transfer
      _messageStream = Supabase.instance.client
          .from('messages')
          .stream(primaryKey: ['id'])
          .eq('room_id', widget.roomId);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_messageStream == null) return const SizedBox.shrink();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _messageStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
        
        final currentUserId = Supabase.instance.client.auth.currentUser?.id;
        
        // Count unread messages (newer than lastRead and not sent by current user)
        int unreadCount = 0;
        bool hasMention = false;
        final userName = Supabase.instance.client.auth.currentUser?.userMetadata?['full_name'] ?? '';

        for (var msg in snapshot.data!) {
          final createdAt = DateTime.parse(msg['created_at']);
          if (createdAt.isAfter(_lastRead!) && msg['sender_id'] != currentUserId) {
            unreadCount++;
            final content = msg['content']?.toString() ?? '';
            final firstName = userName.split(' ')[0];
            if (content.contains('@$userName') || content.contains('@$firstName')) {
              hasMention = true;
            }
          }
        }

        if (unreadCount == 0) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: hasMention ? Colors.orange : Colors.redAccent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasMention) ...[
                const Text('@', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, height: 1)),
                const SizedBox(width: 2),
              ],
              Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, height: 1),
              ),
            ],
          ),
        );
      },
    );
  }
}
