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

  @override
  void initState() {
    super.initState();
    _fetchUsers();
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
      setState(() {
        _users = res as List;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching users: $e');
      setState(() => _isLoading = false);
    }
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
      setState(() {
        _ledger = res as List;
        _isLoadingLedger = false;
      });
    } catch (e) {
      debugPrint('Error fetching ledger: $e');
      setState(() => _isLoadingLedger = false);
    }
  }

  Future<void> _adjustPoints(int amount, String description, String type) async {
    if (_selectedUser == null) return;
    final user = _selectedUser!;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final finalAmount = type == 'CREDIT' ? amount : -amount;
      
      // 1. Insert into Ledger
      await _client.from('reward_ledger').insert({
        'user_id': user['id'],
        'booking_id': user['id'], // Self-referencing adjustment
        'points_changed': finalAmount,
        'type': type,
        'description': '[Admin Adjustment] $description',
      });

      // 2. Update Profile points
      final currentPoints = int.tryParse(user['reward_points']?.toString() ?? '0') ?? 0;
      final newPoints = currentPoints + finalAmount;
      await _client.from('profiles').update({
        'reward_points': newPoints,
      }).eq('id', user['id']);

      // 3. Queue notification email
      final email = user['email'] ?? user['hiker_email'] ?? '';
      if (email.isNotEmpty) {
        await _client.from('reward_emails_queue').insert({
          'user_id': user['id'],
          'recipient_email': email,
          'subject': 'Reward Points Balance Adjustment ⚡️',
          'body': "Hello ${user['full_name']},\n\nAn administrator has adjusted your reward points balance.\n\nTransaction: $description\nChange: $finalAmount points\nNew Balance: $newPoints points\n\nBest Regards,\nTeam trekwithmussafirr",
        });
      }

      Navigator.pop(context); // Pop loading dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully adjusted points! Current balance: $newPoints'), backgroundColor: Colors.green),
      );

      // Refresh data
      final updatedProfile = await _client.from('profiles').select().eq('id', user['id']).single();
      _fetchUsers();
      _fetchUserLedger(updatedProfile);
    } catch (e) {
      Navigator.pop(context); // Pop loading dialog
      debugPrint('Error adjusting points: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to adjust points. Please check database permissions.'), backgroundColor: Colors.red),
      );
    }
  }

  void _showAdjustmentDialog(String type) {
    if (_selectedUser == null) return;
    final amountController = TextEditingController();
    final descController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('MANUAL $type ADJUSTMENT', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Points Amount', border: OutlineInputBorder()),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter points amount';
                  if (int.tryParse(v) == null || int.parse(v) <= 0) return 'Enter valid positive number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Reason / Description', border: OutlineInputBorder()),
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
            style: ElevatedButton.styleFrom(backgroundColor: type == 'CREDIT' ? Colors.green : Colors.red),
            child: const Text('ADJUST', style: TextStyle(color: Colors.white)),
          )
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
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (context, i) {
                    final u = _users[i];
                    final isSelected = _selectedUser?['id'] == u['id'];
                    final points = u['reward_points'] ?? 0;
                    
                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: const Color(0xFFD32F2F).withOpacity(0.05),
                      leading: UserAvatar(name: u['full_name'], imageUrl: u['avatar_url']),
                      title: Text(u['full_name'] ?? 'Explorer', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Role: ${u['role'] ?? 'user'}'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text('$points pts', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
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
      ? const Center(child: Text('Select a hiker to view their rewards ledger.', style: TextStyle(color: Colors.grey)))
      : Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeInDown(
                child: Row(
                  children: [
                    if (!isWide)
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => setState(() => _selectedUser = null),
                      ),
                    UserAvatar(name: _selectedUser!['full_name'], imageUrl: _selectedUser!['avatar_url'], radius: 24),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_selectedUser!['full_name']?.toString().toUpperCase() ?? 'EXPLORER', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                          Text('Current Rewards: ${_selectedUser!['reward_points'] ?? 0} Points', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showAdjustmentDialog('CREDIT'),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('CREDIT POINTS', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showAdjustmentDialog('DEBIT'),
                    icon: const Icon(Icons.remove, color: Colors.white),
                    label: const Text('DEBIT POINTS', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Text('TRANSACTION LEDGER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoadingLedger 
                  ? const Center(child: CircularProgressIndicator())
                  : _ledger.isEmpty
                    ? const Center(child: Text('No reward transactions found for this user.'))
                    : ListView.builder(
                        itemCount: _ledger.length,
                        itemBuilder: (context, i) {
                          final item = _ledger[i];
                          final bool isCredit = item['type'] == 'CREDIT';
                          final dateStr = DateFormat('MMM dd yyyy, HH:mm').format(DateTime.parse(item['created_at']));
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isCredit ? Colors.green.withOpacity(0.03) : Colors.red.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: isCredit ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1)),
                            ),
                            child: Row(
                              children: [
                                Icon(isCredit ? Icons.arrow_upward : Icons.arrow_downward, color: isCredit ? Colors.green : Colors.red),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item['description'] ?? 'Points Adjust', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${isCredit ? "+" : ""}${item['points_changed']}',
                                  style: TextStyle(
                                    color: isCredit ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
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
        title: const Text('REWARDS REGISTRY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        backgroundColor: const Color(0xFFD32F2F),
        elevation: 0,
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
