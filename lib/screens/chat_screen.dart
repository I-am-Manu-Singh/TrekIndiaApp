import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/user_avatar.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/preferences_service.dart';
import 'media_preview_screen.dart';

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
    _initStream();
    _fetchUserRole();
    _fetchMemberNames();
    _messageController.addListener(_onMessageChanged);
    _scrollController.addListener(_onScroll);
  }

  void _initStream() {
    _messagesStream = Supabase.instance.client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', widget.roomId)
        .order('created_at', ascending: false)
        .limit(_pageSize);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _loadMore();
      }
    }
  }

  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _pageSize = 50;
  final ScrollController _scrollController = ScrollController();

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    setState(() {
      _pageSize += 30;
      _initStream();
      _isLoadingMore = false;
    });
  }

  Future<void> _fetchUserRole() async {
    try {
      final res = await Supabase.instance.client.from('profiles').select('role').eq('id', _currentUser!.id).single();
      if (mounted) setState(() => _userRole = res['role'] ?? 'user');
    } catch (_) {}
  }

  Future<void> _toggleReaction(String messageId, String emoji, Map<String, dynamic> currentReactions) async {
    if (_currentUser == null) return;
    
    final Map<String, dynamic> newReactions = Map<String, dynamic>.from(currentReactions);
    final List<dynamic> users = List<dynamic>.from(newReactions[emoji] ?? []);
    
    if (users.contains(_currentUser.id)) {
      users.remove(_currentUser.id);
    } else {
      users.add(_currentUser.id);
    }
    
    if (users.isEmpty) {
      newReactions.remove(emoji);
    } else {
      newReactions[emoji] = users;
    }

    try {
      await Supabase.instance.client.from('chat_messages').update({
        'reactions': newReactions,
      }).eq('id', messageId);
    } catch (e) {
      debugPrint('Reaction Toggle Failed: $e');
    }
  }

  Future<void> _deleteMessage(String messageId, String senderId) async {
    if (_currentUser?.id != senderId && _userRole != 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trip Error: You can only delete your own messages.'), backgroundColor: Colors.red));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Scrub Transtrip?'),
        content: const Text('This will replace the message content with "message deleted" in the trip log.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Abort')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirm Delete', style: TextStyle(color: Colors.red))),
        ],
      )
    );

    if (confirmed == true) {
      try {
        await Supabase.instance.client.from('chat_messages').update({
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
    PreferencesService().setLastRead(widget.roomId);
    NotificationService.activeRoomId = null;
    _messageController.removeListener(_onMessageChanged);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _updateLastReadInCloud() async {
    if (_currentUser == null) return;
    try {
      await Supabase.instance.client.from('profiles').update({
        'last_read_at': DateTime.now().toIso8601String(),
      }).eq('id', _currentUser.id);
      PreferencesService().setLastRead(widget.roomId);
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
    
    // Check for links
    final urlMatch = RegExp(r'(https?://[^\s]+)').firstMatch(content);
    Map<String, dynamic>? linkMeta;
    if (urlMatch != null) {
      linkMeta = {'url': urlMatch.group(0)};
    }

    try {
      await Supabase.instance.client.from('chat_messages').insert({
        'room_id': widget.roomId,
        'sender_id': _currentUser.id,
        'content': content,
        'is_broadcast': _isBroadcastMode,
        'message_type': _isBroadcastMode ? 'broadcast' : 'text',
        'link_metadata': linkMeta,
      });
      await _dbService.updateLastMessage(widget.roomId, content);
      
      // MENTION LOGIC
      final senderName = _currentUser.userMetadata?['full_name'] ?? 'Someone';
      if (content.contains('@')) {
        for (var member in _allMembers) {
          final profile = member['profiles'];
          if (profile == null || profile['id'] == _currentUser.id) continue;
          
          final fullName = (profile['full_name'] ?? '').toString().toLowerCase();
          final firstName = fullName.split(' ').first;
          
          if (content.toLowerCase().contains('@all') || 
              content.toLowerCase().contains('@${fullName.replaceAll(' ', '')}') ||
              content.toLowerCase().contains('@$firstName')) {
            await _dbService.createNotification(
              userId: profile['id'],
              title: 'Mentioned by $senderName',
              body: content,
              category: 'general',
            );
          }
        }
      }

      if (mounted) setState(() => _isBroadcastMode = false);
    } catch (e) {
      // Fallback or handle error
      debugPrint('Send error: $e');
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
    final msgDate = DateTime(date.year, date.month, date.day);
    if (msgDate == today) return 'Today';
    if (msgDate == today.subtract(const Duration(days: 1))) return 'Yesterday';
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

                final Map<String, dynamic> profilesMap = {
                   for (var m in _allMembers) m['user_id'].toString() : m['profiles']
                };

                return ListView.builder(
                  controller: _scrollController,
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

                    final senderProfile = profilesMap[message['sender_id']];

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
                        FadeInUp(
                          duration: const Duration(milliseconds: 200),
                          child: _ChatBubble(
                            message: message, 
                            isMe: isMe,
                            senderProfile: senderProfile,
                            onDelete: () => _deleteMessage(message['id'], message['sender_id']),
                            onReaction: (emoji) => _toggleReaction(message['id'], emoji, message['reactions'] ?? {}),
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
             _buildArchivedFooter(),
        ],
      ),
    );
  }

  Widget _buildArchivedFooter() {
    return Container(
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
            'TRIP PROTOCOL CONCLUDED',
            style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2),
          ),
          const SizedBox(height: 4),
          const Text('This chat has been marked as archived and read-only.', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMentionOverlay() {
    return FadeInUp(
      duration: const Duration(milliseconds: 200),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 250),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5))],
          border: Border.all(color: const Color(0xFFD32F2F).withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.alternate_email, size: 14, color: Color(0xFFD32F2F)),
                  const SizedBox(width: 8),
                  Text('MENTION TREKKER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade500, letterSpacing: 1)),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _mentionFilteredMembers.length,
                itemBuilder: (context, index) {
                  final m = _mentionFilteredMembers[index];
                  final p = m['profiles'];
                  return ListTile(
                    leading: UserAvatar(imageUrl: p['avatar_url'], name: p['full_name'], radius: 15),
                    title: Text(p['full_name'] ?? 'Trip', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: Text(p['role'] ?? 'user', style: const TextStyle(fontSize: 10)),
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
            ),
          ],
        ),
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
        .from('chat_messages')
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
            const Text('ACTIVITY LOG', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            const SizedBox(height: 20),
            Expanded(
              child: (broadcasts as List).isEmpty 
                ? const Center(child: Text('No formal broadcasts logged for this trip.'))
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

class _ChatBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final dynamic senderProfile;
  final VoidCallback? onDelete;
  final Function(String)? onReaction;

  const _ChatBubble({
    required this.message, 
    required this.isMe, 
    this.senderProfile,
    this.onDelete, 
    this.onReaction
  });

  @override
  Widget build(BuildContext context) {
    final bool isBroadcast = message['is_broadcast'] ?? false;
    final Map<String, dynamic> reactions = message['reactions'] ?? {};
    final Map<String, dynamic>? linkMeta = message['link_metadata'];

    final String? senderName = senderProfile?['full_name'];
    final String? senderAvatar = senderProfile?['avatar_url'];
    final String? senderRole = senderProfile?['role'];

    if (isBroadcast) {
      return _buildBroadcastBubble(reactions);
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMe) ...[
                  UserAvatar(radius: 14, imageUrl: senderAvatar, name: senderName),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: GestureDetector(
                    onTap: () => onReaction?.call('👍'),
                    onLongPress: () => _showActionMenu(context),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isMe ? const Color(0xFF18181B) : (Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(20).copyWith(
                          bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(20),
                          bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(0),
                        ),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5, offset: const Offset(0, 2))],
                      ),
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          if (!isMe && senderName != null) _buildSenderHeader(senderName, senderRole),
                          if (linkMeta != null) _buildLinkPreview(context, linkMeta),
                          _buildMessageText(
                            context,
                            message['content'] ?? '',
                            (message['is_deleted'] ?? false) ? Colors.grey : (isMe ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
                            (message['is_deleted'] ?? false)
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('hh:mm a').format(DateTime.parse(message['created_at']).toLocal()),
                            style: TextStyle(fontSize: 8, color: isMe ? Colors.white70 : Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (reactions.isNotEmpty) _buildReactionsDisplay(reactions),
          ],
        ),
      ),
    );
  }

  void _showActionMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('MESSAGE ACTIONS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2, color: Colors.grey)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['👍', '❤️', '🔥', '😂', '😮', '😢'].map((emoji) => InkWell(
                onTap: () {
                  onReaction?.call(emoji);
                  Navigator.pop(context);
                },
                child: Text(emoji, style: const TextStyle(fontSize: 30)),
              )).toList(),
            ),
            const SizedBox(height: 20),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Message', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                onDelete?.call();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSenderHeader(String name, String? role) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          if (role == 'admin' || role == 'staff') ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(color: (role == 'admin' ? Colors.red : Colors.blue).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
              child: Text(role!.toUpperCase(), style: TextStyle(color: (role == 'admin' ? Colors.red : Colors.blue), fontSize: 7, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLinkPreview(BuildContext context, Map<String, dynamic> meta) {
    final url = meta['url'] ?? '';
    final lowerUrl = url.toLowerCase();
    final isMedia = lowerUrl.contains('.jpg') || lowerUrl.contains('.jpeg') || lowerUrl.contains('.png') || 
                    lowerUrl.contains('.gif') || lowerUrl.contains('.mp4') || lowerUrl.contains('.mov');

    return GestureDetector(
      onTap: () {
        if (isMedia) {
          Navigator.push(context, MaterialPageRoute(builder: (c) => MediaPreviewScreen(url: url, title: 'Trip Media')));
        } else {
          launchUrl(Uri.parse(url), mode: LaunchMode.inAppWebView);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            const Icon(Icons.link, size: 16, color: Colors.blueAccent),
            const SizedBox(width: 8),
            Expanded(child: Text(meta['url'], style: const TextStyle(fontSize: 10, color: Colors.blueAccent, decoration: TextDecoration.underline), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionsDisplay(Map<String, dynamic> reactions) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 40, right: 40),
      child: Wrap(
        spacing: 4,
        children: reactions.entries.map((e) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e.key, style: const TextStyle(fontSize: 10)),
                const SizedBox(width: 2),
                Text(e.value.length.toString(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBroadcastBubble(Map<String, dynamic> reactions) {
    return FadeInDown(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.red.shade900, Colors.red.shade600]),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.campaign, color: Colors.white, size: 24)),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('OFFICIAL BROADCAST', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)), Text('CONTROLER ACTION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))])),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),
            Text((message['is_deleted'] ?? false) ? 'This broadcast was deleted' : (message['content'] ?? ''), style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, fontStyle: (message['is_deleted'] ?? false) ? FontStyle.italic : FontStyle.normal)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(children: [Icon(Icons.security, color: Colors.white54, size: 12), SizedBox(width: 4), Text('Verified Admin', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold))]),
                Text(DateFormat('hh:mm a').format(DateTime.parse(message['created_at']).toLocal()), style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageText(BuildContext context, String text, Color textColor, bool isDeleted) {
    if (isDeleted) return Text('Message deleted', style: TextStyle(color: textColor, fontStyle: FontStyle.italic, fontSize: 13));

    final words = text.split(' ');
    return RichText(
      text: TextSpan(
        style: TextStyle(color: textColor, fontSize: 14),
        children: words.map((word) {
          if (word.startsWith('@')) return TextSpan(text: '$word ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber));
          if (word.startsWith('http')) {
            final lowerWord = word.toLowerCase();
            final isMedia = lowerWord.contains('.jpg') || lowerWord.contains('.jpeg') || lowerWord.contains('.png') || 
                            lowerWord.contains('.gif') || lowerWord.contains('.mp4') || lowerWord.contains('.mov');
            return WidgetSpan(
              child: GestureDetector(
                onTap: () {
                  if (isMedia) {
                    Navigator.push(context, MaterialPageRoute(builder: (c) => MediaPreviewScreen(url: word.trim(), title: 'Trip Media')));
                  } else {
                    launchUrl(Uri.parse(word.trim()), mode: LaunchMode.inAppWebView);
                  }
                },
                child: Text('$word ', style: const TextStyle(color: Colors.blueAccent, decoration: TextDecoration.underline, fontSize: 14)),
              ),
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
  void initState() { super.initState(); _checkRoleAndFetch(); }
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
    final adminsRes = await Supabase.instance.client.from('profiles').select('id, full_name, avatar_url, role').eq('role', 'admin');
    final allAdmins = (adminsRes as List).map((a) => { 'user_id': a['id'], 'is_leader': false, 'is_global_admin': true, 'profiles': a }).toList();
    if (mounted) setState(() { _members = [...allAdmins, ...members]; _loading = false; });
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text('TRIP MEMBERS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 20),
          Expanded(
            child: _loading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
              itemCount: _members.length,
              itemBuilder: (ctx, i) {
                final m = _members[i];
                final p = m['profiles'];
                final bool isLeader = m['is_leader'] == true;
                final bool isGlobalAdmin = m['is_global_admin'] == true;
                return ListTile(
                  leading: UserAvatar(imageUrl: p['avatar_url'], name: p['full_name'], radius: 20),
                  title: Text(p['full_name'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(isGlobalAdmin ? 'trekwithmussafirr Official' : (isLeader ? 'Trip Leader' : 'TREKKER'), style: TextStyle(fontSize: 10, color: isGlobalAdmin || isLeader ? Colors.blue : Colors.grey, fontWeight: isLeader ? FontWeight.bold : FontWeight.normal)),
                  trailing: isGlobalAdmin ? const Icon(Icons.verified, color: Colors.blue, size: 16) : (isLeader ? const Icon(Icons.star, color: Colors.amber, size: 16) : null),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
