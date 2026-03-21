import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import '../widgets/user_avatar.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/preferences_service.dart';

class ChatScreen extends StatefulWidget {
  final String roomId;
  final String title;
  final bool isReadOnly;

  const ChatScreen({super.key, required this.roomId, required this.title, this.isReadOnly = false});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final _currentUser = Supabase.instance.client.auth.currentUser;
  final _dbService = DatabaseService();
  late final Stream<List<Map<String, dynamic>>> _messagesStream;
  String _memberNames = 'Loading members...';
  bool _isBroadcastMode = false;
  String _userRole = 'user';
  List<Map<String, dynamic>> _allMembers = [];
  List<Map<String, dynamic>> _mentionFilteredMembers = [];
  bool _showMentionList = false;

  @override
  void initState() {
    super.initState();
    NotificationService.activeRoomId = widget.roomId;
    _updateLastReadInCloud();
    _fetchMemberNames(); // Ensure member names are loaded immediately
    
    _messagesStream = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', widget.roomId)
        .order('created_at', ascending: false);

    _fetchUserRole();
    _messageController.addListener(_onMessageChanged);
  }

  Future<void> _fetchUserRole() async {
    try {
      final res = await Supabase.instance.client.from('profiles').select('role').eq('id', _currentUser!.id).single();
      if (mounted) setState(() => _userRole = res['role'] ?? 'user');
    } catch (_) {}
  }

