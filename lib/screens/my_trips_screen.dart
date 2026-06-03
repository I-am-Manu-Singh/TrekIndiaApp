import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';
import 'trip_detail_screen.dart';
import '../models/trip.dart';
import '../services/database_service.dart';
import '../services/preferences_service.dart';
import '../widgets/unified_trip_card.dart';
import 'trip_certificate_screen.dart';
import '../services/invoice_service.dart';
import 'declaration_form_screen.dart';
import '../widgets/user_avatar.dart';
class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _upcomingBookings = [];
  List<dynamic> _pastBookings = [];
  List<dynamic> _transportBookings = [];
  List<Trip> _wishlistTrips = [];
  List<TripCategory> _availableCategories = [];
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchBookings(),
      _fetchWishlist(),
      _fetchCategories(),
      _fetchTransports(),
    ]);
    
    // Fetch profile for accurate certificate data
    final user = _client.auth.currentUser;
      // Calculate real liquidity balance from payment_logs
      final logs = await _client.from('payment_logs').select('amount, is_incoming').eq('user_id', user!.id);
      double realBalance = (logs as List).fold(0.0, (sum, log) {
        final amount = double.tryParse(log['amount'].toString()) ?? 0;
        final bool isIncoming = log['is_incoming'] ?? true;
        // In this app, many logs have is_incoming=false for outgoing payments (like booking costs)
        // We ensure the balance reflects the CURRENT user wallet state
        return sum + (isIncoming ? amount : -amount);
      });
      
      if (realBalance < 0) realBalance = 0; // Safety for negative balance UI glitch
      
    if (user != null) {
      final res = await _client.from('profiles').select().eq('id', user.id).maybeSingle();
      if (mounted) setState(() => _userProfile = res);
    }
    
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchBookings() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      // NOTE: Guest bookings are automatically claimed via server-side trigger 
      // when the user registers. No client-side update needed here.

      final response = await _client
          .from('bookings')
          .select('*, trip:trips(*)')
          .eq('user_id', user.id)
          .order('trip_date', ascending: true);

      final List res = response as List;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      _upcomingBookings = res.where((b) {
        final status = b['status']?.toString().toLowerCase() ?? '';
        if (status == 'completed' || status == 'cancelled') return false;
        
        final date = DateTime.tryParse(b['trip_date'] ?? '');
        return date != null && (date.isAfter(today) || date.isAtSameMomentAs(today));
      }).toList();

      _pastBookings = res.where((b) {
        final status = b['status']?.toString().toLowerCase() ?? '';
        if (status == 'completed') return true;
        
        final date = DateTime.tryParse(b['trip_date'] ?? '');
        return date != null && date.isBefore(today);
      }).toList();

      if (mounted) {
        setState(() {
          _pastBookings = _pastBookings.reversed.toList();
        });
      }
    } catch (e) {
      print('Error fetching bookings: $e');
    }
  }

  Future<void> _fetchWishlist() async {
    try {
      final savedIds = await PreferencesService().getSavedTrips();
      if (savedIds.isEmpty) {
        if (mounted) setState(() => _wishlistTrips = []);
        return;
      }
      final allTrips = await DatabaseService().fetchTrips();
      if (mounted) {
        setState(() {
          _wishlistTrips = allTrips.where((t) => savedIds.contains(t.id)).toList();
        });
      }
    } catch (e) {
      print('Error fetching wishlist: $e');
    }
  }

  Future<void> _fetchTransports() async {
    final transports = await DatabaseService().fetchTransportBookings();
    if (mounted) setState(() => _transportBookings = transports);
  }

  Future<void> _fetchCategories() async {
    final cats = await DatabaseService().fetchCategories();
    if (mounted) setState(() => _availableCategories = cats);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if we are on Web to determine layout sizing
    final bool isWeb = MediaQuery.of(context).size.width > 900;
    return Scaffold(
      appBar: AppBar(
        title: const Text('MY JOURNEYS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        backgroundColor: const Color(0xFFD32F2F),
        elevation: 0,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 4,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.6),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1),
          tabs: const [
            Tab(text: 'UPCOMING'),
            Tab(text: 'COMPLETED'),
            Tab(text: 'TRANSPORTS'),
            Tab(text: 'WISHLIST'),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWeb ? 800 : double.infinity),
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildTripsList(_upcomingBookings, true),
                  _buildTripsList(_pastBookings, false),
                  _buildTransportList(),
                  _buildWishlist(),
                ],
              ),
        ),
      ),
    );
  }

  Widget _buildWishlist() {
    if (_wishlistTrips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('Your details wishlist is empty.', style: TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Explore Trips'),
            )
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _wishlistTrips.length,
      itemBuilder: (context, index) {
        final trip = _wishlistTrips[index];
        final meta = _availableCategories.where((c) => c.name == trip.category).firstOrNull;
        return UnifiedTripCard(
          trip: trip, 
          categoryMeta: meta,
          heroTag: 'wishlist_${trip.id}',
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 20),
          onRefresh: _fetchData,
        );
      },
    );
  }

  Widget _buildTripsList(List<dynamic> bookings, bool isUpcomingTab) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.landscape_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              isUpcomingTab ? 'No upcoming trips planned.' : 'No completed trips yet.',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            if (isUpcomingTab) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Explore Trips'),
              )
            ]
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        final tripData = booking['trip'];
        final trip = Trip.fromJson(tripData);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        // Safety: Handle missing trip_date
        final String? dateStr = booking['trip_date']?.toString();
        final tripDate = dateStr != null ? DateTime.parse(dateStr) : DateTime.now();
        final isUpcoming = tripDate.isAfter(DateTime.now().subtract(const Duration(days: 1)));

        return FadeInUp(
          delay: Duration(milliseconds: index * 100),
          child: Column(
            children: [
              UnifiedTripCard(
                trip: trip,
                heroTag: 'my_trips_${booking['id']}',
                categoryMeta: _availableCategories.where((c) => c.name == trip.category).firstOrNull,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                width: double.infinity,
                borderRadius: BorderRadius.circular(24),
                showPrice: false,
                showFooter: false,
                customFooter: _buildUnifiedActionFooter(booking, trip, isUpcoming),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUnifiedActionFooter(dynamic booking, Trip trip, bool isUpcoming) {
    final dateStr = booking['trip_date']?.toString();
    final tripDate = dateStr != null ? DateTime.parse(dateStr) : DateTime.now();
    final status = (booking['status'] ?? 'Confirmed').toString().toUpperCase();

    return Column(
      children: [
        const Divider(height: 24),
        Row(
          children: [
            _infoBadge(Icons.calendar_today, DateFormat('dd MMM yyyy').format(tripDate)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (status == 'CANCELLED' ? Colors.red : (status == 'COMPLETED' ? Colors.blueGrey : Colors.green)).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: status == 'CANCELLED' ? Colors.red : (status == 'COMPLETED' ? Colors.blueGrey : Colors.green),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Spacer(),
            _buildMembersMiniPreview(booking['trip_id'], booking['trip_date']),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            if (status != 'COMPLETED' && status != 'CANCELLED')
              _actionBtn(Icons.check_circle_outline, 'COMPLETE', Colors.blueAccent, () => _markAsComplete(booking['id']))
            else if (status == 'COMPLETED')
              _actionBtn(Icons.verified, 'CERTIFICATE', Colors.amber, () {
                 final enrichedBooking = Map<String, dynamic>.from(booking);
                 enrichedBooking['profiles'] = _userProfile;
                 Navigator.push(context, MaterialPageRoute(builder: (c) => TripCertificateScreen(booking: enrichedBooking)));
              }),
            
            if (booking['group_id'] != null)
              _actionBtn(Icons.chat_bubble_outline, 'CHAT', Colors.blue, () => Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => ChatScreen(
                  roomId: booking['group_id'], 
                  title: '${trip.title} Group',
                  isReadOnly: status == 'COMPLETED',
                )),
              )),

            _actionBtn(Icons.receipt_long_outlined, 'INVOICE', Colors.orange, () => InvoiceService.generateAndDownloadInvoice(
              bookingId: booking['id'],
              tripName: trip.title,
              date: tripDate,
              hikerName: booking['hiker_name'] ?? _userProfile?['full_name'] ?? 'Hiker',
              totalPrice: double.tryParse(booking['total_price'].toString()) ?? 0,
              basePrice: double.tryParse((booking['base_price'] ?? 0).toString()) ?? 0,
              pickupPrice: double.tryParse((booking['pickup_price'] ?? 0).toString()) ?? 0,
              pickupLocation: booking['pickup_location'] ?? 'Base Camp',
              email: _userProfile?['email'],
            )),
            
            _actionBtn(Icons.info_outline, 'DETAILS', Colors.grey, () => _showBookingDetails(booking, trip)),
          ],
        ),
      ],
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  void _markAsComplete(String bookingId) async {
    try {
      final booking = (_upcomingBookings + _pastBookings).firstWhere((b) => b['id'] == bookingId);
      final trip = booking['trip'];
      final user = _client.auth.currentUser;
      if (user == null) return;

      await DatabaseService().completeTrip(
        bookingId: bookingId,
        userId: user.id,
        distance: double.tryParse((trip['distance'] ?? trip['total_distance'] ?? 10.0).toString()) ?? 10.0
      );

      _fetchData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ACHIEVEMENT UNLOCKED: Trip marked as completed!'), backgroundColor: Colors.green));
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('MISSION FAILED: $e'), backgroundColor: Colors.red));
    }
  }

  Future<List<dynamic>> _fetchMembers(String tripId, String date) async {
    try {
      // Manual Join for resilience
      final bookingsRes = await Supabase.instance.client
          .from('bookings')
          .select('user_id')
          .eq('trip_id', tripId)
          .eq('trip_date', date)
          .eq('status', 'confirmed');
      
      final userIds = (bookingsRes as List).map((b) => b['user_id'].toString()).toList();
      if (userIds.isEmpty) return [];

      final profilesRes = await Supabase.instance.client
          .from('profiles')
          .select('full_name, avatar_url, role')
          .inFilter('id', userIds);
      
      return (profilesRes as List).map((p) => {'profiles': p}).toList();
    } catch (_) {
      return [];
    }
  }

  void _showBookingDetails(dynamic booking, Trip trip) async {
    final members = await _fetchMembers(trip.id, booking['trip_date']);
    
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(height: 4, width: 40, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            const Text('TRIP DEBRIEF', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2)),
            const SizedBox(height: 8),
            const Text('Operational Logs & Fiscal Data', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 32),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailRow('Trip:', trip.title),
                    _detailRow('Date:', DateFormat('dd MMM yyyy').format(DateTime.parse(booking['trip_date']))),
                    _detailRow('Status:', (booking['status'] ?? 'PENDING').toString().toUpperCase()),
                    _detailRow('Payment:', (booking['payment_status'] ?? 'UNPAID').toString().toUpperCase()),
                    const Divider(height: 32),
                    const Text('TRIP MEMBERS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 16),
                    if (members.isEmpty)
                      const Text('No other confirmed members yet.', style: TextStyle(color: Colors.grey, fontSize: 12))
                    else
                      SizedBox(
                        height: 60,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: members.length + (booking['traveler_details'] != null ? (booking['traveler_details'] as List).length : 0),
                          itemBuilder: (ctx, i) {
                            if (i < members.length) {
                              final p = members[i]['profiles'];
                              return _memberCard(p['avatar_url'], p['full_name']);
                            } else {
                              final extras = booking['traveler_details'] as List;
                              final ext = extras[i - members.length];
                              return _memberCard(null, ext['name'] ?? 'Guest');
                            }
                          },
                        ),
                      ),
                    const Divider(height: 32),
                    const Text('COST BREAKDOWN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 12),
                    _priceRow('Base Package:', '₹${booking['base_price'] ?? 0}'),
                    if ((booking['pickup_price'] ?? 0) > 0) _priceRow('Pickup Surcharge:', '₹${booking['pickup_price'] ?? 0}'),
                    
                    // Explicit Gear/Other calculation
                    () {
                      final total = double.tryParse(booking['total_price'].toString()) ?? 0;
                      final base = double.tryParse((booking['base_price'] ?? 0).toString()) ?? 0;
                      final pickup = double.tryParse((booking['pickup_price'] ?? 0).toString()) ?? 0;
                      final extras = total - base - pickup;
                      
                      if (extras > 0) {
                        return _priceRow('Gear & Extra Services:', '₹${extras.toInt()}');
                      }
                      return const SizedBox.shrink();
                    }(),
                    const Divider(height: 32),
                    const SizedBox(height: 20),
                    if (booking['status']?.toString().toLowerCase() == 'cancelled') ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => InvoiceService.generateRefundInvoice(
                            bookingId: booking['id'],
                            tripName: trip.title,
                            date: DateTime.parse(booking['trip_date']),
                            hikerName: booking['hiker_name'] ?? 'Hiker',
                            refundAmount: double.tryParse(booking['total_price'].toString()) ?? 0,
                            reason: booking['cancellation_reason'] ?? 'User Request',
                            email: _userProfile?['email'],
                          ),
                          icon: const Icon(Icons.history_edu),
                          label: const Text('DOWNLOAD REFUND ADVICE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[800],
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 45),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => InvoiceService.generateAndDownloadInvoice(
                                bookingId: booking['id'],
                                tripName: trip.title,
                                date: DateTime.parse(booking['trip_date']),
                                hikerName: booking['hiker_name'] ?? 'Trip',
                                totalPrice: double.tryParse(booking['total_price'].toString()) ?? 0,
                                basePrice: double.tryParse((booking['base_price'] ?? 0).toString()) ?? 0,
                                pickupPrice: double.tryParse((booking['pickup_price'] ?? 0).toString()) ?? 0,
                                pickupLocation: booking['pickup_location'] ?? 'Base Camp',
                                email: _userProfile?['email'],
                              ),
                              icon: const Icon(Icons.download, size: 16),
                              label: const Text('DOWNLOAD INVOICE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 45),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invoice dispatched to ${_userProfile?['email'] ?? 'registered email'}.'), backgroundColor: Colors.green));
                              },
                              icon: const Icon(Icons.email_outlined, size: 16),
                              label: const Text('SEND TO EMAIL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blueAccent,
                                side: const BorderSide(color: Colors.blueAccent),
                                minimumSize: const Size(0, 45),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          const SizedBox(width: 12),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildMembersMiniPreview(String tripId, String date) {
    return FutureBuilder<List<dynamic>>(
      future: _fetchMembers(tripId, date),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
        final members = snapshot.data!;
        return SizedBox(
          width: 60,
          height: 20,
          child: Stack(
            children: List.generate(members.length > 3 ? 3 : members.length, (i) {
              final p = members[i]['profiles'];
              return Positioned(
                left: i * 14.0,
                child: Container(
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1)),
                  child: UserAvatar(imageUrl: p['avatar_url'], name: p['full_name'], radius: 9),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _infoBadge(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildTransportList() {
    if (_transportBookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_bus_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('No transport bookings found.', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _transportBookings.length,
      itemBuilder: (context, index) {
        final b = _transportBookings[index];
        final isBus = b['transport_type'] == 'bus';
        final dateStr = b['departure_date']?.toString();
        final date = dateStr != null ? DateTime.parse(dateStr) : DateTime.now();
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        return FadeInUp(
          delay: Duration(milliseconds: index * 100),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (isBus ? Colors.orange : Colors.blue).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(isBus ? Icons.directions_bus : Icons.train, color: isBus ? Colors.orange : Colors.blue),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b['transport_name']?.toUpperCase() ?? 'TRANSPORT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.white : Colors.black87, letterSpacing: -0.5)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 10, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(DateFormat('dd MMM yyyy').format(date), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                              const SizedBox(width: 12),
                              Icon(Icons.location_on, size: 10, color: Colors.blueAccent),
                              const SizedBox(width: 4),
                              Text('${b['origin']} → ${b['destination']}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₹${b['price']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                          child: const Text('CONFIRMED', style: TextStyle(color: Colors.green, fontSize: 8, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => InvoiceService.generateTransportInvoice(
                      bookingId: b['id'],
                      transportName: b['transport_name'] ?? 'Transport',
                      type: b['transport_type'] ?? 'bus',
                      from: b['origin'] ?? 'Origin',
                      to: b['destination'] ?? 'Destination',
                      date: date,
                      hikerName: _userProfile?['full_name'] ?? 'Hiker',
                      price: double.tryParse(b['price'].toString()) ?? 0,
                      email: _userProfile?['email'],
                    ),
                    icon: const Icon(Icons.download, size: 14),
                    label: const Text('DOWNLOAD INVOICE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey[800],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _memberCard(String? avatarUrl, String? name) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          UserAvatar(imageUrl: avatarUrl, name: name ?? 'User', radius: 18),
          const SizedBox(height: 4),
          Text(name?.split(' ').first ?? 'User', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
