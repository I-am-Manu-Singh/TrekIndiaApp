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
  double _walletBalance = 0;
  String _role = 'user';

  @override
  void initState() {
    super.initState();
    _initLedger();
  }

  Future<void> _initLedger() async {
    await _fetchUserRole();
    await _fetchLedger();
  }

  Future<void> _fetchUserRole() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      final res = await _client.from('profiles').select('role').eq('id', user.id).single();
      if (mounted) setState(() => _role = res['role'] ?? 'user');
    } catch (_) {}
  }

  Future<void> _fetchLedger() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      // Fetch Bookings
      dynamic bookingQuery = _client
          .from('bookings')
          .select('*, treks(title, image_url), profiles(full_name)');
          
      if (_role != 'admin') {
        bookingQuery = bookingQuery.eq('user_id', user.id);
      }
      
      final bookingsRes = await bookingQuery.order('booking_date', ascending: false);

      // Fetch Rentals
      dynamic rentalQuery = _client
          .from('user_rentals')
          .select('*, gear:gears(name), profiles(full_name)');
          
      if (_role != 'admin') {
        rentalQuery = rentalQuery.eq('user_id', user.id);
      }
      
      final rentalsRes = await rentalQuery.order('issue_date', ascending: false);

      List<dynamic> combined = [];
      
      // Transform bookings to ledger items
      for (var b in bookingsRes) {
        combined.add({
          'id': b['id'],
          'type': 'trek',
          'title': b['treks']?['title'] ?? 'Generic Trek',
          'image_url': b['treks']?['image_url'],
          'amount': double.tryParse(b['total_price'].toString()) ?? 0,
          'paid': double.tryParse(b['paid_amount'].toString()) ?? 0,
          'date': b['booking_date'],
          'status': b['status'],
          'payment_status': b['payment_status'],
          'user_name': b['profiles']?['full_name'],
          'raw': b
        });
      }

      // Transform rentals to ledger items
      for (var r in rentalsRes) {
        combined.add({
          'id': r['id'],
          'type': 'rental',
          'title': 'REF: ${r['gear']?['name'] ?? 'Gear Rental'}',
          'amount': double.tryParse(r['total_price'].toString()) ?? 0,
          'paid': double.tryParse(r['total_price'].toString()) ?? 0, // Rentals are usually paid at issue
          'date': r['issue_date'],
          'status': r['status'],
          'payment_status': 'Paid',
          'user_name': r['profiles']?['full_name'],
          'raw': r
        });
      }

      // Sort by date
      combined.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));

      double spent = 0;
      double revenue = 0;
      double dailyRev = 0;
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      for (var item in combined) {
        final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.parse(item['date']));
        if (item['status'] != 'refunded') {
          spent += item['paid'];
          revenue += item['paid'];
          if (dateStr == todayStr) {
            dailyRev += item['paid'];
          }
        }
      }

      if (mounted) {
        setState(() {
          _transactions = combined;
          _totalSpent = spent;
          _walletBalance = revenue;
          _dailyIncome = dailyRev;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Ledger Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _dailyIncome = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
      appBar: AppBar(
        title: const Text('PAYMENTS & REFUNDS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16)),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.sync), onPressed: _fetchLedger),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildWalletSumary(),
                ),
                if (_role == 'admin')
                  SliverToBoxAdapter(
                    child: _buildMonthlyGraph(),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 30, 20, 10),
                    child: Row(
                      children: [
                        Text(_role == 'admin' ? 'Recent Revenue Flows' : 'Transaction History', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        if (_role == 'admin')
                          _analyticSubItem('DAILY: ₹${_dailyIncome.toInt()}', Colors.green),
                      ],
                    ),
                  ),
                ),
                _transactions.isEmpty
                    ? const SliverFillRemaining(child: Center(child: Text('No transactions yet.')))
                    : SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildTransactionCard(_transactions[index]),
                            childCount: _transactions.length,
                          ),
                        ),
                      ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
    );
  }

  Widget _buildMonthlyGraph() {
    return Container(
      height: 180,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('MONTHLY REVENUE TREND', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _barItem('JAN', 0.4, Colors.blue),
                _barItem('FEB', 0.6, Colors.blue),
                _barItem('MAR', 0.9, Colors.blueAccent),
                _barItem('APR', 0.5, Colors.blue),
                _barItem('MAY', 0.3, Colors.blue),
                _barItem('JUN', 0.7, Colors.blue),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _barItem(String label, double heightFactor, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 30,
          height: 80 * heightFactor,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildWalletSumary() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _summaryItem(_role == 'admin' ? 'TOTAL REVENUE' : 'TOTAL SPENT', '₹${(_role == 'admin' ? _walletBalance : _totalSpent).toInt()}', Colors.white),
              _summaryItem(_role == 'admin' ? 'AVG TICKET' : 'REFUNDED', '₹${_role == 'admin' ? 8400 : 0}', Colors.orangeAccent),
            ],
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              Expanded(child: _ledgerAction(Icons.account_balance_wallet_outlined, _role == 'admin' ? 'Payouts' : 'Add Funds', () {})),
              const SizedBox(width: 12),
              Expanded(child: _ledgerAction(Icons.receipt_long_outlined, 'Tax Docs', () {})),
            ],
          )
        ],
      ),
    );
  }

  Widget _ledgerAction(IconData icon, String label, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white10,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 0,
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
      ],
    );
  }

  Widget _analyticSubItem(String label, Color color) {
     return Container(
       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
       decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
       child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
     );
  }

  Widget _buildTransactionCard(Map<String, dynamic> item) {
    final bool isRefunded = item['status'] == 'refunded';
    final date = DateTime.parse(item['date']);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRental = item['type'] == 'rental';

    return GestureDetector(
      onTap: (_role == 'admin' && !isRental) ? () => _managePaymentAdmin(item['raw']) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              image: item['image_url'] != null ? DecorationImage(image: NetworkImage(item['image_url']), fit: BoxFit.cover) : null,
              color: isRental ? Colors.orange.withOpacity(0.1) : Colors.grey[100],
            ),
            child: item['image_url'] == null 
                ? Icon(isRental ? Icons.shopping_bag_outlined : Icons.terrain, color: isRental ? Colors.orange : Colors.grey) 
                : null,
          ),
          title: Text(item['title'] ?? 'Generic Payment', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_role == 'admin')
                Text('By: ${item['user_name'] ?? 'Trekker'}', style: const TextStyle(fontSize: 10, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(DateFormat('MMM dd, yyyy • hh:mm a').format(date), style: const TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isRefunded ? Colors.red : Colors.green).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isRefunded ? 'REFUNDED' : (item['payment_status']?.toUpperCase() ?? 'SUCCESS'),
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: isRefunded ? Colors.red : (item['payment_status'] == 'Partial' ? Colors.orange : Colors.green)),
                    ),
                  ),
                  if (item['payment_status'] == 'Partial') ...[
                    const SizedBox(width: 8),
                    Text('Due: ₹${item['amount'] - item['paid']}', style: const TextStyle(fontSize: 8, color: Colors.orange, fontWeight: FontWeight.bold)),
                  ],
                  if (isRental) ...[
                    const SizedBox(width: 8),
                    Text(item['status']?.toUpperCase() ?? '', style: const TextStyle(fontSize: 8, color: Colors.blue, fontWeight: FontWeight.bold)),
                  ]
                ],
              )
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isRefunded ? "+" : (_role == 'admin' ? "+" : "-")}₹${item['paid']}',
                style: TextStyle(
                  fontWeight: FontWeight.w900, 
                  fontSize: 16, 
                  color: (isRefunded || _role == 'admin') ? Colors.green : (isDark ? Colors.white : Colors.black)
                ),
              ),
              if (!isRefunded && item['amount'] > item['paid'])
                Text('of ₹${item['amount']}', style: const TextStyle(fontSize: 8, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  void _managePaymentAdmin(Map<String, dynamic> tx) async {
     final total = double.tryParse(tx['total_price'].toString()) ?? 0;
     final paid = double.tryParse(tx['paid_amount'].toString()) ?? 0;
     
     showModalBottomSheet(
       context: context,
       shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
       builder: (c) => Container(
         padding: const EdgeInsets.all(30),
         child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             const Text('MANAGE TRANSACTION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
             const SizedBox(height: 20),
             ListTile(
               leading: const Icon(Icons.check_circle, color: Colors.green),
               title: const Text('Mark as Fully Paid'),
               onTap: () {
                 _updatePaymentStatus(tx['id'], total, 'Paid');
                 Navigator.pop(context);
               },
             ),
             ListTile(
               leading: const Icon(Icons.hourglass_bottom, color: Colors.orange),
               title: const Text('Mark as Partial'),
               onTap: () {
                 _updatePaymentStatus(tx['id'], paid, 'Partial');
                 Navigator.pop(context);
               },
             ),
             ListTile(
               leading: const Icon(Icons.replay, color: Colors.red),
               title: const Text('Initiate Refund'),
               onTap: () {
                 _updatePaymentStatus(tx['id'], paid, 'refunded');
                 Navigator.pop(context);
               },
             ),
           ],
         ),
       )
     );
  }

  Future<void> _updatePaymentStatus(String id, double amount, String status) async {
    try {
      await _client.from('bookings').update({
        'paid_amount': amount,
        'payment_status': status == 'refunded' ? 'Refunded' : status,
        'status': status == 'refunded' ? 'refunded' : 'Confirmed',
      }).eq('id', id);
      _fetchLedger();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Transaction $status successfully.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }
}
