import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';

class AdminWalletScreen extends StatefulWidget {
  const AdminWalletScreen({super.key});

  @override
  State<AdminWalletScreen> createState() => _AdminWalletScreenState();
}

class _AdminWalletScreenState extends State<AdminWalletScreen> {
  final _client = Supabase.instance.client;
  double _balance = 0.0;
  bool _isLoading = true;
  List<dynamic> _transactions = [];

  @override
  void initState() {
    super.initState();
    _fetchWalletData();
  }

  Future<void> _fetchWalletData() async {
    setState(() => _isLoading = true);
    try {
      // For Admin, it shows the "Trip Ledger" or total revenue trends
      final tx = await _client.from('bookings').select('*, profiles(full_name)').order('created_at', ascending: false);
      
      double totalBalance = 0;
      for (var b in tx) {
        if (b['status'] != 'refunded') {
          totalBalance += (double.tryParse(b['paid_amount']?.toString() ?? '') ?? double.tryParse(b['total_price']?.toString() ?? '') ?? 0.0);
        }
      }

      if (mounted) {
        setState(() {
          _balance = totalBalance;
          _transactions = tx.take(20).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('OFFICIAL REVENUE LEDGER', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white, letterSpacing: 2)),
        backgroundColor: const Color(0xFFD32F2F),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white, size: 20), onPressed: _fetchWalletData),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            children: [
              _buildBalanceCard(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Text('RECENT TRIP FUNDING RECEIPTS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5, color: Colors.grey)),
              ),
              ..._transactions.map((t) => _transactionTile(t)).toList(),
            ],
          ),
    );
  }

  Widget _transactionTile(dynamic t) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
        child: const Icon(Icons.download_for_offline_outlined, color: Colors.green, size: 20),
      ),
      title: Text(t['profiles']?['full_name'] ?? 'Trip Payment', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Text(DateFormat('MMM dd, yyyy').format(DateTime.parse(t['created_at'])), style: const TextStyle(fontSize: 10, color: Colors.grey)),
      trailing: Text('+₹${t['paid_amount'] ?? t['total_price']}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 14)),
    );
  }

  Widget _buildBalanceCard() {
    return FadeInDown(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF09090B), Color(0xFF18181B)]),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('AVAILABLE LIQUIDITY', style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
                const Icon(Icons.account_balance_wallet, color: Colors.white24),
              ],
            ),
            const SizedBox(height: 12),
            Text('₹${_balance.toInt()}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(child: _walletAction(Icons.download, 'Withdraw', () {})),
                const SizedBox(width: 12),
                Expanded(child: _walletAction(Icons.history, 'Statement', () {})),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _walletAction(IconData icon, String label, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white10,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }
}
