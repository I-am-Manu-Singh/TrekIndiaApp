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
  List<dynamic> _groupedTreks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchGroupedBookings();
  }

  Future<void> _fetchGroupedBookings() async {
    try {
      // Fetch all bookings with trek details
      final response = await Supabase.instance.client
          .from('bookings')
          .select('*, treks(title, image_url)')
          .order('trek_date', ascending: true);
      
      if (mounted) {
        // Group by Trek ID and Date
        final Map<String, dynamic> groups = {};
        for (var booking in response) {
          final trekId = booking['trek_id'];
          final date = booking['trek_date'];
          final key = '${trekId}_$date';
          
          if (!groups.containsKey(key)) {
            groups[key] = {
              'trek_id': trekId,
              'trek_title': booking['treks']['title'],
              'image_url': booking['treks']['image_url'],
              'date': date,
              'bookings': [],
              'total_travelers': 0,
            };
          }
          groups[key]['bookings'].add(booking);
          groups[key]['total_travelers'] += (booking['travelers'] as int);
        }

        setState(() {
          _groupedTreks = groups.values.toList();
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 4,
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
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_today, size: 16, color: Theme.of(context).primaryColor),
                                          const SizedBox(width: 4),
                                          Text('Date: ${group['date']}', style: const TextStyle(fontWeight: FontWeight.w500)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.group, size: 16, color: Colors.blue[700]),
                                          const SizedBox(width: 4),
                                          Text('Travelers: ${group['total_travelers']}'),
                                        ],
                                      ),
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
