import 'package:flutter/material.dart';
import '../widgets/glass_shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/user_avatar.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'payment_ledger_screen.dart';
import 'my_attendance_screen.dart';
import 'activity_tracking_screen.dart';
import 'policy_handbook_screen.dart';
import 'app_info_screen.dart';
import 'user_support_screen.dart';
import 'admin_trip_groups_screen.dart';
import 'admin_package_management_screen.dart';
import 'admin_broadcast_screen.dart';
import 'employee_tasks_screen.dart';
import 'employee_bookings_screen.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() => _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  final user = Supabase.instance.client.auth.currentUser;
  bool _isLoading = true;
  bool _hasCheckedIn = false;
  Map<String, dynamic>? _employeeData;

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
      final profileRes = await client.from('profiles').select().eq('id', user!.id).maybeSingle();
      
      // Check if already checked in today
      final now = DateTime.now();
      final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final att = await client.from('attendance_logs').select().eq('user_id', user!.id).eq('date', dateStr).maybeSingle();

      if (mounted) {
        setState(() {
          _employeeData = profileRes; // Use profile for leaves/xp
          _hasCheckedIn = att != null;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAttendance() async {
    if (_hasCheckedIn) return;
    
    try {
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);

      await Supabase.instance.client.from('attendance_logs').upsert({
        'user_id': user!.id,
        'date': dateStr,
        'status': 'present',
      }, onConflict: 'user_id,date');

      // SYNC METRICS TO PROFILE (Consistency Protocol)
      final allLogs = await Supabase.instance.client.from('attendance_logs').select('status').eq('user_id', user!.id);
      int paid = 0;
      int unpaid = 0;
      int half = 0;
      int off = 0;
      
      for (var log in (allLogs as List)) {
        String s = log['status']?.toString().toLowerCase() ?? '';
        if (s == 'paid_leave') paid++;
        else if (s == 'leave' || s == 'unpaid_leave') unpaid++;
        else if (s == 'half_day') half++;
        else if (s == 'off_duty') off++;
      }
      
      await Supabase.instance.client.from('profiles').update({
        'paid_leaves': paid,
        'unpaid_leaves': unpaid,
        'half_days': half,
        'off_duty_days': off,
      }).eq('id', user!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CHECK-IN SUCCESSFUL: Workday Started.')));
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Check-in Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildEmployeeShimmer();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('EMPLOYEE DASHBOARD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        backgroundColor: const Color(0xFFD32F2F),
        elevation: 0,
        actions: [
          _liveBadge(),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/edit_profile'),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                UserAvatar(
                  imageUrl: _employeeData?['avatar_url'],
                  name: _employeeData?['full_name'],
                  width: 38,
                  height: 38,
                  borderRadius: BorderRadius.circular(10),
                ),
                if (_employeeData?['aadhar_url'] != null)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(1),
                      decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                      child: const Icon(Icons.verified, color: Colors.white, size: 8),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 20),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildAttendanceHero(),
            const SizedBox(height: 32),
            _buildStaffAnalytics(), // TRIP RELOCATION: Moved from Profile
            const SizedBox(height: 32),
            _buildPerformanceInsights(),
            const SizedBox(height: 32),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('DASHBOARD CONTROLS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5)),
            ),
            const SizedBox(height: 16),
            _buildDashboardGrid(),
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
          Text('ONLINE', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildAttendanceHero() {
    return FadeInDown(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: const Color(0xFFB71C1C).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Column(
          children: [
            const Icon(Icons.touch_app_outlined, color: Colors.white, size: 50),
            const SizedBox(height: 20),
            const Text('Daily Check-In', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              _hasCheckedIn ? "Status: Checked In Successfully" : "Status: Awaiting Check-In",
              style: TextStyle(color: _hasCheckedIn ? Colors.greenAccent : Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _hasCheckedIn ? null : _markAttendance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hasCheckedIn ? Colors.white10 : Colors.white12,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  side: const BorderSide(color: Colors.white24),
                ),
                child: Text(
                  _hasCheckedIn ? "WORKDAY COMPLETE" : "START WORKDAY",
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1),
                ),
              ),
            ),
          ],
        ),
      ),
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
        _dashboardCard('Trip\nSettlements', Icons.account_balance_wallet_outlined, Colors.red.shade100, Colors.red, () => Navigator.pushNamed(context, '/payment_ledger')),
        _dashboardCard('Assigned\nGroups', Icons.groups_outlined, Colors.red.shade100, Colors.red, () => Navigator.pushNamed(context, '/employee_groups')),
        _dashboardCard('Attendance\nRecord', Icons.event_note_outlined, Colors.red.shade100, Colors.red, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const MyAttendanceScreen()))),
        _dashboardCard('Trip\nTasks', Icons.assignment_outlined, Colors.red.shade100, Colors.red, () => Navigator.pushNamed(context, '/employee_tasks')),
        if (_employeeData?['can_manage_trips'] == true)
          _dashboardCard('Manage\nPackages', Icons.redeem, Colors.red.shade100, Colors.red, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminPackageManagementScreen()))),
        if (_employeeData?['can_broadcast'] == true)
          _dashboardCard('Broadcast\nAlerts', Icons.campaign_outlined, Colors.red.shade100, Colors.red, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminBroadcastScreen()))),
        _dashboardCard('Official\nHandbook', Icons.menu_book_outlined, Colors.red.shade100, Colors.red, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PolicyHandbookScreen()))),
        _dashboardCard('Salary\nBreakup', Icons.payments_outlined, Colors.red.shade100, Colors.red, () => Navigator.pushNamed(context, '/salary_breakup')),
      ],
    );
  }

  void _showPlaceholder(String title) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title is currently offline. trekwithmussafirr will release updates soon.')));
  }

  Widget _dashboardCard(String label, IconData icon, Color bgColor, Color iconColor, VoidCallback onTap) {
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

  Widget _buildStaffAnalytics() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.01), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.query_stats, color: Colors.blueAccent, size: 18),
              SizedBox(width: 8),
              Text('STAFF ANALYTICS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5, color: Colors.blueGrey)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _empStatMini('PAID', _employeeData?['paid_leaves'] ?? 0, const Color(0xFFD32F2F)),
              _empStatMini('UNPAID', _employeeData?['unpaid_leaves'] ?? 0, const Color(0xFFD32F2F)),
              _empStatMini('HALF', _employeeData?['half_days'] ?? 0, const Color(0xFFD32F2F)),
              _empStatMini('XP', _employeeData?['xp'] ?? 0, const Color(0xFFD32F2F)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceInsights() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.01), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.track_changes, color: Colors.orangeAccent, size: 18),
              SizedBox(width: 8),
              Text('PERFORMANCE & TARGETS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5, color: Colors.blueGrey)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _empStatMini('TARGET', '85%', const Color(0xFFD32F2F)),
              _empStatMini('CLICKS', '1.2K', const Color(0xFFD32F2F)),
              _empStatMini('CONVERTED', '42', const Color(0xFFD32F2F)),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: 0.85,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD32F2F)),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          const Text('85% of Monthly Booking Target Achieved', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _empStatMini(String label, dynamic val, Color color) {
    return Column(
      children: [
        Text('$val', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildEmployeeShimmer() {
    return GlassShimmer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Attendance Hero Shimmer
            Container(
              height: 200,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ShimmerBlock(width: 50, height: 50, shape: BoxShape.circle),
                  SizedBox(height: 20),
                  ShimmerBlock(width: 150, height: 20),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Analytics Shimmer
            Container(
              height: 120,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(4, (i) => const Column(children: [ShimmerBlock(width: 30, height: 30), SizedBox(height: 8), ShimmerBlock(width: 40, height: 8)])),
              ),
            ),
            const SizedBox(height: 32),
            // Performance Shimmer
            Container(
              height: 150,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ShimmerBlock(width: 150, height: 12),
                  const SizedBox(height: 20),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: List.generate(3, (i) => const ShimmerBlock(width: 50, height: 40))),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Grid Shimmer
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: List.generate(6, (i) => Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ShimmerBlock(width: 30, height: 30, shape: BoxShape.circle),
                    SizedBox(height: 8),
                    ShimmerBlock(width: 40, height: 8),
                  ],
                ),
              )),
            ),
          ],
        ),
      ),
    );
  }
}
