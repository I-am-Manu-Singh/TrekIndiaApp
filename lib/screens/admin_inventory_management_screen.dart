import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';

class AdminInventoryManagementScreen extends StatefulWidget {
  const AdminInventoryManagementScreen({super.key});

  @override
  State<AdminInventoryManagementScreen> createState() => _AdminInventoryManagementScreenState();
}

class _AdminInventoryManagementScreenState extends State<AdminInventoryManagementScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _gears = [];

  @override
  void initState() {
    super.initState();
    _fetchGears();
  }

  Future<void> _fetchGears() async {
    setState(() => _isLoading = true);
    try {
      final res = await _client.from('gears').select().order('name');
      if (mounted) {
        setState(() {
          _gears = res;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddEditGear([dynamic gear]) {
    final nameCtrl = TextEditingController(text: gear?['name']?.toString() ?? '');
    final priceCtrl = TextEditingController(text: gear?['price_per_day']?.toString() ?? '');
    final qtyCtrl = TextEditingController(text: gear?['stock_count']?.toString() ?? '10');
    final categoryCtrl = TextEditingController(text: gear?['category']?.toString() ?? 'General');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.fromLTRB(30, 30, 30, MediaQuery.of(ctx).viewInsets.bottom + 30),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(gear == null ? 'ADD NEW GEAR ASSET' : 'UPGRADE ASSET INFO',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: 1.2,
                        color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 24),
                _input(nameCtrl, 'Asset Name (e.g. Tent 4P)'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _input(priceCtrl, 'Price/Day', isNumeric: true)),
                    const SizedBox(width: 16),
                    Expanded(child: _input(qtyCtrl, 'Total Inventory', isNumeric: true)),
                  ],
                ),
                const SizedBox(height: 16),
                _input(categoryCtrl, 'Category'),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        final data = {
                          'name': nameCtrl.text.trim(),
                          'price_per_day': double.tryParse(priceCtrl.text) ?? 50.0,
                          'stock_count': int.tryParse(qtyCtrl.text) ?? 10,
                          'category': categoryCtrl.text.trim(),
                          'description': 'Field Operative Equipment',
                          'security_deposit': 0.0,
                        };
                        if (gear == null) {
                          await _client.from('gears').insert(data);
                        } else {
                          await _client.from('gears').update(data).eq('id', gear['id']);
                        }
                        if (mounted) {
                          Navigator.pop(ctx);
                          _fetchGears();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('LOGISTICS SYNC COMPLETE'), backgroundColor: Colors.green));
                        }
                      } catch (e) {
                        if (mounted) {
                           debugPrint('HQ GEAR ERROR: $e');
                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('LOGISTICS FAILURE: $e'), backgroundColor: Colors.red));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15))),
                    child: const Text('AUTHORIZE LOGISTICS UPDATE',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _input(TextEditingController ctrl, String hint, {bool isNumeric = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: ctrl,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('INVENTORY INTELLIGENCE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5, color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: _gears.length,
            itemBuilder: (context, index) {
              final g = _gears[index];
              return FadeInUp(
                duration: Duration(milliseconds: 300 + (index * 50)),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.01), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.inventory_2_outlined, color: Colors.blue, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(g['category']?.toString().toUpperCase() ?? 'GENERAL', style: const TextStyle(color: Colors.blueAccent, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                                const Spacer(),
                                 _stockChip(int.tryParse(g['stock_count']?.toString() ?? '0') ?? 0),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(g['name'] ?? 'ASSET', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -0.4, color: isDark ? Colors.white : Colors.black87)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text('₹${g['price_per_day']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.green)),
                                const Text(' / DAY', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey)),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blueGrey),
                                  onPressed: () => _showAddEditGear(g),
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                  onPressed: () async {
                                     final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (c) => AlertDialog(
                                           title: const Text('DECOMTREK?'),
                                           content: Text('Remove ${g['name']}?'),
                                           actions: [
                                              TextButton(onPressed: () => Navigator.pop(c), child: const Text('ABORT')),
                                              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('DELETE', style: TextStyle(color: Colors.red))),
                                           ],
                                        ),
                                     );
                                     if (ok == true) {
                                        await _client.from('gears').delete().eq('id', g['id']);
                                        _fetchGears();
                                     }
                                  },
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditGear(),
        backgroundColor: isDark ? Colors.blueAccent : Colors.black,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _stockChip(int qty) {
     final low = qty < 5;
     return Container(
       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
       decoration: BoxDecoration(color: (low ? Colors.orange : Colors.green).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
       child: Text('STK: $qty', style: TextStyle(color: low ? Colors.orange : Colors.green, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
     );
   }
}
