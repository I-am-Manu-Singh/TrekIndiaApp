import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';

class UserGearRentalScreen extends StatefulWidget {
  const UserGearRentalScreen({super.key});

  @override
  State<UserGearRentalScreen> createState() => _UserGearRentalScreenState();
}

class _UserGearRentalScreenState extends State<UserGearRentalScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _rentals = [];

  @override
  void initState() {
    super.initState();
    _fetchRentals();
  }

  Future<void> _fetchRentals() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    setState(() => _isLoading = true);

    try {
      final res = await _client
          .from('user_rentals')
          .select('*, gear:gears(name)')
          .eq('user_id', user.id)
          .order('issue_date', ascending: false);
      if (mounted) {
        setState(() {
          _rentals = res;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showReserveModal() async {
    setState(() => _isLoading = true);
    final gearRes = await _client.from('gears').select();
    if (mounted) setState(() => _isLoading = false);
    if (gearRes.isEmpty) return;

    String selectedGearId = gearRes[0]['id'];
    int qty = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final currentGear = gearRes.firstWhere((g) => g['id'] == selectedGearId);
                    final int pD = currentGear['price_per_day'] ?? 0;
          final int totalCost = pD * qty;
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Container(
            padding: EdgeInsets.fromLTRB(30, 30, 30, MediaQuery.of(sheetContext).viewInsets.bottom + 30),
            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('HQ GEAR RESERVATION', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 24),
                const Text('SELECT EQUIPMENT', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedGearId,
                  items: gearRes.map((e) => DropdownMenuItem<String>(
                    value: e['id'].toString(), 
                    child: Text(e['name'] ?? 'Gear', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))
                  )).toList(),
                  onChanged: (v) {
                    if (v != null) setModalState(() => selectedGearId = v);
                  },
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('QUANTITY', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    Row(
                      children: [
                        IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: qty > 1 ? () => setModalState(() => qty--) : null),
                        Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => setModalState(() => qty++)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL RENTAL FEE', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    Text('₹$totalCost.0', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF2E7B32))),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () async {
                      final user = _client.auth.currentUser;
                      if (user == null) return;

                      try {
                        await _client.from('user_rentals').insert({
                          'user_id': user.id,
                          'gear_id': selectedGearId,
                          'quantity': qty,
                          'total_price': totalCost,
                          'status': 'pending',
                          'issue_date': DateTime.now().toIso8601String(),
                          'deposit_status': 'Pending'
                        });

                        if (mounted) {
                          Navigator.pop(sheetContext);
                          _fetchRentals();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reservation successfully logged!'), backgroundColor: Colors.green));
                        }
                      } catch (e) {
                         if (mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submission Error: $e'), backgroundColor: Colors.red));
                         }
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7B32), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 0),
                    child: const Text('CONFIRM RESERVATION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('RENTAL MANAGEMENT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        backgroundColor: const Color(0xFF2E7B32),
        elevation: 0,
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _rentals.length,
            itemBuilder: (context, index) {
              final r = _rentals[index];
              return _buildRentalCard(r);
            },
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showReserveModal,
        backgroundColor: const Color(0xFF2E7B32),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('RESERVE GEAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildRentalCard(dynamic r) {
    final bool isReturned = r['status']?.toString().toLowerCase() == 'returned';
    final String issueDate = DateFormat('MMM dd, yyyy').format(DateTime.parse(r['issue_date']));
    final String returnTime = r['returned_at'] != null ? DateFormat('MMM dd, hh:mm a').format(DateTime.parse(r['returned_at'])) : (r['status'] == 'returned' ? 'STILL ARCHIVING...' : 'N/A');

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 20, offset: const Offset(0, 10))],
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(15)),
                  child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF2E7B32), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${r['quantity']}x ${r['gear']?['name'] ?? 'GEAR ITEM'}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                      Text('TREK DEPLOYED: $issueDate', style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    ],
                  ),
                ),
                _statusBadge(isReturned ? 'RETURNED' : (r['status']?.toString().toUpperCase() ?? 'ISSUED'), isReturned ? Colors.green : (r['status'] == 'pending' ? Colors.blue : Colors.orange)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _infoCell('TOTAL RENTAL', '₹${r['total_price']}.0', Icons.payments_outlined),
                _infoCell('SECURITY', 'WAIVED', Icons.shield_outlined),
                _infoCell('STATUS', isReturned ? 'ARCHIVED' : 'ACTIVE', Icons.track_changes_outlined),
              ],
            ),
          ),
          if (isReturned)
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: const BoxDecoration(color: Color(0xFFE8F5E9), borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
              child: Text('ASSET RECOVERED: $returnTime', style: const TextStyle(color: Color(0xFF2E7B32), fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1), textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }

  Widget _infoCell(String label, String value, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: isDark ? Colors.white70 : Colors.black87)),
      ],
    );
  }
}
