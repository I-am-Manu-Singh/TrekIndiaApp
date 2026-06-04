import 'package:flutter/material.dart';
import '../widgets/glass_shimmer.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _broadcasts = [];
  Map<String, dynamic> _stats = {
    'revenue': 0.0,
    'bookings': 0,
    'trips': 0,
    'enquiries': 0,
    'staff': 0,
    'reports': 0,
    'complaints': 0,
  };
  List<FlSpot> _revenueSpots = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final broadcastRes = await _client.from('global_announcements').select().order('created_at', ascending: false);
      final bookingRes = await _client.from('bookings').select('total_price, paid_amount, booking_date');
      final tripRes = await _client.from('trip_groups').select('id').gte('departure_date', DateTime.now().toIso8601String());
      final enquiryRes = await _client.from('support_inquiries').select('id').eq('status', 'pending');
      final profileRes = await _client.from('profiles').select('id, role').neq('role', 'user');
      final complaintRes = await _client.from('complaints').select('id').or('status.eq.pending,status.eq.Pending');
      final taskRes = await _client.from('employee_tasks').select('id').eq('status', 'Pending');

      double revenue = 0;
      Map<int, double> monthlyRev = {};
      for (var b in bookingRes) {
        double amt = double.tryParse(b['paid_amount']?.toString() ?? '0') ?? 
                     double.tryParse(b['total_price']?.toString() ?? '0') ?? 0;
        revenue += amt;
        
        final date = DateTime.tryParse(b['booking_date'] ?? '');
        if (date != null) {
          monthlyRev[date.month] = (monthlyRev[date.month] ?? 0) + amt;
        }
      }

      List<FlSpot> spots = [];
      for (int i = 1; i <= 12; i++) {
        spots.add(FlSpot(i.toDouble(), (monthlyRev[i] ?? 0) / 1000)); // Scale to K
      }

      if (mounted) {
        setState(() {
          _broadcasts = broadcastRes;
          _revenueSpots = spots;
          _stats = {
            'revenue': revenue,
            'bookings': bookingRes.length,
            'trips': tripRes.length,
            'enquiries': enquiryRes.length,
            'staff': profileRes.length,
            'reports': enquiryRes.length, 
            'complaints': complaintRes.length,
            'tasks': taskRes.length,
          };
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: const Text('ADMIN DASHBOARD', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white, letterSpacing: 1.5)),
        backgroundColor: const Color(0xFFD32F2F),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white, size: 20), onPressed: _loadDashboardData),
          IconButton(icon: const Icon(Icons.add_circle, color: Colors.white, size: 20), onPressed: () => _showBroadcastModal()),
        ],
      ),
      body: _isLoading
        ? _buildDashboardShimmer()
        : RefreshIndicator(
            onRefresh: _loadDashboardData,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _buildAnalyticsGraph(),
                    const SizedBox(height: 32),
                    const Text('KEY METRICS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2, color: Colors.blueGrey)),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.6,
                      children: [
                        _statCard('TOTAL REVENUE', '₹${(_stats['revenue'] / 1000).toStringAsFixed(1)}K', Icons.payments, const Color(0xFFD32F2F), onTap: () => Navigator.pushNamed(context, '/admin_finance')),
                        _statCard('TOTAL BOOKINGS', '${_stats['bookings']}', Icons.assignment, const Color(0xFFD32F2F), onTap: () => Navigator.pushNamed(context, '/admin_bookings')),
                        _statCard('TOTAL STAFF', '${_stats['staff']}', Icons.people, const Color(0xFFD32F2F), onTap: () => Navigator.pushNamed(context, '/admin_employees')),
                        _statCard('ACTIVE REPORTS', '${_stats['reports']}', Icons.analytics, const Color(0xFFD32F2F), onTap: () => Navigator.pushNamed(context, '/admin_support_inquiries')),
                        _statCard('COMPLAINTS', '${_stats['complaints']}', Icons.report_problem, const Color(0xFFD32F2F), onTap: () => Navigator.pushNamed(context, '/admin_complaints')),
                        _statCard('PENDING TASKS', '${_stats['tasks']}', Icons.task_alt, const Color(0xFFD32F2F), onTap: () => Navigator.pushNamed(context, '/admin_tasks')),
                      ],
                    ),
                    const SizedBox(height: 40),
                    const Text('NOTIFICATIONS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2, color: Colors.blueGrey)),
                    const SizedBox(height: 16),
                    if (_broadcasts.isEmpty)
                      const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('NO ACTIVE BROADCASTS', style: TextStyle(color: Colors.grey, fontSize: 12))))
                    else
                      ..._broadcasts.map((b) => _buildBroadcastCard(b)),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildAnalyticsGraph() {
    return FadeInDown(
      child: Container(
        height: 250,
        padding: const EdgeInsets.fromLTRB(10, 30, 30, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20)],
        ),
        child: Column(
          children: [
            const Text('REVENUE TRENDS (MONTHLY)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
            const SizedBox(height: 20),
            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _revenueSpots,
                      isCurved: true,
                      color: const Color(0xFFD32F2F),
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [const Color(0xFFD32F2F).withOpacity(0.3), const Color(0xFFD32F2F).withOpacity(0)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String val, IconData icon, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.withOpacity(0.05))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 8),
            Text(val, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 7, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildBroadcastCard(dynamic b) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.withOpacity(0.05))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(DateFormat('MMM dd, HH:mm').format(DateTime.parse(b['created_at'])), style: const TextStyle(fontSize: 10, color: Colors.grey)),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                onPressed: () async {
                  await _client.from('global_announcements').delete().eq('id', b['id']);
                  _loadDashboardData();
                },
              ),
            ],
          ),
          Text(b['title'] ?? 'URGENT INFO', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          Text(b['content'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }

  void _showBroadcastModal({dynamic existing}) {
    final titleCtrl = TextEditingController(text: existing?['title']);
    final contentCtrl = TextEditingController(text: existing?['content']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(30, 30, 30, MediaQuery.of(ctx).viewInsets.bottom + 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SEND NOTIFICATION', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
            const SizedBox(height: 24),
            _modalInput(titleCtrl, 'Title...', 1),
            const SizedBox(height: 16),
            _modalInput(contentCtrl, 'Content...', 4),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () async {
                  if (titleCtrl.text.isEmpty) return;
                  if (existing != null) {
                    await _client.from('global_announcements').update({'title': titleCtrl.text, 'content': contentCtrl.text, 'is_urgent': true}).eq('id', existing['id']);
                  } else {
                    await _client.from('global_announcements').insert({'title': titleCtrl.text, 'content': contentCtrl.text, 'created_at': DateTime.now().toIso8601String(), 'is_urgent': true});
                  }
                  Navigator.pop(ctx);
                  _loadDashboardData();
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: const Text('SEND', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modalInput(TextEditingController ctrl, String hint, int lines) {
    return TextField(
      controller: ctrl,
      maxLines: lines,
      decoration: InputDecoration(hintText: hint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
    );
  }

  Widget _buildDashboardShimmer() {
    return GlassShimmer(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const ShimmerBlock(width: double.infinity, height: 250, borderRadius: 25),
              const SizedBox(height: 32),
              const ShimmerBlock(width: 100, height: 12),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: List.generate(6, (i) => const ShimmerBlock(width: double.infinity, height: 80, borderRadius: 15)),
              ),
              const SizedBox(height: 40),
              const ShimmerBlock(width: 120, height: 12),
              const SizedBox(height: 16),
              ...List.generate(3, (i) => const ShimmerBlock(width: double.infinity, height: 100, margin: EdgeInsets.only(bottom: 12), borderRadius: 20)),
            ],
          ),
        ),
      ),
    );
  }
}
