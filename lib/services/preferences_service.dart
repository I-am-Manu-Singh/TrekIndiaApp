import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  static const String _savedTreksKey = 'saved_treks';

  Future<List<String>> getSavedTreks() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_savedTreksKey) ?? [];
  }

  Future<void> toggleSavedTrek(String trekId) async {
    final prefs = await SharedPreferences.getInstance();
    final savedTreks = prefs.getStringList(_savedTreksKey) ?? [];
    
    if (savedTreks.contains(trekId)) {
      savedTreks.remove(trekId);
    } else {
      savedTreks.add(trekId);
    }
    
    await prefs.setStringList(_savedTreksKey, savedTreks);
  }

  Future<bool> isTrekSaved(String trekId) async {
    final prefs = await SharedPreferences.getInstance();
    final savedTreks = prefs.getStringList(_savedTreksKey) ?? [];
    return savedTreks.contains(trekId);
  }

  Future<void> setLastRead(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_read_$roomId', DateTime.now().toIso8601String());
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
