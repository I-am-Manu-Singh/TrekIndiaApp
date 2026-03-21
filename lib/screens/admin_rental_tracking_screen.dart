import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/trek.dart';
import '../widgets/user_avatar.dart';

class AdminRentalTrackingScreen extends StatefulWidget {
  const AdminRentalTrackingScreen({super.key});

  @override
  State<AdminRentalTrackingScreen> createState() =>
      _AdminRentalTrackingScreenState();
}

class _AdminRentalTrackingScreenState extends State<AdminRentalTrackingScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _rentals = [];
  int _tabIndex = 0; // 0 for Active, 1 for History (Returned)

  @override
  void initState() {
    super.initState();
    _fetchRentals();
  }

  Future<void> _fetchRentals() async {
    setState(() => _isLoading = true);
    try {
      var query = _client
          .from('user_rentals')
          .select('*, profiles(*), gears(*)');
      if (_tabIndex == 0) {
        query = query.or('status.eq.issued, status.eq.Issued, status.is.null');
      } else {
        query = query.or('status.eq.returned, status.eq.Returned');
      }
      final res = await query.order('issue_date', ascending: false);
      if (mounted)
        setState(() {
          _rentals = res;
          _isLoading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F172A) : const Color(0xFFFBFBFB),
      appBar: AppBar(
        title: const Text(
          'GEAR RENTALS',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 13,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchRentals,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Row(
            children: [
              _tabItem(0, 'ACTIVE RENTALS'),
              _tabItem(1, 'RETURN HISTORY'),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildOverview(),
                const SizedBox(height: 32),
                ..._rentals.map((r) => _buildRentalCard(r)).toList(),
                if (_rentals.isEmpty) _buildEmptyState(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showIssueGear,
        backgroundColor: Colors.blueAccent,
        icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
        label: const Text(
          'ISSUE GEAR',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _tabItem(int index, String label) {
    bool selected = _tabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _tabIndex = index);
          _fetchRentals();
        },
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? Colors.blueAccent : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverview() {
    double totalActiveValue = 0;
    double totalRevenue = 0;
    int itemsOut = 0;
    int damageCount = 0;
    int totalReturned = 0;

    for (var r in _rentals) {
      if (_tabIndex == 0) {
        totalActiveValue += double.tryParse(r['total_price'].toString()) ?? 0;
        itemsOut += (r['quantity'] as num?)?.toInt() ?? 1;
      } else {
        totalRevenue += double.tryParse(r['total_price'].toString()) ?? 0;
        totalReturned++;
        if (r['damage_notes'] != null) damageCount++;
      }
    }

    double health = totalReturned == 0
        ? 100
        : ((totalReturned - damageCount) / totalReturned) * 100;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statCol(
            _tabIndex == 0 ? itemsOut.toString() : '₹${totalRevenue.toInt()}',
            _tabIndex == 0 ? 'ITEMS DEPLOYED' : 'TREK YIELD',
            Colors.blue,
          ),
          Container(width: 1, height: 40, color: Colors.grey.shade100),
          _statCol(
            _tabIndex == 0
                ? '₹${totalActiveValue.toInt()}'
                : '${health.toInt()}%',
            _tabIndex == 0 ? 'COMMITTED VALUE' : 'ASSET HEALTH',
            _tabIndex == 0
                ? Colors.black
                : (health > 80 ? Colors.green : Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _statCol(String val, String label, Color color) {
    return Column(
      children: [
        Text(
          val,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildRentalCard(dynamic r) {
    final gear = r['gears'];
    final profile = r['profiles'];
    final bool isReturned = r['status']?.toString().toLowerCase() == 'returned';
    final String issueDate = DateFormat('MMM dd, yyyy').format(DateTime.parse(r['issue_date'] ?? DateTime.now().toIso8601String()));
    final String returnTime = r['returned_at'] != null ? DateFormat('MMM dd, HH:mm').format(DateTime.parse(r['returned_at'])) : 'N/A';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
                children: [
                  UserAvatar(
                    radius: 24,
                    imageUrl: profile?['avatar_url'],
                    name: profile?['full_name'],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${r['quantity']}x ${gear?['name'] ?? 'GEAR ITEM'}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -0.5, color: isDark ? Colors.white : Colors.black87)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.person_pin, size: 10, color: Colors.blueAccent),
                            const SizedBox(width: 4),
                            Text(profile?['full_name']?.toUpperCase() ?? 'TREKKER', style: const TextStyle(color: Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _statusBadge(isReturned ? 'ARCHIVED' : 'ACTIVE', isReturned ? Colors.grey : Colors.orange),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _infoCell('TOTAL VALUE', '₹${r['total_price']}', Icons.payments_outlined),
                  _infoCell('DEPLOYED', issueDate, Icons.calendar_month_outlined),
                  _infoCell(isReturned ? 'RECOVERED' : 'DUE DATE', isReturned ? returnTime : (r['return_date'] != null ? DateFormat('MMM dd').format(DateTime.parse(r['return_date'])) : 'TBD'), Icons.access_time),
                ],
              ),
            ),
            if (!isReturned)
              Padding(
                padding: const EdgeInsets.all(22),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: () => _showReturnDialog(r),
                    icon: const Icon(Icons.assignment_return_outlined, size: 18, color: Colors.white),
                    label: const Text('LOG GEAR RETURN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 0),
                  ),
                ),
              ),
            if (isReturned)
              Container(
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                decoration: BoxDecoration(color: isDark ? Colors.green.withOpacity(0.1) : const Color(0xFFF1F8E9)),
                child: Center(
                  child: Text('GEAR RETURNED TO BASE: $returnTime', style: TextStyle(color: isDark ? Colors.greenAccent : const Color(0xFF2E7B32), fontWeight: FontWeight.w900, fontSize: 8, letterSpacing: 1.5)),
                ),
              ),
          ],
        ),
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
    return Column(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black87)),
      ],
    );
  }

  void _showReturnDialog(dynamic r) {
    bool hasDamage = false;
    final damageCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (c) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (c, setDialogState) => AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            title: Text(
              'GEAR RETURN LOG', 
              style: TextStyle(
                fontWeight: FontWeight.w900, 
                letterSpacing: 1, 
                color: isDark ? Colors.white : Colors.black87
              )
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50, 
                    borderRadius: BorderRadius.circular(15)
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, color: Colors.blueAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Returning ${r['quantity']}x ${r['gears']?['name'] ?? 'Item'}', 
                          style: TextStyle(
                            fontSize: 12, 
                            fontWeight: FontWeight.bold, 
                            color: isDark ? Colors.white70 : Colors.black87
                          )
                        )
                      ),
                    ],
                  ),
                ),
              ],
            ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('ABORT', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
            ElevatedButton(
              onPressed: () async {
                try {
                  final now = DateTime.now().toIso8601String();
                  await _client.from('user_rentals').update({
                    'status': 'returned',
                    'returned_at': now,
                  }).eq('id', r['id']);
                  
                  // SYNC STOCK
                  final String? gId = r['gear_id']?.toString();
                  if (gId != null) {
                    final gearRes = await _client.from('gears').select('stock_count').eq('id', gId).maybeSingle();
                    if (gearRes != null) {
                      int currentStock = (gearRes['stock_count'] as num?)?.toInt() ?? 0;
                      await _client.from('gears').update({
                        'stock_count': currentStock + (r['quantity'] as num).toInt(),
                      }).eq('id', gId);
                    }
                  }

                  if (mounted) {
                    Navigator.pop(c);
                    _fetchRentals();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('GEAR RETURNED: Stock levels updated.'), backgroundColor: Colors.black));
                  }
                } catch (e) {
                   if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('RETURN ERROR: $e'), backgroundColor: Colors.red));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('CONFIRM RETURN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ],
        ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 100),
        child: Column(
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 60,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _tabIndex == 0
                  ? 'No active gear deployments.'
                  : 'No archival data found.',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _showIssueGear() {
    String search = '';
    dynamic selectedGear;
    dynamic selectedUser;
    int qty = 1;
    int qtyDays = 3;
    final securityCtrl = TextEditingController(text: '500');
    bool waiveSecurity = false;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBtmState) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: EdgeInsets.fromLTRB(30, 30, 30, MediaQuery.of(ctx).viewInsets.bottom + 30),
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'OPERATIONAL GEAR DEPLOYMENT',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 1.5,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                onChanged: (v) => setBtmState(() => search = v),
                decoration: InputDecoration(
                  hintText: 'Search Trekker by name/phone...',
                  prefixIcon: const Icon(Icons.person_search_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (selectedUser == null)
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _client
                        .from('profiles')
                        .stream(primaryKey: ['id'])
                        .order('full_name'),
                    builder: (context, snap) {
                      if (!snap.hasData)
                        return const Center(child: CircularProgressIndicator());
                      final users = snap.data!
                          .where(
                            (u) =>
                                (u['full_name'] ?? '').toLowerCase().contains(
                                  search.toLowerCase(),
                                ) ||
                                (u['phone_number'] ?? '').contains(search),
                          )
                          .toList();
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: users.length,
                        itemBuilder: (context, i) {
                          final u = users[i];
                          return ListTile(
                            leading: CircleAvatar(
                               backgroundColor: Colors.blue.withOpacity(0.1),
                               child: Text((u['full_name'] ?? 'T')[0], style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
                            title: Text(u['full_name'] ?? 'Trekker', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text(u['phone_number'] ?? u['email'] ?? '', style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey, fontSize: 10)),
                            onTap: () => setBtmState(() => selectedUser = u),
                          );
                        },
                      );
                    },
                  ),
                )
              else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person, color: Colors.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          selectedUser['full_name'] ?? 'Selected Trekker',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => setBtmState(() => selectedUser = null),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _client
                      .from('gears')
                      .stream(primaryKey: ['id'])
                      .order('name'),
                  builder: (context, snap) {
                    if (!snap.hasData) return const SizedBox.shrink();
                    final gears = snap.data!;
                    if (selectedGear == null && gears.isNotEmpty)
                      selectedGear = gears[0];
                    return DropdownButtonFormField<String>(
                      value: selectedGear?['id']?.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Select Equipment',
                        border: OutlineInputBorder(),
                      ),
                      items: gears
                          .map(
                            (g) => DropdownMenuItem(
                              value: g['id'].toString(),
                              child: Text(g['name']),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setBtmState(() {
                        selectedGear = gears.firstWhere(
                          (g) => g['id'].toString() == v,
                        );
                      }),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('DEPLOYMENT DURATION', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 10)),
                    Row(
                       children: [
                         IconButton(icon: const Icon(Icons.remove, size: 16), onPressed: () => setBtmState(() => qty > 1 ? qty-- : null)),
                         Text('QTY: $qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                         IconButton(icon: const Icon(Icons.add, size: 16), onPressed: () => setBtmState(() => qty++)),
                       ],
                    )
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                   children: [
                     const Icon(Icons.timer_outlined, size: 14, color: Colors.blueAccent),
                     const SizedBox(width: 8),
                     const Text('TREK DAYS:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                     const SizedBox(width: 16),
                     Expanded(
                        child: Slider(
                           value: qtyDays.toDouble(),
                           min: 1, max: 15,
                           divisions: 14,
                           activeColor: Colors.blueAccent,
                           label: '$qtyDays Days',
                           onChanged: (v) => setBtmState(() => qtyDays = v.toInt()),
                        ),
                     ),
                     Text('$qtyDays D', style: const TextStyle(fontWeight: FontWeight.w900)),
                   ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                       child: TextField(
                          controller: securityCtrl,
                          keyboardType: TextInputType.number,
                          enabled: !waiveSecurity,
                          decoration: InputDecoration(
                             labelText: 'SECURITY DEPOSIT',
                             prefixText: '₹',
                             border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                       ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                       children: [
                         const Text('WAIVE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey)),
                         Switch(
                            value: waiveSecurity,
                            onChanged: (v) => setBtmState(() => waiveSecurity = v),
                            activeColor: Colors.redAccent,
                         ),
                       ],
                    )
                  ],
                ),
                const SizedBox(height: 24),
                if (selectedGear != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTAL COMMAND VALUE',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        '₹${((double.tryParse(selectedGear['price_per_day'].toString()) ?? 0) * qty * qtyDays).toInt()}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (selectedUser == null || selectedGear == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ABORT: Personnel or Equipment not selected.')));
                        return;
                      }
                      try {
                        await _client.from('user_rentals').insert({
                          'user_id': selectedUser['id'],
                          'gear_id': selectedGear['id'],
                          'quantity': qty,
                          'total_price':
                              (double.tryParse(selectedGear['price_per_day'].toString()) ?? 0) * qty * qtyDays,
                          'deposit_amount': waiveSecurity ? 0 : (double.tryParse(securityCtrl.text) ?? 500),
                          'is_deposit_paid': !waiveSecurity,
                          'status': 'Issued',
                          'issue_date': DateTime.now().toIso8601String(),
                          'return_date': DateTime.now().add(Duration(days: qtyDays)).toIso8601String(),
                        });
                        if (mounted) {
                          Navigator.pop(ctx);
                          _fetchRentals();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('DEPLOYMENT AUTHORIZED: Gear issued successfully.'), backgroundColor: Colors.green));
                        }
                      } catch (e) {
                         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('DEPLOYMENT FAILED: $e'), backgroundColor: Colors.red));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      'AUTHORIZE ISSUANCE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ],
            ),
          );
        },
      ),
    );
  }
}
