import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/user_avatar.dart';
import 'admin_attendance_screen.dart';
import 'package:animate_do/animate_do.dart';

class AdminEmployeeManagementScreen extends StatefulWidget {
  const AdminEmployeeManagementScreen({super.key});

  @override
  State<AdminEmployeeManagementScreen> createState() => _AdminEmployeeManagementScreenState();
}

class _AdminEmployeeManagementScreenState extends State<AdminEmployeeManagementScreen> {
  final _client = Supabase.instance.client;
  String _searchQuery = '';
  String _filterRole = 'ALL';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('STAFF DIRECTORY', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white, letterSpacing: 1.5)),
        elevation: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _client.from('profiles').stream(primaryKey: ['id']).order('full_name'),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final profiles = snapshot.data!.where((p) {
            final matchesSearch = (p['full_name'] ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) || (p['email'] ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
            final matchesRole = _filterRole == 'ALL' || p['role']?.toString().toUpperCase() == _filterRole;
            return matchesSearch && matchesRole;
          }).toList();

          return Column(
            children: [
              _buildHeader(profiles.length),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: profiles.length,
                  itemBuilder: (context, index) => _buildPersonnelCard(profiles[index]),
                ),
              ),
            ],
          );
        }
      ),
      floatingActionButton: FloatingActionButton(
  onPressed: () => _showAddPersonnelModal(),
  backgroundColor: Colors.blueAccent,
  elevation: 8,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  ),
  child: const Icon(
    Icons.person_add_alt_1,
    color: Colors.white,
    size: 26,
  ),
),
    );
  }

  Widget _buildHeader(int count) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(color: Color(0xFFD32F2F), borderRadius: BorderRadius.vertical(bottom: Radius.circular(30))),
      child: Column(
        children: [
           _buildSearchBar(),
           const SizedBox(height: 20),
           _buildFilters(),
           const SizedBox(height: 20),
           Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
             const Text('TOTAL STAFF', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
             Text('$count MEMBERS', style: const TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
           ]),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final roles = ['ALL', 'USER', 'ADMIN', 'GUIDE', 'STAFF'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: roles.map((r) => _filterChip(r)).toList()),
    );
  }

  Widget _filterChip(String role) {
    bool selected = _filterRole == role;
    return GestureDetector(
      onTap: () => setState(() => _filterRole = role),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: selected ? Colors.blueAccent : Colors.white10, borderRadius: BorderRadius.circular(10)),
        child: Text(role, style: TextStyle(color: selected ? Colors.white : Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(15)),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          icon: Icon(Icons.search, color: Colors.white38),
          border: InputBorder.none,
          hintText: 'Search by name or email...',
          hintStyle: TextStyle(color: Colors.white24, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildPersonnelCard(dynamic p) {
    final role = (p['role'] ?? 'user').toString().toUpperCase();
    final bool isStaff = role != 'USER';
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.04), blurRadius: 15, offset: const Offset(0, 8))],
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: () => _showPersonnelDetail(p),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(22),
                child: Row(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        UserAvatar(radius: 26, imageUrl: p['avatar_url'], name: p['full_name']),
                        if (p['aadhar_url'] != null || p['medical_certificate_url'] != null)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white, width: 1.5)),
                              child: const Icon(Icons.verified, color: Colors.white, size: 10),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p['full_name']?.toUpperCase() ?? 'STAFF', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -0.5, color: isDark ? Colors.white : Colors.black87)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _badge(role, isStaff ? Colors.blue : Colors.grey),
                              if (p['phone_number'] != null) ...[
                                const SizedBox(width: 8),
                                _badge('VERIFIED', Colors.green),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    _iconBox(Icons.chevron_right, Colors.grey.shade300),
                  ],
                ),
              ),
              if (isStaff) Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50),
                child: Row(
                  children: [
                    _miniStat('SALARY', '₹${p['salary'] ?? 0}', isDark),
                    _miniStat('ALLOWANCE', '₹${p['allowance'] ?? 0}', isDark),
                    _miniStat('XP', '${p['xp'] ?? 0} XP', isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold)),
    );
  }

  void _showPersonnelDetail(dynamic p) {
    String currentRole = (p['role'] ?? 'user').toString();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 40, child: Divider(thickness: 4)),
                const SizedBox(height: 24),
                UserAvatar(
                  radius: 40,
                  imageUrl: p['avatar_url'],
                  name: p['full_name'],
                ),
                const SizedBox(height: 16),
                Text(p['full_name'] ?? 'Personnel', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
                Text(p['email'] ?? 'support@tripindia.com', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 32),
                const Align(alignment: Alignment.centerLeft, child: Text('ROLE MANAGEMENT', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2))),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: currentRole,
                  decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 16)),
                  items: ['user', 'admin', 'guide', 'staff'].map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase()))).toList(),
                  onChanged: (v) async {
                    if (v == null) return;
                    await _client.from('profiles').update({'role': v}).eq('id', p['id']);
                    setModalState(() => currentRole = v);
                  },
                ),
                const SizedBox(height: 32),
                const SizedBox(height: 32),
                const Align(alignment: Alignment.centerLeft, child: Text('TRIP HISTORY', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2))),
                const SizedBox(height: 16),
                _taskAnalytics(p),
                const SizedBox(height: 32),
                const Align(alignment: Alignment.centerLeft, child: Text('ATTENDANCE METRICS', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2))),
                const SizedBox(height: 16),
                _attendanceStats(p),
                const SizedBox(height: 32),
                const Align(alignment: Alignment.centerLeft, child: Text('FINANCIALS & ACCOUNTS', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2))),
                const SizedBox(height: 16),
                _editableFinancials(p, setModalState),
                const SizedBox(height: 32),
                const Align(alignment: Alignment.centerLeft, child: Text('ACCESS & PERMISSIONS', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2))),
                const SizedBox(height: 16),
                _permissionsManagement(p, setModalState),
                const SizedBox(height: 32),
                Row(children: [
                  Expanded(child: _actionBtn(Icons.assignment_ind_outlined, 'ATTENDANCE', Colors.blue.shade50, Colors.blue, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => AdminAttendanceScreen(userId: p['id'], userName: p['full_name'] ?? 'Personnel'))))),
                  const SizedBox(width: 16),
                  Expanded(child: _actionBtn(Icons.payments_outlined, 'PAY BREAKUP', Colors.green.shade50, Colors.green, onTap: () => Navigator.pushNamed(context, '/salary_breakup', arguments: p))),
                  const SizedBox(width: 16),
                  Expanded(child: _actionBtn(Icons.money, 'PAYOUTS', Colors.orange.shade50, Colors.orange, onTap: () => _processPayout(p))),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _removeEmployee(p['id'], p['full_name']),
                    icon: const Icon(Icons.person_remove_outlined, color: Colors.red),
                    label: const Text('REMOVE FROM STAFF (Demote to User)', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      )
    );
  }

  Widget _inputSegment(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white, 
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100), 
        borderRadius: BorderRadius.circular(15)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isDark ? Colors.white : Colors.black87)),
        ],
      ),
    );
  }

  Widget _editableFinancials(dynamic p, StateSetter setModalState) {
    return Column(
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('FINANCIAL ASSETS & COMPENSATION', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5)),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _editField(p, 'salary', 'BASE SALARY', Icons.payments_outlined, setModalState)),
            const SizedBox(width: 12),
            Expanded(child: _editField(p, 'allowance', 'ALLOWANCE', Icons.add_chart_outlined, setModalState)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _editField(p, 'paid_leaves', 'PAID QUOTA', Icons.calendar_today_outlined, setModalState)),
            const SizedBox(width: 12),
            Expanded(child: _editField(p, 'unpaid_leaves', 'UNPAID COUNT', Icons.calendar_month_outlined, setModalState)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _editField(p, 'advances', 'ADVANCES', Icons.money_off_csred_outlined, setModalState)),
            const SizedBox(width: 12),
            Expanded(child: _editField(p, 'dues_penalty', 'DUES/PENALTY', Icons.gavel_outlined, setModalState)),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton.icon(
            onPressed: () => _delegateTask(p),
            icon: const Icon(Icons.assignment_ind_outlined, color: Colors.white, size: 18),
            label: const Text('ASSIGN TRIP TASK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
          ),
        ),
      ],
    );
  }

  Widget _permissionsManagement(dynamic p, StateSetter setModalState) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool canManage = p['can_manage_trips'] == true;
    bool canBroadcast = p['can_broadcast'] == true;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200)
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Trip/Package Customization', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                  const Text('Allow staff to add or edit trips', style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
              Switch(
                value: canManage,
                activeColor: Colors.blueAccent,
                onChanged: (val) async {
                  setModalState(() => p['can_manage_trips'] = val);
                  try {
                    await _client.from('profiles').update({'can_manage_trips': val}).eq('id', p['id']);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permissions Updated.')));
                  } catch (_) {}
                },
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Group Broadcast Authority', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                  const Text('Allow staff to send global alerts', style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
              Switch(
                value: canBroadcast,
                activeColor: Colors.orangeAccent,
                onChanged: (val) async {
                  setModalState(() => p['can_broadcast'] = val);
                  try {
                    await _client.from('profiles').update({'can_broadcast': val}).eq('id', p['id']);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Broadcast Authority Updated.')));
                  } catch (_) {}
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _editField(dynamic p, String key, String label, IconData icon, StateSetter setModalState) {
    final ctrl = TextEditingController(text: (p[key] ?? 0).toString());
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white, 
        borderRadius: BorderRadius.circular(15), 
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 8, color: isDark ? Colors.blue.shade200 : Colors.blueGrey, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.blueAccent),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                  decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                  onSubmitted: (v) => _saveField(p, key, v, label, setModalState),
                ),
              ),
              GestureDetector(
                onTap: () => _saveField(p, key, ctrl.text, label, setModalState),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: Colors.green, size: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveField(dynamic p, String key, String valStr, String label, StateSetter setModalState) async {
    final val = double.tryParse(valStr) ?? 0;
    try {
       await _client.from('profiles').update({key: val}).eq('id', p['id']);
       setModalState(() => p[key] = val);
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('TRIP UPDATE: $label SYNCED'), backgroundColor: Colors.black));
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('OFFICIAL FAILURE: $e'), backgroundColor: Colors.red));
    }
  }

  void _delegateTask(dynamic p) {
    Navigator.pop(context); // Close detail modal
    Navigator.pushNamed(context, '/admin_tasks', arguments: p['id']); 
  }

  Future<void> _removeEmployee(String userId, String? userName) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('REMOVE FROM STAFF?'),
        content: Text('Are you sure you want to demote ${userName ?? 'this user'}? They will immediately lose access to the Employee Dashboard, Group Details, and Staff Group Chats. Their role will revert to a standard Traveler.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('REMOVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _client.from('profiles').update({
        'role': 'user',
        'can_manage_trips': false,
      }).eq('id', userId);
      
      if (mounted) {
        Navigator.pop(context); // close the detail modal
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('STAFF REMOVED. Member demoted to standard user.'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('FAILED TO TERMINATE: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _taskAnalytics(dynamic p) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _client.from('employee_tasks').select().eq('assignee_id', p['id']),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: LinearProgressIndicator());
        final tasks = snapshot.data!;
        final pending = tasks.where((t) => t['status']?.toString().toLowerCase() == 'pending').length;
        final active = tasks.where((t) => t['status']?.toString().toLowerCase() == 'in progress').length;
        final done = tasks.where((t) => t['status']?.toString().toLowerCase() == 'completed').length;
        
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Row(
          children: [
            _miniStat('PENDING', '$pending', isDark),
            _miniStat('ACTIVE', '$active', isDark),
            _miniStat('DONE', '$done', isDark),
          ],
        );
      },
    );
  }

  Widget _miniStat(String label, String val, bool isDark) {
    return Expanded(
      child: Column(
        children: [
          Text(val, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
          Text(label, style: const TextStyle(fontSize: 7, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _iconBox(IconData icon, Color c) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: c, size: 18),
    );
  }

  void _processPayout(dynamic p) async {
    final double salary = double.tryParse((p['salary'] ?? 0).toString()) ?? 0;
    final double allowance = double.tryParse((p['allowance'] ?? 0).toString()) ?? 0;
    final int unpaid = int.tryParse((p['unpaid_leaves'] ?? 0).toString()) ?? 0;
    
    // Logic: Deduct 1/30 of salary for each unpaid leave
    final double deduction = (salary / 30) * unpaid;
    final double netPayout = (salary + allowance - deduction).clamp(0, double.infinity);

    if (netPayout <= 0 && salary > 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Insufficient payout balance for this staff member.')));
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('PROCESS PAYOUT'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _payoutRow('Base Salary', salary),
            _payoutRow('Allowance', allowance),
            _payoutRow('Leave Deductions', -deduction, isRed: true),
            const Divider(),
            _payoutRow('NET PAYOUT', netPayout, isBold: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('ABORT')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('CONFIRM PAYOUT')),
        ],
      )
    );

    if (ok == true) {
      try {
        await _client.from('payment_logs').insert({
          'user_id': p['id'],
          'amount': netPayout,
          'is_incoming': false,
          'payment_type': 'SALARY',
          'created_at': DateTime.now().toIso8601String(),
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PAYOUT PROCESSED SUCCESSFULLY.')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PAYOUT FAILED: $e')));
      }
    }
  }

  Widget _payoutRow(String label, double val, {bool isRed = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
          Text('₹${val.toInt()}', style: TextStyle(fontWeight: FontWeight.bold, color: isRed ? Colors.red : (isBold ? Colors.black : Colors.green), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color bg, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(15)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _attendanceStats(dynamic p) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _statBox('PAID', p['paid_leaves'] ?? 0, Colors.green),
        _statBox('UNPAID', p['unpaid_leaves'] ?? 0, Colors.red),
        _statBox('HALF', p['half_days'] ?? 0, Colors.orange),
        _statBox('OFF', p['off_duty_days'] ?? 0, Colors.blueGrey),
      ],
    );
  }

  Widget _statBox(String label, dynamic val, Color color) {
    return Container(
      width: 70,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.1))),
      child: Column(
        children: [
          Text(val.toString(), style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14)),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 8, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showAddPersonnelModal() {
    final emailCtrl = TextEditingController();
    String? selectedRole = 'staff';
    bool isSearching = false;
    Map<String, dynamic>? foundUser;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(30, 30, 30, MediaQuery.of(ctx).viewInsets.bottom + 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('ADD NEW STAFF', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
              const SizedBox(height: 24),
              TextField(
                controller: emailCtrl,
                decoration: InputDecoration(
                  labelText: 'USER EMAIL',
                  labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                  suffixIcon: IconButton(
                    icon: isSearching ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search),
                    onPressed: () async {
                      if (emailCtrl.text.isEmpty) return;
                      setModalState(() => isSearching = true);
                      try {
                        final res = await _client.from('profiles').select().eq('email', emailCtrl.text.trim()).maybeSingle();
                        setModalState(() => foundUser = res);
                      } finally {
                        setModalState(() => isSearching = false);
                      }
                    },
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
              if (foundUser != null) ...[
                const SizedBox(height: 24),
                _buildFoundUserCard(foundUser!),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: InputDecoration(
                    labelText: 'ADD AS...',
                    labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  items: ['admin', 'guide', 'staff'].map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase()))).toList(),
                  onChanged: (v) => setModalState(() => selectedRole = v),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await _client.from('profiles').update({'role': selectedRole}).eq('id', foundUser!['id']);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('STAFF ADDED SUCCESSFULLY.'), backgroundColor: Colors.green));
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('STAFF NOT ADDED: $e'), backgroundColor: Colors.red));
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    child: const Text('CONFIRM TRIP', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ),
              ] else if (isSearching == false && emailCtrl.text.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text('No asset found with this identifier.', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFoundUserCard(Map<String, dynamic> u) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50, 
        borderRadius: BorderRadius.circular(15), 
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100)
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundImage: u['avatar_url'] != null ? NetworkImage(u['avatar_url']) : null, child: u['avatar_url'] == null ? const Icon(Icons.person) : null),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(u['full_name']?.toUpperCase() ?? 'UNKNOWN USER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
            Text(u['email'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ])),
        ],
      ),
    );
  }
}
