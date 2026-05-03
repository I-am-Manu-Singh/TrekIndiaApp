import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import '../services/database_service.dart';
import '../widgets/user_avatar.dart';

class AdminGroupDetailScreen extends StatefulWidget {
  final String tripId;
  final String tripTitle;
  final String date;

  const AdminGroupDetailScreen({
    super.key,
    required this.tripId,
    required this.tripTitle,
    required this.date,
  });

  @override
  State<AdminGroupDetailScreen> createState() => _AdminGroupDetailScreenState();
}

class _AdminGroupDetailScreenState extends State<AdminGroupDetailScreen> {
  List<dynamic> _usersInGroup = [];
  bool _isLoading = true;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final response = await Supabase.instance.client
          .from('bookings')
          .select('*, profiles(full_name, id, avatar_url, role, emergency_contact, blood_group, medical_info), booking_addons(*, gears(*))')
          .eq('trip_id', widget.tripId)
          .eq('trip_date', widget.date)
          .order('booking_date', ascending: true);

      if (mounted) {
        setState(() {
          _usersInGroup = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print('Error fetching users in group: $e');
    }
  }

  Future<void> _removeUserFromGroup(String bookingId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove User'),
        content: const Text('Are you sure you want to remove this user from the trip group? This action will delete their booking.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      setState(() => _isLoading = true);
      await Supabase.instance.client.from('bookings').delete().eq('id', bookingId);
      
      _hasChanges = true;
      _fetchUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User removed successfully')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error removing user: $e')));
      }
    }
  }

  Future<void> _addUserManually() async {
    // A simplified add user dialog
    final _emailController = TextEditingController();
    final _travelersController = TextEditingController(text: '1');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add User to Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Note: Providing an email assigns to an existing user. For manual untracked guests, leave empty (Feature TBD).'),
            const SizedBox(height: 10),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'User Email (Must exist in DB)'),
            ),
            TextField(
              controller: _travelersController,
              decoration: const InputDecoration(labelText: 'Number of Travelers'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != true || _emailController.text.isEmpty) return;

    try {
      setState(() => _isLoading = true);
      
      // Look up profile by email or name
      final email = _emailController.text.trim();
      final profiles = await Supabase.instance.client
          .from('profiles')
          .select('id, full_name')
          .ilike('full_name', '%$email%'); // Simplified search; ideally we'd have emails in profiles but auth.users is protected.
      
      // Since 'profiles' doesn't store email by default in some setups, we'll try to match by name or return error.
      if (profiles.isEmpty) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No matching user found. Try searching by Full Name.')));
           setState(() => _isLoading = false);
        }
        return;
      }

      final userId = profiles[0]['id'];
      final travelers = int.tryParse(_travelersController.text) ?? 1;

      // Find or create group_id for chat
      final groups = await Supabase.instance.client
          .from('trip_groups')
          .select('id')
          .eq('trip_id', widget.tripId)
          .eq('departure_date', widget.date)
          .maybeSingle();
      
      String? groupId;
      if (groups != null) {
        groupId = groups['id'];
      } else {
        final newGroup = await Supabase.instance.client.from('trip_groups').insert({
          'trip_id': widget.tripId,
          'departure_date': widget.date,
          'group_name': '${widget.tripTitle} - ${widget.date}',
        }).select('id').single();
        groupId = newGroup['id'];
      }

      // Create a booking
      await Supabase.instance.client.from('bookings').insert({
        'user_id': userId,
        'trip_id': widget.tripId,
        'group_id': groupId,
        'trip_date': widget.date,
        'travelers': travelers,
        'trip_price': 0, 
        'total_price': 0,
        'payment_status': 'Paid',
        'status': 'Confirmed',
      });

      _hasChanges = true;
      _fetchUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added ${profiles[0]['full_name']} successfully!')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action failed: $e')));
      }
    }
  }

  Future<void> _showBroadcastDialog() async {
    final _msgCtrl = TextEditingController();
    final bool? send = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Send Group Broadcast'),
        content: TextField(
          controller: _msgCtrl,
          decoration: const InputDecoration(hintText: 'Enter broadcast message...'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Send')),
        ],
      ),
    );

    if (send == true && _msgCtrl.text.isNotEmpty) {
      try {
        final group = await Supabase.instance.client.from('trip_groups').select('id').eq('trip_id', widget.tripId).eq('departure_date', widget.date).maybeSingle();
        if (group == null) return;
        
        await Supabase.instance.client.from('messages').insert({
          'room_id': group['id'],
          'sender_id': Supabase.instance.client.auth.currentUser?.id,
          'content': _msgCtrl.text.trim(),
          'is_broadcast': true,
        });
        
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Broadcast sent to group!')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _markAllAsCompleted() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Mark Trip as Completed?'),
        content: const Text('This will mark all participants in this group as having completed the trip. They will receive completion badges and XP.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirm', style: TextStyle(color: Colors.green))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      setState(() => _isLoading = true);
      
      final db = DatabaseService();
      // Get trip details for distance
      final tripRes = await Supabase.instance.client.from('trips').select('distance').eq('id', widget.tripId).single();
      double dist = double.tryParse(tripRes['distance']?.toString() ?? '10') ?? 10.0;

      for (var booking in _usersInGroup) {
        if (booking['profiles']?['id'] != null) {
          await db.completeTrip(
            userId: booking['profiles']['id'],
            tripId: widget.tripId,
            distance: dist,
          );
        }
      }
      
      // MARK GROUP AS COMPLETED
      await Supabase.instance.client.from('trip_groups').update({'status': 'completed'}).eq('trip_id', widget.tripId).eq('departure_date', widget.date);
      
      _hasChanges = true;
      _fetchUsers();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trip marked as COMPLETED! All participants awarded XP.')));
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _refundBooking(dynamic booking) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('REFUND BOOKING?'),
        content: Text('Authorize a refund of ₹${booking['total_price']} for ${booking['profiles']?['full_name']}? This will cancel the booking and record a refund.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('ABORT')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('CONFIRM REFUND', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      setState(() => _isLoading = true);
      await Supabase.instance.client.from('bookings').update({
        'payment_status': 'Refunded',
        'status': 'Cancelled',
      }).eq('id', booking['id']);

      await Supabase.instance.client.from('payment_logs').insert({
        'user_id': booking['user_id'],
        'amount': booking['total_price'],
        'payment_type': 'REFUND',
        'booking_id': booking['id'],
        'is_incoming': false,
      });

      _hasChanges = true;
      _fetchUsers();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Refund Error: $e')));
      }
    }
  }

  Future<void> _updatePaymentStatus(String bookingId, String currentStatus) async {
    final List<String> statuses = ['Pending', 'Partial', 'Paid'];
    final newStatus = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Update Payment Status'),
        children: statuses.map((s) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, s),
          child: Text(s, style: TextStyle(color: s == 'Paid' ? Colors.green : (s == 'Partial' ? Colors.orange : null))),
        )).toList(),
      ),
    );

    if (newStatus != null && newStatus != currentStatus) {
      setState(() => _isLoading = true);
      await Supabase.instance.client.from('bookings').update({'payment_status': newStatus}).eq('id', bookingId);
      
      if (newStatus == 'Paid') {
        final bRes = await Supabase.instance.client.from('bookings').select('user_id, total_price, trip_name').eq('id', bookingId).single();
        await Supabase.instance.client.from('payment_logs').insert({
          'user_id': bRes['user_id'],
          'amount': bRes['total_price'],
          'payment_type': 'CREDIT',
          'description': 'Manual Verification: ${bRes['trip_name'] ?? "Trip"}',
          'is_incoming': true,
          'booking_id': bookingId,
        });
      }
      _hasChanges = true;
      _fetchUsers();
    }
  }

  Future<void> _toggleLeader(String bookingId, bool isAlreadyLeader) async {
    try {
      setState(() => _isLoading = true);
      await Supabase.instance.client.from('bookings').update({'is_leader': !isAlreadyLeader}).eq('id', bookingId);
      _hasChanges = true;
      _fetchUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isAlreadyLeader ? 'Leader status removed' : 'Appointed as Trip Leader!')));
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _hasChanges);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.tripTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.campaign_outlined),
              onPressed: _showBroadcastDialog,
              tooltip: 'Broadcast to Group',
            ),
            IconButton(
              icon: const Icon(Icons.task_alt),
              onPressed: _markAllAsCompleted,
              tooltip: 'Mark All Completed',
            ),
          ],
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _hasChanges),
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              color: Theme.of(context).primaryColor.withOpacity(0.05),
              child: Row(
                children: [
                  Icon(Icons.event_available, color: Theme.of(context).primaryColor, size: 30),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Trip Schedule:', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.grey, fontWeight: FontWeight.bold)),
                      Text(widget.date, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _usersInGroup.isEmpty
                      ? const Center(child: Text('No users in this group.', style: TextStyle(fontSize: 16)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _usersInGroup.length,
                          itemBuilder: (context, index) {
                            final booking = _usersInGroup[index];
                            final profileName = booking['profiles']?['full_name'] ?? 'Guest / Manual Booking';
                            final travelers = booking['travelers'] ?? 1;

                             final paymentStatus = booking['payment_status'] ?? 'Pending';
                             final addons = (booking['booking_addons'] as List?) ?? [];

                             return FadeInUp(
                               duration: Duration(milliseconds: 300 + (index * 100)),
                               child: Container(
                                 margin: const EdgeInsets.only(bottom: 12),
                                 padding: const EdgeInsets.all(16),
                                 decoration: BoxDecoration(
                                   color: Theme.of(context).cardColor,
                                   borderRadius: BorderRadius.circular(20),
                                   boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                                   border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.05)),
                                 ),
                                 child: Column(
                                   children: [
                                     Row(
                                       children: [
                                         Stack(
                                           alignment: Alignment.bottomRight,
                                           children: [
                                              UserAvatar(radius: 22, imageUrl: booking['profiles']?['avatar_url'], name: profileName),
                                              if (booking['profiles']?['aadhar_url'] != null)
                                                const Positioned(
                                                  bottom: 0,
                                                  right: 0,
                                                  child: Icon(Icons.verified, size: 12, color: Colors.blue),
                                                ),
                                           ],
                                         ),
                                         const SizedBox(width: 14),
                                         Expanded(
                                           child: Column(
                                             crossAxisAlignment: CrossAxisAlignment.start,
                                             children: [
                                               Row(
                                                 children: [
                                                   Expanded(
                                                     child: Text(
                                                       profileName.toUpperCase(),
                                                       style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: -0.2),
                                                       overflow: TextOverflow.ellipsis,
                                                     ),
                                                   ),
                                                   if (booking['is_leader'] == true)
                                                     Container(
                                                       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                       decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(4)),
                                                       child: const Text('LEADER', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
                                                     ),
                                                 ],
                                               ),
                                               const SizedBox(height: 2),
                                               Text(
                                                 'Travelers: $travelers • ${booking['payment_method'] ?? 'UPI'}',
                                                 style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                                               ),
                                             ],
                                           ),
                                         ),
                                         PopupMenuButton<String>(
                                           icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                                           onSelected: (val) {
                                             if (val == 'payment') _updatePaymentStatus(booking['id'], paymentStatus);
                                             if (val == 'leader') _toggleLeader(booking['id'], booking['is_leader'] == true);
                                             if (val == 'refund') _refundBooking(booking);
                                             if (val == 'remove') _removeUserFromGroup(booking['id']);
                                           },
                                           itemBuilder: (context) => [
                                             const PopupMenuItem(value: 'payment', child: Text('Manage Payment')),
                                             PopupMenuItem(
                                               value: 'leader', 
                                               child: Text(booking['is_leader'] == true ? 'Remove Leader' : 'Appoint Leader', style: const TextStyle(color: Colors.blue))
                                             ),
                                             const PopupMenuItem(value: 'refund', child: Text('Issue Refund', style: TextStyle(color: Colors.orange))),
                                             const PopupMenuItem(value: 'remove', child: Text('Remove User', style: TextStyle(color: Colors.red))),
                                           ],
                                         ),
                                       ],
                                     ),
                                     if (addons.isNotEmpty) ...[
                                       const Divider(height: 24),
                                       ...addons.map((a) => Padding(
                                         padding: const EdgeInsets.only(bottom: 6),
                                         child: Row(
                                           children: [
                                             const Icon(Icons.shopping_bag_outlined, size: 12, color: Colors.orange),
                                             const SizedBox(width: 8),
                                             Text('${a['gears']?['name'] ?? 'Gear'} (x${a['quantity']})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                             const Spacer(),
                                             Text('₹${a['price_at_booking']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                                           ],
                                         ),
                                       )),
                                     ],
                                     const SizedBox(height: 12),
                                     Container(
                                       padding: const EdgeInsets.all(12),
                                       decoration: BoxDecoration(
                                         color: Theme.of(context).primaryColor.withOpacity(0.03),
                                         borderRadius: BorderRadius.circular(12),
                                       ),
                                       child: Row(
                                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                         children: [
                                           Column(
                                             crossAxisAlignment: CrossAxisAlignment.start,
                                             children: [
                                               const Text('TOTAL PAYABLE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
                                               Text('₹${booking['total_price']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.green)),
                                             ],
                                           ),
                                           Container(
                                             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                             decoration: BoxDecoration(
                                               color: paymentStatus == 'Paid' ? Colors.green : Colors.orange,
                                               borderRadius: BorderRadius.circular(8),
                                             ),
                                             child: Text(
                                               paymentStatus.toUpperCase(),
                                               style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                                             ),
                                           ),
                                         ],
                                       ),
                                     ),
                                   ],
                                 ),
                               ),
                             );
                           },
                         ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addUserManually,
          backgroundColor: Theme.of(context).primaryColor,
          icon: const Icon(Icons.person_add, color: Colors.white),
          label: const Text('Add User', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}
