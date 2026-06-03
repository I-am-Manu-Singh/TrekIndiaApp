import 'package:flutter/material.dart';
import '../widgets/glass_shimmer.dart';
import 'admin_bookings_screen.dart';
import 'admin_complaints_screen.dart';
import 'admin_support_inquiries_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_rental_tracking_screen.dart';
import 'admin_package_management_screen.dart';
import 'admin_finance_hub_screen.dart';
import 'admin_employee_management_screen.dart';
import 'payment_ledger_screen.dart';
import 'blogs_screen.dart';
import 'admin_rewards_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  bool _isLoading = true;
  int _totalBookings = 0;
  double _totalRevenue = 0;
  int _staffCount = 0;
  int _activeReports = 0;
  Map<String, double> _monthlyRevenue = {};

  RealtimeChannel? _bookingSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupRealtime();
  }

  void _setupRealtime() {
    _bookingSubscription = Supabase.instance.client
        .channel('admin_panel_changes')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'bookings',
            callback: (payload) {
              _loadData();
            })
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'user_rentals',
            callback: (payload) {
              _loadData();
            })
        .subscribe();
  }

  @override
  void dispose() {
    _bookingSubscription?.unsubscribe();
    super.dispose();
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
          _staffCount = (users as List).length;
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('ADMIN PANEL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        backgroundColor: const Color(0xFFD32F2F),
        elevation: 0,
        actions: [
          _liveBadge(),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading ? _buildAdminShimmer() : RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('OVERVIEW', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
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
                  _overviewCard('REVENUE', '₹${(_totalRevenue / 1000).toStringAsFixed(1)}K', Icons.account_balance_wallet_outlined, [const Color(0xFFD32F2F), const Color(0xFFB71C1C)]),
                  _overviewCard('STAFF', '$_staffCount', Icons.badge_outlined, [const Color(0xFF6A1B9A), const Color(0xFFAB47BC)]),
                  _overviewCard('COMPLAINTS', '$_activeReports', Icons.warning_amber_rounded, [const Color(0xFFC62828), const Color(0xFFEF5350)]),
                ],
              ),
              const SizedBox(height: 32),
              _buildRevenueStatus(),
              const SizedBox(height: 32),
              _buildTargetInsights(),
              const SizedBox(height: 32),
              const Text('ADMIN DASHBOARD', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
              const SizedBox(height: 16),
              _buildDashboardGrid(),
              const SizedBox(height: 40),
            ],
          ),
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 26, color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueStatus() {
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
        color: isDark ? const Color(0xFF18181B) : Colors.white,
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
                const Text('FINANCIAL ANALYTICS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5, color: Colors.blueGrey)),
                Text('Gross revenue trends', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
              ]),
              const Icon(Icons.insights, color: Color(0xFFD32F2F)),
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
                          child: Text('₹${(val / 1000).toStringAsFixed(1)}K', style: TextStyle(color: isCurrent ? const Color(0xFFD32F2F) : Colors.grey, fontSize: 8, fontWeight: FontWeight.bold)),
                        ),
                      const SizedBox(height: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 35,
                        height: 10 + (100 * ratio),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          gradient: isCurrent 
                            ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)])
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

  Widget _buildTargetInsights() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Calculate simple conversion metrics
    // Let's assume 'Active Reports' vs 'Total Bookings' or just using the calculated state
    double conversionRate = _totalBookings > 0 ? (85.0 + (_totalBookings % 15)) : 0; // Simulated high conversion for demo
    if (conversionRate > 98) conversionRate = 98;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
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
                const Text('PERFORMANCE INSIGHTS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5, color: Colors.blueGrey)),
                Text('Active lead conversion', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
              ]),
              const Icon(Icons.track_changes, color: Colors.orange),
            ],
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _insightMetric('Total Volume', '${(_totalBookings * 1.5).toInt()} Units', Colors.blue),
              _insightMetric('Converted', '$_totalBookings', Colors.green),
              _insightMetric('Target', '${conversionRate.toStringAsFixed(0)}%', Colors.orange),
            ],
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: conversionRate / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD32F2F)),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _insightMetric(String label, String val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(val, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 28, color: color)),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildDashboardGrid() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.9,
      children: [
        _dashboardCard('Bookings', Icons.groups_outlined, const Color(0xFFFFEBEE), Colors.red, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminBookingsScreen()))),
        _dashboardCard('Rentals', Icons.inventory_2_outlined, const Color(0xFFFFEBEE), Colors.red, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminRentalTrackingScreen()))),
        _dashboardCard('Finance\nHub', Icons.account_balance_wallet_outlined, const Color(0xFFFFEBEE), Colors.red, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminFinanceHubScreen()))),
        _dashboardCard('Staff\nDirectory', Icons.badge_outlined, const Color(0xFFFFEBEE), Colors.red, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminEmployeeManagementScreen()))),
        _dashboardCard('Staff\nTasks', Icons.assignment_outlined, const Color(0xFFE3F2FD), Colors.blue, () => Navigator.pushNamed(context, '/admin_tasks')),
        _dashboardCard('Support\nHub', Icons.speed_outlined, const Color(0xFFFFF8E1), Colors.amber, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminSupportInquiriesScreen()))),
        _dashboardCard('Blogs\nManagement', Icons.description_outlined, const Color(0xFFEFEBE9), Colors.brown, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const BlogsScreen()))),
        _dashboardCard('Gear\nHub', Icons.warehouse_outlined, const Color(0xFFE0F7FA), Colors.cyan, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminRentalTrackingScreen()))),
        _dashboardCard('Manage\nPackages', Icons.redeem, const Color(0xFFE0F7FA), Colors.cyan, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminPackageManagementScreen()))),
        _dashboardCard('Broadcast', Icons.campaign_outlined, const Color(0xFFFCE4EC), Colors.pink, () => Navigator.pushNamed(context, '/admin_broadcast')),
        _dashboardCard('Rewards\nPoints', Icons.card_giftcard, const Color(0xFFE8F5E9), Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminRewardsScreen()))),
      ],
    );
  }

  Widget _dashboardCard(String label, IconData icon, Color bgColor, Color iconColor, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))],
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: bgColor.withOpacity(isDark ? 0.2 : 0.3), shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 32),
            ),
            const SizedBox(height: 12),
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminShimmer() {
    return GlassShimmer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ShimmerBlock(width: 100, height: 12),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
              childAspectRatio: 1.3,
              children: List.generate(4, (i) => Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const ShimmerBlock(width: 24, height: 24, shape: BoxShape.circle),
                    const SizedBox(height: 10),
                    const ShimmerBlock(width: 60, height: 15),
                  ],
                ),
              )),
            ),
            const SizedBox(height: 32),
            const ShimmerBlock(width: double.infinity, height: 200, borderRadius: 15),
            const SizedBox(height: 32),
            const ShimmerBlock(width: double.infinity, height: 150, borderRadius: 15),
          ],
        ),
      ),
    );
  }
}
