import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../services/database_service.dart';
import '../services/preferences_service.dart';
import '../models/trek.dart';
import '../widgets/trek_card.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  List<Trek> _savedTreksList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedTreks();
  }

  Future<void> _loadSavedTreks() async {
    try {
      final savedIds = await PreferencesService().getSavedTreks();
      if (savedIds.isEmpty) {
        if (mounted) {
          setState(() {
            _savedTreksList = [];
            _isLoading = false;
          });
        }
        return;
      }
      
      final allTreks = await DatabaseService().fetchTreks();
      final filteredTreks = allTreks.where((trek) => savedIds.contains(trek.id)).toList();
      
      if (mounted) {
        setState(() {
          _savedTreksList = filteredTreks;
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
        title: const Text('Saved Treks', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _savedTreksList.isEmpty 
          ? Center(
              child: FadeInDown(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.favorite_border, size: 80, color: Colors.grey[300]),
                    const SizedBox(height: 20),
                    const Text(
                      'No saved treks yet!',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Hit the heart icon on a trek to save it here for later.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadSavedTreks,
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _savedTreksList.length,
                itemBuilder: (context, index) {
                  return FadeInUp(
                    child: TrekCard(trek: _savedTreksList[index]),
                  );
                },
              ),
            ),
    );
  }
}
