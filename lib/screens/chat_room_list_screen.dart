import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'chat_screen.dart';
import '../widgets/unread_badge.dart';

class ChatRoomListScreen extends StatefulWidget {
  const ChatRoomListScreen({super.key});

  @override
  State<ChatRoomListScreen> createState() => _ChatRoomListScreenState();
}

class _ChatRoomListScreenState extends State<ChatRoomListScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _rooms = [];
  List<dynamic> _broadcasts = [];
  String _role = 'user';

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _fetchUserRole();
    await _fetchRooms();
  }

  Future<void> _fetchUserRole() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      final profile = await _client.from('profiles').select('role').eq('id', user.id).maybeSingle();
      if (profile != null && mounted) {
        setState(() => _role = profile['role'] ?? 'user');
      }
    } catch (_) {}
  }

  Future<void> _fetchRooms() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      dynamic response;
      if (_role == 'admin') {
        // Admins see all groups
        response = await _client.from('trek_groups').select('*, treks(title, image_url)').order('departure_date', ascending: false);
      } else {
        // Users see groups they are booked in
        response = await _client
            .from('bookings')
            .select('group_id, trek_groups(id, group_name, trek_id, treks(title, image_url))')
            .eq('user_id', user.id)
            .not('group_id', 'is', null);
      }

      // Fetch general broadcasts
      final broadcastResponse = await _client
          .from('broadcasts')
          .select('*, profiles(full_name)')
          .order('created_at', ascending: false)
          .limit(1);

      if (mounted) {
        setState(() {
          _rooms = response ?? [];
          _broadcasts = broadcastResponse ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _client.auth.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Please login')));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Expedition Hub', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRooms,
          ),
          if (_role == 'admin')
            IconButton(
              icon: const Icon(Icons.campaign, color: Colors.orange),
              onPressed: () => _showGlobalBroadcastDialog(),
            ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchRooms,
              child: CustomScrollView(
                slivers: [
                  if (_broadcasts.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildBroadcastHeader(),
                    ),
                  
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          const Text('Group Discussions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Theme.of(context).primaryColor, borderRadius: BorderRadius.circular(10)),
                            child: Text('${_rooms.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                    ),
                  ),

                  if (_rooms.isEmpty)
                    SliverFillRemaining(
                      child: _buildEmptyState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = _rooms[index];
                            return _buildRoomTile(item);
                          },
                          childCount: _rooms.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildRoomTile(dynamic item) {
    // Determine data structure based on role/query result
    final group = _role == 'admin' ? item : item['trek_groups'];
    if (group == null) return const SizedBox.shrink();

    final roomId = group['id'];
    final trek = group['treks'];
    final groupName = group['group_name'] ?? 'Trek Group';

    return FutureBuilder<Map<String, dynamic>?>(
      future: _client.from('messages').select('content, sender_id, created_at').eq('room_id', roomId).order('created_at', ascending: false).limit(1).maybeSingle(),
      builder: (context, msgSnapshot) {
        final lastMsg = msgSnapshot.data;
        final lastMsgText = lastMsg?['content'] ?? 'No messages yet...';
        final isBroadcast = lastMsg?['is_broadcast'] == true;

        return FadeInUp(
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  image: trek?['image_url'] != null ? DecorationImage(
                    image: NetworkImage(trek['image_url']),
                    fit: BoxFit.cover,
                  ) : null,
                  color: Colors.grey[200],
                ),
                child: trek?['image_url'] == null ? const Icon(Icons.terrain) : null,
              ),
              title: Text(groupName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    if (isBroadcast) 
                      const Padding(
                        padding: EdgeInsets.only(right: 4.0),
                        child: Icon(Icons.campaign, size: 14, color: Colors.orange),
                      ),
                    Expanded(
                      child: Text(
                        lastMsgText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isBroadcast ? Colors.orange[800] : Colors.grey[600],
                          fontWeight: isBroadcast ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  UnreadBadge(key: ValueKey(roomId), roomId: roomId),
                  const SizedBox(height: 4),
                  const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                ],
              ),
              onTap: () => Navigator.push(
                context, 
                MaterialPageRoute(builder: (c) => ChatScreen(roomId: roomId, title: groupName))
              ).then((_) => setState(() {})),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBroadcastHeader() {
    final b = _broadcasts.first;
    return FadeInDown(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.orange.shade700, Colors.orange.shade400]),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 10))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.campaign, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                const Text('OFFICIAL ANNOUNCEMENT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 12)),
                const Spacer(),
                if (_role == 'admin')
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                    onPressed: () => _deleteBroadcast(b['id']),
                  )
              ],
            ),
            const SizedBox(height: 12),
            Text(
              b['content'] ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500, height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(radius: 10, backgroundColor: Colors.white24, child: const Icon(Icons.person, size: 12, color: Colors.white)),
                const SizedBox(width: 8),
                Text(
                  'Sent by ${b['profiles']?['full_name'] ?? 'Admin'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            )
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
          Icon(Icons.forum_outlined, size: 100, color: Colors.grey[200]),
          const SizedBox(height: 20),
          Text(_role == 'admin' ? 'No trek groups found' : 'No active groups yet', style: TextStyle(color: Colors.grey[400], fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text('Book a trek to join the discussion!', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
        ],
      ),
    );
  }

  Future<void> _showGlobalBroadcastDialog() async {
    final _ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('New Global Announcement'),
        content: TextField(
          controller: _ctrl,
          decoration: const InputDecoration(hintText: 'Enter message for all users...'),
          maxLines: 4,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              if (_ctrl.text.isEmpty) return;
              await _client.from('broadcasts').insert({
                'content': _ctrl.text.trim(),
                'sender_id': _client.auth.currentUser?.id,
              });
              Navigator.pop(c);
              _fetchRooms();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text('ANNOUNCE'),
          )
        ],
      ),
    );
  }

  Future<void> _deleteBroadcast(String id) async {
    await _client.from('broadcasts').delete().eq('id', id);
    _fetchRooms();
  }
}
