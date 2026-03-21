import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import '../widgets/user_avatar.dart';

class AdminFinanceHubScreen extends StatefulWidget {
  const AdminFinanceHubScreen({super.key});

  @override
  State<AdminFinanceHubScreen> createState() => _AdminFinanceHubScreenState();
}

class _AdminFinanceHubScreenState extends State<AdminFinanceHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  double _liquidity = 0;
  double _totalVolume = 0;
  double _gstReserve = 0;
  List<dynamic> _logs = [];
  List<dynamic> _treksAnalytics = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadFinanceData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFinanceData() async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      
      // Fetch core datasets independently for maximum resilience
      final List<dynamic> logsRes = await client.from('payment_logs').select('*, profiles(*), bookings(*)').order('created_at', ascending: false);
      final List<dynamic> treksRes = await client.from('treks').select('*');
      final List<dynamic> bookingsRes = await client.from('bookings').select('*, profiles(*)').order('created_at', ascending: false);
      final List<dynamic> rentalsRes = await client.from('user_rentals').select('*, profiles(*), gears(*)').order('created_at', ascending: false);
      
      double totalRev = 0;
      double rentalRev = 0;
      double logLiq = 0;
      List<dynamic> analytics = [];
      
      // 1. Calculate Revenue and Yield from all Bookings
      for (var b in bookingsRes) {
        final amt = double.tryParse(b['paid_amount']?.toString() ?? '0') ?? 
                    double.tryParse(b['total_price']?.toString() ?? '0') ?? 0;
        totalRev += amt;
        analytics.add({'trek_id': b['trek_id']?.toString(), 'rev': amt});
      }

      // 2. Calculate Rental Revenue
      for (var r in rentalsRes) {
        final amt = double.tryParse(r['total_price']?.toString() ?? '0') ?? 0;
        rentalRev += amt;
      }

      // Map analytics to treks
      List<dynamic> trekAnalytics = treksRes.map((t) {
        final tId = t['id'].toString();
        final tRev = analytics.where((a) => a['trek_id']?.toString() == tId).fold(0.0, (sum, a) => sum + (a['rev'] as double));
        final tCount = bookingsRes.where((b) => b['trek_id']?.toString() == tId).length;
        return {...t, 'rev': tRev, 'count': tCount};
      }).toList();

      // 3. Aggregate manual adjustments from Payment Logs
      if (logsRes.isNotEmpty) {
        for (var l in logsRes) {
          double amt = double.tryParse(l['amount']?.toString() ?? '0') ?? 0;
          if (l['booking_id'] == null) {
            if (l['is_incoming'] == true) logLiq += amt;
            else logLiq -= amt;
          }
        }
      }

      // 4. Synthesize Virtual Ledger (Merging Logs + Bookings + Rentals for visibility)
      List<dynamic> virtualLedger = [...logsRes];
      for (var b in bookingsRes) {
         virtualLedger.add({
           'id': 'b_${b['id']}',
           'amount': double.tryParse(b['total_price']?.toString() ?? '0') ?? 0,
           'is_incoming': true,
           'payment_type': 'TREK BOOKING',
           'created_at': b['created_at'],
           'profiles': b['profiles'],
         });
      }
      for (var r in rentalsRes) {
         virtualLedger.add({
           'id': 'r_${r['id']}',
           'amount': double.tryParse(r['total_price']?.toString() ?? '0') ?? 0,
           'is_incoming': true,
           'payment_type': 'GEAR RENTAL',
           'created_at': r['created_at'],
           'profiles': r['profiles'],
         });
      }
      virtualLedger.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));

      if (mounted) {
        setState(() {
          _logs = virtualLedger;
          _treksAnalytics = trekAnalytics;
          _totalVolume = totalRev + rentalRev;
          _liquidity = totalRev + rentalRev + logLiq;
          _gstReserve = _totalVolume * 0.05;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Finance Sync Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('HQ FINANCE COMMAND', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white, letterSpacing: 1.5)),
        backgroundColor: Colors.black,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.blueAccent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
          tabs: const [
            Tab(text: 'OVERVIEW'),
            Tab(text: 'TREK ANALYTICS'),
            Tab(text: 'LEDGER'),
            Tab(text: 'PAYOUTS'),
            Tab(text: 'TAXES'),
          ],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(),
              _buildTrekAnalyticsTab(),
              _buildLedgerTab(),
              _buildPayoutsTab(),
              _buildTaxInfoTab(),
            ],
          ),
    );
  }

  Widget _buildOverviewTab() {
     return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildLiquidityCard(),
        const SizedBox(height: 32),
        const Text('TREK METRICS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _diagnosticCard('Gross Revenue', '₹${(_totalVolume / 1000).toStringAsFixed(1)}K', Icons.analytics),
            _diagnosticCard('Tax Liability', '₹${(_gstReserve / 1000).toStringAsFixed(1)}K', Icons.gavel_outlined),
            _diagnosticCard('Active Treks', '${_treksAnalytics.where((t)=>t['count']>0).length}', Icons.landscape),
            _diagnosticCard('Personnel Cost', '₹${_treksAnalytics.length * 2}.0K', Icons.people_outline),
          ],
        ),
        const SizedBox(height: 32),
        const Text('RECENT ACTIVITY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
        const SizedBox(height: 16),
        ..._logs.take(5).map((l) => _buildLogItem(l)).toList(),
      ],
    );
  }

  Widget _buildTrekAnalyticsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _treksAnalytics.length,
      itemBuilder: (context, i) {
        final t = _treksAnalytics[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(15), border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey.shade100)),
          child: Row(
            children: [
               Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                 Text(t['title'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
                 Text('${t['count']} Trekkers deployed', style: const TextStyle(fontSize: 10, color: Colors.grey)),
               ])),
               Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                 Text('₹${t['rev'].toInt()}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.blueAccent)),
                 const Text('TOTAL YIELD', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey)),
               ]),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLedgerTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _logs.length,
      itemBuilder: (context, i) => _buildLogItem(_logs[i]),
    );
  }

  Widget _buildLogItem(dynamic l) {
    bool isIn = l['is_incoming'] ?? true;
    final type = l['payment_type']?.toString().toUpperCase() ?? 'SETTLEMENT';
    
    IconData icon = isIn ? Icons.arrow_circle_down : Icons.arrow_circle_up;
    Color iconColor = isIn ? Colors.greenAccent : Colors.orangeAccent;
    
    if (type.contains('BOOKING')) {
      icon = Icons.terrain_outlined;
      iconColor = Colors.blueAccent;
    } else if (type.contains('RENTAL')) {
      icon = Icons.inventory_2_outlined;
      iconColor = Colors.indigoAccent;
    } else if (type.contains('SALARY') || type.contains('PAYOUT')) {
      icon = Icons.payments_outlined;
      iconColor = Colors.tealAccent;
    } else if (type.contains('REFUND')) {
      icon = Icons.undo_outlined;
      iconColor = Colors.redAccent;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey.shade50)),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l['profiles']?['full_name'] ?? (l['bookings']?['profiles']?['full_name'] ?? 'System Sync'), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
            Text(l['payment_type']?.toString().toUpperCase() ?? 'SETTLEMENT', style: const TextStyle(fontSize: 8, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
            Text(l['created_at'] != null ? DateFormat('MMM dd, HH:mm').format(DateTime.parse(l['created_at'])) : 'Pending', style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ])),
          Text('${isIn ? "+" : "-"}₹${l['amount'].toInt()}', style: TextStyle(fontWeight: FontWeight.w900, color: isIn ? Colors.green : Colors.red)),
        ],
      ),
    );
  }

  Widget _buildPayoutsTab() {
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('PERSONNEL PAYOUTS',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 1.5,
                          color: Colors.grey)),
                  TextButton.icon(
                    onPressed: _showDeployPersonnelModal,
                    icon: const Icon(Icons.person_add_outlined, size: 14),
                    label: const Text('DEPLOY PERSONNEL',
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchPersonnel(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(color: Colors.black));
                    }
                    if (snapshot.hasError) {
                      return Center(
                          child: Text('Telemetry Failure: ${snapshot.error}',
                              style: const TextStyle(color: Colors.red)));
                    }

                    final staff = snapshot.data!;
                    if (staff.isEmpty) {
                      return const Center(
                          child: Text('No personnel deployments found.',
                              style: TextStyle(color: Colors.grey)));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: staff.length,
                      itemBuilder: (context, i) {
                        final s = staff[i];
                        final salary =
                            double.tryParse((s['salary'] ?? 0).toString()) ?? 0;
                        final allowance =
                            double.tryParse((s['allowance'] ?? 0).toString()) ?? 0;
                        final int unpaid =
                            int.tryParse((s['unpaid_leaves'] ?? 0).toString()) ?? 0;
                        final double deduction = (salary / 30) * unpaid;
                        final double net = salary + allowance - deduction;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.04), blurRadius: 20, offset: const Offset(0, 10))
                            ],
                            border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey.shade100),
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(22),
                                child: Row(children: [
                                  UserAvatar(
                                    imageUrl: s['avatar_url'],
                                    name: s['full_name'],
                                    radius: 26,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                        Text(s['full_name']?.toUpperCase() ?? 'PERSONNEL',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 16,
                                                letterSpacing: -0.5,
                                                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.badge, size: 10, color: Colors.blue),
                                            const SizedBox(width: 4),
                                            Text(
                                                (s['role'] ?? 'STAFF').toUpperCase(),
                                                style: const TextStyle(
                                                    fontSize: 8,
                                                    color: Colors.blue,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 1.5)),
                                          ],
                                        )
                                      ])),
                                  Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('₹${net.toInt()}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                color: Colors.green,
                                                fontSize: 22)),
                                        const Text('NET SETTLEMENT',
                                            style: TextStyle(
                                                fontSize: 8,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.grey,
                                                letterSpacing: 0.5))
                                      ]),
                                ]),
                              ),
                              Container(
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        _payoutMini('BASE COMP.', salary),
                                        _verticalDivider(),
                                        _payoutMini('ALLOWANCE', allowance),
                                        _verticalDivider(),
                                        _payoutMini('DEDUCTION', -deduction,
                                            isRed: true),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _actionBtn(
                                            Icons.edit_outlined, 'EDITS', Colors.white, Colors.black87,
                                            border: true,
                                            onTap: () => _showEditFinancials(s),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _actionBtn(
                                            Icons.payments_outlined, 'PAYOUT', Colors.black, Colors.white,
                                            onTap: () => _processPayout(s),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }),
            ),
          ],
        ),
        Positioned(
          bottom: 24,
          right: 24,
          child: FloatingActionButton.extended(
            onPressed: _deployPersonnelModal,
            label: const Text('DEPLOY PERSONNEL',
                style: TextStyle(fontWeight: FontWeight.bold)),
            icon: const Icon(Icons.person_add_outlined),
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  void _showDeployPersonnelModal() {
    _deployPersonnelModal();
  }

  Future<List<Map<String, dynamic>>> _fetchPersonnel() async {
    return _client
        .from('profiles')
        .select()
        .neq('role', 'user')
        .order('created_at', ascending: false);
  }

  void _deployPersonnelModal() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final salaryCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'DEPLOY NEW PERSONNEL',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailCtrl,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: salaryCtrl,
                  decoration: InputDecoration(
                    labelText: 'Salary (INR)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final email = emailCtrl.text.trim();
                      final salary = double.tryParse(salaryCtrl.text.trim()) ?? 0;
                      
                      if (name.isEmpty || email.isEmpty) return;
                      
                      try {
                        // TREK: Insert into profiles (assumes email is enough, or using invite flow)
                        await _client.from('profiles').insert({
                          'full_name': name,
                          'email': email,
                          'salary': salary.round(),
                          'role': 'staff', // Default to staff
                          'unpaid_leaves': 0,
                          'paid_leaves': 0,
                          'xp': 500, // Starting XP
                          'created_at': DateTime.now().toIso8601String(),
                        });
                        
                        if (mounted) {
                          Navigator.pop(context);
                          _fetchPersonnel(); // Refresh list
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PERSONNEL DEPLOYED SUCCESSFULLY'), backgroundColor: Colors.green));
                        }
                      } catch (e) {
                         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('DEPLOYMENT ERROR: $e'), backgroundColor: Colors.red));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('DEPLOY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _verticalDivider() {
    return Container(height: 20, width: 1, color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12);
  }

  Widget _payoutMini(String label, double val, {bool isRed = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.grey)),
        Text('₹${val.toInt()}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: isRed ? Colors.red : (isDark ? Colors.white70 : Colors.black87))),
      ],
    );
  }

  Widget _buildTaxInfoTab() {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.receipt_long, size: 80, color: Colors.grey),
        const SizedBox(height: 24),
        Text('TAX COMPLIANCE MODULE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
        const SizedBox(height: 8),
        Text('Estimated GST (5%): ₹${_gstReserve.toInt()}', style: const TextStyle(color: Colors.grey)),
    ]);
  }

  Widget _buildLiquidityCard() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.1), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TOTAL COMMAND LIQUIDITY', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 12),
          Text('₹${_liquidity.toInt()}', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900)),
          const SizedBox(height: 32),
          Row(
            children: [
               _heroBtn(Icons.upload, 'Withdrawal', () {}),
               const SizedBox(width: 12),
               _heroBtn(Icons.history, 'Ledger', () => _tabController.animateTo(2)),
            ],
          )
        ],
      ),
    );
  }

  Widget _heroBtn(IconData icon, String label, VoidCallback onTap) {
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.blueAccent, size: 14), const SizedBox(width: 8), Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))]),
      ),
    ));
  }

  Widget _diagnosticCard(String label, String value, IconData icon) {
     return Container(
       padding: const EdgeInsets.all(20),
       decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(15), border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey.shade100)),
       child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
         Icon(icon, color: Colors.blueAccent, size: 20),
         Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
           Text(label, style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
           Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
         ]),
       ]),
     );
  }
   Widget _actionBtn(IconData icon, String label, Color bg, Color text, {bool border = false, VoidCallback? onTap}) {
     return GestureDetector(
       onTap: onTap,
       child: Container(
         height: 48,
         decoration: BoxDecoration(
           color: bg,
           borderRadius: BorderRadius.circular(15),
           border: border ? Border.all(color: text.withOpacity(0.1)) : null,
         ),
         child: Row(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             Icon(icon, size: 14, color: text),
             const SizedBox(width: 8),
             Text(label, style: TextStyle(color: text, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5)),
           ],
         ),
       ),
     );
   }

   void _showEditFinancials(dynamic p) {
    final salaryCtrl = TextEditingController(text: (p['salary'] ?? 0).toString());
    final allowanceCtrl = TextEditingController(text: (p['allowance'] ?? 0).toString());
    final leavesCtrl = TextEditingController(text: (p['unpaid_leaves'] ?? 0).toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(30, 30, 30, MediaQuery.of(ctx).viewInsets.bottom + 30),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: SizedBox(width: 40, child: Divider(thickness: 4))),
            const SizedBox(height: 24),
            Row(
              children: [
                UserAvatar(radius: 20, imageUrl: p['avatar_url'], name: p['full_name']),
                const SizedBox(width: 12),
                Text('OVERRIDE FINANCIALS: ${p['full_name']?.toUpperCase()}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
              ],
            ),
            const SizedBox(height: 32),
            _prefField(salaryCtrl, 'BASE MONTHLY SALARY', Icons.payments_outlined),
            const SizedBox(height: 16),
            _prefField(allowanceCtrl, 'FIELD ALLOWANCE / KM', Icons.add_chart_outlined),
            const SizedBox(height: 16),
            _prefField(leavesCtrl, 'UNPAID LEAVES (DEDUCTION)', Icons.calendar_month_outlined),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () async {
                  final s = double.tryParse(salaryCtrl.text) ?? 0;
                  final a = double.tryParse(allowanceCtrl.text) ?? 0;
                  final l = int.tryParse(leavesCtrl.text) ?? 0;
                  
                  await _client.from('profiles').update({
                    'salary': s.round(),
                    'allowance': a.round(),
                    'unpaid_leaves': l,
                  }).eq('id', p['id']);
                  
                  Navigator.pop(ctx);
                  setState(() {}); // Refresh list
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Financial intelligence updated successfully.'), backgroundColor: Colors.black));
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: const Text('AUTHORIZE UPDATE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _prefField(TextEditingController ctrl, String label, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: Colors.blueGrey),
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  void _processPayout(dynamic p) async {
    final double salary = double.tryParse((p['salary'] ?? 0).toString()) ?? 0;
    final double allowance = double.tryParse((p['allowance'] ?? 0).toString()) ?? 0;
    final int unpaid = int.tryParse((p['unpaid_leaves'] ?? 0).toString()) ?? 0;
    
    final double deduction = (salary / 30) * unpaid;
    final double netPayout = (salary + allowance - deduction).clamp(0, double.infinity);

    final bool? ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: EdgeInsets.fromLTRB(30, 30, 30, MediaQuery.of(ctx).viewInsets.bottom + 30),
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: SizedBox(width: 40, child: Divider(thickness: 4))),
              const SizedBox(height: 24),
              Text('HQ PAYOUT COMMAND', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 32),
              _payoutRow('Base Salary', salary),
              _payoutRow('Allowance', allowance),
              _payoutRow('Leave Deductions', -deduction, isRed: true),
              const Divider(height: 32),
              _payoutRow('NET SEQUESTRATION', netPayout, isBold: true),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7B32), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  child: const Text('AUTHORIZE PAYOUT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        );
      }
    );

    if (ok == true) {
      try {
        await _client.from('payment_logs').insert({
          'user_id': p['id'],
          'amount': netPayout.round(),
          'is_incoming': false,
          'payment_type': 'SALARY',
          'created_at': DateTime.now().toIso8601String(),
        });
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payout deployed successfully.'), backgroundColor: Colors.green));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payout failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _payoutRow(String label, double val, {bool isRed = false, bool isBold = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
          Text('₹${val.toInt()}', style: TextStyle(fontWeight: FontWeight.bold, color: isRed ? Colors.red : (isBold ? (isDark ? Colors.greenAccent : Colors.black) : Colors.green), fontSize: 13)),
        ],
      ),
    );
  }
}
