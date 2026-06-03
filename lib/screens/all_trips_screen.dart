import 'package:flutter/material.dart';
import '../widgets/glass_shimmer.dart';
import 'package:animate_do/animate_do.dart';
import 'package:collection/collection.dart';
import '../models/trip.dart';
import '../widgets/unified_trip_card.dart';
import '../services/database_service.dart';

class AllTripsScreen extends StatefulWidget {
  final List<Trip> allTrips;
  final String? initialCategory;

  const AllTripsScreen({
    super.key, 
    required this.allTrips, 
    this.initialCategory,
  });

  @override
  State<AllTripsScreen> createState() => _AllTripsScreenState();
}

class _AllTripsScreenState extends State<AllTripsScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<TripCategory> _categories = [];
  String _selectedCategory = 'All';
  List<Trip> _allTrips = [];
  List<Trip> _filteredTrips = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _allTrips = widget.allTrips;
    _selectedCategory = widget.initialCategory ?? 'All';
    _loadCategories();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() => _isLoading = true);
    final trips = await _dbService.fetchTrips();
    if (mounted) {
      setState(() {
        _allTrips = trips;
        _isLoading = false;
      });
      _applyFilter();
    }
  }

  Future<void> _loadCategories() async {
    final cats = await _dbService.fetchCategories();
    if (mounted) {
      setState(() {
        _categories = cats;
      });
      _applyFilter(); // 👈 Re-apply filter now that we have categories
    }
  }

  void _applyFilter() {
    setState(() {
      if (_selectedCategory == 'All' || _selectedCategory.toUpperCase() == 'ALL') {
        _filteredTrips = _allTrips;
      } else if (_selectedCategory.toLowerCase() == 'special') {
        _filteredTrips = _allTrips.where((t) {
          final catMeta = _categories.firstWhereOrNull((c) => c.name == t.category);
          return catMeta?.isSpecial ?? false;
        }).toList();
      } else if (_selectedCategory.toLowerCase() == 'packages') {
        _filteredTrips = _allTrips.where((t) {
          final cat = (t.category ?? '').toLowerCase();
          return cat.contains('package') || cat.contains('vacation');
        }).toList();
      } else {
        // Case-insensitive matching + Region support
        _filteredTrips = _allTrips.where((t) {
          final cat = (t.category ?? '').toLowerCase();
          final loc = (t.location ?? '').toLowerCase();
          final target = _selectedCategory.toLowerCase();
          return cat == target || target.contains(cat) || cat.contains(target) || loc.contains(target);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF09090B) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _selectedCategory.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading 
          ? _buildShimmerList()
          : _filteredTrips.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _filteredTrips.length,
              itemBuilder: (context, index) {
                final t = _filteredTrips[index];
                final meta = _categories.firstWhereOrNull((c) => c.name == t.category);
                
                return FadeInUp(
                  duration: const Duration(milliseconds: 400),
                  delay: Duration(milliseconds: 50 * index),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: UnifiedTripCard(
                      trip: t, 
                      categoryMeta: meta,
                      heroTag: 'all_trips_${t.id}',
                      width: double.infinity,
                      onRefresh: _loadTrips,
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, size: 80, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'NO TRIPS FOUND IN $_selectedCategory',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerList() {
    return GlassShimmer(
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: 3,
        itemBuilder: (context, index) => const ShimmerBlock(
          width: double.infinity,
          height: 280,
          margin: EdgeInsets.only(bottom: 20),
          borderRadius: 24,
        ),
      ),
    );
  }
}
