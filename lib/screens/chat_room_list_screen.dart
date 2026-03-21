import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';
import 'admin_support_inquiries_screen.dart';
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
  String _role = 'user';
  int _activeTabIndex = 0; // 0 for Active, 1 for Completed (Archived)

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
    setState(() => _isLoading = true);
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      final now = DateTime.now().toIso8601String();
      dynamic response;
      
      if (_role == 'admin') {
        var query = _client.from('trek_groups').select('*, treks(title, image_url)');
        
        if (_activeTabIndex == 0) {
          // ACTIVE: Status is NOT completed (includes null)
          query = query.or('status.neq.completed,status.is.null');
        } else {
          // COMPLETED: Status is explicitly completed
          query = query.eq('status', 'completed');
        }
        response = await query.order('departure_date', ascending: _activeTabIndex == 0);
      } else if (_role == 'guide' || _role == 'staff') {
        // TREK CRITICAL: Employee visibility into assigned groups
        // 1. Fetch direct assignments in trek_groups
        var directQuery = _client.from('trek_groups').select('*, treks(title, image_url)')
            .or('guide_id.eq.${user.id},staff_id.eq.${user.id}');
        
        // Apply status-aware filtering to direct assignments
        if (_activeTabIndex == 0) {
          directQuery = directQuery.or('status.neq.completed,status.is.null');
        } else {
          directQuery = directQuery.eq('status', 'completed');
        }
        
        // 2. Fetch staff assignments in trek_group_staff
        final staffAssignments = await _client.from('trek_group_staff')
            .select('trek_id, deployment_date')
            .eq('user_id', user.id);
        
        final directRooms = await directQuery;
        List<dynamic> combinedRooms = List.from(directRooms as List);

        // 3. Aggregate rooms from personnel deployments
        for (var assignment in staffAssignments) {
           var extraQuery = _client.from('trek_groups').select('*, treks(title, image_url)')
               .eq('trek_id', assignment['trek_id']);
           
           if (_activeTabIndex == 0) {
             extraQuery = extraQuery.or('status.neq.completed,status.is.null');
           } else {
             extraQuery = extraQuery.eq('status', 'completed');
           }

           final extraRes = await extraQuery;
           for (var group in (extraRes as List)) {
              // NORMALIZATION PROTOCOL: Extract clean date reference
              // This logic was intended for AdminSquadIntelligenceScreen, but if it's meant to replace the date comparison here,
              // it needs adaptation. Assuming the original date comparison was correct for this context.
              // Reverting to original date comparison logic as the provided snippet is for a different context.
              final String depDate = group['departure_date'].toString().split('T')[0];
              final String assignDate = assignment['deployment_date'].toString().split('T')[0];
              
              if (depDate == assignDate) {
                 bool alreadyAdded = combinedRooms.any((r) => r['id'].toString() == group['id'].toString());
                 if (!alreadyAdded) {
                    combinedRooms.add(group);
                 }
              }
           }
        }
        response = combinedRooms;
      } else {
        // TREK CRITICAL: Fetch user bookings with both booking status and group status
        var query = _client.from('bookings').select('status, group_id, trek_groups(id, group_name, trek_id, departure_date, status, treks(title, image_url))').eq('user_id', user!.id).not('group_id', 'is', null);
        
        final allBookings = await query;
        if (_activeTabIndex == 0) {
          // ACTIVE: Group is not completed AND individual booking is not completed
          response = allBookings.where((b) {
            final gStatus = b['trek_groups']?['status']?.toString().toLowerCase();
            final bStatus = b['status']?.toString().toLowerCase();
            return gStatus != 'completed' && bStatus != 'completed';
          }).toList();
        } else {
          // COMPLETED: Either group is completed OR individual booking is completed
          response = allBookings.where((b) {
            final gStatus = b['trek_groups']?['status']?.toString().toLowerCase();
            final bStatus = b['status']?.toString().toLowerCase();
            return gStatus == 'completed' || bStatus == 'completed';
          }).toList();
        }
      }

      if (mounted) {
        // Fetch last message for each room for tactical sorting
        List<dynamic> roomList = List.from(response ?? []);
        await Future.wait(roomList.map((room) async {
          final roomId = (_role == 'admin' || _role == 'guide' || _role == 'staff') ? room['id'] : room['trek_groups']?['id'];
          if (roomId == null) return;
          final lastMsg = await _client.from('messages').select('created_at').eq('room_id', roomId).order('created_at', ascending: false).limit(1).maybeSingle();
          room['last_message_at'] = lastMsg != null ? DateTime.parse(lastMsg['created_at']) : DateTime(2000);
        }));

        // Sort: Latest message first
        // Sort: Latest message first, fallback to group creation date
        roomList.sort((a, b) {
          final DateTime dtA = a['last_message_at'] ?? DateTime(2000);
          final DateTime dtB = b['last_message_at'] ?? DateTime(2000);
          
          if (dtA != DateTime(2000) || dtB != DateTime(2000)) {
            return dtB.compareTo(dtA);
          }
          
          // Fallback to room creation (created_at)
          final DateTime createA = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(2000);
          final DateTime createB = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(2000);
          return createB.compareTo(createA);
        });

        setState(() {
          _rooms = roomList;
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
        title: const Text('Trek Chats', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchRooms),
          if (_role == 'admin')
            IconButton(
              icon: const Icon(Icons.campaign_outlined, color: Colors.orange),
              onPressed: () => _showGlobalBroadcastDialog(),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _tabItem(0, 'ACTIVE'),
                const SizedBox(width: 20),
                _tabItem(1, 'COMPLETED'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchRooms,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          Text(_activeTabIndex == 0 ? 'Group Discussions' : 'Archived Operations', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                          (context, index) => _buildRoomTile(_rooms[index]),
                          childCount: _rooms.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: _role == 'admin' ? FloatingActionButton.extended(
        heroTag: 'chat_support_fab',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => AdminSupportInquiriesScreen())),
        backgroundColor: Colors.blueAccent,
        icon: const Icon(Icons.support_agent, color: Colors.white),
        label: const Text('HQ SUPPORT HUB', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ) : null,
    );
  }

  Widget _tabItem(int index, String label) {
    bool selected = _activeTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _activeTabIndex = index);
        _fetchRooms();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: selected ? Theme.of(context).primaryColor : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
          const SizedBox(height: 4),
          if (selected) Container(width: 20, height: 2, color: Theme.of(context).primaryColor),
        ],
      ),
    );
  }

  Widget _buildRoomTile(dynamic item) {
    final group = (_role == 'admin' || _role == 'guide' || _role == 'staff') ? item : item['trek_groups'];
    if (group == null) return const SizedBox.shrink();

    final roomId = group['id'];
    final trek = group['treks'];
    final groupName = group['group_name'] ?? 'Trek Group';
    final isArchived = _activeTabIndex == 1;

    return FutureBuilder<Map<String, dynamic>?>(
      future: _client.from('messages').select('content, sender_id, created_at').eq('room_id', roomId).order('created_at', ascending: false).limit(1).maybeSingle(),
      builder: (context, msgSnapshot) {
        final lastMsg = msgSnapshot.data;
        final lastMsgText = isArchived ? 'Trek Complete. Chat Archived.' : (lastMsg?['content'] ?? 'No messages yet...');

        return FadeInUp(
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: Container(
                width: 60, height: 60,
                child: Stack(
                  children: [
                    if (trek?['image_url'] != null) Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.network(trek['image_url'], fit: BoxFit.cover))),
                    if (trek?['image_url'] == null) const Center(child: Icon(Icons.terrain)),
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18))),
                        child: Text(
                          group['departure_date'] != null ? DateFormat('MMM dd').format(DateTime.parse(group['departure_date'])) : 'TBD',
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              title: Text(groupName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Text(lastMsgText, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              trailing: isArchived ? const Icon(Icons.archive_outlined, color: Colors.grey, size: 20) : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  UnreadBadge(key: ValueKey(roomId), roomId: roomId),
                  const SizedBox(height: 4),
                  const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                ],
              ),
              onTap: () {
                if (isArchived && _role != 'admin') {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This chat is archived and read-only.')));
                }
                Navigator.push(context, MaterialPageRoute(builder: (c) => ChatScreen(roomId: roomId, title: groupName, isReadOnly: isArchived)))
                    .then((_) => setState(() {}));
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_outlined, size: 100, color: Colors.grey[200]),
          const SizedBox(height: 20),
          Text(_activeTabIndex == 0 ? 'No active groups' : 'No completed treks', style: TextStyle(color: Colors.grey[400], fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }


  Future<void> _showGlobalBroadcastDialog() async {
    final _ctrl = TextEditingController();
    final _titleCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('New Global Announcement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _titleCtrl, decoration: const InputDecoration(hintText: 'Title (e.g. Weather Alert)')),
            const SizedBox(height: 12),
            TextField(controller: _ctrl, decoration: const InputDecoration(hintText: 'Enter message...'), maxLines: 4),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              if (_ctrl.text.isEmpty) return;
              final User? user = _client.auth.currentUser;
              if (user == null) return;
              final profile = await _client.from('profiles').select('full_name').eq('id', user.id).maybeSingle();
              await _client.from('global_announcements').insert({
                'title': _titleCtrl.text.trim(),
                'content': _ctrl.text.trim(),
                'sender_id': user.id,
                'sender_name': profile?['full_name'] ?? 'HQ COMMAND',
                'created_at': DateTime.now().toIso8601String(),
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
}
