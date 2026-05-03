import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  static const String _savedTripsKey = 'saved_trips';
  
  // Trip Event Bus for Read Receipts
  final _readStreamController = StreamController<String>.broadcast();
  Stream<String> get readStream => _readStreamController.stream;

  Future<List<String>> getSavedTrips() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_savedTripsKey) ?? [];
  }

  Future<void> toggleSavedTrip(String tripId) async {
    final prefs = await SharedPreferences.getInstance();
    final savedTrips = prefs.getStringList(_savedTripsKey) ?? [];
    
    if (savedTrips.contains(tripId)) {
      savedTrips.remove(tripId);
    } else {
      savedTrips.add(tripId);
    }
    
    await prefs.setStringList(_savedTripsKey, savedTrips);
  }

  Future<bool> isTripSaved(String tripId) async {
    final prefs = await SharedPreferences.getInstance();
    final savedTrips = prefs.getStringList(_savedTripsKey) ?? [];
    return savedTrips.contains(tripId);
  }

  Future<void> setLastRead(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toIso8601String();
    await prefs.setString('last_read_$roomId', now);
    // Broadcast update to all details listen nodes
    _readStreamController.add(roomId);
  }

  Future<DateTime> getLastRead(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString('last_read_$roomId');
    return val != null ? DateTime.parse(val) : DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> setTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark', isDark);
  }

  Future<bool> getTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_dark') ?? false;
  }

  Future<void> setNotifications(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);
  }

  Future<bool> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_enabled') ?? true;
  }

  Future<void> setLocationSharing(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('location_sharing_enabled', enabled);
  }

  Future<bool> getLocationSharing() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('location_sharing_enabled') ?? false;
  }
}
