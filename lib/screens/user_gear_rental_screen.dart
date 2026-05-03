import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../models/trip.dart';

class UserGearRentalScreen extends StatefulWidget {
  const UserGearRentalScreen({super.key});

  @override
  State<UserGearRentalScreen> createState() => _UserGearRentalScreenState();
}

class _UserGearRentalScreenState extends State<UserGearRentalScreen> with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;
  TabController? _tabController;
  bool _isLoading = true;
  List<dynamic> _rentals = [];
  RealtimeChannel? _rentalSubscription;

  @override
  void initState() {
    super.initState();
    final controller = TabController(length: 2, vsync: this);
    _tabController = controller;
    _fetchRentals();
    _setupRealtime();
  }

  void _setupRealtime() {
    final user = _client.auth.currentUser;
    if (user == null) return;

    _rentalSubscription = _client
        .channel('user_rentals_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_rentals',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            debugPrint('REALTIME RENTAL UPDATE: ${payload.eventType}');
            _fetchRentals(showLoading: false);
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _rentalSubscription?.unsubscribe();
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _fetchRentals({bool showLoading = true}) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    if (showLoading) setState(() => _isLoading = true);

    try {
      // We fetch ALL to allow the tab logic to work without re-fetching
      var query = _client.from('user_rentals').select('*, gears(*)').eq('user_id', user.id);

      final res = await query.order('issue_date', ascending: false);
      if (mounted) {
        debugPrint('USER RENTALS FETCHED: ${res.length} items');
        for (var r in res) {
          debugPrint('ITEM ID: ${r['id']} | STATUS: ${r['status']}');
        }
        setState(() {
          _rentals = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('USER RENTAL ERROR: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFFBFBFB),
      appBar: AppBar(
        title: const Text('MY EQUIPMENT HUB', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white, letterSpacing: 2)),
        backgroundColor: const Color(0xFFD32F2F),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _fetchRentals),
        ],
        bottom: _tabController == null ? null : TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1),
          tabs: const [
            Tab(text: 'ACTIVE RENTALS'),
            Tab(text: 'RETURN HISTORY'),
          ],
        ),
      ),
      body: _isLoading || _tabController == null
        ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
        : TabBarView(
            controller: _tabController,
            children: [
              _buildRentalsList('NO ACTIVE GEAR TRIPS', true),
              _buildRentalsList('NO ARCHIVE DATA FOUND', false),
            ],
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showReserveModal,
        backgroundColor: Colors.blueAccent,
        icon: const Icon(Icons.add_box_outlined, color: Colors.white),
        label: const Text('NEW RESERVATION', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)),
      ),
    );
  }

  Widget _buildRentalsList(String emptyText, bool isActiveTab) {
    final filteredRentals = _rentals.where((r) {
      final status = (r['status'] ?? 'issued').toString().toLowerCase().trim();
      final isRet = status == 'returned';
      return isActiveTab ? !isRet : isRet;
    }).toList();

    return RefreshIndicator(
      onRefresh: _fetchRentals,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (isActiveTab) ...[
            _buildUserAnalytics(filteredRentals),
            const SizedBox(height: 24),
            const Text('CURRENT POSSESSIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
            const SizedBox(height: 16),
          ],
          if (filteredRentals.isEmpty) _emptyState(emptyText)
          else ...filteredRentals.map((r) => _buildRentalCard(r)).toList(),
        ],
      ),
    );
  }

  Widget _buildUserAnalytics(List<dynamic> activeRentals) {
    int activeCount = activeRentals.length;
    double securityHeld = activeRentals.fold(0, (sum, r) => sum + (double.tryParse(r['gears']?['security_deposit']?.toString() ?? '500') ?? 500));

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        _statCard('$activeCount', 'ACTIVE GEAR', Icons.inventory_2_outlined, Colors.blue),
        _statCard('₹${securityHeld.toInt()}', 'SECURITY HELD', Icons.shield_outlined, Colors.orange),
      ],
    );
  }

  Widget _statCard(String val, String label, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(val, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isDark ? Colors.white : Colors.black87)),
                Text(label, style: const TextStyle(fontSize: 7, color: Colors.grey, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRentalCard(dynamic r) {
    final gear = r['gears'];
    final bool isReturned = r['status']?.toString().toLowerCase().trim() == 'returned';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(20),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: (isReturned ? Colors.green : Colors.blue).withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
              child: Icon(isReturned ? Icons.verified_outlined : Icons.inventory_2_outlined, color: isReturned ? Colors.green : Colors.blueAccent, size: 24),
            ),
            title: Row(
              children: [
                Expanded(child: Text('${r['quantity']}x ${gear?['name'] ?? 'Gear'}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                _statusBadge(r['status'] ?? 'Issued'),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 10, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('ISSUED: ${DateFormat('MMM dd').format(DateTime.parse(r['issue_date']))}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    const SizedBox(width: 12),
                    if (isReturned) ...[
                      const Icon(Icons.check_circle_outline, size: 10, color: Colors.green),
                      const SizedBox(width: 4),
                      Text('RETURNED', style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                    ] else ...[
                      const Icon(Icons.timer_outlined, size: 10, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('DUE: ${r['return_date'] != null ? DateFormat('MMM dd').format(DateTime.parse(r['return_date'])) : 'TBD'}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _infoMini('TOTAL FEE', '₹${r['total_price']}', Colors.green),
                      _infoMini('SECURITY', '₹${gear?['security_deposit'] ?? 500}', Colors.orange),
                      _infoMini('UNIT', '₹${gear?['price_per_day'] ?? 0}/d', Colors.blue),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoMini(String label, String val, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 7, color: Colors.grey, fontWeight: FontWeight.bold)),
        Text(val, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }

  Widget _statusBadge(String status) {
    final bool isReturned = status.toLowerCase().trim() == 'returned';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: (isReturned ? Colors.green : Colors.orange).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(status.toUpperCase(), style: TextStyle(color: isReturned ? Colors.green : Colors.orange, fontSize: 8, fontWeight: FontWeight.bold)),
    );
  }

  Widget _emptyState(String text) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          Text(text, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Need gear for your next trek? Reserve below.', style: TextStyle(color: Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }

  void _showReserveModal() async {
    setState(() => _isLoading = true);
    final gearRes = await DatabaseService().fetchGears();
    if (mounted) setState(() => _isLoading = false);
    if (gearRes.isEmpty) return;

    String selectedGearId = gearRes[0].id;
    int qty = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final gear = gearRes.firstWhere((g) => g.id == selectedGearId);
          final total = gear.pricePerDay.toInt() * qty;
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Container(
            padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('RESERVE EQUIPMENT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5)),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  value: selectedGearId,
                  items: gearRes.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)))).toList(),
                  onChanged: (v) => setModalState(() => selectedGearId = v!),
                  decoration: const InputDecoration(labelText: 'Choose Gear', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('QUANTITY', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    Row(
                      children: [
                        IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: qty > 1 ? () => setModalState(() => qty--) : null),
                        Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                        IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => setModalState(() => qty++)),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ESTIMATED COST', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    Text('₹$total', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Colors.green)),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      final user = _client.auth.currentUser;
                      if (user == null) return;
                      try {
                        await _client.from('user_rentals').insert({
                          'user_id': user.id, 'gear_id': selectedGearId, 'quantity': qty, 'total_price': total,
                          'status': 'Pending', 'issue_date': DateTime.now().toIso8601String(),
                        });
                        Navigator.pop(ctx);
                        _fetchRentals();
                      } catch (e) {
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    },
                    child: const Text('CONFIRM RESERVATION'),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }
}
