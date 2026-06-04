import 'package:flutter/material.dart';
import '../widgets/glass_shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';
import 'admin_support_inquiries_screen.dart';
import '../widgets/unread_badge.dart';
import '../services/preferences_service.dart';
import 'dart:async';

class ChatRoomListScreen extends StatefulWidget {
  const ChatRoomListScreen({super.key});

  @override
  State<ChatRoomListScreen> createState() => _ChatRoomListScreenState();
}

class _ChatRoomListScreenState extends State<ChatRoomListScreen> with AutomaticKeepAliveClientMixin {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _rooms = [];
  List<dynamic> _activeRoomsList = [];
  List<dynamic> _archivedRoomsList = [];
  Map<String, int> _unreadCounts = {};
  String _role = 'user';
  int _activeTabIndex = 0; // 0 for Active, 1 for Completed (Archived)
  RealtimeChannel? _realtimeChannel;
  StreamSubscription? _readSubscription;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initData();
    _setupRealtime();
    _readSubscription = PreferencesService().readStream.listen((_) {
      _fetchUnreadCounts();
    });
  }

  void _setupRealtime() {
    final user = _client.auth.currentUser;
    if (user == null) return;

    _realtimeChannel = _client.channel('chat_list_updates')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'trip_groups',
        callback: (payload) {
          debugPrint('Trip Group Update Detected: ${payload.toString()}');
          _fetchRooms();
        },
      )
      .subscribe();
  }

  @override
  void dispose() {
    _client.removeChannel(_realtimeChannel!);
    _readSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initData() async {
    await _fetchUserRole();
    await _fetchRooms();
  }

  Future<void> _fetchUserRole() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      final profile = await _client.from('profiles').select('role').eq('id', user.id).maybeSingle().timeout(const Duration(seconds: 5));
      if (profile != null && mounted) {
        setState(() => _role = profile['role'] ?? 'user');
      }
    } catch (e) {
      debugPrint('Role fetch failed: $e');
    }
  }

  String _getRoomId(dynamic item) {
    final role = _role.toLowerCase();
    final group = (['admin', 'staff', 'employee'].contains(role)) ? item : item['trip_groups'];
    return group?['id']?.toString() ?? '';
  }

  int get _activeUnreadCount {
    int sum = 0;
    for (final room in _activeRoomsList) {
      sum += _unreadCounts[_getRoomId(room)] ?? 0;
    }
    return sum;
  }

  int get _archivedUnreadCount {
    return 0; // Do not count unread from archived
  }

  Future<void> _fetchUnreadCounts() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      final allRooms = _activeRoomsList; // Revert archived count
      final List<String> roomIds = allRooms.map((r) => _getRoomId(r)).where((id) => id.isNotEmpty).toList();

      if (roomIds.isEmpty) {
        if (mounted) setState(() => _unreadCounts = {});
        return;
      }

      final res = await _client
          .from('chat_messages')
          .select('room_id, created_at, sender_id')
          .inFilter('room_id', roomIds)
          .neq('sender_id', user.id)
          .order('created_at', ascending: false)
          .limit(300);

      final messages = res as List;
      final Map<String, int> counts = {};

      for (final roomId in roomIds) {
        final lastRead = await PreferencesService().getLastRead(roomId);
        final roomMessages = messages.where((m) => 
          m['room_id'].toString() == roomId &&
          DateTime.parse(m['created_at']).isAfter(lastRead)
        );
        counts[roomId] = roomMessages.length;
      }

      if (mounted) {
        setState(() {
          _unreadCounts = counts;
        });
      }
    } catch (e) {
      debugPrint('Error calculating unread counts: $e');
    }
  }

  Future<void> _fetchRooms() async {
    if (!mounted) return;
    // Non-blocking loader: only show shimmer if list is completely empty
    if (_activeRoomsList.isEmpty && _archivedRoomsList.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      final activeResponse = await _getRoomsQuery(user.id, isActive: true);
      final archivedResponse = await _getRoomsQuery(user.id, isActive: false);
      
      if (mounted) {
        setState(() {
          _activeRoomsList = activeResponse as List<dynamic>;
          _archivedRoomsList = archivedResponse as List<dynamic>;
          _rooms = _activeTabIndex == 0 ? _activeRoomsList : _archivedRoomsList;
          _isLoading = false;
        });
        _fetchUnreadCounts();
      }
    } catch (e) {
      debugPrint('Rooms fetch failed: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<dynamic> _getRoomsQuery(String userId, {required bool isActive}) async {
    final role = _role.toLowerCase();
    if (role == 'admin') {
      // Fetch unique trip groups for admins
      final response = await _client.from('trip_groups').select('*, trips(*)').order('departure_date', ascending: isActive);
      
      if (isActive) {
        return (response as List).where((g) => g['status']?.toString().toLowerCase() != 'completed').toList();
      } else {
        return (response as List).where((g) => g['status']?.toString().toLowerCase() == 'completed').toList();
      }
    } else if (role == 'staff' || role == 'employee' || role == 'guide') {
      final staffDeployments = await _client.from('trip_group_staff')
          .select()
          .eq('user_id', userId);
          
      List<dynamic> allMatchingGroups = [];
      
      if (staffDeployments.isNotEmpty) {
        final Set<String> tripIds = staffDeployments.map((s) => s['trip_id']?.toString() ?? '').toSet()
          ..removeWhere((id) => id.isEmpty || id == 'null');
        
        if (tripIds.isNotEmpty) {
          final matchingTripGroups = await _client.from('trip_groups')
              .select('*, trips(*)')
              .inFilter('trip_id', tripIds.toList());
              
          for (var d in staffDeployments) {
            final dTripId = d['trip_id']?.toString();
            final dDate = (d['deployment_date'] ?? '').toString().split('T')[0];
            
            for (var g in matchingTripGroups) {
              final gTripId = g['trip_id']?.toString();
              final gDate = (g['departure_date'] ?? '').toString().split('T')[0];
              if (dTripId == gTripId && dDate == gDate) {
                if (!allMatchingGroups.any((existing) => existing['id'] == g['id'])) {
                  allMatchingGroups.add(g);
                }
              }
            }
          }
        }
      }
      
      allMatchingGroups.sort((a, b) {
        final dateA = (a['departure_date'] ?? '').toString();
        final dateB = (b['departure_date'] ?? '').toString();
        return isActive ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
      });
      
      if (isActive) {
        return allMatchingGroups.where((g) => g['status']?.toString().toLowerCase() != 'completed').toList();
      } else {
        return allMatchingGroups.where((g) => g['status']?.toString().toLowerCase() == 'completed').toList();
      }
    } else {
      final allBookings = await _client.from('bookings').select('status, group_id, trip_groups(*, trips(*))').eq('user_id', userId).not('group_id', 'is', null);
      final List validBookings = (allBookings as List).where((b) => b['trip_groups'] != null).toList();
      if (isActive) {
        return validBookings.where((b) {
          final gStatus = b['trip_groups']?['status']?.toString().toLowerCase();
          final bStatus = b['status']?.toString().toLowerCase();
          return gStatus != 'completed' && bStatus != 'completed';
        }).toList();
      } else {
        return validBookings.where((b) {
          final gStatus = b['trip_groups']?['status']?.toString().toLowerCase();
          final bStatus = b['status']?.toString().toLowerCase();
          return gStatus == 'completed' || bStatus == 'completed';
        }).toList();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('TRIP CHATS', 
         style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Colors.white,
          )
        ),
        backgroundColor: const Color(0xFFD32F2F),
        elevation: 0,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: const Color(0xFFD32F2F),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                _tabItem(0, 'ACTIVE TRIPS'),
                const SizedBox(width: 20),
                _tabItem(1, 'ARCHIVED LOGS'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading  
          ? _buildShimmerList()
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
                            decoration: BoxDecoration(color: const Color(0xFFD32F2F), borderRadius: BorderRadius.circular(10)),
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
                          (context, index) => _buildRoomTile(_rooms[index], index),
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
        backgroundColor: const Color(0xFFD32F2F),
        icon: const Icon(Icons.support_agent, color: Colors.white),
        label: const Text('SUPPORT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ) : null,
    );
  }

  Widget _tabItem(int index, String label) {
    bool selected = _activeTabIndex == index;
    final unreadCount = index == 0 ? _activeUnreadCount : _archivedUnreadCount;
    return GestureDetector(
      onTap: () {
        setState(() => _activeTabIndex = index);
        _fetchRooms();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white60, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.2)),
              if (unreadCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$unreadCount',
                    style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 8, fontWeight: FontWeight.bold, height: 1),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          if (selected) Container(width: 20, height: 2, color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildRoomTile(dynamic item, int index) {
    final role = _role.toLowerCase();
    final group = (['admin', 'staff', 'employee'].contains(role)) ? item : item['trip_groups'];
    if (group == null) return const SizedBox.shrink();

    final roomId = group['id'];
    final trip = group['trips'];
    String groupName = group['group_name'] ?? 'Trip Group';
    if (groupName.toLowerCase().contains('null')) {
      groupName = groupName.replaceAll(RegExp(r'null', caseSensitive: false), 'Staff');
      if (groupName.toLowerCase().contains('null')) groupName = 'Staff Assignment'; // Ultimate Backup
    }
    final isArchived = _activeTabIndex == 1;

    final lastMsgText = isArchived ? 'Trip Complete. Chat Archived.' : (group['last_message_content'] ?? 'No messages yet...');

    return Container(
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
              if (trip?['image_url'] != null) Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.network(trip['image_url'], fit: BoxFit.cover))),
              if (trip?['image_url'] == null) const Center(child: Icon(Icons.terrain)),
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
            UnreadBadge(key: ValueKey('unread_$roomId'), roomId: roomId),
            const SizedBox(height: 4),
            const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
          ],
        ),
        onTap: () {
          if (isArchived && _role != 'admin') {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This chat is archived and read-only.')));
          }
          Navigator.push(context, MaterialPageRoute(builder: (c) => ChatScreen(roomId: roomId, title: groupName, isReadOnly: isArchived)))
              .then((_) => _fetchRooms());
        },
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
          Text(_activeTabIndex == 0 ? 'No active groups' : 'No completed trips', style: TextStyle(color: Colors.grey[400], fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildShimmerList() {
    return GlassShimmer(
      child: ListView.builder(
        itemCount: 8,
        padding: const EdgeInsets.all(20),
        itemBuilder: (context, index) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              const ShimmerBlock(width: 60, height: 60, borderRadius: 18),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ShimmerBlock(width: 150, height: 16),
                    const SizedBox(height: 8),
                    const ShimmerBlock(width: double.infinity, height: 12),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const ShimmerBlock(width: 20, height: 20, shape: BoxShape.circle),
            ],
          ),
        ),
      ),
    );
  }
}
