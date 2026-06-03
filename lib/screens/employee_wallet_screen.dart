import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';

class EmployeeWalletScreen extends StatefulWidget {
  const EmployeeWalletScreen({super.key});

  @override
  State<EmployeeWalletScreen> createState() => _EmployeeWalletScreenState();
}

class _EmployeeWalletScreenState extends State<EmployeeWalletScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  double _balance = 40000;
  dynamic _profile;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    final user = _client.auth.currentUser;
    if (user != null) {
      try {
        final res = await _client.from('profiles').select().eq('id', user.id).single();
        if (mounted) {
          setState(() {
            _profile = res;
            final salary = double.tryParse((res['salary'] ?? 0).toString()) ?? 0;
            final allowance = double.tryParse((res['allowance'] ?? 0).toString()) ?? 0;
            _balance = salary + allowance;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('MY OFFICIAL WALLET', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        backgroundColor: const Color(0xFFD32F2F),
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildBalanceCard(),
        const SizedBox(height: 32),
        const Text('trekwithmussafirr FINANCIAL STANDING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _miniInfo('EST. SETTLEMENT', '₹${_balance.toInt()}', Colors.green)),
            const SizedBox(width: 16),
            Expanded(child: _miniInfo('UNPAID LEAVES', (_profile?['unpaid_leaves'] ?? 0).toString(), Colors.orange)),
          ],
        ),
        const SizedBox(height: 32),
        const Text('RECENT PAYOUT REGISTRY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
        const SizedBox(height: 32),
        const Text('MONTHLY PAYOUT CALENDAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
        const SizedBox(height: 16),
        _buildPayoutCalendar(),
        const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildPayoutCalendar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final firstDay = DateTime(now.year, now.month, 1).weekday;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(DateFormat('MMMM yyyy').format(now).toUpperCase(), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1, color: isDark ? Colors.white70 : Colors.black87)),
              Row(
                children: [
                  _calLegend('SALARY', Colors.green),
                  const SizedBox(width: 8),
                  _calLegend('ALLOWANCE', Colors.blue),
                ],
              )
            ],
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 8, crossAxisSpacing: 8),
            itemCount: daysInMonth + (firstDay % 7),
            itemBuilder: (context, index) {
              if (index < (firstDay % 7)) return const SizedBox();
              final day = index - (firstDay % 7) + 1;
              bool isSalaryD = day == 1;
              bool isAllowD = day == 5;

              return Container(
                decoration: BoxDecoration(
                  color: isSalaryD ? Colors.green.withOpacity(0.2) : (isAllowD ? Colors.blue.withOpacity(0.2) : Colors.transparent),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isSalaryD ? Colors.green : (isAllowD ? Colors.blue : Colors.transparent), width: 1),
                ),
                child: Center(
                  child: Text('$day', style: TextStyle(fontSize: 10, fontWeight: (isSalaryD || isAllowD) ? FontWeight.bold : FontWeight.normal, color: isDark ? Colors.white : Colors.black87)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _calLegend(String label, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.grey)),
      ],
    );
  }

  Widget _buildBalanceCard() {
    final role = (_profile?['role'] ?? 'TEAM').toString().toUpperCase();
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: const Color(0xFFD32F2F).withOpacity(0.2), blurRadius: 15)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CURRENT LIQUIDITY', style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          Text('₹${_balance.toInt()}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
          const SizedBox(height: 24),
          Row(
            children: [
              _label('RANK: $role', Colors.white24),
              const SizedBox(width: 8),
              _label('STATUS: TRIP READY', Colors.white24),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
    );
  }

  Widget _miniInfo(String label, String val, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withOpacity(0.1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(val, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isDark ? Colors.white : Colors.black87)),
        ],
      ),
    );
  }

  Widget _payoutItem(String title, String date, String val) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade50),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
              Text(date, style: const TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ),
          Text(val, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF4CAF50))),
        ],
      ),
    );
  }
}
