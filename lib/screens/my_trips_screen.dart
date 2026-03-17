import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';
import 'trek_detail_screen.dart';
import '../models/trek.dart';
import '../services/database_service.dart';
import '../services/preferences_service.dart';
import '../widgets/trek_card.dart';

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
  List<Trek> _wishlistTreks = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchBookings(),
      _fetchWishlist(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchBookings() async {
    try {
      final user = _client.auth.currentUser;
      final response = await _client
          .from('bookings')
          .select('*, trek:treks(*)')
          .eq('user_id', user!.id)
          .order('trek_date', ascending: true);

      final now = DateTime.now();
      final List<dynamic> upcoming = [];
      final List<dynamic> past = [];

      for (var b in (response as List)) {
        if (b['status'] == 'Completed') {
          past.add(b);
          continue;
        }

        final trekDate = DateTime.parse(b['trek_date']);
        if (trekDate.isAfter(now.subtract(const Duration(days: 1)))) {
          upcoming.add(b);
        } else {
          past.add(b);
        }
      }

      if (mounted) {
        setState(() {
          _upcomingBookings = upcoming;
          _pastBookings = past.reversed.toList();
        });
      }
    } catch (e) {
      print('Error fetching bookings: $e');
    }
  }

  Future<void> _fetchWishlist() async {
    try {
      final savedIds = await PreferencesService().getSavedTreks();
      if (savedIds.isEmpty) {
        if (mounted) setState(() => _wishlistTreks = []);
        return;
      }
      final allTreks = await DatabaseService().fetchTreks();
      if (mounted) {
        setState(() {
          _wishlistTreks = allTreks.where((t) => savedIds.contains(t.id)).toList();
        });
      }
    } catch (e) {
      print('Error fetching wishlist: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Journeys', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 4,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: const [
            Tab(text: 'UPCOMING'),
            Tab(text: 'COMPLETED'),
            Tab(text: 'WISHLIST'),
          ],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: _tabController,
            children: [
              _buildTripsList(_upcomingBookings, true),
              _buildTripsList(_pastBookings, false),
              _buildWishlist(),
            ],
          ),
    );
  }

  Widget _buildWishlist() {
    if (_wishlistTreks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('Your tactical wishlist is empty.', style: TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Explore Missions'),
            )
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _wishlistTreks.length,
      itemBuilder: (context, index) {
        return TrekCard(trek: _wishlistTreks[index]);
      },
    );
  }

  Widget _buildTripsList(List<dynamic> bookings, bool isUpcoming) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.landscape_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              isUpcoming ? 'No upcoming treks planned.' : 'No completed treks yet.',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            if (isUpcoming) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Explore Treks'),
              )
            ]
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        final trekData = booking['trek'];
        final trek = Trek.fromJson(trekData);

        return FadeInUp(
          delay: Duration(milliseconds: index * 100),
          child: Column(
            children: [
              GestureDetector(
                onTap: () => _showBookingDetails(booking, trek),
                child: TrekCard(trek: trek),
              ),
              Transform.translate(
                offset: const Offset(0, -26),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
                    border: Border.all(color: Colors.black.withOpacity(0.05)),
                  ),
                  child: Row(
                    children: [
                      _infoBadge(Icons.calendar_today, DateFormat('dd MMM yyyy').format(DateTime.parse(booking['trek_date']))),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: (isUpcoming ? Colors.green : Colors.blueGrey).withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                        child: Text(isUpcoming ? 'CONFIRMED' : 'COMPLETED', style: TextStyle(color: isUpcoming ? Colors.green : Colors.blueGrey, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                      const Spacer(),
                      if (isUpcoming) ...[
                        TextButton(
                          onPressed: () => _markAsComplete(booking['id']),
                          child: const Text('MARK COMPLETE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                        ),
                        if (booking['group_id'] != null)
                          IconButton(
                            icon: const Icon(Icons.chat_bubble_outline, color: Colors.blue, size: 18),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (c) => ChatScreen(
                                roomId: booking['group_id'], 
                                title: '${trek.title} Group'
                              )),
                            ),
                          ),
                      ],
                      const SizedBox(width: 4),
                      Text('₹${booking['total_price']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _markAsComplete(String bookingId) async {
    try {
      await _client.from('bookings').update({'status': 'Completed'}).eq('id', bookingId);
      _fetchData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trek marked as completed! Summit achieved.')));
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showBookingDetails(dynamic booking, Trek trek) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (c) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('MISSION DEBRIEF', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5)),
            const SizedBox(height: 20),
            _detailRow('Expedition:', trek.title),
            _detailRow('Date:', DateFormat('dd MMM yyyy').format(DateTime.parse(booking['trek_date']))),
            _detailRow('Pickup:', booking['pickup_location'] ?? 'Base Camp'),
            const Divider(height: 32),
            const Text('COST BREAKDOWN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            _priceRow('Base Package:', '₹${booking['base_price'] ?? 0}'),
            _priceRow('Pickup Surcharge:', '₹${booking['pickup_price'] ?? 0}'),
            _priceRow('Gear Rentals:', '₹${(double.tryParse(booking['total_price'].toString()) ?? 0) - (double.tryParse((booking['base_price'] ?? 0).toString()) ?? 0) - (double.tryParse((booking['pickup_price'] ?? 0).toString()) ?? 0)}'),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL PAID', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                Text('₹${booking['total_price']}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Theme.of(context).primaryColor)),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _infoBadge(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
