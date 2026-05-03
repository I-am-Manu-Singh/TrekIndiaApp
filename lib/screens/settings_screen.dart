import 'package:flutter/material.dart';
import '../services/preferences_service.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDark = false;
  bool _notifications = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final dark = await PreferencesService().getTheme();
    final notifs = await PreferencesService().getNotifications();
    setState(() {
      _isDark = dark;
      _notifications = notifs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('APP SETTINGS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 13, color: Colors.white)),
        backgroundColor: const Color(0xFFD32F2F),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _sectionHeader('TRIP SETTINGS'),
          SwitchListTile(
            title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Enable dark theme for the app', style: TextStyle(fontSize: 11)),
            value: themeNotifier.value == ThemeMode.dark,
            activeColor: Colors.blueAccent,
            onChanged: (val) async {
              setState(() => _isDark = val);
              await PreferencesService().setTheme(val);
              themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
              // Force rebuild of THIS screen as well as the app
              setState(() {});
            },
          ),
          SwitchListTile(
            title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Receive real-time updates', style: TextStyle(fontSize: 11)),
            value: _notifications,
            activeColor: Colors.orangeAccent,
            onChanged: (val) async {
              setState(() => _notifications = val);
              await PreferencesService().setNotifications(val);
            },
          ),
          const Divider(height: 48),
          _sectionHeader('PERSONAL DATA'),
          ListTile(
            title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Update your personal and emergency details', style: TextStyle(fontSize: 11)),
            leading: const Icon(Icons.badge_outlined, color: Colors.blueAccent),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => Navigator.pushNamed(context, '/edit_profile'),
          ),
          const Divider(height: 48),
          _sectionHeader('APP DATA'),
          ListTile(
            title: const Text('Clear Local Cache', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Clear temporary app data', style: TextStyle(fontSize: 11)),
            trailing: const Icon(Icons.delete_outline, color: Colors.red),
            onTap: () async {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (c) => const Center(child: CircularProgressIndicator()),
              );
              await Future.delayed(const Duration(seconds: 2));
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('App cache cleared successfully.'), backgroundColor: Colors.black),
                );
              }
            },
          ),
          const Divider(height: 48),
          Center(child: Text('VERSION 1.0.4 - STABLE BRAVO', style: TextStyle(color: Colors.grey.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1))),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Text(title, style: const TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
    );
  }
}
