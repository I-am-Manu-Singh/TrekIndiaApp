import 'package:flutter/material.dart';
import '../main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import '../services/database_service.dart';
import '../services/preferences_service.dart';
import '../models/trek.dart';
import 'admin_dashboard_screen.dart';
import 'package:flutter/foundation.dart';
import 'chat_screen.dart';
import 'trek_detail_screen.dart';
import '../widgets/user_avatar.dart';
import 'edit_profile_screen.dart';
import 'my_trips_screen.dart';
import 'add_trek_screen.dart';
import 'payment_ledger_screen.dart';
import 'user_support_screen.dart';
import 'admin_management_hub_screen.dart';
import 'admin_bookings_screen.dart';
import 'admin_support_inquiries_screen.dart';
import 'admin_complaints_screen.dart';
import 'admin_rental_tracking_screen.dart';
import 'admin_trek_inventory_screen.dart';
import 'trek_training_hub.dart';
import 'leaderboard_screen.dart';
import 'blogs_screen.dart';
import 'user_complaints_screen.dart';
import 'leaderboard_screen.dart';
import 'app_info_screen.dart';
import 'notification_center_screen.dart';
import 'admin_complaints_screen.dart';
import 'admin_wallet_screen.dart';

import 'admin_trek_inventory_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  final user = Supabase.instance.client.auth.currentUser;
  bool _isLoading = true;
  List<dynamic> _myBookings = [];
  List<Trek> _wishlistTreks = [];
  String _role = 'user';
  Map<String, dynamic>? _profileData;
  List<dynamic> _completedTreks = [];
  bool _notificationsEnabled = true;
  bool _locationSharingEnabled = false;
  int _adminBookingsCount = 0;
  double _adminRevenue = 0;
  int _adminTrekkersCount = 0;
  int _adminGuidesCount = 0;
  int _trainingStreak = 0;
  double _prepProgress = 0.0;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchProfile(),
      _fetchMyBookings(),
      _fetchWishlist(),
      _fetchPreferences(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchProfile() async {
    try {
      if (user != null) {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', user!.id)
            .maybeSingle();
        
        if (profile == null) {
          // Auto-create profile if missing as 'user'
          String derivedName = user!.userMetadata?['full_name'] ?? user!.email?.split('@')[0] ?? 'Trekker';
          final newProfile = {
            'id': user!.id,
            'full_name': derivedName,
            'role': 'user',
            'avatar_url': user!.userMetadata?['avatar_url'],
            'phone_number': '',
          };
          await Supabase.instance.client.from('profiles').insert(newProfile);
          if (mounted) setState(() { _role = 'user'; _profileData = newProfile; });
        } else {
          if (mounted) {
            setState(() {
              _role = profile['role'] ?? 'user';
              _profileData = profile;
            });
            if (_role == 'admin') {
              _fetchAdminGlobalStats();
            }
            _fetchCompletedTreks();
            _fetchTrainingStats();
          }
        }
      }
    } catch (e) {
      print('Error fetching profile: $e');
    }
  }

  Future<void> _fetchCompletedTreks() async {
    try {
      final res = await Supabase.instance.client
          .from('bookings')
          .select('*, treks(*)')
          .eq('user_id', user!.id)
          .eq('status', 'Completed');
      if (mounted) setState(() => _completedTreks = res);
    } catch (_) {}
  }

  void _showAdminHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Setup Tutorial'),
        content: const Text('''Your Supabase database is blocking the app from creating your user profile record.

1. Go to your Supabase Dashboard -> SQL Editor.
2. Open the file "grant_admin_access.sql" in this project.
3. Copy the content, replace the placeholder email with yours.
4. Run it in Supabase.
5. Click the Refresh icon at the top of this screen.'''),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))
        ],
      )
    );
  }

  Future<void> _fetchTrainingStats() async {
    final logs = await DatabaseService().fetchTrainingLogs();
    if (logs.isEmpty) return;

    // Streak Logic (simplified for speed)
    final uniqueDays = logs.map((l) => DateFormat('yyyy-MM-dd').format(DateTime.parse(l['completed_at']))).toSet().toList();
    uniqueDays.sort((a, b) => b.compareTo(a));

    int streak = 0;
    DateTime checker = DateTime.now();
    for (int i = 0; i < uniqueDays.length; i++) {
      final day = DateFormat('yyyy-MM-dd').format(checker);
      if (uniqueDays.contains(day)) {
        streak++;
        checker = checker.subtract(const Duration(days: 1));
      } else if (i == 0) {
        checker = checker.subtract(const Duration(days: 1));
        continue;
      } else { break; }
    }

    if (mounted) {
      setState(() {
        _trainingStreak = streak;
        _prepProgress = (logs.length / 20).clamp(0.0, 1.0); // 20 sessions = 100% ready
      });
    }
  }

  Future<void> _fetchAdminGlobalStats() async {
    try {
      final client = Supabase.instance.client;
      final bookingsResponse = await client.from('bookings').select('total_price, user_id');
      double revenue = 0;
      Set<String> uniqueTrekkers = {};
      
      for (var b in (bookingsResponse as List)) {
        revenue += double.tryParse(b['total_price'].toString()) ?? 0;
        if (b['user_id'] != null) uniqueTrekkers.add(b['user_id']);
      }
      
      final guidesResponse = await client.from('profiles').select('id').eq('role', 'guide');
      
      if (mounted) {
        setState(() {
          _adminBookingsCount = bookingsResponse.length;
          _adminRevenue = revenue;
          _adminTrekkersCount = uniqueTrekkers.length;
          _adminGuidesCount = (guidesResponse as List).length;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchMyBookings() async {
    try {
      if (user != null) {
        // Use trek:treks(*) to force singular key name
        final response = await Supabase.instance.client
            .from('bookings')
            .select('*, trek:treks(*)')
            .eq('user_id', user!.id)
            .order('booking_date', ascending: false);
        
        if (mounted) {
          setState(() {
            _myBookings = response;
          });
        }
      }
    } catch (e) {
      print('Error fetching bookings: $e');
    }
  }

  Future<void> _fetchWishlist() async {
    try {
      final savedIds = await PreferencesService().getSavedTreks();
      if (savedIds.isEmpty) {
        if (mounted) setState(() => _wishlistTreks = []);
        return;
      }

      final allTreks = await DatabaseService().fetchTreks();
      if (mounted) {
        setState(() {
          _wishlistTreks = allTreks.where((t) => savedIds.contains(t.id)).toList();
        });
      }
    } catch (e) {
      print('Error fetching wishlist: $e');
    }
  }

  Future<void> _fetchPreferences() async {
    final notify = await PreferencesService().getNotifications();
    final loc = await PreferencesService().getLocationSharing();
    if (mounted) {
      setState(() {
        _notificationsEnabled = notify;
        _locationSharingEnabled = loc;
      });
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notifications',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => NotificationCenterScreen(role: _role))),
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                if (_role != 'admin') _buildTrekStats(),
                const SizedBox(height: 30),
                
                if (_completedTreks.isNotEmpty) ...[
                  _buildSectionTitle('Expedition Badges'),
                  const SizedBox(height: 12),
                  _buildBadges(),
                  const SizedBox(height: 30),
                ],
                
                if (_role != 'admin') ...[
                  _buildConditioningStatus(),
                  const SizedBox(height: 30),
                ],
                
                if (_role != 'admin') ...[
                  _buildMenuTile(Icons.landscape, 'My Journeys', 'Upcoming, past & wishlist', () {
                    Navigator.push(context, MaterialPageRoute(builder: (c) => const MyTripsScreen()));
                  }),
                  _buildMenuTile(Icons.history_edu_outlined, 'My Stories', 'Manage your published blogs', () {
                    Navigator.push(context, MaterialPageRoute(builder: (c) => const BlogsScreen(onlyMyBlogs: true)));
                  }),
                  _buildMenuTile(Icons.account_balance_wallet_outlined, 'Payments & Refunds', 'Transaction history & refunds', () {
                    Navigator.push(context, MaterialPageRoute(builder: (c) => const PaymentLedgerScreen()));
                  }),
                ],
                
                _buildMenuTile(Icons.settings_outlined, 'App Settings', 'Theme, notifications, & more', () {
                   _showSettingsDialog();
                }),
                _buildMenuTile(Icons.info_outline, 'App Intelligence', 'Build, contacts, & mission info', () {
                   Navigator.push(context, MaterialPageRoute(builder: (c) => const AppInfoScreen()));
                }),
                if (_role == 'user' || _role == 'guide')
                  _buildMenuTile(Icons.report_problem_outlined, 'Mission Report', 'File a complaint or feedback', () {
                    Navigator.push(context, MaterialPageRoute(builder: (c) => const UserComplaintsScreen()));
                  }),

                const SizedBox(height: 20),
                _buildMenuTile(Icons.logout, 'Log Out', 'End your current session', () {
                  _signOut();
                }),

                const SizedBox(height: 50),
              ],
            ),
          ),
    );
  }

  Widget _buildMenuTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: ListTile(
          onTap: onTap,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Theme.of(context).primaryColor, size: 20),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildBadges() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _completedTreks.length,
        itemBuilder: (context, index) {
          final trek = _completedTreks[index]['treks'];
          return FadeInRight(
            delay: Duration(milliseconds: 100 * index),
            child: Container(
              width: 80,
              margin: const EdgeInsets.only(right: 15),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [Colors.amber.shade300, Colors.amber.shade700]),
                          boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 8)],
                        ),
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white,
                          backgroundImage: (trek != null && trek['image_url'] != null) ? NetworkImage(trek['image_url']) : null,
                          child: trek == null || trek['image_url'] == null ? const Icon(Icons.terrain, color: Colors.amber) : null,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                          child: const Icon(Icons.emoji_events, color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    trek?['title'] ?? 'Summit',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FadeInUp(
        child: Text(
          title, 
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
        ),
      ),
    );
  }

  void _showPlaceholderDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('GOT IT'))],
      )
    );
  }

  void _showSettingsDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (c) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('App Settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _settingToggle('Dark Mode', themeNotifier.value == ThemeMode.dark, (v) {
                setSheetState(() => themeNotifier.value = v ? ThemeMode.dark : ThemeMode.light);
                PreferencesService().setTheme(v);
              }),
              _settingToggle('Push Notifications', _notificationsEnabled, (v) {
                setSheetState(() => _notificationsEnabled = v);
                setState(() => _notificationsEnabled = v);
                PreferencesService().setNotifications(v);
              }),
              _settingToggle('Location Sharing', _locationSharingEnabled, (v) {
                setSheetState(() => _locationSharingEnabled = v);
                setState(() => _locationSharingEnabled = v);
                PreferencesService().setLocationSharing(v);
              }),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 10),
              const Text('Version 2.5.0 (Stable)', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingToggle(String title, bool value, Function(bool) onChanged) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: Switch(value: value, onChanged: onChanged, activeColor: Theme.of(context).primaryColor),
    );
  }

  Widget _buildTrekStats() {
    int totalKms = 0;
    for (var b in _completedTreks) {
      final trek = b['treks'];
      if (trek != null && trek['total_distance'] != null) {
        String distStr = trek['total_distance'].toString().replaceAll(RegExp(r'[^0-9.]'), '');
        totalKms += (double.tryParse(distStr) ?? 0).toInt();
      }
    }

     return FadeInUp(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Theme.of(context).primaryColor, Theme.of(context).primaryColor.withOpacity(0.7)]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Theme.of(context).primaryColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: IntrinsicHeight(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem('${_completedTreks.length}', 'Treks Completed'),
              _divider(),
              _statItem('$totalKms km', 'Distance covered'),
              _divider(),
              _statItem('LVL ${_profileData?['level'] ?? 1}', '${_profileData?['xp'] ?? 0} XP'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 40, color: Colors.white24);

  Widget _buildAdminPerformanceStats() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem('$_adminBookingsCount', 'MISSIONS', isDark),
              Container(width: 1, height: 30, color: isDark ? Colors.white12 : Colors.black12),
              InkWell(
                onTap: () => _showPersonnelList('trekker'),
                child: _statItem('$_adminTrekkersCount', 'HIKERS', isDark),
              ),
              Container(width: 1, height: 30, color: isDark ? Colors.white12 : Colors.black12),
              InkWell(
                onTap: () => _showPersonnelList('guide'),
                child: _statItem('$_adminGuidesCount', 'GUIDES', isDark),
              ),
              Container(width: 1, height: 30, color: isDark ? Colors.white12 : Colors.black12),
              _statItem('₹${(_adminRevenue / 1000).toStringAsFixed(1)}K', 'REVENUE', isDark),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildAdminMiniGraph(),
      ],
    );
  }

  Widget _buildAdminMiniGraph() {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('REVENUE TREND', style: TextStyle(color: Colors.grey, fontSize: 8, fontWeight: FontWeight.bold)),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _miniBar(0.4),
              _miniBar(0.7),
              _miniBar(0.5),
              _miniBar(0.9),
              _miniBar(0.6),
              _miniBar(0.8),
              _miniBar(0.4),
            ],
          )
        ],
      ),
    );
  }

  Widget _miniBar(double height) {
    return Container(
      width: 15,
      height: 40 * height,
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _statItem(String value, String label, [bool isDark = true]) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildConditioningStatus() {
    return FadeInUp(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.bolt, color: Colors.orangeAccent, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CONDITIONING STATUS', style: TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  Text('${(_prepProgress * 100).toInt()}% Expedition Ready • $_trainingStreak Day Streak', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.leaderboard_outlined, color: Colors.orangeAccent),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const LeaderboardScreen())),
            ),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const TrekTrainingHub())),
              child: const Text('TRAIN', style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditButton() {
    return FadeInUp(
      child: Center(
        child: OutlinedButton.icon(
          onPressed: () async {
            if (_profileData == null) return;
            final refresh = await Navigator.push(
              context, 
              MaterialPageRoute(builder: (context) => EditProfileScreen(profile: _profileData!))
            );
            if (refresh == true) fetchData();
          },
          icon: const Icon(Icons.edit_note, size: 18),
          label: const Text('Complete Profile'),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            foregroundColor: Theme.of(context).primaryColor,
            side: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.5)),
          ),
        ),
      ),
    );
  }

  Widget _buildSafetyCard() {
    return FadeInUp(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.health_and_safety_outlined, color: Colors.redAccent, size: 24),
                SizedBox(width: 10),
                Text('Safety Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.redAccent)),
              ],
            ),
            const SizedBox(height: 16),
            _infoRow(Icons.phone_android, 'Emergency:', _profileData?['emergency_contact'] ?? 'Not Set'),
            const SizedBox(height: 10),
            _infoRow(Icons.bloodtype_outlined, 'Blood Group:', _profileData?['blood_group'] ?? 'Not Set'),
            if (_profileData?['medical_info'] != null) ...[
              const SizedBox(height: 10),
              _infoRow(Icons.medical_services_outlined, 'Notes:', _profileData?['medical_info']),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(width: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildHeader() {
    final String name = _profileData?['full_name'] ?? user?.userMetadata?['full_name'] ?? user?.email?.split('@')[0] ?? 'Trekker';
    final String? avatarUrl = _profileData?['avatar_url'] ?? user?.userMetadata?['avatar_url'];

    return FadeInDown(
      child: Center(
        child: Column(
          children: [
            Hero(
              tag: 'profile_pic',
              child: UserAvatar(
                radius: 50,
                imageUrl: avatarUrl,
                name: name,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_note, color: Colors.amber, size: 24),
                  onPressed: () async {
                    if (_profileData == null) return;
                    final refresh = await Navigator.push(context, MaterialPageRoute(builder: (context) => EditProfileScreen(profile: _profileData!)));
                    if (refresh == true) fetchData();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _role == 'admin' ? Colors.red.withOpacity(0.12) : (_role == 'guide' ? Colors.blue.withOpacity(0.12) : Colors.green.withOpacity(0.12)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _role == 'admin' ? Colors.red.withOpacity(0.3) : (_role == 'guide' ? Colors.blue.withOpacity(0.3) : Colors.green.withOpacity(0.3))),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _role == 'admin' ? Icons.security : (_role == 'guide' ? Icons.directions_walk : Icons.person), 
                    size: 14, 
                    color: _role == 'admin' ? Colors.red : (_role == 'guide' ? Colors.blue : Colors.green)
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _role.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11, 
                      fontWeight: FontWeight.w900, 
                      letterSpacing: 1,
                      color: _role == 'admin' ? Colors.red : (_role == 'guide' ? Colors.blue : Colors.green)
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              user?.email ?? '',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            if ((_profileData?['phone_number'] as String?)?.isNotEmpty ?? false) ...[
              const SizedBox(height: 4),
              Text(
                _profileData!['phone_number'],
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
            if (_role != 'admin') ...[
              const SizedBox(height: 24),
              _buildSafetyCard(),
            ],
            if (_role == 'admin') ...[
              const SizedBox(height: 24),
              _buildAdminPerformanceStats(),
              const SizedBox(height: 16),
              _buildAdminQuickTerminal(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdminQuickTerminal() {
    return FadeInUp(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.only(top: 24),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('COMMAND INTELLIGENCE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.5)),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
              children: [
                _adminGridTile(Icons.groups, 'MISSION SQUADS', () {
                   Navigator.push(context, MaterialPageRoute(builder: (c) => AdminBookingsScreen(showAppBar: true)));
                }),
                _adminGridTile(Icons.payments_outlined, 'PAYMENTS & REFUNDS', () {
                   Navigator.push(context, MaterialPageRoute(builder: (c) => PaymentLedgerScreen()));
                }),
                _adminGridTile(Icons.report_problem_outlined, 'COMPLAINTS', () {
                   Navigator.push(context, MaterialPageRoute(builder: (c) => AdminComplaintsScreen(showAppBar: true)));
                }),
                _adminGridTile(Icons.inventory_2_outlined, 'RENTAL TRACKING', () {
                   Navigator.push(context, MaterialPageRoute(builder: (c) => AdminRentalTrackingScreen()));
                }),
                _adminGridTile(Icons.manage_accounts_outlined, 'PERSONNEL MGT', () {
                   _showUserManagement();
                }),
                _adminGridTile(Icons.inventory, 'TREK INVENTORY', () {
                   Navigator.push(context, MaterialPageRoute(builder: (c) => AdminTrekInventoryScreen()));
                }),
                _adminGridTile(Icons.menu_book_outlined, 'BLOGS & STORIES', () {
                   Navigator.push(context, MaterialPageRoute(builder: (c) => BlogsScreen()));
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPersonnelList(String role) async {
    final client = Supabase.instance.client;
    final res = await client.from('profiles').select().eq('role', role).order('full_name');
    final usersList = res as List<dynamic>;

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (c) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(role == 'guide' ? 'Guided Specialists' : 'Active Trekkers', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: (role == 'guide' ? Colors.blue : Colors.orange).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text(role.toUpperCase(), style: TextStyle(color: (role == 'guide' ? Colors.blue : Colors.orange), fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: usersList.length,
                itemBuilder: (context, i) {
                  final u = usersList[i];
                  return ListTile(
                    leading: UserAvatar(imageUrl: u['avatar_url'], name: u['full_name'], radius: 18),
                    title: Text(u['full_name'] ?? 'Tracker'),
                    subtitle: Text(u['phone_number'] ?? u['email'] ?? ''),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserManagement() async {
    final client = Supabase.instance.client;
    final res = await client.from('profiles').select().order('full_name');
    List<dynamic> allUsers = res as List<dynamic>;
    List<dynamic> filteredUsers = List.from(allUsers);
    String searchQuery = '';

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (c) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Personnel Management', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search personnel...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
                onChanged: (v) {
                  setSheetState(() {
                    searchQuery = v.toLowerCase();
                    filteredUsers = allUsers.where((u) {
                      final name = (u['full_name'] ?? '').toString().toLowerCase();
                      final email = (u['email'] ?? '').toString().toLowerCase();
                      return name.contains(searchQuery) || email.contains(searchQuery);
                    }).toList();
                  });
                },
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, i) {
                    final u = filteredUsers[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: UserAvatar(imageUrl: u['avatar_url'], name: u['full_name'], radius: 24),
                      title: Text(u['full_name'] ?? 'Tracker', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(u['role'] ?? 'user', style: const TextStyle(fontSize: 12)),
                      trailing: PopupMenuButton<String>(
                        initialValue: u['role'],
                        onSelected: (newRole) async {
                          try {
                            await client.from('profiles').update({'role': newRole}).eq('id', u['id']);
                            final updatedRes = await client.from('profiles').select().order('full_name');
                            setSheetState(() {
                              allUsers = updatedRes as List;
                              // re-apply filter
                              filteredUsers = allUsers.where((u) {
                                final name = (u['full_name'] ?? '').toString().toLowerCase();
                                final email = (u['email'] ?? '').toString().toLowerCase();
                                return name.contains(searchQuery) || email.contains(searchQuery);
                              }).toList();
                            });
                          } catch (e) {
                             if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'user', child: Text('User')),
                          const PopupMenuItem(value: 'guide', child: Text('Guide')),
                          const PopupMenuItem(value: 'admin', child: Text('Admin')),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: Text(u['role']?.toString().toUpperCase() ?? 'USER', style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _adminGridTile(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildWishlist() {
    if (_wishlistTreks.isEmpty) {
      return FadeInUp(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.05),
            borderRadius: BorderRadius.circular(15)
          ),
          child: const Center(child: Text('No saved treks yet.', style: TextStyle(color: Colors.grey))),
        ),
      );
    }

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _wishlistTreks.length,
        itemBuilder: (context, index) {
          final trek = _wishlistTreks[index];
          return FadeInRight(
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TrekDetailScreen(trek: trek))),
              child: Container(
                width: 200,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  image: DecorationImage(image: NetworkImage(trek.imageUrl), fit: BoxFit.cover),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.8), Colors.transparent]),
                  ),
                  padding: const EdgeInsets.all(12),
                  alignment: Alignment.bottomLeft,
                  child: Text(trek.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBookingsList() {
    if (_myBookings.isEmpty) {
      return FadeInUp(
        child: Container(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(Icons.landscape, size: 60, color: Colors.grey[300]),
              const SizedBox(height: 16),
              const Text('Start your journey today!', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _myBookings.map((booking) {
        final trekData = booking['trek'];
        if (trekData == null) return const SizedBox.shrink();

        return FadeInUp(
          child: Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  trekData['image_url'] ?? '', 
                  width: 60, height: 60, fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => const Icon(Icons.image),
                ),
              ),
              title: Text(trekData['title'] ?? 'Trek Detail', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Departure: ${booking['trek_date']}'),
              trailing: booking['group_id'] != null 
                ? IconButton(
                    icon: const Icon(Icons.chat_bubble_outline, color: Colors.green),
                    onPressed: () => Navigator.push(
                      context, 
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          roomId: booking['group_id'], 
                          title: '${trekData['title']} (${booking['trek_date']})'
                        )
                      )
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Pending', style: TextStyle(color: Colors.orange, fontSize: 10)),
                      if (booking['status'] != 'Completed')
                        TextButton(
                          onPressed: () => _markAsComplete(booking['id']),
                          child: const Text('MARK COMPLETE', style: TextStyle(fontSize: 8, color: Colors.green, fontWeight: FontWeight.bold)),
                        )
                    ],
                  ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPassportSection() {
    return FadeInUp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.collections_bookmark_outlined, color: Colors.blueAccent),
              SizedBox(width: 10),
              Text('TREKKER PASSPORT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1, color: Colors.blueAccent)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blueAccent.withOpacity(0.1)),
            ),
            child: _myBookings.isEmpty
              ? const Center(child: Text('Complete a trek to earn your first stamp!', style: TextStyle(color: Colors.grey, fontSize: 12)))
              : Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _myBookings.map((b) {
                    final trek = b['trek'];
                    final date = DateTime.tryParse(b['trek_date']) ?? DateTime.now();
                    final isPast = date.isBefore(DateTime.now());
                    if (!isPast) return const SizedBox.shrink();
                    
                    return _buildPassportStamp(trek?['title'] ?? 'Summit', DateFormat('MMM yyyy').format(date));
                  }).toList(),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassportStamp(String title, String date) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.amber.shade700, Colors.amber.shade300]),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.workspace_premium, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(date, style: const TextStyle(fontSize: 8, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Preferences', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 16),
        _settingsTile(Icons.dark_mode_outlined, 'Dark Theme', true, (v) {}),
        _settingsTile(Icons.notifications_none_outlined, 'Push Notifications', true, (v) {}),
        _settingsTile(Icons.location_on_outlined, 'Location Sharing', false, (v) {}),
        _clickableTile(Icons.menu_book_outlined, 'My Stories', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BlogsScreen(onlyMyBlogs: true)))),
        _clickableTile(Icons.report_problem_outlined, 'Mission Reports & Complaints', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserComplaintsScreen()))),
        _clickableTile(Icons.help_outline, 'Tactical Support', () => Navigator.push(context, MaterialPageRoute(builder: (_) => _role == 'admin' ? const AdminSupportInquiriesScreen() : const UserSupportScreen()))),
        _clickableTile(Icons.logout, 'Log Out', _signOut),
      ],
    );
  }

  Widget _settingsTile(IconData icon, String label, bool value, Function(bool) onChanged) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.blueGrey),
      title: Text(label, style: const TextStyle(fontSize: 15)),
      trailing: Switch(value: value, onChanged: onChanged, activeColor: Colors.blue),
    );
  }

  Widget _clickableTile(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.blueGrey),
      title: Text(label, style: const TextStyle(fontSize: 15)),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
    );
  }
  Future<void> _markAsComplete(String bookingId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Complete Mission?'),
        content: const Text('Are you sure you have completed this expedition? This will update your trekker stats and distance covered.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Not yet')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Yes, I did!', style: TextStyle(color: Colors.green))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.from('bookings').update({'status': 'Completed'}).eq('id', bookingId);
        fetchData();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Congratulations on completing the trek!'), backgroundColor: Colors.green));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    }
  }

  void _showNotificationsScreen() {
    Navigator.push(context, MaterialPageRoute(builder: (c) => NotificationCenterScreen(role: _role)));
  }
}
