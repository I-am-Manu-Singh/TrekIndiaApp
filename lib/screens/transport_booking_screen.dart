import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lottie/lottie.dart';
import '../services/transport_service.dart';
import '../services/database_service.dart';
import '../services/invoice_service.dart';

class TransportBookingScreen extends StatefulWidget {
  final String initialMode; // 'bus' or 'train'
  const TransportBookingScreen({super.key, this.initialMode = 'bus'});

  @override
  State<TransportBookingScreen> createState() => _TransportBookingScreenState();
}

class _TransportBookingScreenState extends State<TransportBookingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _fromCtrl = TextEditingController(text: 'Delhi');
  final TextEditingController _toCtrl = TextEditingController(text: 'Manali');
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  bool _isSearching = false;
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialMode == 'bus' ? 0 : 1);
  }

  void _search() async {
    setState(() {
      _isSearching = true;
      _results = [];
    });
    
    final bool isBus = _tabController.index == 0;
    
    final fetchedResults = await TransportService.fetchTransportData(
      type: isBus ? 'bus' : 'train',
      from: _fromCtrl.text.trim(),
      to: _toCtrl.text.trim(),
      date: _selectedDate,
    );

    if (mounted) {
      setState(() {
        _results = fetchedResults;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
      appBar: AppBar(
        title: Text('${_tabController.index == 0 ? 'BUS' : 'TRAIN'} BOOKINGS', 
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 2)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 4,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.6),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          onTap: (i) => setState(() {}),
          tabs: const [
            Tab(icon: Icon(Icons.directions_bus), text: 'BUS'),
            Tab(icon: Icon(Icons.train), text: 'TRAIN'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSearchHeader(isDark, primary),
          Expanded(
            child: _isSearching 
              ? const Center(child: CircularProgressIndicator())
              : _results.isEmpty 
                ? _buildEmptyState()
                : _buildResultsList(isDark, primary),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader(bool isDark, Color primary) {
  return Container(
    padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
          blurRadius: 20,
          offset: const Offset(0, 10),
        )
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center, // <-- important
      children: [
        // Route Selection
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.black26 : Colors.grey[50],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center, // <-- fix vertical alignment
            children: [
              Expanded(
                child: _miniInput(
                  'FROM',
                  _fromCtrl,
                  Icons.location_on,
                  isDark,
                ),
              ),

              const SizedBox(width: 8),

              Container(
                height: 36, // <-- force proper centering
                width: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.swap_horiz, color: primary, size: 20),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: _miniInput(
                  'TO',
                  _toCtrl,
                  Icons.location_city,
                  isDark,
                  alignRight: true,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // Date Selection
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 90)),
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: primary,
                    brightness: isDark ? Brightness.dark : Brightness.light,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked != null) setState(() => _selectedDate = picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.grey[50],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
            ),
            child: Row(
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    Icon(Icons.calendar_month_rounded, size: 22, color: primary),
    const SizedBox(width: 12),

    Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DEPARTURE DATE',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            DateFormat('EEEE, dd MMM yyyy').format(_selectedDate),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ),
    ),

    const SizedBox(width: 8),

    // 🔥 Your circular button at right end
    SizedBox(
      height: 40,
      width: 40,
      child: ElevatedButton(
        onPressed: _search,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
          elevation: 2,
        ),
        child: const Icon(
          Icons.arrow_forward_rounded,
          size: 20,
          color: Colors.white,
        ),
      ),
    ),
  ],
),
          ),
        ),

    
      ],
    ),
  );
}

      Widget _miniInput(
  String label,
  TextEditingController controller,
  IconData icon,
  bool isDark, {
  bool alignRight = false,
}) {
  return SizedBox(
    height: 70,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment:
          alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!alignRight) ...[
          Icon(icon, size: 32, color: Colors.grey),
          const SizedBox(width: 12),
        ],

        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: alignRight
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                label,
                textAlign:
                    alignRight ? TextAlign.right : TextAlign.left,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 2),
              TextField(
                controller: controller,
                textAlign:
                    alignRight ? TextAlign.right : TextAlign.left,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: label,
                ),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),

        if (alignRight) ...[
          const SizedBox(width: 12),
          Icon(icon, size: 32, color: Colors.grey),
        ],
      ],
    ),
  );
}

  Widget _buildEmptyState() {
    return Center(
      child: FadeIn(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.network(
              'https://assets10.lottiefiles.com/packages/lf20_t9gkkhz4.json',
              height: 200,
              errorBuilder: (c, e, s) => Icon(Icons.directions_bus_outlined, size: 80, color: Colors.grey[300]),
            ),
            const SizedBox(height: 24),
            const Text('WHERE TO NEXT?', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 1)),
            const SizedBox(height: 8),
            const Text('Enter your route to see available services', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList(bool isDark, Color primary) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final r = _results[index];
        final double seatsLeft = double.tryParse(r['seats'].toString()) ?? 0;
        final double totalSeats = _tabController.index == 0 ? 40 : 100;
        final double occupancy = 1.0 - (seatsLeft / totalSeats);

        return FadeInUp(
          delay: Duration(milliseconds: 50 * index),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              children: [
                // Top Badge Area
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          r['type'].toString().toUpperCase(),
                          style: TextStyle(color: primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            Text(r['rating'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.only(right: 12, left: 12, bottom: 12),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r['name'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                                const SizedBox(height: 4),
                                Text('${r['from']} to ${r['to']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('₹${r['price']}', style: TextStyle(color: primary, fontWeight: FontWeight.w900, fontSize: 24)),
                              const Text('per traveler', style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                      
                       Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Expanded(child: Divider(thickness: 1, color: isDark ? Colors.white10 : Colors.grey[300])),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Icon(Icons.directions_bus_filled_outlined, size: 20, color: Colors.grey.withOpacity(0.5)),
                            ),
                            Expanded(child: Divider(thickness: 1, color: isDark ? Colors.white10 : Colors.grey[300])),
                          ],
                        ),
                      ),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _timeCard('DEPARTURE', r['time'].split(' - ')[0], _selectedDate, isDark),
                          _timeCard('ARRIVAL', r['time'].split(' - ')[1], _selectedDate, isDark),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Seat Availability Progress
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('SEAT AVAILABILITY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                              Text('${r['seats']} SEATS LEFT', style: TextStyle(color: seatsLeft < 10 ? Colors.red : Colors.green, fontWeight: FontWeight.w900, fontSize: 10)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: occupancy,
                              backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
                              valueColor: AlwaysStoppedAnimation<Color>(occupancy > 0.8 ? Colors.red : primary),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Amenities Icons
                      if (r['amenities'] != null)
                        SizedBox(
                          height: 30,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: (r['amenities'] as List).map((a) => Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
                              ),
                              child: Center(
                                child: Row(
                                  children: [
                                    _getAmenityIcon(a.toString()),
                                    const SizedBox(width: 6),
                                    Text(a.toString(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            )).toList(),
                          ),
                        ),
                      
                      const SizedBox(height: 12),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () => _confirmBooking(r),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            elevation: 0,
                          ),
                          child: const Text('Book Seat', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _timeCard(String label, String time, DateTime date, bool isDark) {
    return Column(
      crossAxisAlignment: label == 'ARRIVAL' ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(time, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(height: 2),
        Text(DateFormat('dd MMM yyyy').format(date), style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Icon _getAmenityIcon(String name) {
    name = name.toLowerCase();
    if (name.contains('wifi')) return const Icon(Icons.wifi, size: 14, color: Colors.blueAccent);
    if (name.contains('ac')) return const Icon(Icons.ac_unit, size: 14, color: Colors.lightBlue);
    if (name.contains('water')) return const Icon(Icons.local_drink, size: 14, color: Colors.blue);
    if (name.contains('food')) return const Icon(Icons.restaurant, size: 14, color: Colors.orange);
    if (name.contains('charging')) return const Icon(Icons.bolt, size: 14, color: Colors.amber);
    return const Icon(Icons.done, size: 14, color: Colors.green);
  }

  void _confirmBooking(Map<String, dynamic> item) {
    final nameCtrl = TextEditingController();
    final ageCtrl = TextEditingController();
    final seatCtrl = TextEditingController();
    bool isProfileLoaded = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          if (!isProfileLoaded) {
            isProfileLoaded = true;
            final user = Supabase.instance.client.auth.currentUser;
            if (user != null) {
              Supabase.instance.client.from('profiles').select('full_name').eq('id', user.id).maybeSingle().then((profile) {
                if (mounted) {
                  setModalState(() {
                    nameCtrl.text = profile?['full_name'] ?? user.userMetadata?['full_name'] ?? user.email?.split('@')[0] ?? '';
                  });
                }
              });
            }
          }

          return Container(
            padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 30),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40)],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(color: Colors.grey.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text('TRAVELER DOSSIER', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 2)),
                  const SizedBox(height: 6),
                  Text('Securing your passage on ${item['name']}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  
                  const SizedBox(height: 32),
                  
                  _formField('FULL NAME (AS PER ID)', nameCtrl, Icons.badge_outlined, isDark),
                  const SizedBox(height: 20),
                  
                  Row(
                    children: [
                      Expanded(child: _formField('AGE', ageCtrl, Icons.cake_outlined, isDark, keyboardType: TextInputType.number)),
                      const SizedBox(width: 16),
                      Expanded(child: _formField('SEAT PREF', seatCtrl, Icons.chair_outlined, isDark)),
                    ],
                  ),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Divider(thickness: 1),
                  ),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('FINAL FARE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                          const SizedBox(height: 4),
                          Text('₹${item['price']}', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w900, fontSize: 28)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Text('ALL TAXES INCL.', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nameCtrl.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter passenger name')));
                          return;
                        }
                        
                        // Show linear progress inside the button or a simple overlay
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Securing your seat...'), duration: Duration(seconds: 1)));

                        final String? bookingId = await DatabaseService().bookTransport(
                          transportName: item['name'],
                          transportType: _tabController.index == 0 ? 'bus' : 'train',
                          from: _fromCtrl.text,
                          to: _toCtrl.text,
                          date: _selectedDate,
                          price: double.tryParse(item['price'].toString()) ?? 0,
                          hikerName: nameCtrl.text.trim(),
                          age: int.tryParse(ageCtrl.text),
                          seat: seatCtrl.text,
                        );

                        if (mounted) {
                          if (bookingId != null) {
                            Navigator.pop(context); // Close Dossier
                            _showPaymentConfirmation(item, bookingId, nameCtrl.text);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Booking failed. Please ensure DB columns are created.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 6,
                        shadowColor: Theme.of(context).primaryColor.withOpacity(0.4),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('CONFIRM & PAY NOW', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1)),
                          SizedBox(width: 12),
                          Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPaymentConfirmation(Map<String, dynamic> item, String bookingId, String userName) {
    // 1. Show Processing Overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(strokeWidth: 6, color: Colors.green),
              const SizedBox(height: 24),
              const Text('PROCESSING PAYMENT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2)),
              const SizedBox(height: 8),
              const Text('Verifying with banking servers...', style: TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ),
        ),
      ),
    );

    // 2. Simulate Delay then show Success
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.pop(context); // Close processing dialog

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => ZoomIn(
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 80),
                const SizedBox(height: 24),
                const Text('BOOKING SECURED', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 1)),
                const SizedBox(height: 8),
                Text('Passage on ${item['name']} confirmed.', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Divider()),
                _confirmRow('Booking ID', bookingId.substring(0, 8).toUpperCase()),
                _confirmRow('Passenger', userName.toUpperCase()),
                _confirmRow('Fare Paid', '₹${item['price']}'),
                _confirmRow('Departure', DateFormat('dd MMM yyyy').format(_selectedDate)),
                const Divider(height: 48),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => InvoiceService.generateTransportInvoice(
                          bookingId: bookingId,
                          transportName: item['name'],
                          type: _tabController.index == 0 ? 'bus' : 'train',
                          from: _fromCtrl.text,
                          to: _toCtrl.text,
                          date: _selectedDate,
                          hikerName: userName,
                          price: double.tryParse(item['price'].toString()) ?? 0,
                        ),
                        icon: const Icon(Icons.description_outlined, size: 16),
                        label: const Text('INVOICE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _shareOnWhatsApp(item, bookingId),
                        icon: const Icon(Icons.chat_bubble_outline, size: 16, color: Colors.white),
                        label: const Text('WHATSAPP', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366), 
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(c);
                      Navigator.pop(context); // Back to search
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('DONE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      );
    });
  }

  void _sendEmail(Map<String, dynamic> item, String bookingId) async {
    final String subject = "Transport Booking Confirmation - ${bookingId.substring(0, 8).toUpperCase()}";
    final String body = "Hello,\n\n"
        "Your transport booking is confirmed.\n\n"
        "Service: ${item['name']}\n"
        "Route: ${_fromCtrl.text} to ${_toCtrl.text}\n"
        "Date: ${DateFormat('dd MMM yyyy').format(_selectedDate)}\n"
        "Booking ID: ${bookingId.substring(0, 8).toUpperCase()}\n"
        "Amount: ₹${item['price']}\n\n"
        "Thank you for choosing Trip India!";
    
    final Uri uri = Uri(
      scheme: 'mailto',
      path: 'support@tripindia.com',
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _shareOnWhatsApp(Map<String, dynamic> item, String bookingId) async {
    final String message = "Hello Trip India Support! I just booked a ${_tabController.index == 0 ? 'Bus' : 'Train'} ticket.\n\n"
        "Service: ${item['name']}\n"
        "Route: ${_fromCtrl.text} to ${_toCtrl.text}\n"
        "Date: ${DateFormat('dd MMM yyyy').format(_selectedDate)}\n"
        "Booking ID: ${bookingId.substring(0, 8).toUpperCase()}\n"
        "Amount: ₹${item['price']}\n\n"
        "Please confirm my departure details.";
    
    final String url = "whatsapp://send?phone=+918949821211&text=${Uri.encodeComponent(message)}";
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      final String webUrl = "https://wa.me/918949821211?text=${Uri.encodeComponent(message)}";
      await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
    }
  }

  Widget _confirmRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
          Text(val, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _formField(String label, TextEditingController ctrl, IconData icon, bool isDark, {TextInputType keyboardType = TextInputType.text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey[50],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1),
          prefixIcon: Icon(icon, size: 20, color: Colors.blueGrey),
          border: InputBorder.none,
          isDense: true,
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
      ),
    );
  }
}
