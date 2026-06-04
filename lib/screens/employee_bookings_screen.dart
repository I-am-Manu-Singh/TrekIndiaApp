import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'admin_group_analytics_screen.dart';
import '../widgets/user_avatar.dart';

class EmployeeBookingsScreen extends StatefulWidget {
  const EmployeeBookingsScreen({super.key});

  @override
  State<EmployeeBookingsScreen> createState() => _EmployeeBookingsScreenState();
}

class _EmployeeBookingsScreenState extends State<EmployeeBookingsScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _tripGroups = [];

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
      // 1. Fetch ALL possible trips for this staff member
      final staffDeployments = await _client.from('trip_group_staff')
          .select()
          .eq('user_id', user.id);
      
      // 2. Aggregate Trip Identifiers
      final Set<String> myTripIds = {
        ...staffDeployments.map<String>((s) => s['trip_id']?.toString() ?? '')
      }..removeWhere((id) => id.isEmpty || id == 'null');

      if (myTripIds.isEmpty) {
        if (mounted) setState(() { _tripGroups = []; _isLoading = false; });
        return;
      }

      // 3. Data Retrieval
      final allBookings = await _client.from('bookings').select('*, trip_groups(id, status)').inFilter('trip_id', myTripIds.toList());
      final allTrips = await _client.from('trips').select().inFilter('id', myTripIds.toList());
      
      // OPTIMIZED: Only fetch profiles for users in these bookings
      final List<String> bookingUserIds = allBookings.map<String>((b) => b['user_id'].toString()).toSet().toList();
      final allProfiles = bookingUserIds.isEmpty 
          ? [] 
          : await _client.from('profiles').select().inFilter('id', bookingUserIds);
      
      final Map<String, dynamic> tripMap = {for (var t in allTrips) t['id']: t};
      final Map<String, dynamic> profileMap = {for (var p in allProfiles) p['id']: p};

      Map<String, dynamic> groups = {};

      void addToGroup(String groupKey, dynamic trip, String date, dynamic profile) {
        if (!groups.containsKey(groupKey)) {
          groups[groupKey] = {
            'trip_id': trip['id'],
            'trip': trip,
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

      // Create groups from staffDeployments
      for (var d in staffDeployments) {
        final tripId = d['trip_id']?.toString();
        final date = (d['deployment_date'] ?? '').toString().split('T')[0].trim();
        if (tripId != null && tripMap[tripId] != null && date.isNotEmpty) {
           final groupKey = '${tripId}_$date';
           addToGroup(groupKey, tripMap[tripId], date, null);
        }
      }

      // 4. Mapping of Bookings to Existing Groups
      for (var b in allBookings) {
        final tripId = b['trip_id']?.toString();
        final trip = tripMap[tripId];
        if (trip == null) continue;

        // TRIP CRITICAL: Date Normalization
        final String rawDate = (b['trip_date'] ?? b['booking_date'] ?? 'TBD').toString();
        final String normalizedDate = rawDate.split('T')[0].split(' ')[0].trim();
        
        final String groupKey = '${tripId}_$normalizedDate';
        if (groups.containsKey(groupKey)) {
          addToGroup(groupKey, trip, normalizedDate, profileMap[b['user_id']]);
        }
      }

      if (mounted) {
        setState(() {
          _tripGroups = groups.values.toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        print('trekwithmussafirr EMPLOYEE GROUP ERROR: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('MY ASSIGNED GROUPS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        backgroundColor: const Color(0xFFD32F2F),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.blueAccent), onPressed: _fetchMyGroups),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  children: [
                    _buildHeaderStats(),
                    Expanded(
                      child: _tripGroups.isEmpty 
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(24),
                            itemCount: _tripGroups.length,
                            itemBuilder: (context, index) => _buildGroupCard(_tripGroups[index]),
                          ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderStats() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFFD32F2F),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(35)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statCol('ASSIGNMENTS', '${_tripGroups.length}', Colors.blueAccent),
          _statCol('TREKKERS', '${_tripGroups.fold(0, (sum, g) => sum + (g['total_strength'] as int))}', Colors.greenAccent),
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
    final trip = g['trip'];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
      ),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => AdminGroupAnalyticsScreen(tripId: g['trip_id'], tripDate: g['date']))),
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: (trip['image_url'] != null) 
                       ? Image.network(trip['image_url']!, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.blue.shade50, child: const Icon(Icons.terrain, color: Colors.blue)))
                       : Container(width: 60, height: 60, color: Colors.blue.shade50, child: const Icon(Icons.terrain, color: Colors.blue)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(trip['title'] ?? 'Trip', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
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
                  Text('${g['total_strength']} Trekkers Enrolled', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
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
          const Text('NO ASSIGNED GROUPS', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 10)),
        ],
      ),
    );
  }
}
