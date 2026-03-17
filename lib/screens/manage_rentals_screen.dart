import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import '../models/trek.dart';

class ManageRentalsScreen extends StatefulWidget {
  const ManageRentalsScreen({super.key});

  @override
  State<ManageRentalsScreen> createState() => _ManageRentalsScreenState();
}

class _ManageRentalsScreenState extends State<ManageRentalsScreen> {
  final _supabase = Supabase.instance.client;
  List<Gear> _gears = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchGears();
  }

  Future<void> _fetchGears() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase.from('gears').select().order('name');
      setState(() {
        _gears = (response as List).map((e) => Gear.fromJson(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteGear(String id) async {
    try {
      await _supabase.from('gears').delete().eq('id', id);
      _fetchGears();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
    }
  }

  void _showAddEditDialog([Gear? gear]) {
    final nameController = TextEditingController(text: gear?.name);
    final priceController = TextEditingController(text: gear?.pricePerDay.toString());
    final categoryController = TextEditingController(text: gear?.category);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(gear == null ? 'Add Rental Gear' : 'Edit Gear'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Gear Name')),
            TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Price per Day (₹)'), keyboardType: TextInputType.number),
            TextField(controller: categoryController, decoration: const InputDecoration(labelText: 'Category')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final price = double.tryParse(priceController.text.trim()) ?? 0;
              final cat = categoryController.text.trim();

              if (name.isEmpty || price <= 0) return;

              try {
                if (gear == null) {
                  await _supabase.from('gears').insert({
                    'name': name,
                    'price_per_day': price,
                    'category': cat,
                  });
                } else {
                  await _supabase.from('gears').update({
                    'name': name,
                    'price_per_day': price,
                    'category': cat,
                  }).eq('id', gear.id);
                }
                Navigator.pop(context);
                _fetchGears();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Rentals'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () => _showAddEditDialog()),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _gears.length,
            itemBuilder: (context, index) {
              final gear = _gears[index];
              return FadeInUp(
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(gear.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('₹${gear.pricePerDay.toInt()}/day • ${gear.category}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showAddEditDialog(gear)),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteGear(gear.id)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
    );
  }
}
