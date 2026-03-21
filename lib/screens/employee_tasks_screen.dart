import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import '../widgets/user_avatar.dart';

class EmployeeTasksScreen extends StatefulWidget {
  const EmployeeTasksScreen({super.key});

  @override
  State<EmployeeTasksScreen> createState() => _EmployeeTasksScreenState();
}

class _EmployeeTasksScreenState extends State<EmployeeTasksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _tasks = [];
  String? _myRole;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAuthAndTasks();
  }

  Future<void> _loadAuthAndTasks() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    
    final prof = await _client.from('profiles').select('role').eq('id', user.id).maybeSingle();
    _myRole = prof?['role']?.toString().toLowerCase();
    
    await _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    setState(() => _isLoading = true);
    try {
       final user = _client.auth.currentUser;
       var query = _client.from('employee_tasks').select('*, assignee:profiles!assignee_id(full_name, avatar_url)');
       
       // If not admin, only show my tasks
       if (_myRole != 'admin') {
         query = query.eq('assignee_id', user!.id);
       }
       
       final res = await query.order('created_at', ascending: false);
       if (mounted) {
         setState(() {
           _tasks = res;
           _isLoading = false;
         });
       }
    } catch (e) {
       if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateTaskStatus(String taskId, String newStatus) async {
    try {
      await _client.from('employee_tasks').update({'status': newStatus, 'updated_at': DateTime.now().toIso8601String()}).eq('id', taskId);
      _fetchTasks();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Task status updated to $newStatus')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update Error: $e'), backgroundColor: Colors.red));
    }
  }

  void _showCreateTask() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String priority = 'Medium';
    String? selectedAssignee;
    List<dynamic> staffList = [];
    bool loadingStaff = true;

    Future<void> fetchStaff(StateSetter setModalState) async {
       final res = await _client.from('profiles').select().neq('role', 'user');
       setModalState(() {
         staffList = res;
         loadingStaff = false;
       });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            padding: EdgeInsets.fromLTRB(30, 30, 30, MediaQuery.of(ctx).viewInsets.bottom + 30),
            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DELEGATE TREK TASK', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1)),
                const SizedBox(height: 24),
                _modalInput(titleCtrl, 'Task Headline...'),
                const SizedBox(height: 16),
                _modalInput(descCtrl, 'Detailed Trek briefing...', lines: 3),
                const SizedBox(height: 16),
                Text('ASSIGN TO PERSONNEL', style: TextStyle(color: isDark ? Colors.white38 : Colors.grey, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 8),
                loadingStaff 
                  ? const CircularProgressIndicator()
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                      child: DropdownButton<String>(
                        value: selectedAssignee,
                        hint: Text('Select Personnel', style: TextStyle(color: isDark ? Colors.white24 : Colors.grey, fontSize: 13)),
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: staffList.map((s) => DropdownMenuItem<String>(
                          value: s['id'].toString(),
                          child: Text(s['full_name'] ?? 'Staff', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13)),
                        )).toList(),
                        onChanged: (v) => setModalState(() => selectedAssignee = v),
                      ),
                    ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 55,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (titleCtrl.text.isEmpty || selectedAssignee == null) return;
                      await _client.from('employee_tasks').insert({
                        'title': titleCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'assignee_id': selectedAssignee,
                        'created_by_id': _client.auth.currentUser?.id,
                        'status': 'Pending',
                        'priority': priority
                      });
                      Navigator.pop(ctx);
                      _fetchTasks();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    child: const Text('AUTHORIZE DELEGATION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          );
        }
      )
    );
  }

  Widget _modalInput(TextEditingController ctrl, String hint, {int lines = 1}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: ctrl,
      maxLines: lines,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.grey),
        filled: true, fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('TREK TASK COMMAND', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
        backgroundColor: Colors.black, foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
          indicatorColor: Colors.blueAccent,
          isScrollable: false,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [Tab(text: 'PENDING'), Tab(text: 'ACTIVE'), Tab(text: 'DONE'), Tab(text: 'STATS')],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: _tabController,
            children: [
              _buildTaskList('Pending'),
              _buildTaskList('In Progress'),
              _buildTaskList('Completed'),
              _buildAnalyticsTab(),
            ],
          ),
      floatingActionButton: _myRole == 'admin' ? FloatingActionButton(
        onPressed: _showCreateTask,
        backgroundColor: Colors.black,
        child: const Icon(Icons.add, color: Colors.white),
      ) : null,
    );
  }

  Widget _buildTaskList(String status) {
    final filtered = _tasks.where((t) => t['status'] == status).toList();
    if (filtered.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.assignment_turned_in_outlined, size: 50, color: Colors.grey), const SizedBox(height: 16), Text('No $status tasks in terminal.', style: const TextStyle(color: Colors.grey))]));
    
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: filtered.length,
      itemBuilder: (context, i) => _buildTaskCard(filtered[i]),
    );
  }

  Widget _buildTaskCard(dynamic t) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _priorityChip(t['priority'] ?? 'Medium'),
              Text(DateFormat('dd MMM').format(DateTime.parse(t['created_at'])), style: const TextStyle(fontSize: 8, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 12),
          Text(t['title'], style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 4),
          Text(t['description'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12, height: 1.4)),
          const SizedBox(height: 20),
          Row(
            children: [
               UserAvatar(
                 imageUrl: t['assignee']?['avatar_url'],
                 name: t['assignee']?['full_name'],
                 radius: 12,
               ),
               const SizedBox(width: 8),
               Text(t['assignee']?['full_name'] ?? 'Unassigned', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
               const Spacer(),
               if (t['status'] != 'Completed') _statusBtn(t),
               if (t['status'] == 'Completed') const Icon(Icons.check_circle, color: Colors.green, size: 20),
            ],
          )
        ],
      ),
    );
  }

  Widget _statusBtn(dynamic t) {
    String next = t['status'] == 'Pending' ? 'In Progress' : 'Completed';
    return ElevatedButton(
      onPressed: () => _updateTaskStatus(t['id'], next),
      style: ElevatedButton.styleFrom(backgroundColor: Colors.black, minimumSize: const Size(80, 30), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      child: Text(next.toUpperCase(), style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  Widget _priorityChip(String p) {
    Color c = p == 'Urgent' ? Colors.red : (p == 'High' ? Colors.orange : Colors.blue);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(p.toUpperCase(), style: TextStyle(color: c, fontSize: 8, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildAnalyticsTab() {
    final pending = _tasks.where((t) => t['status'] == 'Pending').length;
    final active = _tasks.where((t) => t['status'] == 'In Progress').length;
    final done = _tasks.where((t) => t['status'] == 'Completed').length;
    final total = _tasks.length;
    final double percent = total == 0 ? 0 : (done / total);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(30)),
          child: Column(
            children: [
              const Text('TERMINAL EFFICIENCY', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
              const SizedBox(height: 12),
              Text('${(percent * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900)),
              const Text('COMPLETION RATE', style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              LinearProgressIndicator(value: percent, backgroundColor: Colors.white12, color: Colors.blueAccent, minHeight: 8, borderRadius: BorderRadius.circular(4)),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(child: _statCard('PENDING', pending, Colors.orange, isDark)),
            const SizedBox(width: 16),
            Expanded(child: _statCard('ACTIVE', active, Colors.blue, isDark)),
            const SizedBox(width: 16),
            Expanded(child: _statCard('DONE', done, Colors.green, isDark)),
          ],
        )
      ],
    );
  }

  Widget _statCard(String label, int val, Color c, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100)),
      child: Column(children: [Text('$val', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: c)), Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey))]),
    );
  }
}
