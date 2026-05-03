import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'edit_trip_screen.dart';
import '../models/trip.dart';
import 'blogs_screen.dart';

class AdminTripInventoryScreen extends StatefulWidget {
  const AdminTripInventoryScreen({super.key});

  @override
  State<AdminTripInventoryScreen> createState() => _AdminTripInventoryScreenState();
}

class _AdminTripInventoryScreenState extends State<AdminTripInventoryScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _trips = [];

  @override
  void initState() {
    super.initState();
    _fetchTrips();
  }

  Future<void> _fetchTrips() async {
    setState(() => _isLoading = true);
    try {
      final res = await _client.from('trips').select().order('title', ascending: true);
      if (mounted) {
        setState(() {
          _trips = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteTrip(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('REMOVE TRIP?'),
        content: const Text('This will permanently remove this trip from the dashboard. Proceed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('ABORT')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('CONFIRM')
          ),
        ],
      )
    );

    if (confirmed == true) {
      try {
        await _client.from('trips').delete().eq('id', id);
        _fetchTrips();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trip decomtriped successfully.')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  String _searchQuery = '';
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Adventure Trip', 'Religious Trip', 'Yatra', 'Weekend Trip', 'International Trip'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final filteredTrips = _trips.where((t) {
      final matchesSearch = (t['title'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
                            (t['location'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCat = _selectedCategory == 'All' || t['category'] == _selectedCategory;
      return matchesSearch && matchesCat;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
      appBar: AppBar(
        title: const Text('TRIP INVENTORY', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 13)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.add_box_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const EditTripScreen())).then((v) { if(v == true) _fetchTrips(); })),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark ? const Color(0xFF1E293B) : Theme.of(context).primaryColor,
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search dashboard for trips...',
                hintStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 20),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: _categories.map((c) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(c, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _selectedCategory == c ? Colors.white : (isDark ? Colors.grey : Colors.grey[600]))),
                  selected: _selectedCategory == c,
                  onSelected: (s) => setState(() => _selectedCategory = c),
                  backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200],
                  selectedColor: Theme.of(context).primaryColor,
                  checkmarkColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              )).toList(),
            ),
          ),
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : filteredTrips.isEmpty 
                    ? Center(child: Text('No trips found in dashboard.', style: TextStyle(color: isDark ? Colors.grey : Colors.grey[600])))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredTrips.length,
                        itemBuilder: (context, index) {
                          final trip = filteredTrips[index];
                          final hasImage = trip['image_url'] != null && trip['image_url'].toString().isNotEmpty;
                          
                          return FadeInUp(
                            delay: Duration(milliseconds: index * 50),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05)),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                leading: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: hasImage 
                                      ? Image.network(trip['image_url'], fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.broken_image, size: 20))
                                      : const Icon(Icons.terrain, color: Colors.grey, size: 24),
                                  ),
                                ),
                                title: Text(trip['title'] ?? 'Official Trip', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text('${trip['location']} • ₹${trip['base_price']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                      child: Text(trip['category']?.toUpperCase() ?? 'ADVENTURE', style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 8, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_note, size: 22, color: Colors.blueAccent), 
                                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => EditTripScreen(trip: Trip.fromJson(trip)))).then((v) { if(v == true) _fetchTrips(); })
                                    ),
                                    IconButton(icon: const Icon(Icons.delete_sweep_outlined, size: 22, color: Colors.redAccent), onPressed: () => _deleteTrip(trip['id'].toString())),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
