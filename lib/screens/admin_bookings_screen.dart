import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/user_avatar.dart';

class AdminBookingsScreen extends StatefulWidget {
  final bool showAppBar;
  const AdminBookingsScreen({super.key, this.showAppBar = false});

  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _allBookings = [];
  List<Map<String, dynamic>> _groupedMissions = [];

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    setState(() => _isLoading = true);
    try {
      final response = await _client
          .from('bookings')
          .select('*, trek:treks(*), profiles!inner(*), booking_addons(*, gears(*))')
          .order('trek_date', ascending: true);

      if (mounted) {
        Map<String, List<dynamic>> groups = {};
        for (var b in response) {
          String key = "${b['trek_id']}_${b['trek_date']}";
          if (!groups.containsKey(key)) groups[key] = [];
          groups[key]!.add(b);
        }

        List<Map<String, dynamic>> groupedList = [];
        groups.forEach((key, members) {
          groupedList.add({
            'trek': members[0]['trek'],
            'date': members[0]['trek_date'],
            'members': members,
            'total_seats': members.length,
          });
        });

        setState(() {
          _allBookings = response;
          _groupedMissions = groupedList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: widget.showAppBar ? AppBar(
        title: const Text('MISSION CONTROL', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 14)),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ) : null,
      body: RefreshIndicator(
        onRefresh: _fetchBookings,
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _groupedMissions.length,
              itemBuilder: (context, index) {
                final mission = _groupedMissions[index];
                final trek = mission['trek'];
                final date = DateTime.parse(mission['date']);
                final members = mission['members'] as List;

                return FadeInUp(
                  delay: Duration(milliseconds: index * 50),
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: InkWell(
                      onTap: () => _showGroupManagement(members[0]),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(trek?['title'] ?? 'Strategic Expedition', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                      const SizedBox(height: 4),
                                      Text(DateFormat('EEEE, MMM dd yyyy').format(date), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                  child: Text('${members.length} TREKKERS', style: const TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
                                )
                              ],
                            ),
                            const Divider(height: 30),
                            const Text('SQUADRON ROSTER', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 44,
                              child: Stack(
                                children: List.generate(members.length > 5 ? 6 : members.length, (i) {
                                  // Drawing in reverse so index 0 is on top
                                  final int displayCount = members.length > 5 ? 6 : members.length;
                                  final int drawingIndex = displayCount - 1 - i;
                                  
                                  if (drawingIndex == 5) {
                                     return Positioned(
                                       left: drawingIndex * 22.0,
                                       child: CircleAvatar(
                                         radius: 18,
                                         backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                                         child: Text('+${members.length - 5}', style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                                       ),
                                     );
                                  }
                                  
                                  final p = members[drawingIndex]['profiles'];
                                  return Positioned(
                                    left: drawingIndex * 22.0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle, 
                                        border: Border.all(color: isDark ? const Color(0xFF1E293B) : Colors.white, width: 2.5),
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                                      ),
                                      child: UserAvatar(imageUrl: p['avatar_url'], name: p['full_name'], radius: 18),
                                    ),
                                  );
                                }),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _showGroupManagement(members[0]),
                                    icon: const Icon(Icons.groups, size: 16),
                                    label: const Text('MANAGE MISSION SQUAD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(context).primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
      ),
    );
  }

  void _showCostBreakup(Map<String, dynamic> booking) {
    final addons = (booking['booking_addons'] as List?) ?? [];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            const Text('FINANCIAL DOSSIER', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1)),
            const SizedBox(height: 20),
            _breakupRow('Base Trek Fee', '₹${booking['trek_price']}'),
            _breakupRow('Pickup Service', '₹${booking['pickup_price']}'),
            ...addons.map((a) => _breakupRow('Rental: ${a['gears']['name']} (x${a['quantity']})', '₹${a['price_at_booking']}')),
            const Divider(height: 30),
            _breakupRow('TOTAL COMMAND VALUE', '₹${booking['total_price']}', isTotal: true),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showContactHiker(Map<String, dynamic> booking) {
    final profile = booking['profiles'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (c) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UserAvatar(imageUrl: profile['avatar_url'], name: profile['full_name'], radius: 30),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile['full_name'] ?? 'Tracker', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(profile['role'] ?? 'user', style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Contact Info', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 12),
            _contactItem(Icons.phone, 'Phone Number', profile['phone_number'] ?? 'Not Provided'),
            _contactItem(Icons.email, 'Email Address', profile['email'] ?? 'Not Linked'),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (profile['phone_number'] != null) launchUrl(Uri.parse('tel:${profile['phone_number']}'));
                    },
                    icon: const Icon(Icons.call),
                    label: const Text('Call'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                       if (profile['phone_number'] != null) launchUrl(Uri.parse('sms:${profile['phone_number']}'));
                    },
                    icon: const Icon(Icons.message),
                    label: const Text('Text'),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _showGroupManagement(Map<String, dynamic> selectedBooking) {
    final trekId = selectedBooking['trek_id'];
    final trekDate = selectedBooking['trek_date'];
    final members = _allBookings.where((b) => b['trek_id'] == trekId && b['trek_date'] == trekDate).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 24),
                Text('${selectedBooking['trek']?['title'] ?? 'Expedition'} Squadron', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text('Deployment Date: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(trekDate))}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView.builder(
                    itemCount: members.length,
                    itemBuilder: (context, i) {
                      final m = members[i];
                      final p = m['profiles'];
                      final double totalPrice = double.tryParse(m['total_price'].toString()) ?? 0;
                      final double paidAmt = double.tryParse((m['paid_amount'] ?? 0).toString()) ?? 0;
                      final double dueAmt = totalPrice - paidAmt;
                      final String payStatus = m['payment_status'] ?? 'Pending';
                      final Color payColor = payStatus == 'Paid' ? Colors.green : payStatus == 'Partial' ? Colors.orange : Colors.red;
                      final String email = p['email'] ?? m['profiles']?['email'] ?? 'No email';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(backgroundImage: p['avatar_url'] != null ? NetworkImage(p['avatar_url']) : null, child: p['avatar_url'] == null ? const Icon(Icons.person) : null),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(p['full_name'] ?? 'Personnel', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                            if (p['role'] == 'admin' || p['role'] == 'guide') ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                decoration: BoxDecoration(color: (p['role'] == 'admin' ? Colors.red : Colors.blue).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                                child: Text(p['role']!.toUpperCase(), style: TextStyle(color: (p['role'] == 'admin' ? Colors.red : Colors.blue), fontSize: 8, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(email, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                        Text(p['phone_number'] ?? 'No phone', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: payColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                        child: Text(payStatus.toUpperCase(), style: TextStyle(color: payColor, fontSize: 9, fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(height: 4),
                                      Text('₹${paidAmt.toInt()} / ₹${totalPrice.toInt()}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                      if (dueAmt > 0)
                                        Text('Due: ₹${dueAmt.toInt()}', style: const TextStyle(fontSize: 9, color: Colors.red, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _smallAction(Icons.info_outline, 'Details', () => _showContactHiker(m)),
                                  const SizedBox(width: 8),
                                  _smallAction(Icons.payments_outlined, 'Payment', () => _managePayment(m)),
                                  const SizedBox(width: 8),
                                  _smallAction(Icons.receipt_long, 'Breakup', () => _showCostBreakup(m)),
                                  if (p['role'] != 'guide') ...[
                                    const SizedBox(width: 8),
                                    _smallAction(Icons.hiking, 'Set Guide', () => _appointGuide(m['id'], trekId, trekDate, setSheetState)),
                                  ],
                                ],
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
          );
        },
      ),
    );
  }

  Widget _smallAction(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
          child: Column(
            children: [
              Icon(icon, size: 16, color: Theme.of(context).primaryColor),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
            ],
          ),
        ),
      ),
    );
  }

  void _appointGuide(String bookingId, String trekId, String trekDate, StateSetter setSheetState) async {
    // Get list of guides
    try {
      final guides = await _client.from('profiles').select().eq('role', 'guide');
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Appoint Trek Guide'),
          content: SizedBox(
            width: 300,
            height: 300,
            child: ListView.builder(
              itemCount: (guides as List).length,
              itemBuilder: (ctx, i) {
                final g = guides[i];
                return ListTile(
                  leading: UserAvatar(imageUrl: g['avatar_url'], name: g['full_name'], radius: 18),
                  title: Text(g['full_name'] ?? 'Guide', style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () async {
                    // Create a booking for the guide on the same trek date
                    try {
                      await _client.from('bookings').insert({
                        'user_id': g['id'],
                        'trek_id': trekId,
                        'trek_date': trekDate,
                        'total_price': 0,
                        'trek_price': 0,
                        'pickup_price': 0,
                        'paid_amount': 0,
                        'payment_status': 'Paid',
                        'status': 'Confirmed',
                        'pickup_location': 'Guide Assignment',
                      });
                      Navigator.pop(c);
                      _fetchBookings();
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${g['full_name']} appointed as guide!')));
                    } catch (e) {
                      Navigator.pop(c);
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                );
              },
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading guides: $e')));
    }
  }

  void _managePayment(Map<String, dynamic> booking) async {
    final _paidCtrl = TextEditingController(text: (booking['paid_amount'] ?? booking['total_price']).toString());
    final total = double.tryParse(booking['total_price'].toString()) ?? 0;

    final result = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Log Transaction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Total Amount Due: ₹$total', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: _paidCtrl,
              decoration: const InputDecoration(labelText: 'Amount Received (INR)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            const Text('Status will update to Partial or Paid automatically.', style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Update')),
        ],
      )
    );

    if (result == true) {
      final double paid = double.tryParse(_paidCtrl.text) ?? 0;
      String status = 'Pending';
      if (paid >= total) status = 'Paid';
      else if (paid > 0) status = 'Partial';

      try {
        await _client.from('bookings').update({
          'paid_amount': paid,
          'payment_status': status,
        }).eq('id', booking['id']);
        
        // Also update local list to avoid fetch if needed, but fetch is safer
        _fetchBookings();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment records updated.')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Widget _breakupRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isTotal ? Colors.black : Colors.grey, fontWeight: isTotal ? FontWeight.w900 : FontWeight.normal, fontSize: isTotal ? 16 : 14)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: isTotal ? 18 : 14, color: isTotal ? Colors.green : Colors.black)),
        ],
      ),
    );
  }

  Widget _contactItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).primaryColor),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }
}
