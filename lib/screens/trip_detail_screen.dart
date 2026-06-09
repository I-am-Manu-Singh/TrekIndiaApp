import 'dart:ui';
import '../widgets/glass_shimmer.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import '../services/whatsapp_service.dart';
import '../services/invoice_service.dart';
import '../models/trip.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../services/preferences_service.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:share_plus/share_plus.dart';
import 'add_review_screen.dart';
import 'web_view_screen.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'chat_screen.dart';
import 'media_preview_screen.dart';
import '../widgets/user_avatar.dart';
import 'gear_checklist_screen.dart';
import 'edit_trip_screen.dart';
import 'declaration_form_screen.dart';
import '../widgets/trip_booking_sheet.dart';
import '../widgets/trip_reviews_section.dart';
import '../widgets/mock_payment_flow.dart';
import 'my_trips_screen.dart';
import 'login_screen.dart';

class TripDetailScreen extends StatefulWidget {
  final Trip trip;
  final String? heroTag;
  const TripDetailScreen({super.key, required this.trip, this.heroTag});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSaved = false;
  bool _canReview = false;
  int _currentImageIndex = 0;
  final ScreenshotController _screenshotController = ScreenshotController();
  String _role = 'user';
  bool _isLoading = true;
  bool _hasChanged = false;
  Trip? _trip;

  Trip get currentTrip => _trip ?? widget.trip;

  bool get _isTrip =>
      currentTrip.category.toLowerCase().contains('trip') ||
      currentTrip.category == 'Adventure' ||
      currentTrip.difficulty.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    _tabController = TabController(length: _isTrip ? 5 : 4, vsync: this);
    _checkSavedStatus();
    _checkReviewEligibility();
    _checkUserRole();
    _checkBookingAndFetchMembers().then((_) {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  Future<void> _refreshTrip() async {
    final updated = await DatabaseService().fetchTripById(currentTrip.id);
    if (updated != null && mounted) {
      setState(() {
        _trip = updated;
        _hasChanged = true;
      });
    }
  }

  Future<void> _checkUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();
      if (mounted) setState(() => _role = res['role'] ?? 'user');
    } catch (_) {}
  }

  Future<void> _checkSavedStatus() async {
    final isSaved = await PreferencesService().isTripSaved(currentTrip.id);
    if (mounted) setState(() => _isSaved = isSaved);
  }

