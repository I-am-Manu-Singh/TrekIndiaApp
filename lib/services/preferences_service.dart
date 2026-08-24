import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  // Admin Automated Dispatch Routing (Invoices, Declarations, Enquiries)
  Future<void> setAdminDispatchEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('admin_dispatch_email', email);
  }

  Future<String> getAdminDispatchEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('admin_dispatch_email') ?? 'mussafirr1@gmail.com';
  }

  Future<void> setAdminDispatchPhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('admin_dispatch_phone', phone);
  }

  Future<String> getAdminDispatchPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('admin_dispatch_phone') ?? '919876543210';
  }

  Future<void> syncLastReadFromCloud(String userId) async {
    try {
      final client = Supabase.instance.client;
      final profile = await client.from('profiles').select('last_read_at, created_at, role').eq('id', userId).maybeSingle();
      if (profile != null) {
        final lastReadStr = profile['last_read_at'] ?? profile['created_at'];
        if (lastReadStr != null) {
          final lastReadTime = DateTime.parse(lastReadStr.toString());
          final prefs = await SharedPreferences.getInstance();
          
          final role = (profile['role'] ?? 'user').toString().toLowerCase();
          List<String> roomIds = [];
          if (role == 'admin') {
            final groups = await client.from('trip_groups').select('id');
            roomIds = (groups as List).map((g) => g['id'].toString()).toList();
          } else if (role == 'staff' || role == 'employee' || role == 'guide') {
            final staffDeployments = await client.from('trip_group_staff').select('trip_id, deployment_date').eq('user_id', userId);
            if ((staffDeployments as List).isNotEmpty) {
              final Set<String> tripIds = staffDeployments.map((s) => s['trip_id']?.toString() ?? '').toSet()..removeWhere((id) => id.isEmpty || id == 'null');
              if (tripIds.isNotEmpty) {
                final groups = await client.from('trip_groups').select('id, trip_id, departure_date').inFilter('trip_id', tripIds.toList());
                for (var d in staffDeployments) {
                  final dTripId = d['trip_id']?.toString();
                  final dDate = (d['deployment_date'] ?? '').toString().split('T')[0];
                  for (var g in groups) {
                    final gTripId = g['trip_id']?.toString();
                    final gDate = (g['departure_date'] ?? '').toString().split('T')[0];
                    if (dTripId == gTripId && dDate == gDate) {
                      roomIds.add(g['id'].toString());
                    }
                  }
                }
              }
            }
          } else {
            final bookings = await client.from('bookings').select('group_id').eq('user_id', userId).not('group_id', 'is', null);
            roomIds = (bookings as List).map((b) => b['group_id'].toString()).toSet().toList();
          }

          for (final roomId in roomIds) {
            final key = 'last_read_$roomId';
            if (!prefs.containsKey(key)) {
              await prefs.setString(key, lastReadTime.toIso8601String());
            }
          }
        }
      }
    } catch (e) {
      print('Error syncing last read from cloud: $e');
    }
  }
}
