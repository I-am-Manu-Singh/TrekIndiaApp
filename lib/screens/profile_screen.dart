import 'package:flutter/material.dart';
import '../widgets/glass_shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/user_avatar.dart';
import 'admin_finance_hub_screen.dart';
import 'admin_employee_management_screen.dart';
import 'app_info_screen.dart';
import 'leaderboard_screen.dart';
import 'trip_certificate_screen.dart';
import 'gear_checklist_screen.dart';
import '../services/preferences_service.dart';
import '../main.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  dynamic _userData;

  int _tripCount = 0;
  double _totalDistance = 0;
  List<dynamic> _recentBookings = [];
  double _packingProgress = 0.0;
  String? _activeTripId;
  String? _activeTripTitle;
  String get role => (_userData?['role']?.toString().toLowerCase() ?? 'user');

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final user = _client.auth.currentUser;
    if (user != null) {
      try {
        // 1. Fetch Profile Data (Essential)
        final res = await _client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (mounted && res != null) {
          String? name = res['full_name'];
          if (name == null || name.trim().isEmpty || name == 'Explorer') {
            name = user.userMetadata?['full_name'] ?? user.userMetadata?['name'];
            if (name == null || name.trim().isEmpty) {
              name = user.email?.split('@')[0] ?? 'Explorer';
              // Silent Repair
              _client.from('profiles').update({'full_name': name}).eq('id', user.id).then((_) {});
            }
          }
          setState(() {
            _userData = {...res, 'full_name': name};
          });
        } else if (mounted && res == null) {
           // Fallback if DB is empty
           String name = user.userMetadata?['full_name'] ?? user.userMetadata?['name'] ?? user.email?.split('@')[0] ?? 'Explorer';
           setState(() {
             _userData = {
               'full_name': name,
               'avatar_url': user.userMetadata?['avatar_url'] ?? user.userMetadata?['picture'] ?? '',
               'email': user.email,
               'role': 'user',
             };
           });
           // Create profile if missing
           _client.from('profiles').insert({'id': user.id, 'full_name': name, 'email': user.email, 'role': 'user'}).then((_) {});
        }

        // 2. Fetch Stats (Non-essential, handle errors silently)
        try {
          final statsRes = await _client
              .from('bookings')
              .select('*, trips(*)')
              .eq('user_id', user.id)
              .ilike('status', 'completed');

          if (mounted) {
            int trips = 0;
            double dist = 0;
            for (var b in statsRes) {
              trips++;
              if (b['trips'] != null) {
                String dStr = (b['trips']['total_distance'] ?? '0').toString().toLowerCase();
                double dVal = double.tryParse(dStr.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
                dist += dVal;
              }
            }

            setState(() {
              _tripCount = trips;
              _totalDistance = dist;
              _recentBookings = statsRes;
            });
            
            // 3. Fetch Packing Progress for the most recent trip
            final allBookings = await _client.from('bookings').select('trip_id, trip_name').eq('user_id', user.id).order('created_at', ascending: false).limit(1);
            if (allBookings.isNotEmpty) {
              final tripId = allBookings[0]['trip_id'];
              final tripTitle = allBookings[0]['trip_name'];
              
              // Always set the active trip if a booking exists
              setState(() {
                _activeTripId = tripId;
                _activeTripTitle = tripTitle;
              });

              final checklist = await _client.from('gear_checklists').select('is_packed').eq('user_id', user.id).eq('trip_id', tripId);
              if (checklist.isNotEmpty) {
                int packed = (checklist as List).where((i) => i['is_packed'] == true).length;
                setState(() {
                  _packingProgress = packed / checklist.length;
                });
              } else {
                setState(() {
                  _packingProgress = 0;
                });
              }
            }
            if (mounted) setState(() => _isLoading = false);
          }
        } catch (e) {
          debugPrint('Stats fetch failed: $e');
          if (mounted) setState(() => _isLoading = false);
        }
      } catch (e) {
        debugPrint('Profile fetch failed: $e');
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out?'),
        content: const Text(
          'Are you sure you want to end your current session?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Log Out',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('PROFILE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
          backgroundColor: const Color(0xFFD32F2F),
          elevation: 0,
        ),
        body: _buildShimmerProfile(),
      );
    }

    final String? role = _userData?['role']?.toString().toLowerCase();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'PROFILE',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFD32F2F),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 30),
            _buildHeader(),
            const SizedBox(height: 30),

            // Operational modules have been moved to Admin Panels (Admin trekwithmussafirr / Dashboards)
            if (role == 'user') ...[
              _buildMedalCase(),
              const SizedBox(height: 20),
              _buildPreparationHub(),
              const SizedBox(height: 20),
            ],
            
            if (role == 'user') ...[
              _buildListItem(
                Icons.leaderboard_outlined,
                'Global Ranking',
                'Check your status in the trip community',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const LeaderboardScreen())),
              ),
            ],
            _buildListItem(
              Icons.info_outline,
              'App Info',
              'Build v1.0.4, contacts, & trip info',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => const AppInfoScreen()),
              ),
            ),
            _buildListItem(
              Icons.settings_outlined,
              'App Settings',
              'Trip configs & device sync',
              onTap: () => _showAppSettings(),
            ),
            _buildListItemColor(
              Icons.logout,
              'Log Out',
              'End your current session',
              color: Colors.redAccent,
              onTap: _logout,
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final String? fullName = _userData?['full_name']?.toString();
    final String? avatarUrl = _userData?['avatar_url']?.toString();
    final String initial = (fullName != null && fullName.isNotEmpty)
        ? fullName[0].toUpperCase()
        : 'M';

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3), width: 2),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 8))],
              ),
              child: UserAvatar(
                imageUrl: avatarUrl,
                name: fullName,
                width: 110,
                height: 110,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            if (_userData?['aadhar_url'] != null || _userData?['medical_certificate_url'] != null)
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                  ),
                  child: const Icon(Icons.verified, color: Colors.white, size: 16),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _userData?['full_name'] ?? 'N/A',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit_note, color: Colors.blueAccent, size: 20),
              onPressed: () async {
                await Navigator.pushNamed(context, '/travel_documents');
                _fetchProfile();
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: (role.toUpperCase() == 'ADMIN')
                    ? Colors.red.withOpacity(0.1)
                    : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_user,
                    size: 10,
                    color: (role.toUpperCase() == 'ADMIN') ? Colors.redAccent : Colors.green,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    role.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: (role.toUpperCase() == 'ADMIN') ? Colors.redAccent : Colors.green,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: (_userData?['aadhar_url'] != null || _userData?['medical_certificate_url'] != null)
                    ? Colors.blue.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    (_userData?['aadhar_url'] != null || _userData?['medical_certificate_url'] != null) ? Icons.check_circle : Icons.error_outline,
                    size: 10,
                    color: (_userData?['aadhar_url'] != null || _userData?['medical_certificate_url'] != null) ? Colors.blue : Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    (_userData?['aadhar_url'] != null || _userData?['medical_certificate_url'] != null) ? 'VERIFIED' : 'NOT VERIFIED',
                    style: TextStyle(
                      fontSize: 9, 
                      fontWeight: FontWeight.bold, 
                      color: (_userData?['aadhar_url'] != null || _userData?['medical_certificate_url'] != null) ? Colors.blue : Colors.orange,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _userData?['email'] ?? 'N/A',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        Text(
          _userData?['phone_number'] ?? 'N/A',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildMedalCase() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('MEDAL CASE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5, color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.blueGrey)),
              Text('$_tripCount COMPLETED', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            ],
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _recentBookings.isEmpty
                  ? <Widget>[
                      const Text('No medals earned yet.', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    ]
                  : _recentBookings.map<Widget>((b) => _achievementBadge(
                      b['trips']?['title'] ?? 'Trip',
                      b['trips']?['image_url'] ?? 'https://images.unsplash.com/photo-1544735716-932d56158227',
                    )).toList(),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
                _miniStat('TOTAL DISTANCE', '${_totalDistance.toInt()} KM'),
                _miniStat('TRIP XP', '${_userData?['xp'] ?? 0}'),
                _miniStat('RANK LEVEL', '${_userData?['level'] ?? 1}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String val) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
        Text(label, style: const TextStyle(fontSize: 7, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _achievementBadge(String name, String image) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 70,
                height: 70,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade200, Colors.amber.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(color: Theme.of(context).cardColor, shape: BoxShape.circle),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(35),
                    child: CachedNetworkImage(
                      imageUrl: image,
                      fit: BoxFit.cover,
                      placeholder: (c, u) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      errorWidget: (c, u, e) => Container(color: Colors.amber.shade50, child: const Icon(Icons.military_tech, color: Colors.amber, size: 30)),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: const Icon(Icons.military_tech, color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 70,
            child: Text(
              name.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmploymentSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: Colors.blueAccent, size: 20),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('STAFF ANALYTICS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5, color: isDark ? Colors.white : Colors.black87)),
                  Text('Assignment & Attendance Metrics', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _empStat('PAID', _userData?['paid_leaves'] ?? 0, Colors.green),
              _empStat('LEAVES', _userData?['unpaid_leaves'] ?? 0, Colors.red),
              _empStat('HALF', _userData?['half_days'] ?? 0, Colors.orange),
              _empStat('OFF', _userData?['off_duty_days'] ?? 0, Colors.blue),
            ],
          ),
          const SizedBox(height: 20),
          Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
          const SizedBox(height: 16),
           Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('OPERATIONAL STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blueGrey)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 10),
                    SizedBox(width: 4),
                    Text('ACTIVE DUTY', style: TextStyle(color: Colors.green, fontSize: 8, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _empStat(String label, dynamic val, Color color) {
    return Column(
      children: [
        Text('$val', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
      ],
    );
  }

  Widget _statItem(String val, String label) {
    return Column(
      children: [
        Text(
          val,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }


  Widget _buildSafetySection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade50),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.health_and_safety_outlined,
                color: Colors.redAccent.withOpacity(0.7),
                size: 18,
              ),
              const SizedBox(width: 12),
              Text(
                'Safety & Record',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _kv('Emergency Contact:', _userData?['emergency_contact'] ?? 'N/A'),
          _kv('Blood Group:', _userData?['blood_group'] ?? 'A-'),
          _kv('Medical Info:', _userData?['medical_info'] ?? 'None'),
          const SizedBox(height: 24),
          Text(
            'Documents',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87),
          ),
          const SizedBox(height: 16),
          _docCheck('Passport Photo', _userData?['passport_url'] != null),
          _docCheck('Aadhar Card', _userData?['aadhar_url'] != null),
          _docCheck('Blood Group ID', true),
          _docCheck('Health Certificate', _userData?['medical_certificate_url'] != null),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 45,
            child: OutlinedButton(
              onPressed: () =>
                  Navigator.pushNamed(context, '/travel_documents'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: const Text(
                'EDIT PROFILE & RECORD',
                style: TextStyle(
                  color: Color(0xFF2E7B32),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.phone_android_outlined,
            size: 14,
            color: Colors.grey.shade400,
          ),
          const SizedBox(width: 8),
          Text(
            k,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            v,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _docCheck(String label, bool done) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.badge_outlined,
                size: 14,
                color: const Color(0xFF2E7B32).withOpacity(0.5),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
          if (done)
            const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 14),
        ],
      ),
    );
  }

  Widget _buildListItem(
    IconData icon,
    String title,
    String sub, {
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade50),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F8E9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF2E7B32)),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87),
        ),
        subtitle: Text(
          sub,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
        trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  Widget _buildListItemColor(
    IconData icon,
    String title,
    String sub, {
    Color color = Colors.black87,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade50),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color,
          ),
        ),
        subtitle: Text(
          sub,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
        onTap: onTap,
      ),
    );
  }

  void _showPlaceholder(String title) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$title screen under maintenance.')));
  }

  Widget _buildPreparationHub() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('MY EXPEDITION PREP', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5, color: Theme.of(context).primaryColor)),
              const Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Bag Packing Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(_activeTripTitle != null ? 'Preparing for $_activeTripTitle' : 'Ensure you have everything for your next trip', style: TextStyle(color: Colors.grey, fontSize: 10)),
                  ],
                ),
              ),
              Text('${(_packingProgress * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.green)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _packingProgress,
              backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 20),
          _buildListItem(
            Icons.checklist_rtl_rounded, 
            'Gear Checklist', 
            'Verify your essential gear', 
            onTap: () {
              if (_activeTripId != null) {
                Navigator.push(context, MaterialPageRoute(builder: (c) => GearChecklistScreen(tripId: _activeTripId!, tripTitle: _activeTripTitle!))).then((_) => _fetchProfile());
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active bookings found to pack for.')));
              }
            }
          ),
        ],
      ),
    );
  }


  void _showAppSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Center(
              child: SizedBox(width: 40, child: Divider(thickness: 4)),
            ),
            const SizedBox(height: 24),
            const Icon(
              Icons.settings_suggest_outlined,
              size: 60,
              color: Colors.orange,
            ),
            const SizedBox(height: 24),
            const Text(
              'APP SETTINGS',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: 1.5,
              ),
            ),
            const Text(
              'Customize according to your preferences',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 10,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 32),
            _settingToggle(
              'Trip Theme',
              'Switch between Light & Dark mode',
              Theme.of(context).brightness == Brightness.dark,
              isTheme: true,
            ),
            _settingToggle(
              'Push Notifications',
              'Status Alerts & Assignment signals',
              true,
            ),
            _settingToggle(
              'Biometric Auth',
              'Secure access to trekwithmussafirr systems',
              false,
            ),
            _settingToggle(
              'Offline Mode',
              'Cache trip data for low signal areas',
              true,
            ),
            _settingToggle(
              'Location Tracking',
              'Real-time group positioning',
              true,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _settingToggle(
    String title,
    String sub,
    bool value, {
    bool isTheme = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(15),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          sub,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
        value: value,
        activeColor: const Color(0xFF2E7B32),
        onChanged: (v) async {
          if (isTheme) {
            final newMode = v ? ThemeMode.dark : ThemeMode.light;
            themeNotifier.value = newMode;
            await PreferencesService().setTheme(v);
            if (mounted) Navigator.pop(context); // Close sheet to reflect changes
          }
        },
      ),
    );
  }

  Widget _buildShimmerProfile() {
    return GlassShimmer(
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 40),
            const ShimmerBlock(width: 110, height: 110, borderRadius: 22),
            const SizedBox(height: 20),
            const ShimmerBlock(width: 180, height: 24, borderRadius: 8),
            const SizedBox(height: 12),
            const ShimmerBlock(width: 120, height: 16, borderRadius: 8),
            const SizedBox(height: 40),
            const ShimmerBlock(width: double.infinity, height: 180, margin: EdgeInsets.symmetric(horizontal: 20), borderRadius: 25),
            const SizedBox(height: 30),
            ...List.generate(4, (i) => const ShimmerBlock(width: double.infinity, height: 70, margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8), borderRadius: 15)),
          ],
        ),
      ),
    );
  }
}
