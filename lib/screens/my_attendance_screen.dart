import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class MyAttendanceScreen extends StatefulWidget {
  const MyAttendanceScreen({super.key});

  @override
  State<MyAttendanceScreen> createState() => _MyAttendanceScreenState();
}

class _MyAttendanceScreenState extends State<MyAttendanceScreen> {
  final _client = Supabase.instance.client;
  DateTime _currentMonth = DateTime.now();
  Map<int, String> _attendanceMap = {};
  Map<String, dynamic>? _metrics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAttendance();
  }

  Future<void> _fetchAttendance() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    
    setState(() => _isLoading = true);
    try {
      final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
      final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
      
      final res = await _client.from('attendance_logs')
          .select()
          .eq('user_id', user.id)
          .gte('date', firstDay.toIso8601String())
          .lte('date', lastDay.toIso8601String());

      Map<int, String> newMap = {};
      for (var a in res) {
        final date = DateTime.parse(a['date']);
        newMap[date.day] = a['status'] ?? 'present';
      }

      // AGGREGATE ALL TIME METRICS for historical accuracy
      final allLogs = await _client.from('attendance_logs').select('status').eq('user_id', user.id);
      int paid = 0, unpaid = 0, half = 0, off = 0;
      for (var l in (allLogs as List)) {
         final s = l['status']?.toString().toLowerCase();
         if (s == 'paid_leave') paid++;
         else if (s == 'leave' || s == 'unpaid_leave') unpaid++;
         else if (s == 'half_day') half++;
         else if (s == 'off_duty') off++;
      }

      if (mounted) setState(() { 
        _attendanceMap = newMap; 
        _metrics = {
           'paid_leaves': paid,
           'unpaid_leaves': unpaid,
           'half_days': half,
           'off_duty_days': off,
        };
        _isLoading = false; 
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('MY ATTENDANCE RECORD', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white, letterSpacing: 1.5)),
        backgroundColor: const Color(0xFFD32F2F),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildMonthHeader(),
          _buildMetrics(),
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
      color: const Color(0xFFD32F2F),
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

  Widget _buildMetrics() {
    int paid = _metrics?['paid_leaves'] ?? 0;
    int unpaid = _metrics?['unpaid_leaves'] ?? 0;
    int halfDay = _metrics?['half_days'] ?? 0;
    int offDuty = _metrics?['off_duty_days'] ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      color: Theme.of(context).cardColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _metricItem('PAID', '$paid', Colors.lightGreen),
          _metricItem('UNPAID', '$unpaid', Colors.red),
          _metricItem('HALF', '$halfDay', Colors.orange),
          _metricItem('OFF', '$offDuty', Colors.blue),
        ],
      ),
    );
  }

  Widget _metricItem(String label, String val, Color color) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey)),
      ],
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

        return Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Text('$day', style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 14)),
        );
      },
    );
  }

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
