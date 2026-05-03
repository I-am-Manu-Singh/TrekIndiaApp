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
  String _searchQuery = "";

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
                Text('DELEGATE TRIP TASK', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1)),
                const SizedBox(height: 24),
                _modalInput(titleCtrl, 'Task Headline...'),
                const SizedBox(height: 16),
                _modalInput(descCtrl, 'Detailed Trip briefing...', lines: 3),
                const SizedBox(height: 16),
                Text('ASSIGN TO STAFF', style: TextStyle(color: isDark ? Colors.white38 : Colors.grey, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 8),
                loadingStaff 
                  ? const CircularProgressIndicator()
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                      child: DropdownButton<String>(
                        value: selectedAssignee,
                        hint: Text('Select Employee', style: TextStyle(color: isDark ? Colors.white24 : Colors.grey, fontSize: 13)),
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
    
    final pending = _tasks.where((t) => t['status'] == 'Pending').length;
    final active = _tasks.where((t) => t['status'] == 'In Progress').length;
    final done = _tasks.where((t) => t['status'] == 'Completed').length;
    final total = _tasks.length;
    final double percent = total == 0 ? 0 : (done / total);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('TASK CONTROL CENTER', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2)),
        backgroundColor: const Color(0xFFD32F2F), 
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // Fixed Stats Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFD32F2F), Color(0xFFB71C1C), Color(0xFF880E4F)],
                  ),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))
                  ]
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _topStatItem('PENDING', pending, Colors.orangeAccent),
                        _topStatItem('ACTIVE', active, Colors.blueAccent),
                        _topStatItem('DONE', done, Colors.greenAccent),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('TOTAL EFFICIENCY', style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              Text('${(percent * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percent,
                              backgroundColor: Colors.white12,
                              color: Colors.white,
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Container(
                  height: 45,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search tasks...',
                      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                      border: InputBorder.none,
                      icon: Icon(Icons.search, size: 18, color: Colors.grey.shade400),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Tabs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      color: isDark ? Colors.blueAccent : Colors.black,
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'PENDING'),
                      Tab(text: 'ACTIVE'),
                      Tab(text: 'DONE'),
                      Tab(text: 'ALL'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Task List Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTaskList('Pending'),
                    _buildTaskList('In Progress'),
                    _buildTaskList('Completed'),
                    _buildTaskList('All'),
                  ],
                ),
              ),
            ],
          ),
      floatingActionButton: _myRole == 'admin' ? FloatingActionButton(
        onPressed: _showCreateTask,
        backgroundColor: Colors.black,
        child: const Icon(Icons.add, color: Colors.white),
      ) : null,
    );
  }

  Widget _topStatItem(String label, int val, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text('$val', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
            child: Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList(String status) {
    var filtered = status == 'All' ? _tasks : _tasks.where((t) => t['status'] == status).toList();
    
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((t) => 
        (t['title']?.toString().toLowerCase().contains(_searchQuery) ?? false) ||
        (t['description']?.toString().toLowerCase().contains(_searchQuery) ?? false)
      ).toList();
    }
    if (filtered.isEmpty) {
      return FadeIn(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, 
            children: [
              Icon(Icons.assignment_turned_in_outlined, size: 40, color: Colors.grey.withOpacity(0.3)), 
              const SizedBox(height: 16), 
              Text('No $status tasks', style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500))
            ]
          ),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: filtered.length,
      itemBuilder: (context, i) => FadeInUp(
        duration: Duration(milliseconds: 300 + (i * 100)),
        child: _buildTaskCard(filtered[i]),
      ),
    );
  }

  Widget _buildTaskCard(dynamic t) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = t['status'] == 'Pending' ? Colors.orange : (t['status'] == 'In Progress' ? Colors.blue : Colors.green);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor, 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _priorityChip(t['priority'] ?? 'Medium'),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(t['status'].toString().toUpperCase(), style: TextStyle(color: statusColor, fontSize: 7, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Text(DateFormat('dd MMM').format(DateTime.parse(t['created_at'])), style: const TextStyle(fontSize: 8, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 12),
          Text(t['title'], style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
          if (t['description'] != null && t['description'].toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(t['description'], style: const TextStyle(color: Colors.grey, fontSize: 11, height: 1.4)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
               UserAvatar(
                 imageUrl: t['assignee']?['avatar_url'],
                 name: t['assignee']?['full_name'],
                 radius: 12,
               ),
               const SizedBox(width: 8),
               Text(t['assignee']?['full_name'] ?? 'Unassigned', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54)),
               const Spacer(),
               if (t['status'] != 'Completed') _statusBtn(t),
               if (t['status'] == 'Completed') const Icon(Icons.check_circle, color: Colors.green, size: 22),
            ],
          )
        ],
      ),
    );
  }

  Widget _statusBtn(dynamic t) {
    String next = t['status'] == 'Pending' ? 'In Progress' : 'Completed';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _updateTaskStatus(t['id'], next),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))]
          ),
          child: Text(next.toUpperCase(), style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _priorityChip(String p) {
    Color c = p == 'Urgent' ? Colors.red : (p == 'High' ? Colors.orange : Colors.blue);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fiber_manual_record, size: 6, color: c),
          const SizedBox(width: 4),
          Text(p.toUpperCase(), style: TextStyle(color: c, fontSize: 7, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

