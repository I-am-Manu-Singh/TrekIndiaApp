import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'admin_squad_intelligence_screen.dart';
import '../widgets/user_avatar.dart';

class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({super.key});

  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  final _client = Supabase.instance.client;
  DateTime? _selectedDate;
  bool _isLoading = true;
  List<dynamic> _trekGroups = [];
  int _tabIndex = 0; // 0 for Active, 1 for Archived

  @override
  void initState() {
    super.initState();
    _fetchGroups();
  }

  Future<void> _fetchGroups() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch Raw Data (Strategic Relation Sync)
      final allBookings = await _client.from('bookings').select('*, trek_groups(id, group_name)').order('created_at', ascending: false);
      final allTreks = await _client.from('treks').select();
      final allProfiles = await _client.from('profiles').select();
      final allStaff = await _client.from('trek_group_staff').select();

      final Map<String, dynamic> trekMap = {for (var t in allTreks) t['id']: t};
      final Map<String, dynamic> profileMap = {for (var p in allProfiles) p['id']: p};

      Map<String, dynamic> groups = {};

      void addToGroup(String groupKey, dynamic trek, String date, dynamic profile, double price, String? realGroupId) {
        if (trek == null) return;
        
        // TEMPORAL SENSOR: Filter by date if selected
        if (_selectedDate != null) {
           try {
             final dParsed = DateTime.parse(date);
             if (dParsed.year != _selectedDate!.year || dParsed.month != _selectedDate!.month || dParsed.day != _selectedDate!.day) {
                return;
             }
           } catch (_) { 
             return; 
           }
        }

        if (!groups.containsKey(groupKey)) {
          groups[groupKey] = {
            'trek_id': trek['id'],
            'trek': trek,
            'date': date,
            'total_revenue': 0.0,
            'participants': [],
            'group_id': realGroupId, // MISSION CRITICAL: Sync with established room
          };
        }
        if (profile != null) {
          groups[groupKey]['participants'].add(profile);
          groups[groupKey]['total_revenue'] += price;
        }
        // Preserve the strongest ID link
        if (realGroupId != null && groups[groupKey]['group_id'] == null) {
            groups[groupKey]['group_id'] = realGroupId;
        }
      }

      // 2. Process Bookings Intel
      for (var b in allBookings) {
        final trekId = b['trek_id']?.toString() ?? 'GENERIC_TREK';
        final trek = trekMap[trekId] ?? {
          'id': trekId,
          'trek_name': 'Unknown Tactical Deployment',
          'trek_destination': 'Field Sector Alpha',
          'trek_image': 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b'
        };

        final String bStatus = b['payment_status']?.toString().toLowerCase() ?? '';
        final String gStatus = b['status']?.toString().toLowerCase() ?? '';
        bool isCompleted = bStatus == 'completed' || gStatus == 'completed';

        if (_tabIndex == 0 && isCompleted) continue;
        if (_tabIndex == 1 && !isCompleted) continue;

        final String rawDate = b['trek_date'] ?? b['booking_date'] ?? 'TBD';
        final String groupKey = '${trekId}_$rawDate';
        final userProfile = profileMap[b['user_id']];
        
        final String? realGroupId = b['trek_groups']?['id']?.toString() ?? b['group_id']?.toString();
        
        addToGroup(groupKey, trek, rawDate, userProfile, double.tryParse(b['total_price'].toString()) ?? 0, realGroupId);
      }

      // 3. Process Field Staff Intel
      for (var s in allStaff) {
        final tDate = s['deployment_date'] ?? ''; 
        final tId = s['trek_id'];
        final gKey = '${tId}_$tDate';
        if (groups.containsKey(gKey)) {
           final staffProfile = profileMap[s['user_id']];
           if (staffProfile != null) {
              groups[gKey]['participants'].add(staffProfile);
           }
        }
      }

      if (mounted) {
        setState(() {
          _trekGroups = groups.values.toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('BOOKINGS MANAGEMENT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_month, color: _selectedDate != null ? Colors.blueAccent : Colors.white),
            onPressed: () async {
               final d = await showDatePicker(
                 context: context, 
                 initialDate: _selectedDate ?? DateTime.now(), 
                 firstDate: DateTime(2024), 
                 lastDate: DateTime(2030)
               );
               if (d != null) {
                 setState(() => _selectedDate = d);
                 _fetchGroups();
               } else if (_selectedDate != null) {
                 setState(() => _selectedDate = null);
                 _fetchGroups();
               }
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Row(
            children: [
               _tabItem(0, 'ACTIVE SECTORS'),
               _tabItem(1, 'MISSION ARCHIVE'),
            ],
          ),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (_selectedDate != null) Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    const Icon(Icons.filter_list, size: 14, color: Colors.blueAccent),
                    const SizedBox(width: 8),
                    Text('FILTERING DATE: ${DateFormat('MMM dd, yyyy').format(_selectedDate!)}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    const Spacer(),
                    TextButton(onPressed: () { setState(() => _selectedDate = null); _fetchGroups(); }, child: const Text('CLEAR', style: TextStyle(fontSize: 10, color: Colors.red))),
                  ],
                ),
              ),
              _buildAnalyticsCards(),
              const SizedBox(height: 24),
              const Text('HQ COMMAND GRID', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5, color: Colors.grey)),
              const SizedBox(height: 16),
              ..._trekGroups.map((g) => _buildGroupCard(g)).toList(),
            ],
          ),
    );
  }

  Widget _buildGroupCard(dynamic g) {
    final trek = g['trek'];
    String dateStr = 'TBD';
    try {
      if (g['date'] != null && g['date'].toString().isNotEmpty) {
         dateStr = DateFormat('EEEE, MMM dd yyyy').format(DateTime.parse(g['date']));
      }
    } catch (_) {}

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.03), blurRadius: 10)],
        border: Border.all(color: _tabIndex == 1 ? Colors.blueGrey.withOpacity(0.1) : Colors.green.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(trek['title'] ?? 'Generic Trek', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isDark ? Colors.white : Colors.black87)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: isDark ? Colors.blue.withOpacity(0.1) : const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(8)),
                child: Text('${g['participants'].length} TREKKERS', style: const TextStyle(color: Color(0xFF1976D2), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(dateStr, style: const TextStyle(color: Color(0xFF1976D2), fontSize: 13, fontWeight: FontWeight.bold)),
              Text('₹${g['total_revenue'].toInt()}', style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 16, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 24),
          const Text('SQUAD ROSTER', style: TextStyle(color: Colors.grey, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...g['participants'].map((p) => _rosterChip(p)).toList(),
              if (g['participants'].length > 4) 
                _rosterMoreChip(g['participants'].length - 4),
            ],
          ),
          const SizedBox(height: 24),
          if (_tabIndex == 0) Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (c) => AdminSquadIntelligenceScreen(trekId: trek['id'], deploymentDate: g['date'])));
                    _fetchGroups();
                  },
                  icon: const Icon(Icons.groups_outlined, color: Colors.white, size: 16),
                  label: const Text('MANAGE SQUAD', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7B32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                     final ok = await showDialog<bool>(
                       context: context,
                       builder: (c) => AlertDialog(
                         title: const Text('MISSION COMPLETION'),
                         content: Text('Are you sure you want to mark ${trek['title']} as COMPLETED? This will archive the deployment.'),
                         actions: [
                           TextButton(onPressed: () => Navigator.pop(c), child: const Text('ABORT')),
                           ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('COMPLETE MISSION')),
                         ],
                       )
                     );
                     if (ok == true) {
                       await _client.from('bookings').update({'payment_status': 'completed'}).eq('trek_id', trek['id']).eq('trek_date', g['date']);
                       final Map<String, dynamic> groupPayload = {
                           'trek_id': trek['id'],
                           'departure_date': g['date'],
                           'status': 'completed',
                           'group_name': trek['title'] ?? 'Strategic Group',
                       };
                       if (g['group_id'] != null) {
                           groupPayload['id'] = g['group_id'];
                       }
                       await _client.from('trek_groups').upsert(groupPayload);
                       _fetchGroups();
                     }
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('COMPLETE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rosterChip(dynamic p) {
    if (p == null) return const SizedBox.shrink();
    final String? fullName = p['full_name']?.toString();
    final String? avatarUrl = p['avatar_url']?.toString();
    final String initial = (fullName != null && fullName.isNotEmpty) ? fullName[0].toUpperCase() : 'T';
    
    return Tooltip(
      message: fullName ?? 'Trekker',
      child: UserAvatar(
        radius: 14,
        imageUrl: p?['avatar_url'],
        name: p?['full_name'],
      ),
    );
  }

  Widget _rosterMoreChip(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
      child: Text('+$count MORE', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
    );
  }

  Widget _buildAnalyticsCards() {
    double totalRevenue = _trekGroups.fold(0, (sum, g) => sum + (g['total_revenue'] as double));
    int totalParticipants = _trekGroups.fold(0, (sum, g) => sum + (g['participants'].length as int));

    return Row(
      children: [
        Expanded(child: _analyticsCard('OFFICIAL SECTORS', '${_trekGroups.length}', Colors.blue, Icons.map_outlined)),
        const SizedBox(width: 12),
        Expanded(child: _analyticsCard('TOTAL STRENGTH', '$totalParticipants', Colors.orange, Icons.groups_outlined)),
        const SizedBox(width: 12),
        Expanded(child: _analyticsCard('HQ REVENUE', '₹${totalRevenue.toInt()}', Colors.green, Icons.account_balance_wallet_outlined)),
      ],
    );
  }

  Widget _analyticsCard(String label, String val, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 12),
          Text(val, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _tabItem(int index, String label) {
    bool selected = _tabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _tabIndex = index);
          _fetchGroups();
        },
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? Colors.blueAccent : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

}
