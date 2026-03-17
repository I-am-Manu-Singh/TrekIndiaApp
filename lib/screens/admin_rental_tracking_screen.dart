import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import '../widgets/user_avatar.dart';

class AdminRentalTrackingScreen extends StatefulWidget {
  const AdminRentalTrackingScreen({super.key});

  @override
  State<AdminRentalTrackingScreen> createState() => _AdminRentalTrackingScreenState();
}

class _AdminRentalTrackingScreenState extends State<AdminRentalTrackingScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _rentals = [];

  @override
  void initState() {
    super.initState();
    _fetchRentals();
  }

  Future<void> _fetchRentals() async {
    setState(() => _isLoading = true);
    try {
      final response = await _client
          .from('user_rentals')
          .select('*, gear:gears(*), profiles!inner(*)')
          .order('issue_date', ascending: false);
      
      if (mounted) {
        setState(() {
          _rentals = response;
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

  Future<void> _markAsReturned(String id, double securityPaid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Confirm Return'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mark this item as safely returned to base.'),
            const SizedBox(height: 12),
            Text('Security Deposit to Refund: ₹$securityPaid', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
            child: const Text('CONFIRM RETURN')
          ),
        ],
      )
    );

    if (confirmed == true) {
      try {
        await _client.from('user_rentals').update({
          'status': 'returned',
          'return_date': DateTime.now().toIso8601String(),
          'security_deposit_refunded': true,
        }).eq('id', id);
        _fetchRentals();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item returned and security refunded.'), backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _showIssueGearDialog() async {
      try {
      final List<dynamic> profiles = await _client.from('profiles').select('id, full_name').order('full_name');
      final List<dynamic> gears = await _client.from('gears').select('id, name, price_per_day, security_deposit');

      if (!mounted) return;

      String? selectedUserId;
      String? selectedGearId;
      final qtyCtrl = TextEditingController(text: '1');
      final daysCtrl = TextEditingController(text: '1');
      final securityCtrl = TextEditingController(text: '500');
      bool securityCharged = true;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (c) => StatefulBuilder(
          builder: (context, setSheetState) => Container(
            decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
            padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(c).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Issue Tactical Gear', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(labelText: 'SELECT TREKKER', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
                  items: profiles.map((p) => DropdownMenuItem(value: p['id'] as String, child: Text(p['full_name']))).toList(),
                  onChanged: (v) => selectedUserId = v,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(labelText: 'SELECT GEAR', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
                  items: gears.map((g) => DropdownMenuItem(value: g['id'] as String, child: Text(g['name']))).toList(),
                  onChanged: (v) {
                    selectedGearId = v;
                    final g = gears.firstWhere((gear) => gear['id'] == v);
                    setSheetState(() => securityCtrl.text = (g['security_deposit'] ?? 500).toString());
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                     Expanded(child: TextField(controller: qtyCtrl, decoration: InputDecoration(labelText: 'QTY', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))), keyboardType: TextInputType.number)),
                     const SizedBox(width: 16),
                     Expanded(child: TextField(controller: daysCtrl, decoration: InputDecoration(labelText: 'DAYS', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))), keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: TextField(controller: securityCtrl, decoration: InputDecoration(labelText: 'SECURITY DEPOSIT', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))), keyboardType: TextInputType.number)),
                    const SizedBox(width: 15),
                    Column(
                      children: [
                        const Text('COLLECTED?', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
                        Switch(value: securityCharged, activeColor: Theme.of(context).primaryColor, onChanged: (v) => setSheetState(() => securityCharged = v)),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedUserId == null || selectedGearId == null) return;
                    try {
                      final gear = gears.firstWhere((g) => g['id'] == selectedGearId);
                      final price = (gear['price_per_day'] as num) * (int.tryParse(qtyCtrl.text) ?? 1) * (int.tryParse(daysCtrl.text) ?? 1);
                      
                      await _client.from('user_rentals').insert({
                        'user_id': selectedUserId,
                        'gear_id': selectedGearId,
                        'quantity': int.tryParse(qtyCtrl.text) ?? 1,
                        'total_price': price,
                        'security_deposit_paid': double.tryParse(securityCtrl.text) ?? 0,
                        'status': 'issued',
                        'issue_date': DateTime.now().toIso8601String(),
                      });
                      Navigator.pop(c);
                      _fetchRentals();
                    } catch (_) {}
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  child: const Text('CONFIRM ISSUANCE', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (_) {}
  }

  Widget _buildRentalAnalytics() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    double todayRevenue = 0;
    double todayDue = 0;
    int itemsOut = 0;
    int itemsToday = 0;

    for (var r in _rentals) {
      final issueDate = DateFormat('yyyy-MM-dd').format(DateTime.parse(r['issue_date']));
      final amount = double.tryParse(r['total_price'].toString()) ?? 0;
      
      if (issueDate == today) {
        todayRevenue += amount;
        itemsToday++;
      }
      
      if (r['status'] == 'issued') {
        todayDue += amount;
        itemsOut++;
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.black, 
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: isDark ? Colors.white12 : Colors.transparent),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _analyticItem('TODAY REVENUE', '₹${todayRevenue.toInt()}', Colors.greenAccent),
          _analyticItem('PENDING REVENUE', '₹${todayDue.toInt()}', Colors.orangeAccent),
          _analyticItem('ARSNEL OUT', itemsOut.toString(), Colors.blueAccent),
        ],
      ),
    );
  }

  Widget _analyticItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color, letterSpacing: -1)),
        Text(label, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('GEAR RENTALS & ARSNEL', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 13)),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _fetchRentals,
            child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _rentals.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) return _buildRentalAnalytics();
                  final r = _rentals[index - 1];
                  final isReturned = r['status'] == 'returned';
                  final statusColor = isReturned ? Colors.green : Colors.orange;
                  
                  return FadeInUp(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white, 
                        borderRadius: BorderRadius.circular(20), 
                        border: Border.all(color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              UserAvatar(imageUrl: r['profiles']?['avatar_url'], name: r['profiles']?['full_name'], radius: 18),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r['gear']?['name'] ?? 'Tactical Gear', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text('User: ${r['profiles']?['full_name']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('₹${r['total_price']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text('Sec: ₹${r['security_deposit_paid'] ?? 0}', style: const TextStyle(fontSize: 9, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                                ],
                              )
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                child: Text(r['status'].toString().toUpperCase(), style: TextStyle(color: statusColor, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                              ),
                              if (!isReturned)
                                ElevatedButton.icon(
                                  onPressed: () => _markAsReturned(r['id'], (r['security_deposit_paid'] ?? 0).toDouble()),
                                  icon: const Icon(Icons.keyboard_return, size: 14),
                                  label: const Text('MARK RETURNED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).primaryColor, 
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showIssueGearDialog,
        backgroundColor: isDark ? Colors.white : Colors.black,
        icon: Icon(Icons.add_shopping_cart, color: isDark ? Colors.black : Colors.white),
        label: Text('ISSUE GEAR', style: TextStyle(color: isDark ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
