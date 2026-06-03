import 'dart:async';
import 'package:flutter/material.dart';
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
import '../services/invoice_service.dart';

class TripTerminalScreen extends StatefulWidget {
  const TripTerminalScreen({super.key});

  @override
  State<TripTerminalScreen> createState() => _TripTerminalScreenState();
}

class _TripTerminalScreenState extends State<TripTerminalScreen> {
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
        .listen((_) => _loadDashboardData());
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
      final logs = await _client.from('payment_logs').select('amount').eq('user_id', user.id);
      double realBalance = (logs as List).fold(0.0, (sum, log) => sum + (double.tryParse(log['amount'].toString()) ?? 0));

      final announcements = await _client
          .from('global_announcements')
          .select()
          .order('created_at', ascending: false)
          .limit(2);

      final activeBookings = await _client
          .from('bookings')
          .select('*, trip:trips(*)')
          .eq('user_id', user.id)
          .neq('status', 'cancelled')
          .order('trip_date', ascending: true)
          .limit(3);

      if (mounted) {
        setState(() {
          _userData = profile;
          _role = profile?['role'] ?? 'user';
          _walletBalance = realBalance;
          _globalAnnouncements = announcements;
          _activeBookings = activeBookings as List;
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
        backgroundColor: Colors.black,
        elevation: 0,
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildWalletCard(),
                   const SizedBox(height: 22),  
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    children: [
                      _hubItem(
                        Icons.auto_stories_outlined,
                        'MY BLOGS',
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
                        Icons.folder_shared_outlined,
                        'Documents',
                        Colors.teal,
                        () => Navigator.pushNamed(context, '/travel_documents'),
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
                    ],
                  ),
                  const SizedBox(height: 16),
                  _hubItem(
                    Icons.badge_outlined,
                    'Achievements & Progress',
                    Colors.amber,
                    () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AchievementsScreen())),
                  ),
                  const SizedBox(height: 32),
                  const Text('ACTIVE JOURNEYS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2, color: Colors.grey)),
                  const SizedBox(height: 16),
                  if (_activeBookings.isEmpty) 
                    _emptyTripsCard()
                  else 
                    ..._activeBookings.map((b) => _terminalTripCard(b)),
                  const SizedBox(height: 40),
                ],
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
              _walletBtn('ADD FUNDS', Icons.add_circle_outline, Colors.blueAccent, onTap: () {}),
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

  Widget _terminalTripCard(dynamic b) {
    final trip = b['trip']; // Note: fetching uses 'trip' alias in select
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                trip?['image_url'] ?? 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b',
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (ctx, e, s) => Container(width: 60, height: 60, color: Colors.blue.shade50, child: const Icon(Icons.terrain, color: Colors.blue)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip?['title'] ?? 'TRIP',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 10, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd MMM').format(DateTime.parse(b['trip_date'])),
                        style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                        child: Text(
                          b['status']?.toString().toUpperCase() ?? 'CONFIRMED',
                          style: const TextStyle(color: Colors.green, fontSize: 7, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => InvoiceService.generateAndDownloadInvoice(
                bookingId: b['id'],
                tripName: trip?['title'] ?? 'Trip',
                date: DateTime.parse(b['trip_date']),
                hikerName: b['hiker_name'] ?? _userData?['full_name'] ?? 'Hiker',
                totalPrice: double.tryParse(b['total_price'].toString()) ?? 0,
                basePrice: double.tryParse((b['base_price'] ?? 0).toString()) ?? 0,
                pickupPrice: double.tryParse((b['pickup_price'] ?? 0).toString()) ?? 0,
                pickupLocation: b['pickup_location'] ?? 'Base Camp',
                email: _userData?['email'],
              ),
              icon: const Icon(Icons.download_for_offline_rounded, color: Colors.blueAccent),
              tooltip: 'Download Invoice',
            ),
          ],
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

  Widget _hubItem(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: color, size: 34),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
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
}
