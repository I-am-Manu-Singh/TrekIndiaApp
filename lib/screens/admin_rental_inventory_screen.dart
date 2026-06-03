import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';

class AdminRentalInventoryScreen extends StatefulWidget {
  const AdminRentalInventoryScreen({super.key});

  @override
  State<AdminRentalInventoryScreen> createState() => _AdminRentalInventoryScreenState();
}

class _AdminRentalInventoryScreenState extends State<AdminRentalInventoryScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _inventory = [];
  List<dynamic> _activeRentals = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final gearRes = await _client.from('gears').select();
      final rentalRes = await _client.from('user_rentals').select('*, gear:gears(*), user:profiles(full_name)').neq('status', 'returned');
      
      if (mounted) {
        setState(() {
          _inventory = gearRes;
          _activeRentals = rentalRes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddGear() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final stockCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('ADD NEW INVENTORY ITEM'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Item Name')),
            TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Price Per Day'), keyboardType: TextInputType.number),
            TextField(controller: stockCtrl, decoration: const InputDecoration(labelText: 'Total Stock'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              try {
                await _client.from('gears').insert({
                  'name': nameCtrl.text.trim(),
                  'price_per_day': double.tryParse(priceCtrl.text) ?? 50.0,
                  'stock_count': int.tryParse(stockCtrl.text) ?? 10,
                  'category': 'Essential',
                  'description': 'Field Staff Equipment',
                  'security_deposit': 0.0,
                });
                if (mounted) {
                  Navigator.pop(c);
                  _loadData(); // Changed from _fetchGears() to _loadData() as _fetchGears() is not defined
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('LOGISTICS SYNC: Gear asset comtriped.'), backgroundColor: Colors.green));
                }
              } catch (e) {
                if (mounted) {
                  debugPrint('TREKWITHMUSSAFIRR GEAR ERROR: $e');
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('LOGISTICS FAILURE: $e'), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('ADD ITEM'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('GEAR & LOGISTICS HUB', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white, letterSpacing: 2)),
          backgroundColor: Colors.black,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'INVENTORY'),
              Tab(text: 'ACTIVE RENTALS'),
            ],
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1),
          ),
        ),
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              children: [
                _buildInventoryList(),
                _buildRentalList(),
              ],
            ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddGear,
          backgroundColor: Colors.blueAccent,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildInventoryList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _inventory.length,
      itemBuilder: (context, index) {
        final item = _inventory[index];
        final int inUse = _activeRentals.where((r) => r['gear_id'] == item['id']).fold(0, (sum, r) => sum + (int.tryParse(r['quantity']?.toString() ?? '0') ?? 0));
        final int available = (int.tryParse(item['stock_count']?.toString() ?? '0') ?? 0) - inUse;

        return FadeInUp(
          delay: Duration(milliseconds: index * 50),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.02), blurRadius: 10)],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
                  child: const Icon(Icons.inventory_2_outlined, color: Colors.blueAccent, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['name'] ?? 'GEAR', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                      Text('RATE: ₹${item['price_per_day']}/day', style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$available / ${item['stock_count']}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isDark ? Colors.white : Colors.black87)),
                    const Text('AVAILABLE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRentalList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _activeRentals.length,
      itemBuilder: (context, index) {
        final r = _activeRentals[index];
        final String user = r['user']?['full_name'] ?? 'Trip';
        final String gear = r['gear']?['name'] ?? 'Item';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                    Text('$gear (x${r['quantity']})', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _client.from('user_rentals').update({'status': 'returned', 'returned_at': DateTime.now().toIso8601String()}).eq('id', r['id']);
                  _loadData();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, elevation: 0),
                child: const Text('MARK RETURNED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }
}
