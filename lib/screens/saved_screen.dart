import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../services/database_service.dart';
import '../services/preferences_service.dart';
import '../models/trip.dart';
import '../widgets/trip_card.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  List<Trip> _savedTripsList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedTrips();
  }

  Future<void> _loadSavedTrips() async {
    try {
      final savedIds = await PreferencesService().getSavedTrips();
      if (savedIds.isEmpty) {
        if (mounted) {
          setState(() {
            _savedTripsList = [];
            _isLoading = false;
          });
        }
        return;
      }
      
      final allTrips = await DatabaseService().fetchTrips();
      final filteredTrips = allTrips.where((trip) => savedIds.contains(trip.id)).toList();
      
      if (mounted) {
        setState(() {
          _savedTripsList = filteredTrips;
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
      appBar: AppBar(
        title: const Text('Saved Trips', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _savedTripsList.isEmpty 
          ? Center(
              child: FadeInDown(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.favorite_border, size: 80, color: Colors.grey[300]),
                    const SizedBox(height: 20),
                    const Text(
                      'No saved trips yet!',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Hit the heart icon on a trip to save it here for later.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadSavedTrips,
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _savedTripsList.length,
                itemBuilder: (context, index) {
                  return FadeInUp(
                    child: TripCard(trip: _savedTripsList[index]),
                  );
                },
              ),
            ),
    );
  }
}
