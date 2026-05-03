import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/preferences_service.dart';

class UnreadBadge extends StatefulWidget {
  final String roomId;
  
  const UnreadBadge({super.key, required this.roomId});

  @override
  State<UnreadBadge> createState() => _UnreadBadgeState();
}

class _UnreadBadgeState extends State<UnreadBadge> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  
  DateTime? _lastRead;
  Stream<List<Map<String, dynamic>>>? _messageStream;
  StreamSubscription? _readSubscription;

  @override
  void initState() {
    super.initState();
    _fetchLastRead();
    // Trip subscription to global read receipts
    _readSubscription = PreferencesService().readStream.listen((roomId) {
      if (roomId == widget.roomId) {
        _fetchLastRead();
      }
    });
  }

  @override
  void dispose() {
    _readSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchLastRead() async {
    final lr = await PreferencesService().getLastRead(widget.roomId);
    if (!mounted) return;
    
    // Fetch user profile for accurate mention detection
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && _userName == null) {
      final profile = await Supabase.instance.client.from('profiles').select('full_name').eq('id', user.id).maybeSingle();
      if (mounted) _userName = profile?['full_name'];
    }

    setState(() {
      _lastRead = lr;
      _messageStream = Supabase.instance.client
          .from('chat_messages')
          .stream(primaryKey: ['id'])
          .eq('room_id', widget.roomId);
    });
  }
  String? _userName;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_messageStream == null) return const SizedBox.shrink();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _messageStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
        
        final currentUserId = Supabase.instance.client.auth.currentUser?.id;
        
        // Count unread messages (newer than lastRead and not sent by current user)
        int unreadCount = 0;
        bool hasMention = false;
        final user = Supabase.instance.client.auth.currentUser;
        final fullName = _userName ?? user?.userMetadata?['full_name'] ?? '';
        final firstName = fullName.contains(' ') ? fullName.split(' ').first : fullName;

        final lowerUserName = fullName.toLowerCase();
        final lowerFirstName = firstName.toLowerCase();

        for (var msg in snapshot.data!) {
          final createdAt = DateTime.parse(msg['created_at']);
          if (createdAt.isAfter(_lastRead ?? DateTime.fromMillisecondsSinceEpoch(0)) && msg['sender_id'] != currentUserId) {
            unreadCount++;
            final content = (msg['content'] ?? '').toString().toLowerCase();
            
            // Trip Mention Detection: Case-insensitive check
            bool isMe = (lowerUserName.isNotEmpty && content.contains('@$lowerUserName')) || 
                        (lowerFirstName.isNotEmpty && content.contains('@$lowerFirstName')) ||
                        content.contains('@all');
            
            if (isMe) hasMention = true;
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