  Future<void> _deleteMessage(String messageId, String senderId) async {
    if (_currentUser?.id != senderId && _userRole != 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trek Error: You can only scrub your own transmissions.'), backgroundColor: Colors.red));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Scrub Transmission?'),
        content: const Text('This will replace the message content with "message deleted" in the mission log.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Abort')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirm Scrub', style: TextStyle(color: Colors.red))),
        ],
      )
    );

    if (confirmed == true) {
      try {
        await Supabase.instance.client.from('messages').update({
          'content': 'This message was deleted',
          'is_deleted': true,
        }).eq('id', messageId);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Operation Failed: $e')));
      }
    }
  }

  Future<void> _fetchMemberNames() async {
    try {
      final members = await _dbService.fetchGroupMembers(widget.roomId);
      if (!mounted) return;
      
      _allMembers = members;
      if (members.isEmpty) {
        setState(() => _memberNames = 'Tap to view details');
        return;
      }
      
      final names = members.map((m) => m['profiles']?['full_name']?.toString().split(' ').first ?? 'User').toSet().toList();
      String preview = names.take(3).join(', ');
      if (names.length > 3) preview += ' and ${names.length - 3} more';
      
      setState(() {
        _memberNames = preview.isEmpty ? 'Tap to view members' : preview;
      });
    } catch (e) {
      if (mounted) setState(() => _memberNames = 'Tap to view members');
    }
  }

  @override
  void dispose() {
    _updateLastReadInCloud();
    PreferencesService().setLastRead(widget.roomId); // Update local tactical status on egress
    NotificationService.activeRoomId = null;
    _messageController.removeListener(_onMessageChanged);
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _updateLastReadInCloud() async {
    if (_currentUser == null) return;
    try {
      await Supabase.instance.client.from('profiles').update({
        'last_read_at': DateTime.now().toIso8601String(),
      }).eq('id', _currentUser.id);
      PreferencesService().setLastRead(widget.roomId); // Trek sync
    } catch (_) {}
  }

  void _onMessageChanged() {
    final text = _messageController.text;
    final selection = _messageController.selection;
    if (selection.baseOffset < 0) return;

    final beforeCursor = text.substring(0, selection.baseOffset);
    final lastAt = beforeCursor.lastIndexOf('@');

    if (lastAt != -1 && !beforeCursor.substring(lastAt).contains(' ')) {
      final query = beforeCursor.substring(lastAt + 1).toLowerCase();
      setState(() {
        _showMentionList = true;
        _mentionFilteredMembers = _allMembers.where((m) {
          final name = (m['profiles']?['full_name'] ?? '').toString().toLowerCase();
          return name.contains(query);
        }).toList();
      });
    } else {
      if (_showMentionList) setState(() => _showMentionList = false);
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _currentUser == null) return;

    _messageController.clear();
    try {
      // Primary Trek Insert
      await Supabase.instance.client.from('messages').insert({
        'room_id': widget.roomId,
        'sender_id': _currentUser.id,
        'content': content,
        'is_broadcast': _isBroadcastMode,
        'message_type': _isBroadcastMode ? 'broadcast' : 'text',
      });
      if (mounted) setState(() => _isBroadcastMode = false);
    } catch (e) {
      if (e.toString().contains('message_type') || e.toString().contains('PGRST204')) {
        // Fallback: Column missing in schema, try without message_type metadata
        try {
          await Supabase.instance.client.from('messages').insert({
            'room_id': widget.roomId,
            'sender_id': _currentUser.id,
            'content': content,
            'is_broadcast': _isBroadcastMode,
          });
          if (mounted) setState(() => _isBroadcastMode = false);
        } catch (e2) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Critical Send Error: $e2')));
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    }
  }

  void _showMembers() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => _MembersList(
        roomId: widget.roomId, 
        dbService: _dbService,
        onRefresh: _fetchMemberNames,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(date.year, date.month, date.day);

    if (msgDate == today) return 'Today';
    if (msgDate == yesterday) return 'Yesterday';
    return DateFormat('dd MMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _showMembers,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(_memberNames, style: const TextStyle(fontSize: 10, color: Colors.white70)),
            ],
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_edu),
            tooltip: 'Broadcast History',
            onPressed: () => _showBroadcastHistory(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error.toString()}'));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final messages = snapshot.data!;
                if (messages.isEmpty) return const Center(child: Text('No messages yet.'));

                // Trek Sync: Mark as read when new intel arrives while on-station
                if (messages.isNotEmpty) {
                  PreferencesService().setLastRead(widget.roomId);
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message['sender_id'] == _currentUser?.id;
                    final createdAt = DateTime.parse(message['created_at']).toLocal();
                    
                    bool showDate = false;
                    if (index == messages.length - 1) {
                      showDate = true;
                    } else {
                      final prevDate = DateTime.parse(messages[index + 1]['created_at']).toLocal();
                      if (_formatDate(createdAt) != _formatDate(prevDate)) {
                        showDate = true;
                      }
                    }

                    return Column(
                      children: [
                        if (showDate)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
                                child: Text(_formatDate(createdAt), style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        GestureDetector(
                          onLongPress: () {
                            final bool isAuthor = message['sender_id'] == _currentUser?.id;
                            // Check for admin role would require more lookups but we can use the role from bubble or assume admin can delete all
                            // For now allow author to delete. Admin deletion logic handled in bubble
                            if (!(message['is_deleted'] ?? false)) {
                              _deleteMessage(message['id'], message['sender_id']);
                            }
                          },
                          child: FadeInUp(
                            duration: const Duration(milliseconds: 200),
                            child: _ChatBubble(
                              message: message, 
                              isMe: isMe,
                              onDelete: () => _deleteMessage(message['id'], message['sender_id']),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          if (_showMentionList && _mentionFilteredMembers.isNotEmpty)
            _buildMentionOverlay(),
          if (!widget.isReadOnly) 
             _buildMessageInput()
          else
             Container(
               width: double.infinity,
               padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
               decoration: BoxDecoration(
                 color: Theme.of(context).cardColor,
                 border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
               ),
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   const Icon(Icons.archive_outlined, color: Colors.grey, size: 24),
                   const SizedBox(height: 12),
                   Text(
                     'MISSION PROTOCOL CONCLUDED',
                     style: TextStyle(
                       color: Colors.grey.shade400,
                       fontWeight: FontWeight.w900,
                       fontSize: 10,
                       letterSpacing: 2,
                     ),
                   ),
                   const SizedBox(height: 4),
                   const Text(
                     'This chat has been marked as archived and read-only due to trek completeion.',
                     style: TextStyle(color: Colors.grey, fontSize: 12),
                   ),
                 ],
               ),
             ),
        ],
      ),
    );
  }

  Widget _buildMentionOverlay() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _mentionFilteredMembers.length,
        itemBuilder: (context, index) {
          final m = _mentionFilteredMembers[index];
          final p = m['profiles'];
          return ListTile(
            leading: UserAvatar(imageUrl: p['avatar_url'], name: p['full_name'], radius: 15),
            title: Text(p['full_name'] ?? 'Trekker', style: const TextStyle(fontSize: 14)),
            onTap: () {
              final text = _messageController.text;
              final selection = _messageController.selection;
              final beforeCursor = text.substring(0, selection.baseOffset);
              final afterCursor = text.substring(selection.baseOffset);
              final lastAt = beforeCursor.lastIndexOf('@');
              
              final newText = beforeCursor.substring(0, lastAt) + '@${p['full_name']} ' + afterCursor;
              _messageController.text = newText;
              _messageController.selection = TextSelection.collapsed(offset: lastAt + (p['full_name'] as String).length + 2);
              setState(() => _showMentionList = false);
            },
          );
        },
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          if (_userRole == 'admin')
            IconButton(
              icon: Icon(_isBroadcastMode ? Icons.campaign : Icons.campaign_outlined, color: _isBroadcastMode ? Colors.red : Colors.grey),
              onPressed: () => setState(() => _isBroadcastMode = !_isBroadcastMode),
            ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: _isBroadcastMode ? Colors.red : Theme.of(context).primaryColor,
            child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: _sendMessage),
          )
        ],
      ),
    );
  }

  void _showBroadcastHistory(BuildContext context) async {
    final broadcasts = await Supabase.instance.client
        .from('messages')
        .select('*, profiles(full_name)')
        .eq('room_id', widget.roomId)
        .eq('is_broadcast', true)
        .order('created_at', ascending: false);

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (c) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('EXPEDITION DISPATCH LOG', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            const SizedBox(height: 20),
            Expanded(
              child: (broadcasts as List).isEmpty 
                ? const Center(child: Text('No formal broadcasts logged for this mission.'))
                : ListView.builder(
                    itemCount: broadcasts.length,
                    itemBuilder: (ctx, i) {
                      final b = broadcasts[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b['content'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text(
                              '${DateFormat('MMM dd, HH:mm').format(DateTime.parse(b['created_at']))} • ${b['profiles']?['full_name'] ?? 'Admin'}',
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatefulWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final VoidCallback? onDelete;

  const _ChatBubble({required this.message, required this.isMe, this.onDelete});

  @override
  State<_ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<_ChatBubble> {
  static final Map<String, Map<String, String?>> _profileCache = {};
  String? _senderName;
  String? _senderAvatar;

  @override
  void initState() {
    super.initState();
    _fetchSender();
  }

  Future<void> _fetchSender() async {
    if (widget.isMe) return;
    final senderId = widget.message['sender_id'];
    if (senderId == null) return;

    if (_profileCache.containsKey(senderId)) {
      if (mounted) {
        setState(() {
          _senderName = _profileCache[senderId]!['name'];
          _senderAvatar = _profileCache[senderId]!['avatar'];
        });
      }
      return;
    }

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('full_name, avatar_url')
          .eq('id', senderId)
          .single();
      
      _profileCache[senderId] = {
        'name': data['full_name'],
        'avatar': data['avatar_url']
      };

      if (mounted) {
        setState(() {
          _senderName = data['full_name'];
          _senderAvatar = data['avatar_url'];
          _senderRole = data['role'];
        });
      }
    } catch (_) {}
  }
  String? _senderRole;

  @override
  Widget build(BuildContext context) {
    final bool isBroadcast = widget.message['is_broadcast'] ?? false;
    
    if (isBroadcast) {
      return FadeInDown(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.red.shade900, Colors.red.shade600],
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.campaign, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('OFFICIAL BROADCAST', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
                        Text('COMMANDER ACTION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              Text(
                (widget.message['is_deleted'] ?? false) ? 'This broadcast was deleted' : (widget.message['content'] ?? ''), 
                style: TextStyle(
                  color: Colors.white, 
                  fontSize: 16, 
                  fontWeight: FontWeight.w600,
                  fontStyle: (widget.message['is_deleted'] ?? false) ? FontStyle.italic : FontStyle.normal,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Row(
                    children: [
                      const Icon(Icons.security, color: Colors.white54, size: 12),
                      const SizedBox(width: 4),
                      const Text('Verified Admin', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Text(
                    DateFormat('hh:mm a').format(DateTime.parse(widget.message['created_at']).toLocal()),
                    style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!widget.isMe) ...[
              UserAvatar(radius: 14, imageUrl: _senderAvatar, name: _senderName),
              const SizedBox(width: 8),
            ],
            GestureDetector(
              onLongPress: widget.onDelete,
              child: Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: widget.isMe 
                    ? const Color(0xFF1E293B) // Trek Navy for sender
                    : (Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(20).copyWith(
                    bottomRight: widget.isMe ? const Radius.circular(0) : const Radius.circular(20),
                    bottomLeft: widget.isMe ? const Radius.circular(20) : const Radius.circular(0),
                  ),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (!widget.isMe && _senderName != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_senderName!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                            if (_senderRole == 'admin' || _senderRole == 'guide') ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(color: (_senderRole == 'admin' ? Colors.red : Colors.blue).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                child: Text(_senderRole!.toUpperCase(), style: TextStyle(color: (_senderRole == 'admin' ? Colors.red : Colors.blue), fontSize: 7, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    _buildMessageText(
                      widget.message['content'] ?? '',
                      (widget.message['is_deleted'] ?? false) 
                        ? Colors.grey 
                        : (widget.isMe ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
                      (widget.message['is_deleted'] ?? false)
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('hh:mm a').format(DateTime.parse(widget.message['created_at']).toLocal()),
                      style: TextStyle(fontSize: 8, color: widget.isMe ? Colors.white70 : Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageText(String content, Color color, bool isDeleted) {
    if (isDeleted) {
      return Text(content, style: TextStyle(color: color, fontSize: 14, fontStyle: FontStyle.italic));
    }

    final words = content.split(' ');
    return RichText(
      text: TextSpan(
        style: TextStyle(color: color, fontSize: 14),
        children: words.map((word) {
          if (word.startsWith('@')) {
            return TextSpan(
              text: '$word ',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
            );
          }
          return TextSpan(text: '$word ');
        }).toList(),
      ),
    );
  }
}

class _MembersList extends StatefulWidget {
  final String roomId;
  final DatabaseService dbService;
  final VoidCallback? onRefresh;

  const _MembersList({required this.roomId, required this.dbService, this.onRefresh});

  @override
  State<_MembersList> createState() => _MembersListState();
}

class _MembersListState extends State<_MembersList> {
  bool _isAdmin = false;
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkRoleAndFetch();
  }

  Future<void> _checkRoleAndFetch() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final profile = await Supabase.instance.client.from('profiles').select('role').eq('id', user.id).maybeSingle();
      if (mounted) setState(() => _isAdmin = profile?['role'] == 'admin');
    }
    _fetch();
  }

  Future<void> _fetch() async {
    final members = await widget.dbService.fetchGroupMembers(widget.roomId);
    
    // Also fetch all admins to show them in group details as support
    final adminsRes = await Supabase.instance.client.from('profiles').select('id, full_name, avatar_url, role').eq('role', 'admin');
    final allAdmins = (adminsRes as List).map((a) => {
      'user_id': a['id'],
      'is_leader': false,
      'is_global_admin': true,
      'profiles': a
    }).toList();

    if (mounted) {
      setState(() { 
        // Merge bookings members with global admins (avoiding duplicates)
        final List<Map<String, dynamic>> combined = [...members];
        for (var admin in allAdmins) {
          if (!combined.any((m) => m['user_id'] == admin['user_id'])) {
            combined.add(admin);
          }
        }
        _members = combined; 
        _loading = false; 
      });
    }
  }

  void _showAddMemberDialog() async {
    final client = Supabase.instance.client;
    final res = await client.from('profiles').select('id, full_name, email, role');
    final allUsers = res as List<dynamic>;

    String searchQuery = '';
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (c) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredUsers = allUsers.where((u) {
              final name = (u['full_name'] ?? '').toString().toLowerCase();
              final email = (u['email'] ?? '').toString().toLowerCase();
              return name.contains(searchQuery.toLowerCase()) || email.contains(searchQuery.toLowerCase());
            }).toList();

            return AlertDialog(
              title: const Text('Add User to Group'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search by name or email...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (val) => setDialogState(() => searchQuery = val),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredUsers.length,
                        itemBuilder: (ctx, i) {
                          final u = filteredUsers[i];
                          if (_members.any((m) => m['user_id'] == u['id'])) return const SizedBox.shrink();
                          
                          return ListTile(
                            leading: UserAvatar(imageUrl: u['avatar_url'], name: u['full_name'], radius: 15),
                            title: Text(u['full_name'] ?? 'Trekker'),
                            subtitle: Text(u['role'] ?? 'user'),
                            trailing: const Icon(Icons.add_circle_outline, color: Colors.green),
                            onTap: () async {
                              Navigator.pop(c);
                              try {
                                final groupData = await client.from('trek_groups').select('trek_id').eq('id', widget.roomId).maybeSingle();
                                if (groupData == null) return;
                                await client.from('bookings').insert({
                                  'user_id': u['id'],
                                  'trek_id': groupData['trek_id'],
                                  'group_id': widget.roomId,
                                  'booking_date': DateTime.now().toIso8601String(),
                                  'total_price': 0,
                                  'payment_status': 'Paid',
                                });
                                _fetch();
                                widget.onRefresh?.call(); // Refresh names in header
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added ${u['full_name']}')));
                              } catch (e) {
                                print('Error adding member: $e');
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final admins = _members.where((m) => m['profiles']?['role'] == 'admin').toList();
    final guides = _members.where((m) => m['profiles']?['role'] == 'guide').toList();
    final users = _members.where((m) => m['profiles']?['role'] != 'admin' && m['profiles']?['role'] != 'guide').toList();

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Expedition Members', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (_isAdmin)
                  TextButton.icon(
                    onPressed: _showAddMemberDialog,
                    icon: const Icon(Icons.person_add, size: 16),
                    label: const Text('Add'),
                  )
              ],
            ),
          ),
          TabBar(
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).primaryColor,
            tabs: const [
              Tab(text: 'Admins'),
              Tab(text: 'Guides'),
              Tab(text: 'Trekkers'),
            ],
          ),
          if (_loading) const Expanded(child: Center(child: CircularProgressIndicator()))
          else Expanded(
            child: TabBarView(
              children: [
                _memberList(admins),
                _memberList(guides),
                _memberList(users),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _memberList(List<Map<String, dynamic>> list) {
    if (list.isEmpty) return const Center(child: Text('Empty list', style: TextStyle(color: Colors.grey)));
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final m = list[index];
        final p = m['profiles'];
        final bool isLeader = m['is_leader'] == true;
        final bool isGlobalAdmin = m['is_global_admin'] == true;
        final bool isPersonAdmin = p['role'] == 'admin';

        return ListTile(
          leading: UserAvatar(imageUrl: p['avatar_url'], name: p['full_name'], radius: 18),
          title: Row(
            children: [
              Text(p['full_name'] ?? 'Trekker', style: TextStyle(fontWeight: (isPersonAdmin || p['role'] == 'guide') ? FontWeight.bold : FontWeight.normal)),
              if (p['role'] == 'admin' || p['role'] == 'guide') ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: (p['role'] == 'admin' ? Colors.red : Colors.blue).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                  child: Text(p['role']!.toUpperCase(), style: TextStyle(color: (p['role'] == 'admin' ? Colors.red : Colors.blue), fontSize: 8, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
          subtitle: Text(p['role'] ?? 'User', style: const TextStyle(fontSize: 10)),
          trailing: _isAdmin && !isGlobalAdmin ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.person_remove_outlined, size: 18, color: Colors.redAccent),
                onPressed: () => _removeMember(m['id'], p['full_name']),
              ),
            ],
          ) : null,
        );
      },
    );
  }


  Future<void> _removeMember(String bookingId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Discharge Member?'),
        content: Text('Are you sure you want to remove $name from this mission group?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Abort')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Discharge', style: TextStyle(color: Colors.red))),
        ],
      )
    );

    if (confirm == true) {
      await Supabase.instance.client.from('bookings').update({'group_id': null}).eq('id', bookingId);
      _fetch();
      widget.onRefresh?.call();
    }
  }
}
