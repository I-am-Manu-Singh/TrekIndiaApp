import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../widgets/glass_shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'my_trips_screen.dart';
import 'blogs_screen.dart';
import 'trip_training_hub.dart';
import 'user_gear_rental_screen.dart';
import 'user_complaints_screen.dart';
import 'ai_guide_screen.dart';
import 'achievements_screen.dart';
import 'user_support_screen.dart';

class TripDashboardScreen extends StatefulWidget {
  const TripDashboardScreen({super.key});

  @override
  State<TripDashboardScreen> createState() => _TripDashboardScreenState();
}

class _TripDashboardScreenState extends State<TripDashboardScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  List<dynamic> _activeBookings = [];
  List<dynamic> _globalAnnouncements = [];
  double _walletBalance = 0;
  String _role = 'user';
  StreamSubscription? _walletSubscription;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _setupWalletListener();
  }

  void _setupWalletListener() {
    final user = _client.auth.currentUser;
    if (user == null) return;
    _walletSubscription = _client
        .from('payment_logs')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .listen((_) {
          // Optimization: Use a local timer to throttle reloads to once every 2 seconds max
          _throttleDashboardReload();
        });
  }

  Timer? _reloadTimer;
  void _throttleDashboardReload() {
    if (_reloadTimer?.isActive ?? false) return;
    _reloadTimer = Timer(const Duration(seconds: 2), _loadDashboardData);
  }

  @override
  void dispose() {
    _walletSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final profile = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      
      // Calculate real liquidity balance from payment_logs
      final logs = await _client.from('payment_logs').select('amount, is_incoming').eq('user_id', user.id);
      double realBalance = (logs as List).fold(0.0, (sum, log) {
        final amount = double.tryParse(log['amount'].toString()) ?? 0;
        final bool isIncoming = log['is_incoming'] ?? true;
        // In this app, many logs have is_incoming=false for outgoing payments (like booking costs)
        // We ensure the balance reflects the CURRENT user wallet state
        return sum + (isIncoming ? amount : -amount);
      });
      
      if (realBalance < 0) realBalance = 0; // Safety for negative balance UI glitch

      final announcements = await _client
          .from('global_announcements')
          .select()
          .order('created_at', ascending: false)
          .limit(2);

      // Resilient bookings fetch
      final bookingsRaw = await _client.from('bookings').select().eq('user_id', user.id).order('trip_date', ascending: true);
      final tripsRaw = await _client.from('trips').select();
      final tripsMap = {for (var t in tripsRaw) t['id']: t};

      final bookingsEnriched = (bookingsRaw as List).map((b) {
        final booking = Map<String, dynamic>.from(b);
        booking['trips'] = tripsMap[b['trip_id']];
        return booking;
      }).where((b) => b['status']?.toString().toLowerCase() != 'completed').toList();

      if (mounted) {
        setState(() {
          _userData = profile;
          _role = profile?['role'] ?? 'user';
          _walletBalance = realBalance;
          _globalAnnouncements = announcements;
          _activeBookings = bookingsEnriched;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
   return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'MY DASHBOARD',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        backgroundColor: const Color(0xFFD32F2F),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (c) => const AIGuideScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: _role == 'admin' ? Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: FloatingActionButton.extended(
          heroTag: 'trip_support_fab',
          onPressed: _showSupportRegistry,
          backgroundColor: Colors.blueAccent,
          icon: const Icon(Icons.support_agent, color: Colors.white),
          label: const Text('trekwithmussafirr SUPPORT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ) : null,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: kIsWeb ? 800 : double.infinity),
          child: _isLoading
              ? _buildDashboardShimmer()
              : RefreshIndicator(
                  onRefresh: _loadDashboardData,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _buildWalletCard(),
                      const SizedBox(height: 22),
                      const Text('EXPLORER HUD', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5, color: Colors.grey)),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        children: [
                          _hubItem(
                            Icons.auto_stories_outlined,
                            'Blogs',
                            Colors.orange,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (c) =>
                                    const BlogsScreen(onlyMyBlogs: true),
                              ),
                            ),
                          ),
                          _hubItem(
                            Icons.map_outlined,
                            'Journeys',
                            Colors.blue,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (c) => const MyTripsScreen(),
                              ),
                            ),
                          ),
                          _hubItem(
                            Icons.shopping_bag_outlined,
                            'Rentals',
                            Colors.deepPurple,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (c) => const UserGearRentalScreen(),
                              ),
                            ),
                          ),
                          _hubItem(
                            Icons.report_problem_outlined,
                            'Support',
                            Colors.red,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (c) => const UserSupportScreen(),
                              ),
                            ),
                          ),
                          _hubItem(
                            Icons.fitness_center,
                            'Training',
                            Colors.green,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (c) => const TripTrainingHub(),
                              ),
                            ),
                          ),
                          if (_role != 'user')
                            _hubItem(
                              Icons.account_balance_outlined,
                              'trekwithmussafirr Payroll',
                              Colors.indigo,
                              () => Navigator.pushNamed(context, '/salary_breakup'),
                            ),
                            _hubItem(
                            Icons.badge_outlined,
                            'Achievements',
                            Colors.amber,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (c) => const AchievementsScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      const Text('UPCOMING ADVENTURES', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5, color: Colors.grey)),
                      if (_activeBookings.isEmpty) _emptyTripsCard()
                      else ..._activeBookings.map((b) => _tripCard(b)).toList(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildWalletCard() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF18181B), Colors.black],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'WALLET BALANCE',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Text('TRIP READY', style: TextStyle(color: Colors.blueAccent, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '₹${_walletBalance.toInt()}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              _walletBtn('ADD FUNDS', Icons.add_circle_outline, Colors.blueAccent, onTap: () async {
                // Mock Fund Addition for Demonstration
                final user = Supabase.instance.client.auth.currentUser;
                if (user == null) return;
                await Supabase.instance.client.from('payment_logs').insert({
                  'user_id': user.id,
                  'amount': 5000,
                  'is_incoming': true,
                  'description': 'Manual Wallet Top-up (Authorized)',
                });
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('₹5000 ADDED TO EXPEDITION WALLET'), backgroundColor: Colors.green));
                _loadDashboardData();
              }),
              const SizedBox(width: 16),
              _walletBtn(
                'HISTORY',
                Icons.account_tree_outlined,
                Colors.white.withOpacity(0.05),
                onTap: () => Navigator.pushNamed(context, '/payment_ledger'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _walletBtn(
    String label,
    IconData icon,
    Color bg, {
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 14),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tripCard(dynamic b) {
    final trip = b['trips'];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FadeInUp(
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const MyTripsScreen())),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  trip?['image_url'] ?? 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b',
                  width: 55,
                  height: 55,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, e, s) => Container(width: 55, height: 55, color: Colors.blue.shade50, child: const Icon(Icons.terrain, color: Colors.blue)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip?['title'] ?? 'TRIP',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      b['status']?.toString().toUpperCase() ?? 'PENDING',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyTripsCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade100,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          const Icon(Icons.explore_outlined, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'NO ACTIVE TRIPS',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Book your next trip.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _hubItem(IconData icon, String label, Color color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
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
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(isDark ? 0.2 : 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white70 : Colors.black87,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _broadcastCard(dynamic b) {
    final bool isUrgent = b['is_urgent'] ?? false;
    final String priority = b['priority']?.toString() ?? (isUrgent ? 'urgent' : 'standard');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Color baseColor = Colors.blue;
    if (priority == 'urgent' || isUrgent) baseColor = Colors.red;
    if (priority == 'info') baseColor = Colors.teal;
    if (priority == 'warning') baseColor = Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: baseColor.withOpacity(isDark ? 0.15 : 0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: baseColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isUrgent || priority == 'urgent' ? Icons.warning_amber_rounded : (priority == 'info' ? Icons.info_outline : Icons.campaign_outlined), 
            color: baseColor, 
            size: 20
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b['title'] ?? 'ANNOUNCEMENT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                Text(b['content'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 16, color: isDark ? Colors.white24 : Colors.grey),
        ],
      ),
    );
  }

  void _showSupportRegistry() {
    // Already defined in ChatRoomList but for Admin accessibility in dashboard too
    Navigator.pushNamed(context, '/chat_rooms');
  }

  Widget _buildDashboardShimmer() {
    return GlassShimmer(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Wallet Card Shimmer
          Container(
            padding: const EdgeInsets.all(30),
            height: 200,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBlock(width: 100, height: 10),
                SizedBox(height: 16),
                ShimmerBlock(width: 150, height: 40),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const ShimmerBlock(width: 100, height: 12),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: List.generate(6, (i) => Container(
              padding: const EdgeInsets.all(12),
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
          const SizedBox(height: 32),
          const ShimmerBlock(width: 150, height: 12),
          const SizedBox(height: 16),
          ...List.generate(2, (i) => Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            height: 90,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: const Row(
              children: [
                ShimmerBlock(width: 55, height: 55, borderRadius: 12),
                SizedBox(width: 16),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBlock(width: 120, height: 12),
                    SizedBox(height: 8),
                    ShimmerBlock(width: 60, height: 8),
                  ],
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
