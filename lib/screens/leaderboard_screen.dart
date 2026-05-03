import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../services/database_service.dart';
import '../widgets/user_avatar.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final _db = DatabaseService();
  List<Map<String, dynamic>> _leaders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLeaders();
  }

  Future<void> _loadLeaders() async {
    final leaders = await _db.fetchLeaderboard();
    if (mounted) {
      setState(() {
        _leaders = leaders;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('HALL OF VALOR', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 16)),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orangeAccent))
          : _leaders.isEmpty
            ? _buildEmptyState()
            : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildTopThree(),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index < 3) return const SizedBox.shrink(); // Handled by TopThree
                        return _leaderCard(index);
                      },
                      childCount: _leaders.length,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTopThree() {
    if (_leaders.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_leaders.length > 1) _podiumItem(_leaders[1], 2, 100),
          if (_leaders.isNotEmpty) _podiumItem(_leaders[0], 1, 140),
          if (_leaders.length > 2) _podiumItem(_leaders[2], 3, 90),
        ],
      ),
    );
  }

  Widget _podiumItem(Map<String, dynamic> user, int rank, double height) {
    Color rankColor = rank == 1 ? Colors.amber : (rank == 2 ? Colors.grey.shade400 : Colors.orange.shade700);
    return FadeInUp(
      delay: Duration(milliseconds: 200 * rank),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: rankColor, width: 3)),
                child: UserAvatar(imageUrl: user['avatar_url']?.toString(), name: user['full_name']?.toString() ?? 'Trip', radius: rank == 1 ? 40 : 30),
              ),
              Positioned(
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: rankColor, shape: BoxShape.circle),
                  child: Text('$rank', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(user['full_name']?.toString() ?? 'Trip', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
          Text('LVL ${user['level'] ?? 1}', style: TextStyle(color: rankColor, fontSize: 10, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Container(
            width: 70,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [rankColor.withOpacity(0.3), Colors.transparent],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Center(
              child: Text('${user['xp'] ?? 0} XP', style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _leaderCard(int index) {
    final user = _leaders[index];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10)],
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Text('${index + 1}', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(width: 16),
            UserAvatar(imageUrl: user['avatar_url']?.toString(), name: user['full_name']?.toString() ?? 'Trip', radius: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user['full_name']?.toString() ?? 'Trip', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                  Text('Level ${user['level'] ?? 1}', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 11)),
                ],
              ),
            ),
            Text('${user['xp'] ?? 0} XP', style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FadeInDown(child: const Icon(Icons.shield_outlined, size: 80, color: Colors.grey)),
          const SizedBox(height: 24),
          const Text('THE HALL IS CURRENTLY EMPTY', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Complete trips and training to earn your place here.', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _loadLeaders,
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
            child: const Text('SYNC RECORDS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}
