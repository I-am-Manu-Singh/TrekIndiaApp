import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'admin_group_detail_screen.dart';

class AdminTrekGroupsScreen extends StatefulWidget {
  const AdminTrekGroupsScreen({super.key});

  @override
  State<AdminTrekGroupsScreen> createState() => _AdminTrekGroupsScreenState();
}

class _AdminTrekGroupsScreenState extends State<AdminTrekGroupsScreen> {
  final _client = Supabase.instance.client;
  List<dynamic> _groupedTreks = [];
  bool _isLoading = true;

  bool _isInitialized = false;
  bool _onlyMe = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _onlyMe = args?['onlyMe'] ?? false;
      _isInitialized = true;
      _fetchGroupedBookings();
    }
  }

  Future<void> _fetchGroupedBookings() async {
    try {
      final user = _client.auth.currentUser;
      final bool onlyMe = _onlyMe;

      // Trek Fetch: Retrieve groups with their assigned guide/staff and participant bookings
      final response = await _client.from('trek_groups')
          .select('*, treks(title, image_url), bookings(*)')
          .order('departure_date', ascending: true);
      
      if (mounted) {
        // Fetch staff assignments for the current user
        List<dynamic> staffAssignments = [];
        if (onlyMe && user != null) {
          staffAssignments = await _client.from('trek_group_staff')
              .select('trek_id, deployment_date')
              .eq('user_id', user.id);
        }

        final List<Map<String, dynamic>> finalGroups = (response as List).map((g) => {
          'trek_id': g['trek_id'],
          'trek_title': g['treks']['title'],
          'image_url': g['treks']['image_url'],
          'date': g['departure_date'],
          'guide_id': g['guide_id'],
          'staff_id': g['staff_id'],
          'bookings': g['bookings'],
          'total_travelers': (g['bookings'] as List).fold(0, (sum, b) => sum + (b['travelers'] as int? ?? 0)),
        }).toList();

        List<Map<String, dynamic>> filtered = finalGroups;
        if (onlyMe && user != null) {
          // Trek Filter: Check if user is a participant, assigned guide/staff, or deployed via trek_group_staff
          filtered = finalGroups.where((g) {
            final participants = g['bookings'] as List? ?? [];
            bool isParticipant = participants.any((b) => b['user_id'].toString() == user.id.toString());
            bool isLeader = (g['guide_id'] != null && g['guide_id'].toString() == user.id.toString()) || 
                          (g['staff_id'] != null && g['staff_id'].toString() == user.id.toString());
            
            // Check if deployed in this specific trek on this specific date
            bool isStaffDeployed = staffAssignments.any((sa) {
              final String sd = sa['deployment_date'].toString().split('T')[0];
              final String gd = g['date'].toString().split('T')[0];
              return sa['trek_id'].toString() == g['trek_id'].toString() && sd == gd;
            });

            return isParticipant || isLeader || isStaffDeployed;
          }).toList();
        }

        setState(() {
          _groupedTreks = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print('Error fetching grouped bookings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TREK GROUPS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5, color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groupedTreks.isEmpty
              ? const Center(child: Text('No active trek groups found.', style: TextStyle(fontSize: 18, color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _groupedTreks.length,
                  itemBuilder: (context, index) {
                    final group = _groupedTreks[index];
                    return FadeInUp(
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: Theme.of(context).brightness == Brightness.dark ? 0 : 2,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(15),
                          onTap: () async {
                            final changed = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AdminGroupDetailScreen(
                                  trekId: group['trek_id'],
                                  trekTitle: group['trek_title'],
                                  date: group['date'],
                                ),
                              ),
                            );
                            if (changed == true) {
                              setState(() => _isLoading = true);
                              _fetchGroupedBookings();
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    group['image_url'] ?? '',
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      width: 80,
                                      height: 80,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.image_not_supported),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        group['trek_title'] ?? 'Unknown Trek',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_today, size: 16, color: Theme.of(context).primaryColor),
                                          const SizedBox(width: 4),
                                          Text('Date: ${group['date']}', style: TextStyle(fontWeight: FontWeight.w500, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.group, size: 16, color: Colors.blue[700]),
                                          const SizedBox(width: 4),
                                          Text('Travelers: ${group['total_travelers']}', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87)),
                                        ],
                                      ),
                                      if (group['guide_id'] != null) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.assignment_ind, size: 12, color: Colors.green[700]),
                                            const SizedBox(width: 4),
                                            const Text('Team Leader Assigned', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
