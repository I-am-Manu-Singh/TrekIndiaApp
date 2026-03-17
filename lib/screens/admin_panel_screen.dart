import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import '../widgets/user_avatar.dart';
import 'admin_bookings_screen.dart';
import 'admin_complaints_screen.dart';
import 'admin_support_inquiries_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_rental_tracking_screen.dart';
import 'admin_trek_inventory_screen.dart';
import 'payment_ledger_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  bool _isLoading = true;
  int _totalBookings = 0;
  double _totalRevenue = 0;
  int _totalUsers = 0;
  int _pendingRentals = 0;
  int _openComplaints = 0;
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
      final users = await client.from('profiles').select('id');
      final rentals = await client.from('user_rentals').select('status');

      double revenue = 0;
      Map<String, double> monthly = {};
      for (var row in (bookings as List)) {
        double val = double.tryParse(row['total_price'].toString()) ?? 0;
        revenue += val;
        try {
          DateTime date = DateTime.parse(row['booking_date']);
          String m = DateFormat('MMM').format(date);
          monthly[m] = (monthly[m] ?? 0) + val;
        } catch (_) {}
      }

      int openComplaints = 0;
      try {
        final complaints = await client.from('complaints').select('id').neq('status', 'resolved');
        openComplaints = (complaints as List).length;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _totalBookings = (bookings as List).length;
          _totalRevenue = revenue;
          _totalUsers = (users as List).length;
          _pendingRentals = (rentals as List).where((r) => r['status'] != 'returned').length;
          _openComplaints = openComplaints;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FadeInDown(
                      child: Row(
                        children: [
                          Icon(Icons.admin_panel_settings, size: 28, color: Theme.of(context).primaryColor),
                          const SizedBox(width: 12),
                          const Expanded(child: Text('Command Intelligence', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
                          _liveBadge(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        _statCard('Bookings', '$_totalBookings', Icons.book_online, Colors.blue, isDark),
                        const SizedBox(width: 12),
                        _statCard('Revenue', '₹${(_totalRevenue / 1000).toStringAsFixed(1)}K', Icons.payments, Colors.green, isDark),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _statCard('Hikers', '$_totalUsers', Icons.people, Colors.purple, isDark),
                        const SizedBox(width: 12),
                        _statCard('Active Gear', '$_pendingRentals', Icons.shopping_bag, Colors.orange, isDark),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildRevenueChart(isDark),
                    const SizedBox(height: 24),
                    const Text('QUICK ACTIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.grey)),
                    const SizedBox(height: 16),
                    _actionCard('Mission Control', 'Manage trek bookings & squads', Icons.groups, Colors.blueAccent, () {
                      Navigator.push(context, MaterialPageRoute(builder: (c) => AdminBookingsScreen(showAppBar: true)));
                    }, isDark),
                    const SizedBox(height: 12),
                    _actionCard('Tactical Rentals', 'Issue and track gear returns', Icons.inventory_2_outlined, Colors.orange, () {
                      Navigator.push(context, MaterialPageRoute(builder: (c) => AdminRentalTrackingScreen()));
                    }, isDark),
                    const SizedBox(height: 12),
                    _actionCard('Complaints Center', '${_openComplaints} open reports', Icons.report_problem_outlined, Colors.pink, () {
                      Navigator.push(context, MaterialPageRoute(builder: (c) => AdminComplaintsScreen(showAppBar: true)));
                    }, isDark),
                    const SizedBox(height: 12),
                    _actionCard('Support Engagement', 'AI escalations & inquiries', Icons.support_agent, Colors.purple, () {
                      Navigator.push(context, MaterialPageRoute(builder: (c) => AdminSupportInquiriesScreen()));
                    }, isDark),
                    const SizedBox(height: 12),
                    _actionCard('Announcement History', 'View & manage broadcasts', Icons.campaign, Colors.redAccent, () {
                      // AdminBroadcastsScreen is in admin_dashboard_screen.dart
                      Navigator.push(context, MaterialPageRoute(builder: (c) => AdminBroadcastsScreen()));
                    }, isDark),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _liveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: Colors.green, size: 8),
          SizedBox(width: 6),
          Text('LIVE', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: FadeInUp(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 10),
              Text(title, style: TextStyle(color: isDark ? Colors.grey : Colors.grey[600], fontSize: 10, fontWeight: FontWeight.bold)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRevenueChart(bool isDark) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final currentIdx = DateTime.now().month - 1;
    final displayMonths = <String>[];
    for (int i = 5; i >= 0; i--) {
      int idx = (currentIdx - i);
      if (idx < 0) idx += 12;
      displayMonths.add(months[idx]);
    }

    double maxRev = 1000;
    _monthlyRevenue.values.forEach((v) { if (v > maxRev) maxRev = v; });

    return FadeInUp(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Revenue Intelligence', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            Text('Last 6 months', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: displayMonths.map((m) {
                double v = _monthlyRevenue[m] ?? 0;
                double h = maxRev == 0 ? 5 : (v / maxRev) * 100;
                return _bar(h.clamp(5, 100), m, v, isDark);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(double h, String l, double amt, bool isDark) {
    return Column(
      children: [
        if (amt > 0) Text('₹${(amt / 1000).toStringAsFixed(1)}K', style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 8, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          width: 30,
          height: h,
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Theme.of(context).primaryColor.withOpacity(0.3), Theme.of(context).primaryColor]),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 8),
        Text(l, style: TextStyle(color: isDark ? Colors.grey : Colors.grey[600], fontSize: 10)),
      ],
    );
  }

  Widget _actionCard(String title, String sub, IconData icon, Color color, VoidCallback onTap, bool isDark) {
    return FadeInUp(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: color)),
              const SizedBox(width: 20),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), const SizedBox(height: 2), Text(sub, style: const TextStyle(fontSize: 11, color: Colors.grey))])),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
