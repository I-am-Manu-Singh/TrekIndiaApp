import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';

class PaymentLedgerScreen extends StatefulWidget {
  const PaymentLedgerScreen({super.key});

  @override
  State<PaymentLedgerScreen> createState() => _PaymentLedgerScreenState();
}

class _PaymentLedgerScreenState extends State<PaymentLedgerScreen>
    with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _transactions = [];
  double _totalSpent = 0;
  String _role = 'user';

  // Reward points
  int _rewardBalance = 0;
  List<Map<String, dynamic>> _rewardLedger = [];

  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _fetchAll();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    await Future.wait([_fetchLedger(), _fetchRewardLedger()]);
  }

  Future<void> _fetchLedger() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    setState(() => _isLoading = true);

    try {
      final profile = await _client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      final bool isAdmin = (profile?['role'] ?? 'user') == 'admin';
      if (mounted) _role = profile?['role'] ?? 'user';

      var bQuery = _client.from('bookings').select();
      if (!isAdmin) bQuery = bQuery.eq('user_id', user.id);
      final bookingsResRaw =
          await bQuery.order('booking_date', ascending: false);

      var rQuery = _client.from('user_rentals').select();
      if (!isAdmin) rQuery = rQuery.eq('user_id', user.id);
      final rentalsResRaw =
          await rQuery.order('issue_date', ascending: false);

      var pQuery = _client.from('payment_logs').select();
      if (!isAdmin) pQuery = pQuery.eq('user_id', user.id);
      final logsResRaw =
          await pQuery.order('created_at', ascending: false);

      final allTrips = await _client.from('trips').select('id, title');
      final allProfiles =
          await _client.from('profiles').select('id, full_name');
      final allGears = await _client.from('gears').select('id, name');

      final tripMap = {for (var t in allTrips) t['id']: t['title']};
      final profileMap = {
        for (var p in allProfiles) p['id']: p['full_name']
      };
      final gearMap = {for (var g in allGears) g['id']: g['name']};

      List<dynamic> combined = [];
      double balance = 0;

      for (var b in bookingsResRaw as List) {
        double amt = double.tryParse(b['paid_amount'].toString()) ?? 0;
        bool isIncome = isAdmin;
        balance += isIncome ? amt : -amt;
        final uName = profileMap[b['user_id']] ?? 'User';
        final tTitle = tripMap[b['trip_id']] ?? 'Trip Payment';
        combined.add({
          'title': (isAdmin ? '[$uName] ' : '') + tTitle,
          'amount': amt,
          'date': b['booking_date'],
          'type': 'Trip',
          'is_income': isIncome,
          'icon': Icons.terrain,
          'color': Colors.blue,
        });
      }

      for (var r in rentalsResRaw as List) {
        double amt = double.tryParse(r['total_price'].toString()) ?? 0;
        bool isIncome = isAdmin;
        balance += isIncome ? amt : -amt;
        final uName = profileMap[r['user_id']] ?? 'User';
        final gName = gearMap[r['gear_id']] ?? 'Rental Item';
        combined.add({
          'title': (isAdmin ? '[$uName] ' : '') + 'Gear: $gName',
          'amount': amt,
          'date': r['issue_date'],
          'type': 'Gear',
          'is_income': isIncome,
          'icon': Icons.inventory_2,
          'color': Colors.orange,
        });
      }

      for (var l in logsResRaw as List) {
        double amt = double.tryParse(l['amount'].toString()) ?? 0;
        final bool isLogIncoming = l['is_incoming'] == true;
        bool isIncome = isAdmin ? isLogIncoming : !isLogIncoming;
        balance += isIncome ? amt : -amt;
        final uName = profileMap[l['user_id']] ?? 'Staff';
        combined.add({
          'title': (isAdmin ? '[$uName] ' : '') +
              (l['payment_type'] ?? 'Trip Payout'),
          'amount': amt,
          'date': l['created_at'],
          'type': l['payment_type'] ?? 'Finance',
          'is_income': isIncome,
          'icon': (l['payment_type'] == 'SALARY')
              ? Icons.payments
              : Icons.account_balance_wallet,
          'color': (l['payment_type'] == 'SALARY')
              ? Colors.purple
              : Colors.teal,
        });
      }

      combined.sort((a, b) => DateTime.parse(b['date'].toString())
          .compareTo(DateTime.parse(a['date'].toString())));

      if (mounted) {
        setState(() {
          _transactions = combined;
          _totalSpent = balance;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchRewardLedger() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      final rows = await _client
          .from('reward_ledger')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      int balance = 0;
      final entries = <Map<String, dynamic>>[];
      for (final row in (rows as List)) {
        final pts = int.tryParse((row['points'] ?? 0).toString()) ?? 0;
        final type = row['type']?.toString() ?? 'credit';
        final isCredit = type == 'credit';
        balance += isCredit ? pts : -pts;
        entries.add({
          'points': pts,
          'type': type,
          'description': row['description'] ?? '',
          'date': row['created_at'],
        });
      }
      if (mounted) {
        setState(() {
          _rewardBalance = balance < 0 ? 0 : balance;
          _rewardLedger = entries;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF09090B) : Colors.grey[50],
      appBar: AppBar(
        title: const Text('MY WALLET',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white)),
        backgroundColor: const Color(0xFFD32F2F),
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
          tabs: const [
            Tab(text: 'TRANSACTIONS'),
            Tab(text: '🏆 REWARDS'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildTransactionsTab(isDark),
                _buildRewardsTab(isDark),
              ],
            ),
    );
  }

  // ─── TRANSACTIONS TAB ─────────────────────────────────────────────────────
  Widget _buildTransactionsTab(bool isDark) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildWalletHeader(),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TRIP TRANSACTIONS',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white38 : Colors.grey,
                      letterSpacing: 1.2)),
              const SizedBox(height: 16),
              ..._transactions
                  .map((tx) => _buildTransactionCard(tx))
                  .toList(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWalletHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _totalSpent >= 0
              ? [const Color(0xFF388E3C), const Color(0xFF1B5E20)]
              : [const Color(0xFFC62828), const Color(0xFFB71C1C)],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
              color: (_totalSpent >= 0
                      ? const Color(0xFF1B5E20)
                      : const Color(0xFFB71C1C))
                  .withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              _role == 'admin'
                  ? 'OFFICIAL FISCAL BALANCE'
                  : 'TOTAL TRIP INVESTMENT',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1)),
          const SizedBox(height: 12),
          Text(
              '${_totalSpent >= 0 ? "+" : "-"}₹${_totalSpent.abs().toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                  child: _headerButton(
                      Icons.workspace_premium_rounded, 'Rewards',
                      () => _tabCtrl.animateTo(1))),
              const SizedBox(width: 16),
              Expanded(
                  child: _headerButton(Icons.menu_book, 'Passbook', () {})),
            ],
          )
        ],
      ),
    );
  }

  Widget _headerButton(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, size: 14),
      label: Text(label,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: Colors.white.withOpacity(0.3)),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> tx) {
    final bool isIncome = tx['is_income'] ?? false;
    final Color color =
        tx['color'] ?? (isIncome ? Colors.green : Colors.red);
    final IconData icon = tx['icon'] ??
        (isIncome ? Icons.arrow_downward : Icons.arrow_upward);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black
                  .withOpacity(isDark ? 0.3 : 0.01),
              blurRadius: 10)
        ],
        border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey.shade50),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx['title'],
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark
                            ? Colors.white
                            : Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(
                    DateFormat('MMM dd, yyyy').format(
                        DateTime.parse(tx['date'].toString())),
                    style: TextStyle(
                        color:
                            isDark ? Colors.white38 : Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text('${isIncome ? "+" : "-"}₹${tx['amount'].toInt()}',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: isIncome
                      ? Colors.green.shade700
                      : Colors.red.shade700)),
        ],
      ),
    );
  }

  // ─── REWARDS TAB ──────────────────────────────────────────────────────────
  Widget _buildRewardsTab(bool isDark) {
    const int pointsPerRupee = 10;
    final double balanceInRupees = _rewardBalance / pointsPerRupee;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Reward Balance Card ────────────────────────────────────────────
        FadeInDown(
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE6A817), Color(0xFFFF6F00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFFE6A817).withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.workspace_premium_rounded,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  const Text('REWARD POINTS BALANCE',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5)),
                ]),
                const SizedBox(height: 16),
                Text('$_rewardBalance pts',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w900)),
                Text(
                    '≈ ₹${balanceInRupees.toStringAsFixed(0)} discount value',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Text(
                      '10 pts = ₹1 off on your next booking',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),

        // ── Points summary row ─────────────────────────────────────────────
        FadeInUp(
          delay: const Duration(milliseconds: 100),
          child: Row(children: [
            _rewardStat('Total Earned',
                '${_rewardLedger.where((e) => e['type'] == 'credit').fold(0, (s, e) => s + (e['points'] as int))} pts',
                Colors.green),
            const SizedBox(width: 12),
            _rewardStat('Total Redeemed',
                '${_rewardLedger.where((e) => e['type'] == 'debit').fold(0, (s, e) => s + (e['points'] as int))} pts',
                Colors.red.shade400),
          ]),
        ),
        const SizedBox(height: 28),

        // ── History ───────────────────────────────────────────────────────
        Text('POINTS HISTORY',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white38 : Colors.grey,
                letterSpacing: 1.5)),
        const SizedBox(height: 12),

        if (_rewardLedger.isEmpty)
          _emptyRewards(isDark)
        else
          ..._rewardLedger.asMap().entries.map((entry) {
            final e = entry.value;
            final isCredit = e['type'] == 'credit';
            return FadeInUp(
              delay: Duration(milliseconds: entry.key * 40),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF18181B)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: isCredit
                          ? Colors.amber.withOpacity(0.2)
                          : Colors.red.withOpacity(0.15)),
                ),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (isCredit ? Colors.amber : Colors.red)
                          .withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                        isCredit
                            ? Icons.add_circle_outline
                            : Icons.remove_circle_outline,
                        color: isCredit ? Colors.amber : Colors.red,
                        size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e['description'],
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: isDark
                                    ? Colors.white
                                    : Colors.black87),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Text(
                            e['date'] != null
                                ? DateFormat('MMM dd, yyyy  HH:mm')
                                    .format(DateTime.parse(
                                        e['date'].toString()))
                                : '',
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                      '${isCredit ? '+' : '-'}${e['points']} pts',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: isCredit
                              ? const Color(0xFFE6A817)
                              : Colors.red)),
                ]),
              ),
            );
          }),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _rewardStat(String label, String value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: color)),
        ]),
      ),
    );
  }

  Widget _emptyRewards(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(children: [
          Icon(Icons.workspace_premium_outlined,
              size: 60,
              color: Colors.amber.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text('No reward points yet',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          const Text('Book a trek to start earning points!',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      ),
    );
  }
}