  Future<void> _checkReviewEligibility() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Check if user has a booking for this trip
    try {
      final res = await Supabase.instance.client
          .from('bookings')
          .select('id')
          .eq('trip_id', currentTrip.id)
          .eq('user_id', user.id)
          .limit(1);
      if (res.isNotEmpty && mounted) {
        setState(() => _canReview = true);
      }
    } catch (_) {}
  }

  List<dynamic> _tripMembers = [];
  bool _isBooked = false;

  Future<void> _checkBookingAndFetchMembers() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final bookings = await Supabase.instance.client
          .from('bookings')
          .select('id, trip_date')
          .eq('trip_id', currentTrip.id)
          .eq('user_id', user.id)
          .limit(1);

      if (bookings.isNotEmpty) {
        if (mounted) setState(() => _isBooked = true);
        final date = bookings[0]['trip_date'];
        final members = await Supabase.instance.client
            .from('bookings')
            .select('profiles(full_name, avatar_url, role)')
            .eq('trip_id', currentTrip.id)
            .eq('trip_date', date)
            .eq('status', 'confirmed');
        if (mounted) setState(() => _tripMembers = members as List);
      }
    } catch (_) {}
  }

  Future<void> _toggleSaved() async {
    await PreferencesService().toggleSavedTrip(currentTrip.id);
    _checkSavedStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 400,
              pinned: false,
              floating: true,
              flexibleSpace: FlexibleSpaceBar(background: _buildImageGallery()),
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      color: Colors.black.withOpacity(0.3),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context, _hasChanged),
                      ),
                    ),
                  ),
                ),
              ),
              actions: [
                if (_role == 'admin')
                  _buildAppBarAction(Icons.edit, () async {
                    final r = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (c) => EditTripScreen(trip: currentTrip),
                      ),
                    );
                    if (r == true) _refreshTrip();
                  }),
                _buildAppBarAction(
                  Icons.share,
                  () => Share.share(
                    'Check out ${currentTrip.title} on trekwithmussafirr!',
                  ),
                ),
                _buildAppBarAction(
                  _isSaved ? Icons.favorite : Icons.favorite_border,
                  _toggleSaved,
                  color: _isSaved ? Colors.red : Colors.white,
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 12),
                    _buildLocationAndOfficialActions(),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                preferredHeight: kTextTabBarHeight,
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: Theme.of(context).primaryColor,
                    unselectedLabelColor: Colors.grey,
                    indicatorWeight: 3,
                    indicatorSize: TabBarIndicatorSize.label,
                    tabs: [
                      const Tab(text: 'General'),
                      const Tab(text: 'Itinerary'),
                      const Tab(text: 'Inclusions'),
                      if (_isTrip) const Tab(text: 'Preparation'),
                      const Tab(text: 'Reviews'),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: _isLoading
            ? _buildShimmerBody()
            : Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverview(),
                    _buildItinerary(),
                    _buildInclusionsExclusions(),
                    if (_isTrip) _buildPreparationTab(),
                    TripReviewsSection(
                      tripId: currentTrip.id,
                      canReview: _canReview,
                    ),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildAppBarAction(
    IconData icon,
    VoidCallback onTap, {
    Color color = Colors.white,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Colors.black.withOpacity(0.3),
            child: IconButton(
              icon: Icon(icon, color: color),
              onPressed: onTap,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreparationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildProPreparationGuide(),
          const SizedBox(height: 24),
          _buildCarryList(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final double originalPrice = currentTrip.basePrice ?? 0.0;
    final double discountPrice = currentTrip.discountedPrice ?? 0.0;
    final bool hasDiscount = originalPrice > discountPrice;

    return FadeInUp(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              currentTrip.title,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (hasDiscount)
                Text(
                  '₹${originalPrice.toInt()}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    decoration: TextDecoration.lineThrough,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  '₹${discountPrice.toInt()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationAndOfficialActions() {
    return FadeInUp(
      delay: const Duration(milliseconds: 100),
      child: Row(
        children: [
          Icon(
            Icons.location_on,
            color: Theme.of(context).colorScheme.secondary,
            size: 20,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Row(
              children: [
                Text(
                  currentTrip.location,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    currentTrip.category.toUpperCase(),
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).primaryColor,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _detailsIconBtn(
            Icons.travel_explore,
            'FLYOVER',
            Colors.blue,
            _openFlyover,
          ),
          const SizedBox(width: 8),
          _detailsIconBtn(
            Icons.support_agent,
            'SUPPORT',
            Colors.blueGrey,
            _showSupportDetails,
          ),
        ],
      ),
    );
  }

  void _showSupportDetails() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Support coming soon')));
  }

  Widget _detailsIconBtn(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveActions() {
    return const SizedBox.shrink(); // Relocated to Itinerary Tab
  }

  void _openFlyover() {
    String url = '';

    if (currentTrip.googleMapLink != null &&
        currentTrip.googleMapLink!.isNotEmpty) {
      url = currentTrip.googleMapLink!;
    } else {
      // Fallback if no link is provided
      final query = Uri.encodeComponent(
        '${currentTrip.title} ${currentTrip.location}',
      );
      url = 'https://www.google.com/maps/search/?api=1&query=$query';
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => WebViewFlyoverScreen(url: url, title: 'Trip Flyover'),
      ),
    );
  }

  Future<void> _exportItineraryPdf() async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'trip RECORD',
                        style: pw.TextStyle(
                          color: PdfColors.blue900,
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      pw.Text(
                        currentTrip.title.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue900,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Text(
                      'OFFICIAL BRIEFING',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 0.5, color: PdfColors.grey300),
              pw.SizedBox(height: 10),
            ],
          ),
          footer: (context) => pw.Column(
            children: [
              pw.Divider(thickness: 0.5, color: PdfColors.grey300),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Generated by trekwithmussafirr App',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey,
                    ),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          build: (context) => [
            pw.Row(
              children: [
                _pdfStatBox('LOCATION', currentTrip.location),
                _pdfStatBox('DIFFICULTY', currentTrip.difficulty),
                _pdfStatBox('ALTITUDE', currentTrip.altitude),
                _pdfStatBox('DURATION', currentTrip.duration),
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Text(
              'OPERATIONAL OVERVIEW',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 13,
                color: PdfColors.blue800,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              currentTrip.description,
              style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
            ),

            pw.SizedBox(height: 24),
            pw.Text(
              'trip DAILY PLAN (ITINERARY)',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 13,
                color: PdfColors.blue800,
              ),
            ),
            pw.SizedBox(height: 12),
            ...currentTrip.itinerary
                .map(
                  (it) => pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 12),
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        left: pw.BorderSide(color: PdfColors.blue900, width: 3),
                      ),
                      color: PdfColors.grey50,
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'DAY ${it.day}: ${it.title}',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                            if (it.time.isNotEmpty)
                              pw.Text(
                                it.time,
                                style: pw.TextStyle(
                                  color: PdfColors.orange800,
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          it.description,
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey800,
                          ),
                        ),
                        if (it.distance.isNotEmpty)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(top: 4),
                            child: pw.Text(
                              'Distance Threshold: ${it.distance}',
                              style: pw.TextStyle(
                                color: PdfColors.blue,
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                )
                .toList(),

            pw.SizedBox(height: 24),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _pdfCheckList('INCLUSIONS', currentTrip.inclusions),
                ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  child: _pdfCheckList('GEAR TO CARRY', currentTrip.carryList),
                ),
              ],
            ),
          ],
        ),
      );

      final pdfBytes = await pdf.save();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Itinerary generated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  pw.Widget _pdfCheckList(String title, List<String> items) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        ...items.map(
          (e) => pw.Text('• $e', style: const pw.TextStyle(fontSize: 9)),
        ),
      ],
    );
  }

  void _showManagePackingList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GearChecklistScreen(
          tripId: currentTrip.id,
          tripTitle: currentTrip.title,
          carryList: currentTrip.carryList,
        ),
      ),
    );
  }

  Widget _buildPrecisionCompass() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const minItemWidth = 92.0;
          const gap = 14.0;
          final width = constraints.maxWidth;
          final columns = (width / (minItemWidth + gap)).floor().clamp(2, 5);
          final itemWidth = (width - (gap * (columns - 1))) / columns;

          return Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            spacing: gap,
            runSpacing: gap,
            children: [
              _techItem(
                Icons.terrain,
                'Altitude',
                currentTrip.altitude,
                itemWidth,
              ),
              _techItem(
                Icons.height,
                'Peak',
                currentTrip.peakElevation ?? 'N/A',
                itemWidth,
              ),
              _techItem(
                Icons.speed,
                'Difficulty',
                currentTrip.difficulty,
                itemWidth,
              ),
              _techItem(
                Icons.timer,
                'Duration',
                currentTrip.duration,
                itemWidth,
              ),
              _techItem(
                Icons.flag_outlined,
                'Start',
                currentTrip.startPoint ?? 'N/A',
                itemWidth,
              ),
              _techItem(
                Icons.explore_outlined,
                'Facing',
                currentTrip.orientation ?? 'North',
                itemWidth,
              ),
              _techItem(
                Icons.directions_walk,
                'Dist',
                currentTrip.totalDistance ?? '0km',
                itemWidth,
              ),
              _techItem(
                Icons.calendar_month,
                'Best Months',
                currentTrip.bestMonths ?? 'TBD',
                itemWidth,
              ),
              _techItem(
                Icons.inventory_2_outlined,
                'Type',
                currentTrip.packageType ?? 'Standard',
                itemWidth,
              ),
            ],
          );
        },
      ),
    );
  }

  pw.Widget _pdfStatBox(String title, String value) {
    return pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.only(right: 8),
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // Widget _buildPrecisionCompass() {
  //   return Container(
  //     padding: const EdgeInsets.all(16),
  //     decoration: BoxDecoration(
  //       color: Theme.of(context).cardColor,
  //       borderRadius: BorderRadius.circular(16),
  //     ),
  //     child: Row(
  //       mainAxisAlignment: MainAxisAlignment.spaceAround,
  //       children: [
  //         _techItem(Icons.terrain, 'Altitude', currentTrip.altitude),
  //         _techItem(Icons.speed, 'Difficulty', currentTrip.difficulty),
  //         _techItem(Icons.timer, 'Duration', currentTrip.duration),
  //       ],
  //     ),
  //   );
  // }
  Future<void> _exportItineraryImage() async {
    try {
      final image = await _screenshotController.captureFromWidget(
        Material(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'trip ITINERARY',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF0D47A1),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  currentTrip.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  currentTrip.location,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 30),
                const Divider(),
                const SizedBox(height: 20),
                ...currentTrip.itinerary
                    .map(
                      (it) => Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: Color(0xFF0D47A1),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${it.day}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          it.title,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                      if (it.time.isNotEmpty)
                                        Text(
                                          it.time,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    it.description,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  if (it.distance.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'DISTANCE: ${it.distance}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                const SizedBox(height: 30),
                const Divider(),
                const SizedBox(height: 10),
                const Center(
                  child: Text(
                    'Booked via trekwithmussafirr App',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final directory = await getApplicationDocumentsDirectory();
      final imagePath = await File(
        '${directory.path}/${currentTrip.id}_itinerary.png',
      ).create();
      await imagePath.writeAsBytes(image);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Itinerary image saved to documents!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'SHARE',
              textColor: Colors.white,
              onPressed: () {
                Share.shareXFiles([
                  XFile(imagePath.path),
                ], text: 'Check out my itinerary for ${currentTrip.title}!');
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export image: $e'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  void _showReadinessQuiz() {
    final Map<int, bool> answers = {0: false, 1: false, 2: false, 3: false};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Trip Readiness Quiz',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
                ),
                const SizedBox(height: 10),
                Text(
                  'Assess your preparation for ${currentTrip.title}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 30),
                _quizItem(
                  _isTrip
                      ? 'Can you trip 10km with a 5kg pack?'
                      : 'Do you have valid travel documents?',
                  _isTrip ? Icons.fitness_center : Icons.description_outlined,
                  answers[0]!,
                  (v) => setSheetState(() => answers[0] = v!),
                ),
                _quizItem(
                  _isTrip
                      ? 'Have you trained at 2000m+ before?'
                      : 'Have you checked local weather?',
                  _isTrip ? Icons.terrain : Icons.wb_sunny_outlined,
                  answers[1]!,
                  (v) => setSheetState(() => answers[1] = v!),
                ),
                _quizItem(
                  'Do you have valid travel insurance?',
                  Icons.security,
                  answers[2]!,
                  (v) => setSheetState(() => answers[2] = v!),
                ),
                _quizItem(
                  _isTrip
                      ? 'Can you sustain 5km/hr for 30 mins?'
                      : 'Are you ready for the journey?',
                  Icons.bolt,
                  answers[3]!,
                  (v) => setSheetState(() => answers[3] = v!),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {
                    final score =
                        (answers.values.where((v) => v).length /
                            answers.length) *
                        100;
                    Navigator.pop(context);
                    _showSimulatedAction(
                      'Assessment Complete: You are ${score.toInt()}% ready for this trip!',
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    'CALCULATE MY SCORE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _quizItem(
    String question,
    IconData icon,
    bool value,
    Function(bool?) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              question,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Checkbox(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _actionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: BorderSide(color: color.withOpacity(0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSimulatedAction(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildFallbackCover() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Opacity(
          opacity: 0.25,
          child: Image.asset(
            'assets/images/app_logo.png',
            fit: BoxFit.contain,
            width: 160,
          ),
        ),
      ),
    );
  }

  Widget _buildImageGallery() {
    final images = [
      if (currentTrip.imageUrl.isNotEmpty) currentTrip.imageUrl,
      ...currentTrip.images.where((img) => img.isNotEmpty),
    ];
    // Show a single fallback slot if no images at all
    final displayImages = images.isEmpty ? [''] : images;

    return Stack(
      children: [
        PageView.builder(
          itemCount: displayImages.length,
          onPageChanged: (index) => setState(() => _currentImageIndex = index),
          itemBuilder: (context, index) {
            final imageUrl = displayImages[index];
            if (imageUrl.isEmpty) {
              return _buildFallbackCover();
            }
            return Hero(
              tag: index == 0
                  ? (widget.heroTag ?? 'trip_image_${currentTrip.id}')
                  : 'trip_image_extra_${currentTrip.id}_$index',
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: Colors.grey[200]),
                errorWidget: (context, url, error) => _buildFallbackCover(),
              ),
            );
          },
        ),
        // Dot indicators — pill for active, circle for inactive
        if (displayImages.length > 1)
          Positioned(
            bottom: 44,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                displayImages.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: _currentImageIndex == index ? 20 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: _currentImageIndex == index
                        ? Colors.white
                        : Colors.white.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),

        Positioned(
          bottom: 20,
          left: 20,
          right: 20, // <-- give Row full width to work with
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween, // <-- push ends apart
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      currentTrip.rating.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.image_outlined,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${images.length} Photos',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherSection() {
    // Simulated weather based on location altitude/region
    int temp = 12;
    if (currentTrip.altitude.contains('4,000') ||
        currentTrip.altitude.contains('5,000'))
      temp = -2;
    else if (currentTrip.location.toLowerCase().contains('himachal') ||
        currentTrip.location.toLowerCase().contains('uttarakhand'))
      temp = 8;

    return FadeIn(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_queue, color: Colors.blue, size: 28),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Base Camp Weather',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  Text(
                    '${temp}°C • Clear Skies • No Rain',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInclusionsExclusions() {
    final inclusions = currentTrip.inclusions;
    final exclusions = currentTrip.exclusions;

    if (inclusions.isEmpty && exclusions.isEmpty) {
      return const Center(
        child: Text(
          'N/A - Information not provided',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (inclusions.isNotEmpty)
            _buildCheckList('What is Included', inclusions, Colors.green),
          if (inclusions.isNotEmpty && exclusions.isNotEmpty)
            const SizedBox(height: 24),
          if (exclusions.isNotEmpty)
            _buildCheckList(
              'What is Not Included',
              exclusions,
              Colors.redAccent,
            ),
        ],
      ),
    );
  }

  Widget _buildCheckList(String title, List<String> items, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 12),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Icon(
                  color == Colors.green
                      ? Icons.check_circle_outline
                      : Icons.cancel_outlined,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.blueGrey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCarryList() {
    final items = currentTrip.carryList;

    if (items.isEmpty) {
      return const Center(
        child: Text(
          'N/A - Carry list not provided',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Essential Carry List',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 12),
          Text(
            'Everything you need for the ${currentTrip.title} adventure.',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 16),
          _buildCarryListGrid(),
        ],
      ),
    );
  }

  Widget _buildCarryListGrid() {
    return FutureBuilder<Map<String, int>>(
      future: _getGearProgressCounts(),
      builder: (context, snapshot) {
        final data =
            snapshot.data ??
            {
              'packed': 0,
              'total': currentTrip.carryList.isNotEmpty
                  ? currentTrip.carryList.length
                  : 6,
            };
        int checked = data['packed']!;
        int total = data['total']!;
        double progress = total == 0 ? 0.0 : checked / total;
        final items = currentTrip.carryList.isNotEmpty
            ? currentTrip.carryList
            : [
                'Tripking Shoes',
                'Rucksack',
                'Headtorch',
                'Layered Clothing',
                'Tripking Poles',
                'Medical Kit',
              ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                ),
              ),
              child: Row(
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
                    ),
                    strokeWidth: 8,
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${(progress * 100).toInt()}% READY',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        '$checked of $total items packed',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: () => setState(() {}),
                  ),
                ],
              ),
            ),
            if (Supabase.instance.client.auth.currentUser != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _showManagePackingList(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                icon: const Icon(Icons.inventory_2_outlined, size: 18),
                label: const Text(
                  'MANAGE MY PACKING LIST',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'trip READINESS: GEAR GRID',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1.5,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: 60,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blueAccent.withOpacity(0.05),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildConsolidatedTechnicalInfo() {
    return FadeInUp(
      delay: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildPrecisionCompass(),
            const SizedBox(height: 16), // Reduced space
            const Divider(),
            const SizedBox(height: 20),
            _buildInteractiveActions(),
          ],
        ),
      ),
    );
  }

  Widget _techItem(IconData icon, String label, String value, double width) {
    return SizedBox(
      width: width,
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text(_isTrip ? 'Trip Coordinates' : 'Location Highlights', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          // const SizedBox(height: 4),
          _buildPrecisionCompass(),
          const SizedBox(height: 16),
          if (_isTrip) _buildSeasonalOutlook(),
          const SizedBox(height: 24),
          if (currentTrip.packages.isNotEmpty) _buildPackagesSection(),
          // const SizedBox(height: 24),
          const Text(
            'TRIP STORY',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            currentTrip.description,
            style: const TextStyle(color: Colors.blueGrey, height: 1.6),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPackagesSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'trip PACKAGES',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...currentTrip.packages
            .map(
              (pkg) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey.shade100,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        color: Colors.blueAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pkg.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            pkg.description,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₹${pkg.price.toInt()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ],
    );
  }

  Widget _buildSquadInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'YOUR SQUAD',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.blue.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.group_outlined, color: Colors.blueAccent),
                  const SizedBox(width: 12),
                  Text(
                    '${_tripMembers.length} Members in this batch',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (c) => const MyTripsScreen()),
                    ),
                    child: const Text(
                      'VIEW DETAILS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (_tripMembers.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _tripMembers.length,
                    itemBuilder: (ctx, i) {
                      final m = _tripMembers[i];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: UserAvatar(name: m['full_name'], radius: 18),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<Map<String, int>> _getGearProgressCounts() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return {'packed': 0, 'total': 0};
    try {
      final res = await Supabase.instance.client
          .from('gear_checklists')
          .select('id, is_packed')
          .eq('user_id', user.id)
          .eq('trip_id', currentTrip.id);

      final list = res as List;
      if (list.isEmpty) {
        return {'packed': 0, 'total': currentTrip.carryList.length};
      }
      int packed = list.where((item) => item['is_packed'] == true).length;
      return {'packed': packed, 'total': list.length};
    } catch (_) {
      return {'packed': 0, 'total': currentTrip.carryList.length};
    }
  }

  Widget _buildProPreparationGuide() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int temp = 8;
    if (currentTrip.altitude.contains('4,000') ||
        currentTrip.altitude.contains('5,000')) {
      temp = -5;
    } else if (currentTrip.altitude == 'N/A' || currentTrip.altitude.isEmpty) {
      temp = 15; // Default for non-altitude trips
    }

    return FutureBuilder<Map<String, int>>(
      future: _getGearProgressCounts(),
      builder: (context, snapshot) {
        final data =
            snapshot.data ??
            {
              'packed': 0,
              'total': currentTrip.carryList.isNotEmpty
                  ? currentTrip.carryList.length
                  : 6,
            };
        int checked = data['packed']!;
        int total = data['total']!;
        double progress = total == 0 ? 0.0 : checked / total;

        return Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18181B) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.03),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'trip PREPARATION',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Trip Briefing & Stamina Goals',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.greenAccent.withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.greenAccent,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress > 0.8 ? Colors.greenAccent : Colors.orangeAccent,
                  ),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 24),
              _proPrepItem(
                Icons.thermostat,
                'Altitude Temp Cap:',
                '${temp}°C',
                temp < 0
                    ? 'Sub-zero gear thermal rating mandatory.'
                    : 'Standard thermal layering recommended.',
              ),
              const SizedBox(height: 16),
              _proPrepItem(
                Icons.fitness_center,
                'Cardio Threshold:',
                currentTrip.difficulty.toLowerCase().contains('hard')
                    ? '10km / 50m'
                    : '5km / 30m',
                'Target stamina for ${currentTrip.difficulty.toLowerCase()} terrain.',
              ),
              const SizedBox(height: 16),
              _proPrepItem(
                Icons.water_drop,
                'Hydration Plan:',
                temp < 5 ? '4-5 Ltrs/Day' : '3-4 Ltrs/Day',
                'Crucial for altitude acclimatization.',
              ),
              const SizedBox(height: 16),
              _proPrepItem(
                Icons.medical_services_outlined,
                'Acclimatization:',
                '${(double.tryParse(currentTrip.altitude.replaceAll(RegExp(r'[^0-9]'), '')) ?? 3000) / 10}m Ascent',
                'Daily elevation gain limit for safety.',
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'REQUIRED DOCUMENTS',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1.5,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (c) =>
                        DeclarationFormScreen(tripTitle: currentTrip.title),
                  ),
                ),
                icon: const Icon(Icons.draw_outlined),
                label: const Text('SIGN RISK DECLARATION'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Declaration must be signed in-app before departure.',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'TERMS & CONDITIONS',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1.5,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                currentTrip.termsConditions?.isNotEmpty == true
                    ? currentTrip.termsConditions!
                    : 'Standard company terms and conditions apply.',
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'CANCELLATION POLICY',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1.5,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                currentTrip.cancellationPolicy?.isNotEmpty == true
                    ? currentTrip.cancellationPolicy!
                    : 'Standard cancellation policies apply. Contact support for details.',
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _proPrepItem(IconData icon, String label, String value, String tip) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: Theme.of(context).primaryColor),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).primaryColor,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                tip,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSeasonalOutlook() {
    if (currentTrip.seasonalInfo.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Seasonal Climate Outlook',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 280,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: currentTrip.seasonalInfo.entries.map((entry) {
              return _seasonCard(
                entry.key.toUpperCase(),
                entry.value.toString(),
                _getSeasonalTemp(entry.key),
                _getSeasonalColor(entry.key),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _getSeasonalTemp(String month) {
    switch (month.toLowerCase()) {
      case 'dec':
      case 'jan':
      case 'feb':
        return '-5°C to 5°C';
      case 'mar':
      case 'apr':
      case 'may':
        return '10°C to 20°C';
      case 'jun':
      case 'jul':
      case 'aug':
        return '15°C to 25°C';
      default:
        return '5°C to 15°C';
    }
  }

  Color _getSeasonalColor(String month) {
    switch (month.toLowerCase()) {
      case 'dec':
      case 'jan':
      case 'feb':
        return Colors.blue;
      case 'mar':
      case 'apr':
      case 'may':
        return Colors.orange;
      case 'jun':
      case 'jul':
      case 'aug':
        return Colors.green;
      default:
        return Colors.cyan;
    }
  }

  Widget _seasonCard(String month, String note, String temp, Color color) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            month,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note,
            style: const TextStyle(fontSize: 10, color: Colors.blueGrey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Text(
            temp,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildItinerary() {
    return Screenshot(
      controller: _screenshotController,
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Expanded(
                  child: _actionButton(
                    Icons.image_outlined,
                    'EXPORT IMAGE',
                    Colors.orangeAccent,
                    _exportItineraryImage,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _actionButton(
                    Icons.picture_as_pdf_outlined,
                    'EXPORT PDF',
                    Colors.redAccent,
                    _exportItineraryPdf,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            ...List.generate(currentTrip.itinerary.length, (index) {
              final step = currentTrip.itinerary[index];

              return FadeInLeft(
                delay: Duration(milliseconds: 50 * index),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Column(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: Theme.of(context).primaryColor,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          Expanded(
                            child: VerticalDivider(
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.3),
                              thickness: 2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),

                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      step.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  if (step.time.isNotEmpty)
                                    Text(
                                      step.time,
                                      style: const TextStyle(
                                        color: Colors.orange,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),

                              Text(
                                step.description,
                                style: const TextStyle(color: Colors.grey),
                              ),

                              if (step.distance.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.directions_walk,
                                        size: 14,
                                        color: Colors.blueAccent,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        step.distance,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.blueAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () => _showBookingSheet(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Text(
          _isTrip ? 'Book Your Adventure' : 'Secure Your Package',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // Future<void> _checkBookingAndFetchMembers() async {
  //   final user = Supabase.instance.client.auth.currentUser;
  //   if (user == null) return;
  //   try {
  //     final res = await Supabase.instance.client.from('bookings').select('group_id').eq('trip_id', currentTrip.id).eq('user_id', user.id).maybeSingle();
  //     if (res != null && mounted) {
  //       setState(() => _isBooked = true);
  //       final members = await Supabase.instance.client.from('bookings').select('full_name, user_id').eq('trip_id', currentTrip.id);
  //       if (mounted) setState(() => _tripMembers = members);
  //     }
  //   } catch (_) {}
  // }

  Future<Map<String, int>> _fetchBatchAvailability() async {
    try {
      final res = await Supabase.instance.client
          .from('bookings')
          .select('trip_date')
          .eq('trip_id', currentTrip.id);
      Map<String, int> counts = {};
      for (var row in res) {
        String d = DateFormat(
          'yyyy-MM-dd',
        ).format(DateTime.parse(row['trip_date']));
        counts[d] = (counts[d] ?? 0) + 1;
      }
      return counts;
    } catch (e) {
      return {};
    }
  }

  Widget _buildOtherDatePicker(
    BuildContext context,
    DateTime selectedDate,
    Function(DateTime) onSelected,
  ) {
    return GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: selectedDate,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (d != null) onSelected(d);
      },
      child: Container(
        width: 100,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.calendar_today, size: 20, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'OTHER DATE',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBookingSheet(BuildContext context) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in or register to book your adventure.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (c) => const LoginScreen()),
      );
      return;
    }
    final freshTrip = await DatabaseService().fetchTripById(currentTrip.id);
    if (freshTrip != null && mounted) {
      setState(() {
        _trip = freshTrip;
        _hasChanged = true;
      });
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return TripBookingSheet(
          trip: currentTrip,
          isTrip: _isTrip,
          onConfirm:
              (
                total,
                tripFee,
                pickupFee,
                pickupLoc,
                date,
                addons,
                gears,
                name,
                phone,
                email,
                pax,
                additional,
                payMethod,
                payProof,
                redeemPoints,
                pointsRedeemed,
              ) {
                Navigator.pop(context);
                _showMockPaymentFlow(
                  total,
                  tripFee,
                  pickupFee,
                  pickupLoc,
                  date,
                  addons,
                  gears,
                  name,
                  phone,
                  email,
                  pax,
                  additional,
                  payMethod,
                  payProof,
                  redeemPoints,
                  pointsRedeemed,
                );
              },
        );
      },
    );
  }

  void _showMockPaymentFlow(
    double total,
    double tripFee,
    double pickupFee,
    String pickupLocation,
    DateTime date,
    Map<String, int> gearAddons,
    List<Gear> gears,
    String name,
    String phone,
    String email,
    int pax,
    List<Map<String, dynamic>> additionalTravelers,
    String payMethod,
    String? payProof,
    bool redeemPoints,
    int pointsRedeemed,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: MockPaymentFlow(
          total: total,
          onComplete: () {
            Navigator.pop(c);
            _confirmBooking(
              total,
              tripFee,
              pickupFee,
              pickupLocation,
              date,
              gearAddons,
              gears,
              name,
              phone,
              email,
              pax,
              additionalTravelers,
              payMethod,
              payProof,
              redeemPoints,
              pointsRedeemed,
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmBooking(
    double total,
    double tp,
    double pp,
    String loc,
    DateTime date,
    Map<String, int> addons,
    List<Gear> allGears,
    String hikerName,
    String hikerPhone,
    String hikerEmail,
    int pax,
    List<Map<String, dynamic>> additionalTravelers,
    String payMethod,
    String? payProof,
    bool redeemPoints,
    int pointsRedeemed,
  ) async {
    showDialog(
      context: context,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    final formattedAddons = addons.entries
        .map(
          (e) => {
            'gear_id': e.key,
            'quantity': e.value,
            'price':
                allGears.firstWhere((g) => g.id == e.key).pricePerDay *
                int.parse(currentTrip.duration.split(' ')[0]),
          },
        )
        .toList();

    final user = Supabase.instance.client.auth.currentUser;
    String? currentUserId = user?.id;

    final String? groupId = await DatabaseService().bookTrip(
      tripId: currentTrip.id,
      fullName: hikerName,
      phoneNumber: hikerPhone,
      hikerEmail: hikerEmail,
      userId: currentUserId,
      pax: pax,
      tripTitle: currentTrip.title,
      tripDate: date,
      tripPrice: tp,
      pickupPrice: pp,
      pickupLocation: loc,
      totalPrice: total,
      addons: formattedAddons,
      additionalTravelers: additionalTravelers,
      paymentMethod: payMethod,
      paymentProof: payProof,
    );
    if (mounted) Navigator.pop(context);

    if (groupId != null && mounted) {
      // ── Reward points ledger writes ───────────────────────────────────
      if (currentUserId != null) {
        try {
          // 1. Debit redeemed points (if user chose to redeem)
          if (redeemPoints && pointsRedeemed > 0) {
            await Supabase.instance.client.from('reward_ledger').insert({
              'user_id': currentUserId,
              'points': pointsRedeemed,
              'type': 'debit',
              'description':
                  'Points redeemed for ₹${(pointsRedeemed / 10).toStringAsFixed(0)} discount on ${currentTrip.title}',
              'reference_id': groupId,
              'created_at': DateTime.now().toIso8601String(),
            });
            // Push debit notification
            await Supabase.instance.client.from('notifications').insert({
              'user_id': currentUserId,
              'title': '🏆 Reward Points Redeemed',
              'body':
                  'You redeemed $pointsRedeemed points (₹${(pointsRedeemed / 10).toStringAsFixed(0)} off) on your booking for ${currentTrip.title}.',
              'category': 'reward',
              'is_read': false,
              'created_at': DateTime.now().toIso8601String(),
            });
          }
          // 2. Credit earned reward points (trip-level, after booking)
          final pointsToEarn = currentTrip.rewardPoints * pax;
          if (pointsToEarn > 0) {
            await Supabase.instance.client.from('reward_ledger').insert({
              'user_id': currentUserId,
              'points': pointsToEarn,
              'type': 'credit',
              'description':
                  'Earned $pointsToEarn points for booking ${currentTrip.title}',
              'reference_id': groupId,
              'created_at': DateTime.now().toIso8601String(),
            });
            // Push credit notification
            await Supabase.instance.client.from('notifications').insert({
              'user_id': currentUserId,
              'title': '🏆 +$pointsToEarn Reward Points Earned!',
              'body':
                  'Congrats! You earned $pointsToEarn reward points for booking ${currentTrip.title}. View your balance in the Wallet.',
              'category': 'reward',
              'is_read': false,
              'created_at': DateTime.now().toIso8601String(),
            });
          }
          final profile = await Supabase.instance.client
              .from('profiles')
              .select('reward_points')
              .eq('id', currentUserId)
              .maybeSingle();
          final currentBalance =
              int.tryParse((profile?['reward_points'] ?? 0).toString()) ?? 0;
          final updatedBalance =
              (currentBalance -
                      (redeemPoints ? pointsRedeemed : 0) +
                      pointsToEarn)
                  .clamp(0, 1 << 31)
                  .toInt();
          await Supabase.instance.client
              .from('profiles')
              .update({'reward_points': updatedBalance})
              .eq('id', currentUserId);
        } catch (e) {
          debugPrint('Reward ledger write error: $e');
        }
      }

      _showBookingSuccess(groupId);
      _checkBookingAndFetchMembers();

      InvoiceService.generateAndDownloadInvoice(
        bookingId: groupId,
        tripName: currentTrip.title,
        date: date,
        hikerName: hikerName,
        totalPrice: total,
        basePrice: tp,
        pickupPrice: pp,
        pickupLocation: loc,
        email: hikerEmail,
      );

      if (payMethod == 'WhatsApp') {
        WhatsAppService.contactAdminForPayment(
          hikerName: hikerName,
          tripName: currentTrip.title,
          bookingId: groupId,
          method: payMethod,
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking failed. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showBookingSuccess(String groupId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Booking Confirmed!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your adventure starts soon. You have been added to the official group chat.',
              textAlign: TextAlign.center,
            ),
            if (currentTrip.travelerFormUrl != null &&
                currentTrip.travelerFormUrl!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Action Required',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Please fill out the traveler details form for your safety and preparation.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () =>
                          launchUrl(Uri.parse(currentTrip.travelerFormUrl!)),
                      icon: const Icon(Icons.assignment, size: 16),
                      label: const Text(
                        'FILL DETAILS',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 36),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(c);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => ChatScreen(
                    roomId: groupId,
                    title: '${currentTrip.title} Group',
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('OPEN GROUP CHAT'),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerBody() {
    return GlassShimmer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ShimmerBlock(width: 150, height: 20),
            const SizedBox(height: 20),
            const ShimmerBlock(
              width: double.infinity,
              height: 100,
              borderRadius: 15,
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                3,
                (i) =>
                    const ShimmerBlock(width: 80, height: 80, borderRadius: 15),
              ),
            ),
            const SizedBox(height: 40),
            ...List.generate(
              4,
              (i) => const ShimmerBlock(
                width: double.infinity,
                height: 12,
                margin: EdgeInsets.only(bottom: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate({required this.child, required this.preferredHeight});

  final Widget child;
  final double preferredHeight;

  @override
  double get minExtent =>
      preferredHeight +
      (WidgetsBinding.instance.platformDispatcher.implicitView?.padding.top ??
              44) /
          (WidgetsBinding
                  .instance
                  .platformDispatcher
                  .implicitView
                  ?.devicePixelRatio ??
              1);

  @override
  double get maxExtent =>
      preferredHeight +
      (WidgetsBinding.instance.platformDispatcher.implicitView?.padding.top ??
              44) /
          (WidgetsBinding
                  .instance
                  .platformDispatcher
                  .implicitView
                  ?.devicePixelRatio ??
              1);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(top: true, bottom: false, child: child),
    );
  }

  @override
  bool shouldRebuild(covariant _SliverAppBarDelegate oldDelegate) => false;
}
