import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AdminAttendanceScreen extends StatefulWidget {
  final String userId;
  final String userName;
  const AdminAttendanceScreen({super.key, required this.userId, required this.userName});

  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen> {
  final _client = Supabase.instance.client;
  DateTime _currentMonth = DateTime.now();
  Map<int, String> _attendanceMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAttendance();
  }

  Future<void> _fetchAttendance() async {
    setState(() => _isLoading = true);
    try {
      final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
      final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
      
      final res = await _client.from('attendance_logs')
          .select()
          .eq('user_id', widget.userId)
          .gte('date', firstDay.toIso8601String())
          .lte('date', lastDay.toIso8601String());

      Map<int, String> newMap = {};
      for (var a in res) {
        final date = DateTime.parse(a['date']);
        newMap[date.day] = a['status'] ?? 'present';
      }

      if (mounted) setState(() { _attendanceMap = newMap; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _markAttendance(int day, String status) async {
    final date = DateTime(_currentMonth.year, _currentMonth.month, day);
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    
    try {
      await _client.from('attendance_logs').upsert({
        'user_id': widget.userId,
        'date': dateStr,
        'status': status.toLowerCase(),
      });
      
      // RECALCULATE AGGREGATE METRICS FOR PROFILE
      // Calculate All-Time Stats from Logs for Reliability
      final logs = await _client.from('attendance_logs').select('status').eq('user_id', widget.userId);
      
      int paid = 0, unpaid = 0, half = 0, off = 0;
      for (var log in (logs as List)) {
        final s = log['status']?.toString().toLowerCase() ?? '';
        if (s == 'paid_leave') paid++;
        else if (s == 'leave' || s == 'unpaid_leave') unpaid++;
        else if (s == 'half_day') half++;
        else if (s == 'off_duty') off++;
      }
      
      await _client.from('profiles').update({
        'paid_leaves': paid,
        'unpaid_leaves': unpaid,
        'half_days': half,
        'off_duty_days': off,
      }).eq('id', widget.userId);

      _fetchAttendance();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Trek Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('${widget.userName.toUpperCase()} ATTENDANCE', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white, letterSpacing: 1.5)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildMonthHeader(),
          Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildCalendarGrid()),
          _buildLegend(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildMonthHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 16), onPressed: () { setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1)); _fetchAttendance(); }),
          Text(DateFormat('MMMM yyyy').format(_currentMonth).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white, letterSpacing: 2)),
          IconButton(icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16), onPressed: () { setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1)); _fetchAttendance(); }),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 12, crossAxisSpacing: 12),
      itemCount: daysInMonth,
      itemBuilder: (context, index) {
        int day = index + 1;
        String? status = _attendanceMap[day];
        Color color = _getStatusColor(status);

        return GestureDetector(
          onTap: () => _showStatusPicker(day),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Text('$day', style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 14)),
          ),
        );
      },
    );
  }

  void _showStatusPicker(int day) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      backgroundColor: Theme.of(context).cardColor,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('MARK ATTENDANCE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
            const SizedBox(height: 12),
            Text('DATE: ${DateFormat('MMM dd').format(DateTime(_currentMonth.year, _currentMonth.month, day))}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 24),
            _statusPickerTile(day, 'PRESENT', 'present', Colors.green),
            _statusPickerTile(day, 'PAID LEAVE', 'paid_leave', Colors.lightGreen),
            _statusPickerTile(day, 'UNPAID LEAVE', 'leave', Colors.red),
            _statusPickerTile(day, 'HALF DAY', 'half_day', Colors.orange),
            _statusPickerTile(day, 'OFF DUTY', 'off_duty', Colors.blue),
            _statusPickerTile(day, 'NONE', 'none', Colors.grey),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _statusPickerTile(int day, String label, String value, Color color) {
    return ListTile(
      leading: CircleAvatar(radius: 6, backgroundColor: color),
      title: Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
      onTap: () { 
        Navigator.pop(context); 
        _markAttendance(day, value); 
      },
    );
  }
  
  // Actually, I need to pass the day to the list tile or local function
  // Re-implementing _statusListTile properly inside _showStatusPicker

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'present': return Colors.green;
      case 'paid_leave': return Colors.lightGreen;
      case 'leave': return Colors.red;
      case 'unpaid_leave': return Colors.red;
      case 'half_day': return Colors.orange;
      case 'off_duty': return Colors.blue;
      default: return Colors.grey;
    }
  }

  Widget _buildLegend() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legendItem('PRESENT', Colors.green),
            const SizedBox(width: 16),
            _legendItem('LEAVE', Colors.red),
            const SizedBox(width: 16),
            _legendItem('HALF DAY', Colors.orange),
            const SizedBox(width: 16),
            _legendItem('OFF-DUTY', Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey)),
      ],
    );
  }
}
