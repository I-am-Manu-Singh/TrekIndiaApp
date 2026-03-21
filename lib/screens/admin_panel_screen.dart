import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'admin_bookings_screen.dart';
import 'admin_complaints_screen.dart';
import 'admin_support_inquiries_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_rental_tracking_screen.dart';
import 'admin_package_management_screen.dart';
import 'admin_finance_hub_screen.dart';
import 'admin_personnel_management_screen.dart';
import 'payment_ledger_screen.dart';
import 'blogs_screen.dart';
import 'admin_inventory_management_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  bool _isLoading = true;
  int _totalBookings = 0;
  double _totalRevenue = 0;
  int _personnelCount = 0;
  int _activeReports = 0;
  Map<String, double> _monthlyRevenue = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final bookings = await client.from('bookings').select('id, total_price, booking_date');
      final rentals = await client.from('user_rentals').select('total_price, created_at');
      final users = await client.from('profiles').select('id').neq('role', 'user');
      final reports = await client.from('complaints').select('id').neq('status', 'resolved');

      double revenue = 0;
      Map<String, double> monthly = {};
      
      // Process Bookings
      for (var row in (bookings as List)) {
        double val = double.tryParse(row['total_price'].toString()) ?? 0;
        revenue += val;
        try {
          DateTime date = DateTime.parse(row['booking_date']);
          String m = DateFormat('MMM').format(date);
          monthly[m] = (monthly[m] ?? 0) + val;
        } catch (_) {}
      }

      // Process Rentals
      for (var row in (rentals as List)) {
        double val = double.tryParse(row['total_price'].toString()) ?? 0;
        revenue += val;
        try {
          DateTime date = DateTime.parse(row['created_at']);
          String m = DateFormat('MMM').format(date);
          monthly[m] = (monthly[m] ?? 0) + val;
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _totalBookings = (bookings as List).length;
          _totalRevenue = revenue;
          _personnelCount = (users as List).length;
          _activeReports = (reports as List).length;
          _monthlyRevenue = monthly;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('ADMIN PANEL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        backgroundColor: const Color(0xFF2E7B32),
        elevation: 0,
        actions: [
          _liveBadge(),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('OFFICIAL OVERVIEW', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
              childAspectRatio: 1.3,
              children: [
                _overviewCard('BOOKINGS', '$_totalBookings', Icons.assignment_outlined, [const Color(0xFF1976D2), const Color(0xFF42A5F5)]),
                _overviewCard('YIELD', '₹${(_totalRevenue / 1000).toStringAsFixed(1)}K', Icons.account_balance_wallet_outlined, [const Color(0xFF2E7B32), const Color(0xFF66BB6A)]),
                _overviewCard('PERSONNEL', '$_personnelCount', Icons.badge_outlined, [const Color(0xFF6A1B9A), const Color(0xFFAB47BC)]),
                _overviewCard('COMPLAINTS', '$_activeReports', Icons.warning_amber_rounded, [const Color(0xFFC62828), const Color(0xFFEF5350)]),
              ],
            ),
            const SizedBox(height: 32),
            _buildRevenueIntelligence(),
            const SizedBox(height: 32),
            const Text('ADMIN TERMINAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
            const SizedBox(height: 16),
            _buildTerminalGrid(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _liveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: Colors.greenAccent, size: 6),
          SizedBox(width: 6),
          Text('LIVE', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _overviewCard(String title, String value, IconData icon, List<Color> colors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: colors.first.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueIntelligence() {
    final now = DateTime.now();
    final months = List.generate(6, (i) {
      final date = DateTime(now.year, now.month - (5 - i), 1);
      return DateFormat('MMM').format(date);
    });

    double maxVal = 0;
    for (var m in months) {
      if ((_monthlyRevenue[m] ?? 0) > maxVal) maxVal = _monthlyRevenue[m]!;
    }
    if (maxVal == 0) maxVal = 1;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('FISCAL INTELLIGENCE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5, color: Colors.blueGrey)),
                Text('Gross revenue trends', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
              ]),
              const Icon(Icons.insights, color: Colors.green),
            ],
          ),
          const SizedBox(height: 48),
          SizedBox(
            height: 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: months.map((m) {
                final val = _monthlyRevenue[m] ?? 0;
                final ratio = val / maxVal;
                final isCurrent = m == DateFormat('MMM').format(now);
                
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (val > 0)
                        FadeInUp(
                          child: Text('₹${(val / 1000).toStringAsFixed(1)}K', style: TextStyle(color: isCurrent ? Colors.green : Colors.grey, fontSize: 8, fontWeight: FontWeight.bold)),
                        ),
                      const SizedBox(height: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 35,
                        height: 10 + (100 * ratio),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          gradient: isCurrent 
                            ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF66BB6A), Color(0xFF2E7B32)])
                            : LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.grey.withOpacity(0.1), Colors.grey.withOpacity(0.05)]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(m, style: TextStyle(color: isCurrent ? (isDark ? Colors.green : Colors.black87) : Colors.grey, fontSize: 10, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalGrid() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.9,
      children: [
        _terminalCard('Bookings\nManagement', Icons.groups_outlined, Colors.blue.shade100, Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminBookingsScreen()))),
        _terminalCard('Rentals\nMangement', Icons.inventory_2_outlined, Colors.orange.shade100, Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminRentalTrackingScreen()))),
        _terminalCard('Official\nFinance', Icons.account_balance_wallet_outlined, Colors.green.shade100, Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminFinanceHubScreen()))),
        _terminalCard('Employees\nDatabase', Icons.badge_outlined, Colors.indigo.shade100, Colors.indigo, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminPersonnelManagementScreen()))),
        _terminalCard('Support\nHub', Icons.speed_outlined, Colors.amber.shade100, Colors.amber, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminSupportInquiriesScreen()))),
        _terminalCard('Blogs\nManagement', Icons.description_outlined, Colors.brown.shade100, Colors.brown, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const BlogsScreen()))),
        _terminalCard('Inventory\nCommand', Icons.warehouse_outlined, Colors.cyan.shade100, Colors.cyan, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminInventoryManagementScreen()))),
        _terminalCard('Manage\nPackages', Icons.redeem, Colors.cyan.shade100, Colors.cyan, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminPackageManagementScreen()))),
        _terminalCard('Broadcast\nControl', Icons.campaign_outlined, Colors.pink.shade100, Colors.pink, () => Navigator.pushNamed(context, '/admin_broadcast')),
      ],
    );
  }

  Widget _terminalCard(String label, IconData icon, Color bgColor, Color iconColor, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))],
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: bgColor.withOpacity(isDark ? 0.2 : 0.3), shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 12),
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : Colors.black87)),
          ],
        ),
      ),
    );
  }
}
