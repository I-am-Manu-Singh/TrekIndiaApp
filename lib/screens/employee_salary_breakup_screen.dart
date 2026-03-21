import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';

class EmployeeSalaryBreakupScreen extends StatefulWidget {
  final dynamic profileOverride;
  const EmployeeSalaryBreakupScreen({super.key, this.profileOverride});

  @override
  State<EmployeeSalaryBreakupScreen> createState() => _EmployeeSalaryBreakupScreenState();
}

class _EmployeeSalaryBreakupScreenState extends State<EmployeeSalaryBreakupScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  DateTime _currentMonth = DateTime.now();
  Map<String, dynamic>? _profile;
  List<dynamic> _payoutHistory = [];
  Map<String, int> _attendanceStats = {'present': 0, 'half': 0, 'unpaid': 0, 'paid_leave': 0, 'off_duty': 0};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final user = _client.auth.currentUser;
    if (user == null && widget.profileOverride == null) return;

    final profileId = widget.profileOverride != null ? widget.profileOverride['id'] : user!.id;

    try {
      final pRes = await _client.from('profiles').select().eq('id', profileId).maybeSingle();
      
      // Fetch attendance for the selected month to get accurate counts
      final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
      final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
      
      final attRes = await _client.from('attendance_logs')
          .select()
          .eq('user_id', profileId)
          .gte('date', firstDay.toIso8601String())
          .lte('date', lastDay.toIso8601String());

      Map<String, int> stats = {'present': 0, 'half': 0, 'unpaid': 0, 'paid_leave': 0, 'off_duty': 0};
      for (var a in attRes) {
        final s = a['status']?.toString().toLowerCase() ?? '';
        if (s == 'present') stats['present'] = (stats['present'] ?? 0) + 1;
        else if (s == 'half_day') stats['half'] = (stats['half'] ?? 0) + 1;
        else if (s == 'leave' || s == 'unpaid_leave') stats['unpaid'] = (stats['unpaid'] ?? 0) + 1;
        else if (s == 'paid_leave') stats['paid_leave'] = (stats['paid_leave'] ?? 0) + 1;
        else if (s == 'off_duty') stats['off_duty'] = (stats['off_duty'] ?? 0) + 1;
      }

      final hRes = await _client.from('payment_logs')
          .select()
          .eq('user_id', profileId)
          .eq('payment_type', 'SALARY')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _profile = pRes;
          _payoutHistory = hRes;
          _attendanceStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile ?? widget.profileOverride;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('PAYROLL TERMINAL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildMonthNavigator(),
              const SizedBox(height: 24),
              if (p != null) ...[
                _buildCurrentBreakup(p),
                const SizedBox(height: 32),
                const Text('OFFICIAL PAYROLL HISTORY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.grey, letterSpacing: 1)),
                const SizedBox(height: 16),
                ..._payoutHistory.map((h) => _buildHistoryCard(h)).toList(),
                if (_payoutHistory.isEmpty) _buildEmptyHistory(),
              ],
            ],
          ),
    );
  }

  Widget _buildMonthNavigator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(15)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 16),
            onPressed: () { setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1)); _loadData(); }
          ),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _currentMonth,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                initialDatePickerMode: DatePickerMode.year,
              );
              if (picked != null) {
                setState(() => _currentMonth = DateTime(picked.year, picked.month));
                _loadData();
              }
            },
            child: Column(
              children: [
                Text(DateFormat('MMMM yyyy').format(_currentMonth).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white, letterSpacing: 1.5)),
                const Text('OPERATIONAL CYCLE', style: TextStyle(fontSize: 8, color: Colors.white38, fontWeight: FontWeight.bold, letterSpacing: 2)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
            onPressed: () { setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1)); _loadData(); }
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentBreakup(dynamic p) {
    final double salary = double.tryParse((p['salary'] ?? 0).toString()) ?? 0;
    final double dailyAllowance = double.tryParse((p['allowance'] ?? 0).toString()) ?? 0;
    final double profileAdvances = double.tryParse((p['advances'] ?? 0).toString()) ?? 0;
    final double profileDues = double.tryParse((p['dues_penalty'] ?? 0).toString()) ?? 0;

    final int daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final int presentCount = _attendanceStats['present'] ?? 0;
    final int offDutyCount = _attendanceStats['off_duty'] ?? 0;
    final int paidLeaveCount = _attendanceStats['paid_leave'] ?? 0;
    final int halfDayCount = _attendanceStats['half'] ?? 0;
    final int unpaidCount = _attendanceStats['unpaid'] ?? 0;

    // Calculation: (salary / daysInMonth) is daily rate
    final double dailyRate = salary / daysInMonth;
    final double lopDays = unpaidCount + (halfDayCount * 0.5);
    final double lopsPrice = lopDays * dailyRate;
    
    // Monthly Allowance Calculation: presentDays * dailyAllowance
    // Only 'present' days get the active field allowance
    final double totalAllowance = presentCount * dailyAllowance;

    final double net = (salary + totalAllowance - lopsPrice - profileAdvances - profileDues).clamp(0, double.infinity);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FadeInDown(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('NET DISBURSEMENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                    Text('₹${net.toInt()}', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
                  child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.green, size: 28),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _statGrid(daysInMonth, presentCount, offDutyCount, halfDayCount, unpaidCount, paidLeaveCount),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            _breakupRow('Base Salary (${daysInMonth}d cycle)', '₹${salary.toInt()}', Icons.payments_outlined),
            _breakupRow('Field Allowance (${presentCount}d active)', '₹${totalAllowance.toInt()}', Icons.add_chart_outlined, color: Colors.blueAccent),
            _breakupRow('Attendance Deductions (${lopDays}d)', '-₹${lopsPrice.toInt()}', Icons.event_busy_outlined, color: Colors.orange),
            if (profileAdvances > 0) _breakupRow('Company Advances', '-₹${profileAdvances.toInt()}', Icons.money_off_csred_outlined, color: Colors.redAccent),
            if (profileDues > 0) _breakupRow('Tactical Dues/Penalty', '-₹${profileDues.toInt()}', Icons.gavel_outlined, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('CONFIRMED PAYOUT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                Text('₹${net.toInt()}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.green)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statGrid(int total, int present, int off, int half, int unpaid, int paidL) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          Row(
            children: [
              _statItem('CYCLE', '$total', Colors.grey),
              _statItem('PRESENT', '$present', Colors.green),
              _statItem('OFF DUTY', '$off', Colors.blue),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statItem('PAID LV', '$paidL', Colors.lightGreen),
              _statItem('HALF DAY', '$half', Colors.orange),
              _statItem('UNPAID', '$unpaid', Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String val, Color c) {
    return Expanded(
      child: Column(
        children: [
          Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: c)),
          Text(label, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _breakupRow(String label, String val, IconData icon, {Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color ?? Colors.grey),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color ?? (isDark ? Colors.white : Colors.black87))),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(dynamic h) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final date = DateFormat('MMMM yyyy').format(DateTime.parse(h['created_at']));
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_outlined, color: Colors.green, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                const Text('Disbursed via HQ Bank Transfer', style: TextStyle(fontSize: 9, color: Colors.grey)),
              ],
            ),
          ),
          Text('₹${(h['amount'] as num).toInt()}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.green)),
        ],
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.history_toggle_off_outlined, size: 48, color: Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 12),
            const Text('No historical payout logs found.', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
