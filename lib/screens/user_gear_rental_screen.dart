import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import '../models/trek.dart';
import '../services/database_service.dart';

class UserGearRentalScreen extends StatefulWidget {
  const UserGearRentalScreen({super.key});

  @override
  State<UserGearRentalScreen> createState() => _UserGearRentalScreenState();
}

class _UserGearRentalScreenState extends State<UserGearRentalScreen> {
  final _db = DatabaseService();
  final _client = Supabase.instance.client;
  List<Gear> _availableGears = [];
  Map<String, int> _selectedGears = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchGears();
  }

  Future<void> _fetchGears() async {
    final gears = await _db.fetchGears();
    if (mounted) {
      setState(() {
        _availableGears = gears;
        _isLoading = false;
      });
    }
  }

  void _confirmRental() async {
    if (_selectedGears.isEmpty) return;

    final user = _client.auth.currentUser;
    if (user == null) return;

    showDialog(context: context, builder: (c) => const Center(child: CircularProgressIndicator()));

    try {
      for (var entry in _selectedGears.entries) {
        final gear = _availableGears.firstWhere((g) => g.id == entry.key);
        await _client.from('user_rentals').insert({
          'user_id': user.id,
          'gear_id': entry.key,
          'quantity': entry.value,
          'total_price': gear.pricePerDay * entry.value * 7, // Fixed 7 days for independent rental
          'status': 'requested',
          'issue_date': DateTime.now().toIso8601String(),
          'rental_type': 'independent',
        });
      }
      if (mounted) {
        Navigator.pop(context); // Pop loader
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rental request sent! Our team will contact you for pickup.'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Arsenal Rental', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              _buildHeader(isDark),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _availableGears.length,
                  itemBuilder: (context, index) {
                    final gear = _availableGears[index];
                    final qty = _selectedGears[gear.id] ?? 0;
                    return FadeInUp(
                      delay: Duration(milliseconds: index * 50),
                      child: Card(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: ListTile(
                          title: Text(gear.name, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                          subtitle: Text('₹${gear.pricePerDay.toInt()}/day • ${gear.category}', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (qty > 0) ...[
                                IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () => setState(() => _selectedGears[gear.id] = qty - 1)),
                                Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                              IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.green), onPressed: () => setState(() => _selectedGears[gear.id] = qty + 1)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              _buildSummary(),
            ],
          ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      width: double.infinity,
      color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TACTICAL GEAR RENTAL', style: TextStyle(fontWeight: FontWeight.w900, color: isDark ? Colors.blueAccent : Colors.black54, fontSize: 10, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Text('Rent high-quality gear even if you are not trekking with us.', style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    double totalPerDay = 0;
    _selectedGears.forEach((id, qty) {
       final gear = _availableGears.firstWhere((g) => g.id == id);
       totalPerDay += gear.pricePerDay * qty;
    });
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Daily Rate', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
              Text('₹${totalPerDay.toInt()}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black)),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _selectedGears.isEmpty ? null : _confirmRental,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            child: const Text('SUBMIT RENTAL REQUEST', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
