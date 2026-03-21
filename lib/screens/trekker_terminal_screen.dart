import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'my_trips_screen.dart';
import 'blogs_screen.dart';
import 'trek_training_hub.dart';
import 'user_gear_rental_screen.dart';
import 'user_complaints_screen.dart';
import 'ai_guide_screen.dart';
import 'achievements_screen.dart';
import 'user_support_screen.dart';

class TrekkerTerminalScreen extends StatefulWidget {
  const TrekkerTerminalScreen({super.key});

  @override
  State<TrekkerTerminalScreen> createState() => _TrekkerTerminalScreenState();
}

class _TrekkerTerminalScreenState extends State<TrekkerTerminalScreen> {
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
    _loadTerminalData();
    _setupWalletListener();
  }

  void _setupWalletListener() {
    final user = _client.auth.currentUser;
    if (user == null) return;
    _walletSubscription = _client
        .from('payment_logs')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .listen((_) => _loadTerminalData());
  }

  @override
  void dispose() {
    _walletSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadTerminalData() async {
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

      if (mounted) {
        setState(() {
          _userData = profile;
          _role = profile?['role'] ?? 'user';
          _walletBalance = realBalance;
          _globalAnnouncements = announcements;
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
          'TREKKER TERMINAL',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
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
          heroTag: 'trekker_support_fab',
          onPressed: _showSupportRegistry,
          backgroundColor: Colors.blueAccent,
          icon: const Icon(Icons.support_agent, color: Colors.white),
          label: const Text('HQ SUPPORT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ) : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTerminalData,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildWalletCard(),
                   const SizedBox(height: 10),  
                    const Text(
                      'TREK HUB',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1.2,
                    ),
                  ),
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
                        'My Stories',
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
                        () => Navigator.pushNamed(context, '/tactical_dossier'),
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
                            builder: (c) => const TrekTrainingHub(),
                          ),
                        ),
                      ),
                      if (_role != 'user')
                        _hubItem(
                          Icons.account_balance_outlined,
                          'HQ Payroll',
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
          colors: [Color(0xFF1E293B), Colors.black],
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
                'COMMAND LIQUIDITY',
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
                child: const Text('TREK READY', style: TextStyle(color: Colors.blueAccent, fontSize: 8, fontWeight: FontWeight.bold)),
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

  Widget _missionCard(dynamic b) {
    final trek = b['treks'];
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
                  trek?['image_url'] ?? 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b',
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
                      trek?['title'] ?? 'TREK',
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

  Widget _emptyTreksCard() {
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
            'NO ACTIVE TREKS',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Deploy yourself on a new trek expedition.',
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
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
    // Already defined in ChatRoomList but for Admin accessibility in terminal too
    Navigator.pushNamed(context, '/chat_rooms');
  }
}
