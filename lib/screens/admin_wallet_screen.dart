import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';

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
      // For Admin, it shows the "Expedition Ledger" or total revenue trends
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
    return _isLoading 
      ? const Center(child: CircularProgressIndicator())
      : Column(
          children: [
            _buildBalanceCard(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Text('RECENT REVENUE TRANSACTIONS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5, color: Colors.grey)),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _transactions.length,
                itemBuilder: (context, index) {
                  final t = _transactions[index];
                  return ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.add, color: Colors.white, size: 16)),
                    title: Text(t['profiles']?['full_name'] ?? 'Trekker Payment', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text(t['trek_id'] ?? 'Expedition Mission', style: const TextStyle(fontSize: 10)),
                    trailing: Text('+₹${t['total_price']}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w900)),
                  );
                },
              ),
            ),
          ],
        );
  }

  Widget _buildBalanceCard() {
    return FadeInDown(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)]),
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
