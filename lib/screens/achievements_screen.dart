import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _profile;
  int _completedTrips = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      final p = await _client.from('profiles').select().eq('id', user.id).maybeSingle();
      final trips = await _client.from('bookings').select('id').eq('user_id', user.id).eq('status', 'Completed');
      if (mounted) {
        setState(() {
          _profile = p;
          _completedTrips = (trips as List).length;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final xp = _profile?['xp'] ?? 0;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('HONOR & ACHIEVEMENTS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        backgroundColor: const Color(0xFFD32F2F),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildRankHeader(xp),
          const SizedBox(height: 32),
          Text('TRIP ACCOMPLISHED', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2, color: isDark ? Colors.white54 : Colors.grey)),
          const SizedBox(height: 16),
          _badgeItem('Summit Seeker', 'Completed first 4,000m+ trip', Icons.terrain, Colors.orangeAccent, _completedTrips >= 1),
          _badgeItem('Night Scout', 'Completed a night navigation exercise', Icons.bedtime, Colors.blueAccent, xp > 500),
          _badgeItem('Iron Hiker', '5 consecutive days with 10km+ movement', Icons.fitness_center, Colors.redAccent, xp > 2000),
          _badgeItem('Eco Guardian', 'Participated in a mountain cleanup group', Icons.eco, Colors.greenAccent, _completedTrips > 5),
          const SizedBox(height: 32),
          Text('TRIP PROGRESSION', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2, color: isDark ? Colors.white54 : Colors.grey)),
          const SizedBox(height: 16),
          _progressTile('Navigation Mastery', (xp / 5000).clamp(0.0, 1.0)),
          _progressTile('Altitude Resilience', (_completedTrips / 10).clamp(0.0, 1.0)),
          _progressTile('Survival Skills', (xp / 10000).clamp(0.0, 1.0)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildRankHeader(int xp) {
    String rank = 'INITIATE';
    if (xp > 5000) rank = 'ELITE PATHFINDER';
    else if (xp > 2000) rank = 'ADVANCED PATHFINDER';
    else if (xp > 500) rank = 'RECON TRACKER';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FadeInDown(
      child: Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: isDark ? [const Color(0xFF18181B), Colors.black] : [Colors.blueGrey.shade800, Colors.black]),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            const CircleAvatar(radius: 40, backgroundColor: Colors.white10, child: Icon(Icons.shield, color: Colors.amber, size: 40)),
            const SizedBox(height: 16),
            Text('RANK: $rank', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1)),
            Text('Total XP: $xp • $_completedTrips Trips', style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _badgeItem(String title, String desc, IconData icon, Color color, bool isUnlocked) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(isUnlocked ? 0.2 : 0.05), shape: BoxShape.circle),
            child: Icon(icon, color: isUnlocked ? color : Colors.white24, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: isUnlocked ? (isDark ? Colors.white : Colors.black87) : (isDark ? Colors.white38 : Colors.grey), fontWeight: FontWeight.bold, fontSize: 15)),
              Text(desc, style: TextStyle(color: isDark ? Colors.white24 : Colors.grey.shade600, fontSize: 11)),
            ]),
          ),
          if (!isUnlocked) Icon(Icons.lock_outline, color: isDark ? Colors.white10 : Colors.grey.shade300, size: 16),
        ],
      ),
    );
  }

  Widget _progressTile(String label, double val) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12, fontWeight: FontWeight.bold)),
              Text('${(val * 100).toInt()}%', style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(value: val, backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200, valueColor: const AlwaysStoppedAnimation(Colors.amber), minHeight: 6),
          ),
        ],
      ),
    );
  }
}
