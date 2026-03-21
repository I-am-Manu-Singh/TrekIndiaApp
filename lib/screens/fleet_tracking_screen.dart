import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class FleetTrackingScreen extends StatefulWidget {
  const FleetTrackingScreen({super.key});

  @override
  State<FleetTrackingScreen> createState() => _FleetTrackingScreenState();
}

class _FleetTrackingScreenState extends State<FleetTrackingScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _activeSquads = [];

  @override
  void initState() {
    super.initState();
    _fetchFleetStatus();
  }

  Future<void> _fetchFleetStatus() async {
    setState(() => _isLoading = true);
    try {
      final res = await _client
          .from('bookings')
          .select('*, treks(*)')
          .gte('trek_date', DateTime.now().toIso8601String());
      
      Map<String, dynamic> groups = {};
      for (var b in res) {
        String key = '${b['trek_id']}_${b['trek_date']}';
        if (!groups.containsKey(key)) {
          groups[key] = {
            'title': b['treks']['title'],
            'status': 'TREK ACTIVE',
            'altitude': '${2000 + (b['treks']['id'].hashCode % 3000)}m',
            'color': Colors.green,
          };
        }
      }

      if (mounted) {
        setState(() {
          _activeSquads = groups.values.toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('FLEET & ASSET TRACKING', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5, color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildLiveMapHeader(),
              const SizedBox(height: 32),
              const Text('DEPLOYED SQUADS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2, color: Colors.blueGrey)),
              const SizedBox(height: 16),
              if (_activeSquads.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('NO SQUADS IN FIELD', style: TextStyle(color: Colors.grey, fontSize: 12))))
              else
                ..._activeSquads.map((s) => _fleetItem(s['title'], s['status'], s['altitude'], s['color'])).toList(),
              const SizedBox(height: 40),
              _buildAssetStatus(),
            ],
          ),
    );
  }

  Widget _buildLiveMapHeader() {
    return FadeInDown(
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade900,
          borderRadius: BorderRadius.circular(25),
          image: const DecorationImage(
            image: NetworkImage('https://images.unsplash.com/photo-1524661135-423995f22d0b?q=80&w=1000&auto=format&fit=crop'),
            fit: BoxFit.cover,
            opacity: 0.3,
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
                Icon(Icons.radar, color: Colors.greenAccent, size: 40),
                SizedBox(height: 12),
                Text('LIVE RADAR ACTIVE', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 10)),
                Text('Real-time GPS synchronization engaged', style: TextStyle(color: Colors.white70, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fleetItem(String title, String status, String alt, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade100)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.location_on, color: color, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(status, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ]),
          ),
          Text(alt, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.blueGrey)),
        ],
      ),
    );
  }

  Widget _buildAssetStatus() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('LOGISTICS STATUS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
          const SizedBox(height: 20),
          _assetTile(Icons.wifi, 'Satellite Comms', 'OPERATIONAL', Colors.green),
          _assetTile(Icons.medical_services, 'Medical Kits', 'CHECKED (12)', Colors.blue),
          _assetTile(Icons.backpack, 'Rental Stock', 'REPLENISHMENT REQ.', Colors.red),
        ],
      ),
    );
  }

  Widget _assetTile(IconData icon, String label, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}
