import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/user_avatar.dart';

class AdminGroupDetailsScreen extends StatefulWidget {
  final String tripId;
  final String? tripDate;
  const AdminGroupDetailsScreen({
    super.key,
    required this.tripId,
    this.tripDate,
  });

  @override
  State<AdminGroupDetailsScreen> createState() =>
      _AdminGroupDetailsScreenState();
}

class _AdminGroupDetailsScreenState
    extends State<AdminGroupDetailsScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _participants = [];
  List<dynamic> _assignedStaff = [];

  int _cleared = 0;
  int _pending = 0;
  double _valuePending = 0;

  @override
  void initState() {
    super.initState();
    _fetchGroup();
  }

  Future<void> _fetchGroup() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch Core Participants
      final res = await _client
          .from('bookings')
          .select('*, profiles(*)')
          .eq('trip_id', widget.tripId);

      // 2. Tactical Date Normalization
      final String filterDate = (widget.tripDate ?? '').toString().split('T')[0].split(' ')[0].trim();
      debugPrint('GROUP ANALYTICS: Target Trip=${widget.tripId} Date=$filterDate');
      
      final List<dynamic> groupParticipants = res.where((b) {
         final dRaw = (b['trip_date'] ?? b['booking_date'] ?? b['departure_date'] ?? '').toString().trim();
         final String d = dRaw.split('T')[0].split(' ')[0].trim();
         final bool match = d == filterDate || dRaw.contains(filterDate);
         if (res.length < 10) debugPrint('GROUP EVAL: dRaw=$dRaw vs filterDate=$filterDate -> Match=$match');
         return match;
      }).toList();

      debugPrint('GROUP STRENGTH: Filtered Count=${groupParticipants.length}');

      // 3. Decoupled Staff Intelligence (Resilient Fetch)
      List<dynamic> groupStaff = [];
      try {
        final List<dynamic> staffList = await _client.from('trip_group_staff').select().eq('trip_id', widget.tripId);
        
        // Manual Profile Join for absolute Resilience
        final List<String> userIds = staffList.map((s) => s['user_id'].toString()).toList();
        final List<dynamic> profilesRes = userIds.isEmpty ? [] : await _client.from('profiles').select().inFilter('id', userIds);
        
        final Map<String, dynamic> profileMap = { for (var p in profilesRes) p['id'] : p };

        groupStaff = staffList.where((s) {
           final dRaw = (s['deployment_date'] ?? '').toString().trim();
           final String d = dRaw.split('T')[0].split(' ')[0].trim();
           final bool match = d == filterDate || dRaw.contains(filterDate);
           
           // Link profile manually
           s['profiles'] = profileMap[s['user_id']];
           
           return match;
        }).toList();
        
      } catch (staffErr) {
        debugPrint('STAFF SYNC FAILURE: $staffErr');
      }

      int clearedCount = 0;
      int pendingCount = 0;
      double pendingVal = 0;

      for (var b in groupParticipants) {
        // RADICAL LOGISTICS SYNC: Fetch Addons/Gear for this specific booking
        List<dynamic> addons = [];
        try {
           final addonsRes = await _client.from('booking_addons').select('*, gears(*)').eq('booking_id', b['id']);
           addons = addonsRes;
        } catch (_) {}
        b['booking_addons'] = addons;

        // Ensure paid_amount and total_price are correct
        final double paid = double.tryParse(b['paid_amount']?.toString() ?? '0') ?? 0;
        final double total = double.tryParse(b['total_price']?.toString() ?? '0') ?? 0;
        final double due = (total - paid).clamp(0, double.infinity);

        b["_computed_total"] = total;
        b["_computed_due"] = due;

        if (due <= 0) {
          clearedCount++;
        } else {
          pendingCount++;
          pendingVal += due;
        }
      }

      if (mounted) {
        setState(() {
          _participants = groupParticipants;
          _assignedStaff = groupStaff;

          _cleared = clearedCount;
          _pending = pendingCount;
          _valuePending = pendingVal;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        debugPrint('TREKWITHMUSSAFIRR INFO FATAL: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('FATAL: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'GROUP DETAILS',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1, color: Colors.blueAccent),
            onPressed: _showAddTrip,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildSquadHeader(),
                const SizedBox(height: 32),
                _buildTopDeploymentActions(),
                if (_assignedStaff.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  const Text('ASSIGNED CONTROL STAFF', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.indigo, letterSpacing: 1.5)),
                  const SizedBox(height: 16),
                  ..._assignedStaff.map((s) => _buildStaffCard(s)).toList(),
                ],
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('DEPLOYED STAFF', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.grey, letterSpacing: 1.5)),
                    _infoChip('${_participants.length} TOTAL', Colors.blueGrey),
                  ],
                ),
                const SizedBox(height: 16),
                ..._participants.map((p) => _buildParticipantCard(p)).toList(),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildTopDeploymentActions() {
    return Row(
      children: [
        Expanded(
          child: _actionBtn(
            Icons.person_add_alt_1_outlined,
            'ADD TRAVELER',
            Colors.blueAccent,
            Colors.white,
            onTap: _showAddTrip,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionBtn(
            Icons.badge_outlined,
            'ASSIGN STAFF',
            const Color(0xFF1E293B),
            Colors.white,
            onTap: _showDeployEmployee,
          ),
        ),
      ],
    );
  }

  Widget _buildSquadHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.01), blurRadius: 10),
        ],
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Group Status',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: isDark ? Colors.white : Colors.black87),
              ),
              const Icon(
                Icons.analytics_outlined,
                color: Color(0xFF1976D2),
                size: 24,
              ),
            ],
          ),
          Text(
            'Assignment: ${widget.tripDate != null ? DateFormat('EEEE, MMM dd yyyy').format(DateTime.parse(widget.tripDate!)) : "Pending Schedule"}',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _headerStat('${_participants.length}', 'TRAVELERS', Colors.blue),
              _headerStat(
                '₹${(_participants.length * 8000).toInt()}',
                'EST. REVENUE',
                Colors.green,
              ),
              _headerStat('$_cleared', 'CLEARED', Colors.teal),
              _headerStat('$_pending', 'PENDING', Colors.orange),
            ],
          ),
          const Divider(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'BALANCE DUE',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '₹${_valuePending.toInt()}',
                style: const TextStyle(
                  color: Color(0xFFFA8072),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String val, String label, Color color) {
    return Column(
      children: [
        Text(
          val,
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 8,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantCard(dynamic b) {
    final profile = b['profiles'];
    final paid = double.tryParse(b['paid_amount']?.toString() ?? '0') ?? 0;
    final total = b['_computed_total'] ?? 0.0;
    final due = b['_computed_due'] ?? 0.0;
    final bool isCleared = due <= 0;
    final bool isExtreme = due > 5000;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.04), blurRadius: 20, offset: const Offset(0, 10)),
        ],
        border: Border.all(color: isExtreme ? Colors.redAccent.withOpacity(0.2) : (isDark ? Colors.white10 : Colors.grey.shade100)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Column(
          children: [
            _cardHeader(profile, isCleared, due, profile?['id']),
            Container(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade50),
            _cardBody(b, paid, total, due, isCleared),
          ],
        ),
      ),
    );
  }

  Widget _cardHeader(dynamic profile, bool isCleared, double due, String? userId) {
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          Stack(
            children: [
              UserAvatar(radius: 30, imageUrl: profile?['avatar_url'], name: profile?['full_name']),
              if (isCleared)
                Positioned(
                  right: 0, bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                    child: const Icon(Icons.check, size: 10, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile?['full_name']?.toUpperCase() ?? 'STAFF', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: -0.5, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _docIndicator('DOCS', profile?['aadhar_url'] != null && profile?['medical_certificate_url'] != null),
                    const SizedBox(width: 8),
                    _docIndicator('VERIFIED', profile?['phone_number'] != null),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: (isCleared ? Colors.green : Colors.orange).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        children: [
                          Icon(isCleared ? Icons.shield_outlined : Icons.timer_outlined, color: isCleared ? Colors.green : Colors.orange, size: 10),
                          const SizedBox(width: 4),
                          Text(isCleared ? 'CLEARED' : 'PENDING', style: TextStyle(color: isCleared ? Colors.green : Colors.orange, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _docIndicator(String label, bool ok) {
    return Row(
      children: [
        Icon(ok ? Icons.check_circle : Icons.error_outline, color: ok ? Colors.blue : Colors.grey.shade400, size: 10),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: ok ? Colors.blue.shade700 : Colors.grey, fontSize: 7, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _cardBody(dynamic b, double paid, double total, double due, bool isCleared) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.blueGrey.shade50.withOpacity(0.3)),
      child: Column(
        children: [
          Row(
            children: [
              _statMini('COMMITTED', '₹${total.toInt()}', isDark ? Colors.white70 : Colors.black),
              const SizedBox(width: 10),
              _statMini('PAID', '₹${paid.toInt()}', Colors.green.shade700),
              const SizedBox(width: 10),
              _statMini('REMAINING', '₹${due.toInt()}', isCleared ? Colors.grey : Colors.redAccent),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _actionBtn(
                  Icons.receipt_long_outlined, 'HISTORY', isDark ? Colors.white10 : Colors.white, isDark ? Colors.white70 : Colors.black87,
                  border: true,
                  onTap: () => _showFinancialRecord(b),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _actionBtn(
                  Icons.add_card_outlined, 'LOG PAY', isDark ? Colors.white10 : Colors.black, isDark ? Colors.white : Colors.white,
                  onTap: () => _showLogTransaction(b),
                ),
              ),
              const SizedBox(width: 12),
              _iconCircleBtn(Icons.delete_outline, Colors.redAccent, () => _confirmRemove(b)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statMini(String label, String val, Color c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Text(label, style: const TextStyle(fontSize: 6, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(val, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: c)),
        ]),
      ),
    );
  }

  Widget _iconCircleBtn(IconData icon, Color c, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: c.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: c),
      ),
    );
  }

  Widget _cardStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }

  Widget _docIcon(bool verified, IconData icon) {
    return Icon(icon, size: 14, color: verified ? Colors.green : Colors.grey.shade300);
  }

  void _showFinancialRecord(dynamic b) {
    final double total = double.tryParse(b['total_price']?.toString() ?? '0') ?? 0;
    final double paid = double.tryParse(b['paid_amount']?.toString() ?? '0') ?? 0;
    final double tripBase = double.tryParse(b['trip_price']?.toString() ?? '0') ?? 0;
    final double pkgUpgrade = double.tryParse(b['package_price']?.toString() ?? '0') ?? 0;
    final double pickupLogistics = double.tryParse(b['pickup_fee']?.toString() ?? '0') ?? 0;
    
    final List<dynamic> addons = (b['booking_addons'] as List?) ?? [];
    final double gearTotal = addons.fold(0.0, (sum, a) => sum + (double.tryParse(a['price_at_booking']?.toString() ?? '0') ?? 0));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(30),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: SizedBox(width: 40, child: Divider(thickness: 4)),
              ),
              const SizedBox(height: 24),
              Text(
                'FINANCIAL RECORD',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 1,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 32),
              _documentsRow('Sector Entry (Base)', '₹${tripBase.toInt()}'),
              if (pkgUpgrade > 0) _documentsRow('Tactical Package Ops', '₹${pkgUpgrade.toInt()}', color: Colors.orange),
              if (pickupLogistics > 0) _documentsRow('Field Logistics (Pickup)', '₹${pickupLogistics.toInt()}', color: Colors.teal),
              if (addons.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('ARMORY / RENTAL BREAKDOWN', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                const SizedBox(height: 12),
                ...addons.map((a) {
                  final g = a['gears'];
                  final n = g != null ? (g['name'] ?? 'Gear') : 'Rental Item';
                  final qty = a['quantity'] ?? 1;
                  final p = double.tryParse(a['price_at_booking']?.toString() ?? '0') ?? 0;
                  return _documentsRow('• $n (x$qty)', '₹${p.toInt()}');
                }),
                _documentsRow('Total Armory Value', '₹${gearTotal.toInt()}', color: Colors.blueAccent),
              ],
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   const Text('TOTAL CONTRACT VALUE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                   Text('₹${total.toInt()}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF2E7B32))),
                ],
              ),
              _documentsRow('Credits Received', '₹${paid.toInt()}', color: Colors.green),
              _documentsRow('Remaining Liability', '₹${(total - paid).toInt()}', color: (total - paid) > 0 ? Colors.redAccent : Colors.grey),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _documentsRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: color ?? (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogTransaction(dynamic b) {
    final amtCtrl = TextEditingController();
    String method = 'UPI';
    List<dynamic> history = [];
    bool historyLoading = true;

    Future<void> fetchHistory(StateSetter setModalState) async {
      try {
        final res = await _client
            .from('payment_logs')
            .select()
            .eq('booking_id', b['id'])
            .order('created_at', ascending: false);
        history = res;
        setModalState(() => historyLoading = false);
      } catch (_) {
        setModalState(() => historyLoading = false);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          if (historyLoading) {
            fetchHistory(setModalState);
          }
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            color: Theme.of(context).cardColor,
            padding: EdgeInsets.fromLTRB(
              30,
              30,
              30,
              MediaQuery.of(ctx).viewInsets.bottom + 30,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'LOG TRANSACTION',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: isDark ? Colors.white : Colors.black87),
                ),
                const SizedBox(height: 24),
                Text(
                  'TRIPKER: ${b['profiles']?['full_name']}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amtCtrl,
                  decoration: InputDecoration(
                    hintText: 'Amount Received (INR)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  children: ['UPI', 'CASH', 'CARD', 'TRANSFER']
                      .map(
                        (m) => ChoiceChip(
                          label: Text(m),
                          selected: method == m,
                          onSelected: (s) => setModalState(() => method = m),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      double amt = double.tryParse(amtCtrl.text) ?? 0;
                      if (amt <= 0) return;
                      try {
                        await _client.from('payment_logs').insert({
                          'booking_id': b['id'],
                          'amount': amt,
                          'payment_type': method,
                          'is_incoming': true,
                          'created_at': DateTime.now().toIso8601String(),
                        });

                        double newPaid =
                            (double.tryParse(b['paid_amount'].toString()) ??
                                0) +
                            amt;
                        String status =
                            (newPaid >=
                                (double.tryParse(b['total_price'].toString()) ??
                                    0))
                            ? 'Paid'
                            : 'Partial';

                        await _client
                            .from('bookings')
                            .update({
                              'paid_amount': newPaid.round(),
                              'payment_status': status,
                            })
                            .eq('id', b['id']);

                        Navigator.pop(ctx);
                        _fetchSquad();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Transaction Logged Successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to log transaction: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      'SUBMIT LOG',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'TRANSACTION HISTORY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (historyLoading)
                  const Center(child: CircularProgressIndicator())
                else if (history.isEmpty)
                  const Center(
                    child: Text(
                      'No previous logs.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  )
                else
                  ...history
                      .map(
                        (h) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    h['payment_type'] ?? 'UPI',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    h['created_at'] != null
                                        ? h['created_at'].substring(0, 10)
                                        : 'Today',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '₹${h['amount'].toInt()}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddTrip() {
    String search = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMe) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.all(30),
          child: Column(
            children: [
              Text(
                'DEPLOY TRIPKER REGISTRY',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 1.5,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                onChanged: (v) => setMe(() => search = v),
                decoration: InputDecoration(
                  hintText: 'Search by name or email...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _client
                      .from('profiles')
                      .stream(primaryKey: ['id'])
                      .order('full_name'),
                  builder: (context, snap) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    if (!snap.hasData)
                      return const Center(child: CircularProgressIndicator());
                    final users = snap.data!
                        .where(
                          (u) =>
                              (u['full_name'] ?? '').toLowerCase().contains(
                                search.toLowerCase(),
                              ) ||
                              (u['email'] ?? '').toLowerCase().contains(
                                search.toLowerCase(),
                              ),
                        )
                        .toList();
                    return ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, i) {
                        final u = users[i];
                        final name = u['full_name'] ?? 'Trip';
                        bool isAlreadyPinned = _participants.any(
                          (p) => p['user_id'] == u['id'],
                        );

                        return ListTile(
                          leading: UserAvatar(
                            imageUrl: u['avatar_url'],
                            name: name,
                            radius: 20,
                          ),
                          title: Text(name, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                          subtitle: Text(u['email'] ?? u['phone_number'] ?? '', style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey)),
                          trailing: Icon(
                            isAlreadyPinned
                                ? Icons.check_circle
                                : Icons.add_circle,
                            color: isAlreadyPinned ? Colors.blue : Colors.green,
                          ),
                          onTap: isAlreadyPinned
                              ? null
                              : () async {
                                  try {
                                    await _client.from('bookings').insert({
                                      'user_id': u['id'],
                                      'trip_id': widget.tripId,
                                      'payment_status': 'Pending',
                                      'paid_amount': 0,
                                      'total_price': 8000,
                                      'trip_price': 8000,
                                      'trip_date': widget.tripDate != null && widget.tripDate!.isNotEmpty 
                                          ? (widget.tripDate!.contains(',') ? DateFormat('EEEE, MMM dd yyyy').parse(widget.tripDate!).toIso8601String() : widget.tripDate)
                                          : DateTime.now().toIso8601String(),
                                      'booking_date': DateTime.now().toIso8601String(),
                                    });
                                    Navigator.pop(ctx);
                                    _fetchSquad();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '$name deployed successfully.',
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Assignment failed: $e'),
                                      ),
                                    );
                                  }
                                },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeployEmployee() {
    List<dynamic> currentStaff = [];
    bool staffLoading = true;

    Future<void> fetchStaff(StateSetter setModalState) async {
      try {
        final res = await _client
            .from('trip_group_staff')
            .select()
            .eq('trip_id', widget.tripId);
        currentStaff = res;
        setModalState(() => staffLoading = false);
      } catch (_) {
        setModalState(() => staffLoading = false);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          if (staffLoading) fetchStaff(setModalState);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 30),
              const Text(
                'DEPLOY TREKWITHMUSSAFIRR STAFF',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 400,
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _client
                      .from('profiles')
                      .stream(primaryKey: ['id'])
                      .order('full_name'),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());
                    final staffCandidates = snapshot.data!
                        .where((p) => p['role'] != 'user')
                        .toList();
                    return ListView.builder(
                      itemCount: staffCandidates.length,
                      itemBuilder: (context, i) {
                        final s = staffCandidates[i];
                        bool isAlreadyDeployed = currentStaff.any(
                          (cs) => cs['user_id'] == s['id'],
                        );
                        return ListTile(
                          leading: UserAvatar(
                            imageUrl: s['avatar_url'],
                            name: s['full_name'],
                            radius: 20,
                          ),
                          title: Text(s['full_name'] ?? 'Employee'),
                          subtitle: Text(
                            s['role']?.toString().toUpperCase() ?? 'STAFF',
                          ),
                          trailing: Icon(
                            isAlreadyDeployed
                                ? Icons.verified
                                : Icons.add_circle_outline,
                            color: isAlreadyDeployed
                                ? Colors.green
                                : Colors.blue,
                          ),
                          onTap: isAlreadyDeployed
                              ? null
                              : () async {
                                  try {
                                    String rawDate = DateTime.now().toIso8601String();
                                    if (widget.tripDate != null && widget.tripDate!.isNotEmpty) {
                                      try {
                                        if (widget.tripDate!.contains(',')) {
                                          rawDate = DateFormat('EEEE, MMM dd yyyy').parse(widget.tripDate!).toIso8601String();
                                        } else {
                                          rawDate = widget.tripDate!;
                                        }
                                      } catch (_) {}
                                    }

                                    final existing = await _client.from('trip_group_staff')
                                      .select()
                                      .eq('trip_id', widget.tripId)
                                      .eq('user_id', s['id'])
                                      .eq('deployment_date', rawDate)
                                      .maybeSingle();
                                    if (existing != null) throw 'Employee already deployed to this trip on this date.';

                                    // ROLE NORMALIZATION: Ensure it matches the check constraint in DB
                                    String role = (s['role'] ?? 'staff').toString().toLowerCase();
                                    if (role == 'admin') role = 'staff'; 

                                    // Infrastructure Sync: Ensure the global group entry exists so it shows in chats/groups
                                    String staffName = s['full_name'] ?? 'Staff';
                                    if (staffName.toLowerCase() == 'null') staffName = 'Staff';
                                    
                                    await _client.from('trip_groups').upsert({
                                      'trip_id': widget.tripId,
                                      'departure_date': rawDate,
                                      'group_name': '$staffName\'s Assignment Group',
                                    });

                                    await _client.from('trip_group_staff').insert({
                                      'trip_id': widget.tripId,
                                      'user_id': s['id'],
                                      'role': role,
                                      'deployment_date': rawDate,
                                    });
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${s['full_name']} Deployed Successfully.'), backgroundColor: Colors.green));
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Assignment error: $e'), backgroundColor: Colors.red));
                                  }
                                },
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 30),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmRemove(dynamic b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('REMOVE TRIPKER?'),
        content: const Text(
          'This will abort their trip and delete the booking record.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _client.from('bookings').delete().eq('id', b['id']);
      _fetchSquad();
    }
  }

  Widget _iconButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 8,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showContactSheet(dynamic profile) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                UserAvatar(
                  imageUrl: profile?['avatar_url'],
                  name: profile?['full_name'],
                  radius: 30,
                ),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile?['full_name'] ?? 'Employee',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                    Text(
                      profile?['role']?.toString().toLowerCase() ?? 'user',
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            _contactRow(Icons.phone, 'Phone', profile?['phone'] ?? 'no phone'),
            _contactRow(
              Icons.medical_information_outlined,
              'Blood Group',
              profile?['blood_group'] ?? 'Unknown',
            ),
            _contactRow(
              Icons.emergency_outlined,
              'Emergency',
              profile?['emergency_contact'] ?? 'Not set',
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: _actionBtn(
                    Icons.phone_in_talk,
                    'Call',
                    const Color(0xFF2E7B32),
                    Colors.white,
                    onTap: () async =>
                        await launchUrl(Uri.parse('tel:${profile?['phone']}')),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _actionBtn(
                    Icons.chat_bubble_outline,
                    'SMS',
                    Colors.transparent,
                    Colors.grey,
                    onTap: () async =>
                        await launchUrl(Uri.parse('sms:${profile?['phone']}')),
                    border: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactRow(IconData icon, String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2E7B32), size: 18),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                val,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(
    IconData icon,
    String label,
    Color bg,
    Color fg, {
    VoidCallback? onTap,
    bool border = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(15),
          border: border ? Border.all(color: Colors.grey.shade200) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fg, size: 14),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.bold,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffCard(dynamic s) {
    final profile = s["profiles"];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.indigo.withOpacity(0.1) : Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.indigo.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          UserAvatar(radius: 20, imageUrl: profile?["avatar_url"], name: profile?["full_name"]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile?["full_name"] ?? "CONTROLER", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(s["role"]?.toString().toUpperCase() ?? "STAFF", style: TextStyle(fontSize: 10, color: Colors.indigo.shade700, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
            onPressed: () async {
               await _client.from("trip_group_staff").delete().eq("id", s["id"]);
               _fetchSquad();
            },
          ),
        ],
      ),
    );
  }

}
