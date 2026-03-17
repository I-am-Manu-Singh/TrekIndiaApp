import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/trek.dart';
import '../services/database_service.dart';
import 'admin_management_hub_screen.dart';
import 'admin_support_inquiries_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = true;
  
  int _totalBookings = 0;
  double _totalRevenue = 0;
  int _totalUsers = 0;
  int _totalRentals = 0;
  int _returnedRentals = 0;
  int _pendingRentals = 0;
  Map<String, double> _monthlyRevenue = {};

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    await _loadStats();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadStats() async {
    try {
      final client = Supabase.instance.client;
      final bookingsCount = await client.from('bookings').select('id');
      final revenueResponse = await client.from('bookings').select('total_price, booking_date');
      final usersCount = await client.from('profiles').select('id');

      double revenue = 0;
      Map<String, double> monthly = {};
      
      for (var row in (revenueResponse as List)) {
        double val = double.tryParse(row['total_price'].toString()) ?? 0;
        revenue += val;
        try {
          DateTime date = DateTime.parse(row['booking_date']);
          String m = DateFormat('MMM').format(date);
          monthly[m] = (monthly[m] ?? 0) + val;
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _totalBookings = (bookingsCount as List).length;
          _totalRevenue = revenue;
          _totalUsers = (usersCount as List).length;
          _monthlyRevenue = monthly;
        });
      }

      final rentals = await client.from('user_rentals').select('status');
      if (mounted) {
        setState(() {
          _totalRentals = (rentals as List).length;
          _returnedRentals = rentals.where((r) => r['status'] == 'returned').length;
          _pendingRentals = _totalRentals - _returnedRentals;
        });
      }
    } catch (e) {
      print('Error loading admin stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administration HQ', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeInDown(
                child: Row(
                  children: [
                    const Icon(Icons.analytics_outlined, size: 28, color: Colors.black),
                    const SizedBox(width: 12),
                    const Text('Intelligence Overview', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    _liveBadge(),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _buildStatCard('Bookings', '$_totalBookings', Icons.book_online, Colors.blue),
                  const SizedBox(width: 16),
                  _buildStatCard('Revenue', '₹${(_totalRevenue / 1000).toStringAsFixed(1)}K', Icons.payments, Colors.green),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildStatCard('Hikers', '$_totalUsers', Icons.people, Colors.purple),
                  const SizedBox(width: 16),
                  _buildStatCard('Active Gear', '$_pendingRentals', Icons.shopping_bag, Colors.orange),
                ],
              ),
              const SizedBox(height: 24),
              _buildRevenueChart(),
              const SizedBox(height: 24),
              _buildLargeMenuCard('Support Engagement', 'Resolve personnel escalations & AI logs.', Icons.support_agent, Colors.pinkAccent, () {
                Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminSupportInquiriesScreen()));
              }),
              const SizedBox(height: 16),
              _buildLargeMenuCard('Announcement History', 'View and manage mission broadcasts.', Icons.history, Colors.redAccent, () {
                Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminBroadcastsScreen()));
              }),
              const SizedBox(height: 50),
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
        children: [
          Icon(Icons.circle, color: Colors.green, size: 8),
          const SizedBox(width: 6),
          const Text('LIVE', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 4)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart() {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final currentIdx = DateTime.now().month - 1;
    final displayMonths = [];
    for (int i = 5; i >= 0; i--) {
      int idx = (currentIdx - i);
      if (idx < 0) idx += 12;
      displayMonths.add(months[idx]);
    }

    double maxRev = 1000;
    _monthlyRevenue.values.forEach((v) { if (v > maxRev) maxRev = v; });

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(30)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Revenue Intelligence', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: displayMonths.map((m) {
              double v = _monthlyRevenue[m] ?? 0;
              double h = maxRev == 0 ? 0 : (v / maxRev) * 100;
              return _bar(h.clamp(5, 100), m, v);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _bar(double h, String l, double amt) {
    return Column(
      children: [
        if (amt > 0) Text('₹${(amt / 1000).toStringAsFixed(1)}K', style: const TextStyle(color: Colors.amber, fontSize: 8, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(width: 25, height: h, decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(6))),
        const SizedBox(height: 8),
        Text(l, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }

  Widget _buildLargeMenuCard(String title, String sub, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: color)),
            const SizedBox(width: 20),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text(sub, style: const TextStyle(fontSize: 12, color: Colors.grey))])),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class AdminBroadcastsScreen extends StatefulWidget {
  const AdminBroadcastsScreen({super.key});

  @override
  State<AdminBroadcastsScreen> createState() => _AdminBroadcastsScreenState();
}

class _AdminBroadcastsScreenState extends State<AdminBroadcastsScreen> {
  bool _isLoading = true;
  List<dynamic> _broadcasts = [];

  @override
  void initState() {
    super.initState();
    _fetchBroadcasts();
  }

  Future<void> _fetchBroadcasts() async {
    setState(() => _isLoading = true);
    final res = await Supabase.instance.client.from('broadcasts').select().order('created_at', ascending: false);
    if (mounted) setState(() { _broadcasts = res; _isLoading = false; });
  }

  Future<void> _delete(String id) async {
    await Supabase.instance.client.from('broadcasts').delete().eq('id', id);
    _fetchBroadcasts();
  }

  Future<void> _showCreateDialog({Map<String, dynamic>? existing}) async {
    final c = TextEditingController(text: existing?['content']);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'New Squad Dispatch' : 'Refine Dispatch'),
        content: TextField(controller: c, maxLines: 3, decoration: const InputDecoration(hintText: 'Enter alert message...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(onPressed: () async {
            if (c.text.isEmpty) return;
            if (existing == null) {
              await Supabase.instance.client.from('broadcasts').insert({
                'sender_id': Supabase.instance.client.auth.currentUser!.id,
                'content': c.text
              });
            } else {
              await Supabase.instance.client.from('broadcasts').update({
                'content': c.text
              }).eq('id', existing['id']);
            }
            Navigator.pop(ctx);
            _fetchBroadcasts();
          }, child: Text(existing == null ? 'DISPATCH' : 'UPDATE'))
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcement History', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        label: const Text('NEW ANNOUNCEMENT', style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.campaign),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _broadcasts.length,
            itemBuilder: (context, i) {
              final b = _broadcasts[i];
              final date = DateTime.parse(b['created_at']).toLocal();
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(b['content'], style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(DateFormat('MMM dd, yyyy • HH:mm').format(date), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent), onPressed: () => _showCreateDialog(existing: b)),
                      IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _delete(b['id'])),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }
}
