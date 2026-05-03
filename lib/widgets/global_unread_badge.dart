import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/preferences_service.dart';

class GlobalUnreadBadge extends StatefulWidget {
  final Widget icon;
  
  const GlobalUnreadBadge({super.key, required this.icon});

  @override
  State<GlobalUnreadBadge> createState() => _GlobalUnreadBadgeState();
}

class _GlobalUnreadBadgeState extends State<GlobalUnreadBadge> {
  final _client = Supabase.instance.client;
  int _totalUnread = 0;
  bool _hasMention = false;
  StreamSubscription? _readSubscription;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _calculateGlobalUnread();
    
    // Listen for local read-receipt updates to decrement counters immediately
    _readSubscription = PreferencesService().readStream.listen((_) {
      _calculateGlobalUnread();
    });

    // Efficiency Hack: Don't listen to ALL messages. 
    // Listen to PreferencesService and poll occasionally or use a more specific stream.
    // However, for immediate feedback on new messages, we need a stream.
    // We'll limit the stream to only triggered updates.
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) => _calculateGlobalUnread());
  }

  @override
  void dispose() {
    _readSubscription?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _calculateGlobalUnread() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final profile = await _client.from('profiles').select('role, full_name').eq('id', user.id).maybeSingle();
      final role = profile?['role'] ?? 'user';
      final fullName = profile?['full_name'] ?? '';
      final firstName = fullName.split(' ').first;

      List<String> roomIds = [];

      if (role == 'admin') {
        final groups = await _client.from('trip_groups').select('id').or('status.neq.completed,status.is.null');
        roomIds = (groups as List).map((g) => g['id'].toString()).toList();
      } else {
        final bookings = await _client.from('bookings').select('group_id, trip_groups(status)').eq('user_id', user.id).not('group_id', 'is', null);
        roomIds = (bookings as List).where((b) {
          final gStatus = b['trip_groups']?['status']?.toString().toLowerCase();
          return gStatus != 'completed';
        }).map((b) => b['group_id'].toString()).toSet().toList();
      }

      if (roomIds.isEmpty) {
        if (mounted) setState(() { _totalUnread = 0; _hasMention = false; });
        return;
      }

      int totalCount = 0;
      bool mentionFound = false;

      // TRIP CRITICAL: Single Batch Intel Retrieval
      final res = await _client
          .from('chat_messages')
          .select('room_id, content, sender_id, created_at')
          .inFilter('room_id', roomIds)
          .neq('sender_id', user.id)
          .order('created_at', ascending: false)
          .limit(100); // Only look at recent 100 messages across all rooms for badges
      
      final allRecentMessages = res as List;
      final lowerUserName = fullName.toLowerCase();
      final lowerFirstName = firstName.toLowerCase();

      for (final roomId in roomIds) {
        final lastRead = await PreferencesService().getLastRead(roomId);
        final unreadList = allRecentMessages.where((m) => 
          m['room_id'].toString() == roomId && 
          DateTime.parse(m['created_at']).isAfter(lastRead)
        ).toList();
        
        totalCount += unreadList.length;

        if (!mentionFound && unreadList.isNotEmpty) {
          for (final m in unreadList) {
            final content = (m['content'] ?? '').toString().toLowerCase();
            if (content.contains('@$lowerUserName') || content.contains('@$lowerFirstName') || content.contains('@all') || (role == 'admin' && content.contains('@admin'))) {
              mentionFound = true;
              break;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _totalUnread = totalCount;
          _hasMention = mentionFound;
        });
      }
    } catch (e) {
      debugPrint('Trip Error calculating global unread: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.icon,
        if (_totalUnread > 0)
          Positioned(
            right: -8,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: _hasMention ? Colors.orange : Colors.red,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_hasMention)
                    const Padding(
                      padding: EdgeInsets.only(right: 2),
                      child: Text('@', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, height: 1)),
                    ),
                  Text(
                    _totalUnread > 99 ? '99+' : '$_totalUnread',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, height: 1),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
