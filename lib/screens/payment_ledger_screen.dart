import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';

class PaymentLedgerScreen extends StatefulWidget {
  const PaymentLedgerScreen({super.key});

  @override
  State<PaymentLedgerScreen> createState() => _PaymentLedgerScreenState();
}

class _PaymentLedgerScreenState extends State<PaymentLedgerScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _transactions = [];
  double _totalSpent = 0;
  String _role = 'user';

  @override
  void initState() {
    super.initState();
    _fetchLedger();
  }

  Future<void> _fetchLedger() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    setState(() => _isLoading = true);

    try {
      final profile = await _client.from('profiles').select('role').eq('id', user.id).maybeSingle();
      final bool isAdmin = (profile?['role'] ?? 'user') == 'admin';
      if (mounted) _role = profile?['role'] ?? 'user';

      // 1. Fetch Data Independently (Manual Join)
      var bQuery = _client.from('bookings').select();
      if (!isAdmin) bQuery = bQuery.eq('user_id', user.id);
      final bookingsResRaw = await bQuery.order('booking_date', ascending: false);

      var rQuery = _client.from('user_rentals').select();
      if (!isAdmin) rQuery = rQuery.eq('user_id', user.id);
      final rentalsResRaw = await rQuery.order('issue_date', ascending: false);

      var pQuery = _client.from('payment_logs').select();
      if (!isAdmin) pQuery = pQuery.eq('user_id', user.id);
      final logsResRaw = await pQuery.order('created_at', ascending: false);

      // Pre-fetch relation mapping
      final allTrips = await _client.from('trips').select('id, title');
      final allProfiles = await _client.from('profiles').select('id, full_name');
      final allGears = await _client.from('gears').select('id, name');

      final tripMap = {for (var t in allTrips) t['id']: t['title']};
      final profileMap = {for (var p in allProfiles) p['id']: p['full_name']};
      final gearMap = {for (var g in allGears) g['id']: g['name']};

      List<dynamic> combined = [];
      double balance = 0;

      // Process Bookings
      for (var b in bookingsResRaw as List) {
        double amt = double.tryParse(b['paid_amount'].toString()) ?? 0;
        bool isIncome = isAdmin;
        balance += isIncome ? amt : -amt;
        final uName = profileMap[b['user_id']] ?? 'User';
        final tTitle = tripMap[b['trip_id']] ?? 'Trip Payment';
        combined.add({
          'title': (isAdmin ? '[$uName] ' : '') + tTitle,
          'amount': amt,
          'date': b['booking_date'],
          'type': 'Trip',
          'is_income': isIncome,
          'icon': Icons.terrain,
          'color': Colors.blue,
        });
      }

      // Process Rentals
      for (var r in rentalsResRaw as List) {
        double amt = double.tryParse(r['total_price'].toString()) ?? 0;
        bool isIncome = isAdmin;
        balance += isIncome ? amt : -amt;
        final uName = profileMap[r['user_id']] ?? 'User';
        final gName = gearMap[r['gear_id']] ?? 'Rental Item';
        combined.add({
          'title': (isAdmin ? '[$uName] ' : '') + 'Gear: $gName',
          'amount': amt,
          'date': r['issue_date'],
          'type': 'Gear',
          'is_income': isIncome,
          'icon': Icons.inventory_2,
          'color': Colors.orange,
        });
      }

      // Process Finance Logs
      for (var l in logsResRaw as List) {
        double amt = double.tryParse(l['amount'].toString()) ?? 0;
        final bool isLogIncoming = l['is_incoming'] == true;
        bool isIncome = isAdmin ? isLogIncoming : !isLogIncoming;

        balance += isIncome ? amt : -amt;
        final uName = profileMap[l['user_id']] ?? 'Staff';
        combined.add({
          'title': (isAdmin ? '[$uName] ' : '') + (l['payment_type'] ?? 'Trip Payout'),
          'amount': amt,
          'date': l['created_at'],
          'type': l['payment_type'] ?? 'Finance',
          'is_income': isIncome,
          'icon': (l['payment_type'] == 'SALARY') ? Icons.payments : Icons.account_balance_wallet,
          'color': (l['payment_type'] == 'SALARY') ? Colors.purple : Colors.teal,
        });
      }

      combined.sort((a, b) => DateTime.parse(b['date'].toString()).compareTo(DateTime.parse(a['date'].toString())));

      if (mounted) {
        setState(() {
          _transactions = combined;
          _totalSpent = balance;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF09090B) : Colors.white,
      appBar: AppBar(
        title: const Text('MY OFFICIAL WALLET', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        backgroundColor: const Color(0xFFD32F2F),
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            children: [
              _buildWalletHeader(),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TRIP TRANSACTIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : Colors.grey, letterSpacing: 1.2)),
                    const SizedBox(height: 16),
                    ..._transactions.map((tx) => _buildTransactionCard(tx)).toList(),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
    );
  }

  Widget _buildWalletHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, 
          end: Alignment.bottomRight, 
          colors: _totalSpent >= 0 
            ? [const Color(0xFF388E3C), const Color(0xFF1B5E20)] 
            : [const Color(0xFFC62828), const Color(0xFFB71C1C)]
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: (_totalSpent >= 0 ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C)).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_role == 'admin' ? 'OFFICIAL FISCAL BALANCE' : 'TOTAL TRIP INVESTMENT', style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 12),
          Text('${_totalSpent >= 0 ? "+" : "-"}₹${_totalSpent.abs().toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(child: _headerButton(Icons.add_chart, 'Analytics', () {})),
              const SizedBox(width: 16),
              Expanded(child: _headerButton(Icons.menu_book, 'Passbook', () {})),
            ],
          )
        ],
      ),
    );
  }

  Widget _headerButton(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, size: 14),
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: Colors.white.withOpacity(0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> tx) {
    final bool isIncome = tx['is_income'] ?? false;
    final Color color = tx['color'] ?? (isIncome ? Colors.green : Colors.red);
    final IconData icon = tx['icon'] ?? (isIncome ? Icons.arrow_downward : Icons.arrow_upward);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.01), blurRadius: 10)],
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade50),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx['title'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(DateFormat('MMM dd, yyyy').format(DateTime.parse(tx['date'].toString())), style: TextStyle(color: isDark ? Colors.white38 : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${isIncome ? "+" : "-"}₹${tx['amount'].toInt()}', 
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: isIncome ? Colors.green.shade700 : Colors.red.shade700)
          ),
        ],
      ),
    );
  }
}
