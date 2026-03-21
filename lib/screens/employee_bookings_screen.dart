import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'admin_squad_intelligence_screen.dart';
import '../widgets/user_avatar.dart';

class EmployeeBookingsScreen extends StatefulWidget {
  const EmployeeBookingsScreen({super.key});

  @override
  State<EmployeeBookingsScreen> createState() => _EmployeeBookingsScreenState();
}

class _EmployeeBookingsScreenState extends State<EmployeeBookingsScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _trekGroups = [];

  @override
  void initState() {
    super.initState();
    _fetchMyGroups();
  }

  Future<void> _fetchMyGroups() async {
    setState(() => _isLoading = true);
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Fetch ALL possible deployments for this operative
      final staffDeployments = await _client.from('trek_group_staff')
          .select()
          .eq('user_id', user.id);
      
      final directDeployments = await _client.from('trek_groups')
          .select('*, treks(title, image_url)')
          .or('guide_id.eq.${user.id},staff_id.eq.${user.id}');
      
      // 2. Aggregate Trek Identifiers
      final Set<String> myTrekIds = {
        ...staffDeployments.map<String>((s) => s['trek_id'].toString()),
        ...directDeployments.map<String>((g) => g['trek_id'].toString())
      };

      if (myTrekIds.isEmpty) {
        if (mounted) setState(() { _trekGroups = []; _isLoading = false; });
        return;
      }

      // 3. Strategic Intel Retrieval
      final allBookings = await _client.from('bookings').select('*, trek_groups(id, status)').inFilter('trek_id', myTrekIds.toList());
      final allTreks = await _client.from('treks').select().inFilter('id', myTrekIds.toList());
      final allProfiles = await _client.from('profiles').select();
      
      final Map<String, dynamic> trekMap = {for (var t in allTreks) t['id']: t};
      final Map<String, dynamic> profileMap = {for (var p in allProfiles) p['id']: p};

      Map<String, dynamic> groups = {};

      void addToGroup(String groupKey, dynamic trek, String date, dynamic profile) {
        if (!groups.containsKey(groupKey)) {
          groups[groupKey] = {
            'trek_id': trek['id'],
            'trek': trek,
            'date': date,
            'participants': [],
            'total_strength': 0,
          };
        }
        if (profile != null) {
          groups[groupKey]['participants'].add(profile);
          groups[groupKey]['total_strength']++;
        }
      }

      // 4. Tactical Mapping
      for (var b in allBookings) {
        final trekId = b['trek_id']?.toString();
        final trek = trekMap[trekId];
        if (trek == null) continue;

        // MISSION CRITICAL: Date Normalization
        final String rawDate = (b['trek_date'] ?? b['booking_date'] ?? 'TBD').toString();
        final String normalizedDate = rawDate.split('T')[0].split(' ')[0].trim();
        
        // 5. Verifying Operative Presence on Station
        bool isMyAssignment = staffDeployments.any((d) {
          final sDate = (d['deployment_date'] ?? '').toString().split('T')[0].split(' ')[0].trim();
          return d['trek_id'].toString() == trekId && (sDate == normalizedDate || d['deployment_date']?.toString().contains(normalizedDate) == true);
        }) || directDeployments.any((g) {
          final gDate = (g['departure_date'] ?? '').toString().split('T')[0].split(' ')[0].trim();
          return g['trek_id'].toString() == trekId && (gDate == normalizedDate || g['departure_date']?.toString().contains(normalizedDate) == true);
        });

        if (isMyAssignment) {
          final String groupKey = '${trekId}_$normalizedDate';
          addToGroup(groupKey, trek, normalizedDate, profileMap[b['user_id']]);
        }
      }

      if (mounted) {
        setState(() {
          _trekGroups = groups.values.toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        print('HQ EMPLOYEE SQUAD ERROR: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('MY ASSIGNED SQUADS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.blueAccent), onPressed: _fetchMyGroups),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : Column(
              children: [
                _buildHeaderStats(),
                Expanded(
                  child: _trekGroups.isEmpty 
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: _trekGroups.length,
                        itemBuilder: (context, index) => _buildGroupCard(_trekGroups[index]),
                      ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeaderStats() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(35)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statCol('SQUADS', '${_trekGroups.length}', Colors.blueAccent),
          _statCol('TREKKERS', '${_trekGroups.fold(0, (sum, g) => sum + (g['total_strength'] as int))}', Colors.greenAccent),
        ],
      ),
    );
  }

  Widget _statCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
      ],
    );
  }

  Widget _buildGroupCard(dynamic g) {
    final trek = g['trek'];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
      ),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => AdminSquadIntelligenceScreen(trekId: g['trek_id'], deploymentDate: g['date']))),
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: (trek['image_url'] != null) 
                       ? Image.network(trek['image_url']!, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.blue.shade50, child: const Icon(Icons.terrain, color: Colors.blue)))
                       : Container(width: 60, height: 60, color: Colors.blue.shade50, child: const Icon(Icons.terrain, color: Colors.blue)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(trek['title'] ?? 'Expedition', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                        Text(DateFormat('EEEE, MMM dd yyyy').format(DateTime.parse(g['date'])), style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24))),
              child: Row(
                children: [
                  const Icon(Icons.groups_outlined, size: 14, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  Text('${g['total_strength']} Personnel Enrolled', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                ],
              ),
            ),
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
          Icon(Icons.assignment_ind_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('NO ASSIGNED SQUADS', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 10)),
        ],
      ),
    );
  }
}
