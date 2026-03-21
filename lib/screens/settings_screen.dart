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
    setState(() => _isDark = dark);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DEPLOYMENT SETTINGS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 13, color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _sectionHeader('TREK CONFIGURATION'),
          SwitchListTile(
            title: const Text('Night Ops Mode', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Enable dark theme for low-light scouting', style: TextStyle(fontSize: 11)),
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
            title: const Text('Intel Pings', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Receive real-time mission notifications', style: TextStyle(fontSize: 11)),
            value: _notifications,
            activeColor: Colors.orangeAccent,
            onChanged: (val) => setState(() => _notifications = val),
          ),
          const Divider(height: 48),
          _sectionHeader('IDENTITY TELEMETRY'),
          ListTile(
            title: const Text('Edit Mission Profile', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Update identity documents and squad metadata', style: TextStyle(fontSize: 11)),
            leading: const Icon(Icons.badge_outlined, color: Colors.blueAccent),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => Navigator.pushNamed(context, '/edit_profile'),
          ),
          const Divider(height: 48),
          _sectionHeader('HQ DATA'),
          ListTile(
            title: const Text('Clear Local Cache', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Flush temporary mission assets', style: TextStyle(fontSize: 11)),
            trailing: const Icon(Icons.delete_outline, color: Colors.red),
            onTap: () {},
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
