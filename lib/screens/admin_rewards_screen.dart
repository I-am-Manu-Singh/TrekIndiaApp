import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import '../widgets/user_avatar.dart';

class AdminRewardsScreen extends StatefulWidget {
  const AdminRewardsScreen({super.key});

  @override
  State<AdminRewardsScreen> createState() => _AdminRewardsScreenState();
}

class _AdminRewardsScreenState extends State<AdminRewardsScreen> {
  final _client = Supabase.instance.client;
  final _searchController = TextEditingController();

  bool _isLoading = false;
  List<dynamic> _users = [];
  Map<String, dynamic>? _selectedUser;
  List<dynamic> _ledger = [];
  bool _isLoadingLedger = false;

  // Global stats
  int _totalIssued = 0;
  int _totalRedeemed = 0;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _fetchGlobalStats();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchGlobalStats() async {
    try {
      final rows = await _client
          .from('reward_ledger')
          .select('points, type');
      int issued = 0, redeemed = 0;
      for (final row in (rows as List)) {
        final pts = int.tryParse((row['points'] ?? 0).toString()) ?? 0;
        final type = (row['type'] ?? '').toString().toLowerCase();
        if (type == 'credit') issued += pts;
        else redeemed += pts;
      }
      if (mounted) setState(() { _totalIssued = issued; _totalRedeemed = redeemed; });
    } catch (e) {
      debugPrint('Stats error: $e');
    }
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final query = _searchController.text.trim();
      var request = _client.from('profiles').select().order('full_name', ascending: true);
      if (query.isNotEmpty) {
        request = _client.from('profiles').select().ilike('full_name', '%$query%').order('full_name', ascending: true);
      }
      final res = await request;
      if (mounted) setState(() { _users = res as List; _isLoading = false; });
    } catch (e) {
      debugPrint('Error fetching users: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Compute live balance from ledger rows (credit - debit)
  int _balanceFromLedger(List<dynamic> ledger) {
    int bal = 0;
    for (final row in ledger) {
      final pts = int.tryParse((row['points'] ?? 0).toString()) ?? 0;
      final type = (row['type'] ?? '').toString().toLowerCase();
      bal += type == 'credit' ? pts : -pts;
    }
    return bal < 0 ? 0 : bal;
  }

  Future<void> _fetchUserLedger(Map<String, dynamic> userProfile) async {
    setState(() {
      _selectedUser = userProfile;
      _isLoadingLedger = true;
      _ledger = [];
    });
    try {
      final res = await _client
          .from('reward_ledger')
          .select()
          .eq('user_id', userProfile['id'])
          .order('created_at', ascending: false);
      if (mounted) setState(() { _ledger = res as List; _isLoadingLedger = false; });
    } catch (e) {
      debugPrint('Error fetching ledger: $e');
      if (mounted) setState(() => _isLoadingLedger = false);
    }
  }

  Future<void> _adjustPoints(int amount, String description, String type) async {
    if (_selectedUser == null) return;
    final user = _selectedUser!;
    final isCredit = type.toLowerCase() == 'credit';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1. Insert into reward_ledger with unified schema
      await _client.from('reward_ledger').insert({
        'user_id': user['id'],
        'points': amount,
        'type': isCredit ? 'credit' : 'debit',
        'description': '[Admin] $description',
        'created_at': DateTime.now().toIso8601String(),
      });

      // 2. Push in-app notification
      await _client.from('notifications').insert({
        'user_id': user['id'],
        'title': isCredit
            ? '🏆 +$amount Reward Points Added'
            : '🏆 $amount Reward Points Deducted',
        'body': isCredit
            ? 'An admin credited $amount reward points to your account. Reason: $description'
            : 'An admin deducted $amount reward points from your account. Reason: $description',
        'category': 'reward',
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully ${isCredit ? 'credited' : 'debited'} $amount points.'),
          backgroundColor: isCredit ? Colors.green : Colors.red,
        ),
      );

      // Refresh
      _fetchGlobalStats();
      final updatedProfile = await _client.from('profiles').select().eq('id', user['id']).single();
      _fetchUsers();
      _fetchUserLedger(updatedProfile);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint('Error adjusting points: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showAdjustmentDialog(String type) {
    if (_selectedUser == null) return;
    final isCredit = type.toLowerCase() == 'credit';
    final amountController = TextEditingController();
    final descController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isCredit ? 'CREDIT POINTS' : 'DEBIT POINTS',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isCredit ? Colors.green : Colors.red,
          ),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Points Amount',
                  prefixIcon: Icon(
                    isCredit ? Icons.add_circle_outline : Icons.remove_circle_outline,
                    color: isCredit ? Colors.green : Colors.red,
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter points amount';
                  if (int.tryParse(v) == null || int.parse(v) <= 0) return 'Enter a valid positive number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: descController,
                decoration: InputDecoration(
                  labelText: 'Reason / Description',
                  prefixIcon: const Icon(Icons.notes_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter adjustment reason';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final points = int.parse(amountController.text);
                final desc = descController.text;
                Navigator.pop(context);
                _adjustPoints(points, desc, type);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isCredit ? Colors.green : Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('CONFIRM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width > 900;

    final Widget leftPanel = Container(
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          // Global stats bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE6A817), Color(0xFFFF6F00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('REWARDS OVERVIEW',
                          style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      Text('Issued: $_totalIssued pts  •  Redeemed: $_totalRedeemed pts  •  Net: ${_totalIssued - _totalRedeemed} pts',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => _fetchUsers(),
              decoration: InputDecoration(
                labelText: 'Search Hikers...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFFD32F2F)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ),
          // User list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _users.length,
                    itemBuilder: (context, i) {
                      final u = _users[i];
                      final isSelected = _selectedUser?['id'] == u['id'];
                      // Show balance from profile field if available, otherwise 0
                      final points = u['reward_points'] ?? 0;
                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: const Color(0xFFD32F2F).withOpacity(0.05),
                        leading: UserAvatar(name: u['full_name'], imageUrl: u['avatar_url']),
                        title: Text(u['full_name'] ?? 'Explorer',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${u['role'] ?? 'user'}',
                            style: const TextStyle(fontSize: 11)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6A817).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('$points pts',
                              style: const TextStyle(
                                  color: Color(0xFFE6A817),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                        onTap: () => _fetchUserLedger(u),
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    final Widget rightPanel = _selectedUser == null
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_search_outlined,
                    size: 64, color: Colors.grey.withOpacity(0.3)),
                const SizedBox(height: 16),
                const Text('Select a hiker to view their rewards ledger.',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                FadeInDown(
                  child: Row(
                    children: [
                      if (!isWide)
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => setState(() => _selectedUser = null),
                        ),
                      UserAvatar(
                          name: _selectedUser!['full_name'],
                          imageUrl: _selectedUser!['avatar_url'],
                          radius: 24),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedUser!['full_name']?.toString().toUpperCase() ?? 'EXPLORER',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                            // Live balance from ledger
                            Text(
                              'Live Balance: ${_balanceFromLedger(_ledger)} pts'
                              ' ≈ ₹${(_balanceFromLedger(_ledger) / 10).toStringAsFixed(0)}',
                              style: const TextStyle(
                                  color: Color(0xFFE6A817), fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showAdjustmentDialog('credit'),
                        icon: const Icon(Icons.add, color: Colors.white, size: 16),
                        label: const Text('CREDIT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showAdjustmentDialog('debit'),
                        icon: const Icon(Icons.remove, color: Colors.white, size: 16),
                        label: const Text('DEBIT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                const Text('TRANSACTION LEDGER',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey, letterSpacing: 1.5)),
                const SizedBox(height: 12),

                // Ledger list
                Expanded(
                  child: _isLoadingLedger
                      ? const Center(child: CircularProgressIndicator())
                      : _ledger.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.workspace_premium_outlined,
                                      size: 48, color: Colors.amber.withOpacity(0.3)),
                                  const SizedBox(height: 12),
                                  const Text('No reward transactions yet.',
                                      style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _ledger.length,
                              itemBuilder: (context, i) {
                                final item = _ledger[i];
                                // Support both lowercase 'credit'/'debit' (new) 
                                // and uppercase 'CREDIT'/'DEBIT' (old legacy rows)
                                final typeStr = (item['type'] ?? '').toString().toLowerCase();
                                final bool isCredit = typeStr == 'credit';
                                // Support both column names: 'points' (new) and 'points_changed' (old)
                                final pts = int.tryParse(
                                    (item['points'] ?? item['points_changed'] ?? 0).toString()
                                  )?.abs() ?? 0;
                                final dateStr = item['created_at'] != null
                                    ? DateFormat('MMM dd yyyy, HH:mm')
                                        .format(DateTime.parse(item['created_at']))
                                    : '—';

                                return FadeInUp(
                                  delay: Duration(milliseconds: i * 30),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isCredit
                                          ? Colors.green.withOpacity(0.03)
                                          : Colors.red.withOpacity(0.03),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isCredit
                                            ? Colors.green.withOpacity(0.12)
                                            : Colors.red.withOpacity(0.12),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            color: (isCredit ? Colors.green : Colors.red).withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            isCredit ? Icons.add_circle_outline : Icons.remove_circle_outline,
                                            color: isCredit ? Colors.green : Colors.red,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item['description'] ?? 'Points Adjustment',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 3),
                                              Text(dateStr,
                                                  style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '${isCredit ? "+" : "-"}$pts pts',
                                          style: TextStyle(
                                            color: isCredit ? const Color(0xFFE6A817) : Colors.red,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('REWARDS REGISTRY',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        backgroundColor: const Color(0xFFD32F2F),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _fetchUsers();
              _fetchGlobalStats();
              if (_selectedUser != null) _fetchUserLedger(_selectedUser!);
            },
          ),
        ],
      ),
      body: isWide
          ? Row(
              children: [
                Expanded(flex: 2, child: leftPanel),
                Expanded(flex: 3, child: rightPanel),
              ],
            )
          : (_selectedUser == null ? leftPanel : rightPanel),
    );
  }
}
