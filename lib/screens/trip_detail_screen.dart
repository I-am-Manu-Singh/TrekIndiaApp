import 'dart:ui';
import '../widgets/glass_shimmer.dart';
import 'dart:io';
import 'package:flutter/services.dart';
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
                  _showExportItineraryOptions,
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.location_on,
            color: Theme.of(context).colorScheme.secondary,
            size: 20,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                Text(
                  currentTrip.location,
                  style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    currentTrip.category.toUpperCase(),
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _detailsIconBtn(
            Icons.travel_explore,
            'FLYOVER',
            Colors.blue,
            _openFlyover,
          ),
          const SizedBox(width: 6),
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

  void _showExportItineraryOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E24) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'EXPORT ITINERARY',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: 1,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.share_outlined, color: Colors.blueAccent),
              ),
              title: const Text('Share Trip Link & Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Send direct booking & expedition overview link to friends', style: TextStyle(fontSize: 11, color: Colors.grey)),
              onTap: () {
                Navigator.pop(ctx);
                Share.share('Check out ${currentTrip.title} (${currentTrip.duration}) on trekwithmussafirr! Book your slot now.');
              },
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.picture_as_pdf_outlined, color: Colors.redAccent),
              ),
              title: const Text('Export Official PDF Document', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Complete briefing with inclusions, carry list, & company seal', style: TextStyle(fontSize: 11, color: Colors.grey)),
              onTap: () {
                Navigator.pop(ctx);
                _exportItineraryPdf();
              },
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.image_outlined, color: Colors.orangeAccent),
              ),
              title: const Text('Export High-Res Image Graphic', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Sharable poster format for WhatsApp, Stories & Social Media', style: TextStyle(fontSize: 11, color: Colors.grey)),
              onTap: () {
                Navigator.pop(ctx);
                _exportItineraryImage();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _exportItineraryPdf() async {
    try {
      final pdf = pw.Document();
      pw.MemoryImage? logoImage;
      try {
        final logoData = await rootBundle.load('assets/images/app_logo.png');
        logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
      } catch (_) {}

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          header: (context) => pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Row(
                    children: [
                      if (logoImage != null) ...[
                        pw.Image(logoImage, width: 36, height: 36),
                        pw.SizedBox(width: 10),
                      ],
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'trekwithmussafirr',
                            style: pw.TextStyle(
                              color: PdfColors.red900,
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          pw.Text(
                            'Official Trip Briefing & Master Itinerary',
                            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.red900,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          currentTrip.category.toUpperCase(),
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 7.5,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
                        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 0.5, color: PdfColors.grey300),
              pw.SizedBox(height: 8),
            ],
          ),
          footer: (context) => pw.Column(
            children: [
              pw.Divider(thickness: 0.5, color: PdfColors.grey300),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'trekwithmussafirr • 383 street no. 11 Rajendra Nagar, Shiv Complex, Dehradun • mussafirr1@gmail.com',
                    style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
                  ),
                ],
              ),
            ],
          ),
          build: (context) => [
            pw.Text(
              currentTrip.title.toUpperCase(),
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              children: [
                _pdfStatBox('LOCATION', currentTrip.location),
                _pdfStatBox('DIFFICULTY', currentTrip.difficulty),
                _pdfStatBox('ALTITUDE', currentTrip.altitude),
                _pdfStatBox('DURATION', currentTrip.duration),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              children: [
                _pdfStatBox('BASE PRICE', 'INR ${currentTrip.basePrice.toInt()}'),
                _pdfStatBox('START POINT', currentTrip.startPoint ?? 'Dehradun'),
                _pdfStatBox('TOTAL DIST.', currentTrip.totalDistance ?? 'N/A'),
                _pdfStatBox('BEST MONTHS', currentTrip.bestMonths.isNotEmpty ? currentTrip.bestMonths : 'All Year'),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Trip Overview & Route',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
                color: PdfColors.red900,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              (currentTrip.tripStory != null && currentTrip.tripStory!.isNotEmpty)
                  ? currentTrip.tripStory!
                  : currentTrip.description,
              style: const pw.TextStyle(fontSize: 8.5, lineSpacing: 1.5, color: PdfColors.grey800),
            ),

            if (currentTrip.pickupOptions.isNotEmpty) ...[
              pw.SizedBox(height: 14),
              pw.Text(
                'AVAILABLE PICKUP & TRANSPORT HUBS',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.red900),
              ),
              pw.SizedBox(height: 6),
              pw.Wrap(
                spacing: 8,
                runSpacing: 6,
                children: currentTrip.pickupOptions
                    .map(
                      (p) => pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey100,
                          borderRadius: pw.BorderRadius.circular(4),
                          border: pw.Border.all(color: PdfColors.grey300),
                        ),
                        child: pw.Text(
                          '${p.location}: INR ${p.price.toInt()}',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey800),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],

            pw.SizedBox(height: 16),
            pw.Text(
              'DAY-BY-DAY ITINERARY',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
                color: PdfColors.red900,
              ),
            ),
            pw.SizedBox(height: 8),
            ...currentTrip.itinerary
                .map(
                  (it) {
                    // Extract parameters for PDF chips
                    String? distChip = it.distance.isNotEmpty ? it.distance : null;
                    if (distChip == null || distChip.isEmpty) {
                      final kmMatch = RegExp(r'(\d+(?:\.\d+)?(?:\s*[-–to]+\s*\d+(?:\.\d+)?)?)\s*km', caseSensitive: false).firstMatch(it.description);
                      if (kmMatch != null) distChip = '${kmMatch.group(1)} km';
                    }

                    String? timeChip = it.time.isNotEmpty ? it.time : null;
                    if (timeChip == null || timeChip.isEmpty) {
                      final hrsMatch = RegExp(r'(\d+(?:\.\d+)?(?:\s*[-–to]+\s*\d+(?:\.\d+)?)?)\s*(?:hrs|hours|hour|hr)\b', caseSensitive: false).firstMatch(it.description);
                      if (hrsMatch != null) timeChip = '${hrsMatch.group(1)} hrs';
                    }

                    String? altChip;
                    final altMatch = RegExp(r'(\d+(?:,\d+)?(?:\s*[-–to]+\s*\d+(?:,\d+)?)?)\s*(ft|feet|m|meters|meter)\b', caseSensitive: false).firstMatch(it.description);
                    if (altMatch != null) {
                      altChip = '${altMatch.group(1)} ${altMatch.group(2)}';
                    }

                    return pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 8),
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey50,
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            children: [
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: const pw.BoxDecoration(
                                  color: PdfColors.red900,
                                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                                ),
                                child: pw.Text(
                                  'DAY ${it.day}',
                                  style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontSize: 7.5,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ),
                              pw.SizedBox(width: 6),
                              pw.Expanded(
                                child: pw.Text(
                                  it.title.isNotEmpty ? it.title : 'Stage ${it.day}',
                                  style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 9,
                                    color: PdfColors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (distChip != null || timeChip != null || altChip != null) ...[
                            pw.SizedBox(height: 4),
                            pw.Row(
                              children: [
                                if (distChip != null) ...[
                                  pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                    decoration: pw.BoxDecoration(
                                      color: PdfColors.blue50,
                                      border: pw.Border.all(color: PdfColors.blue200),
                                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                                    ),
                                    child: pw.Text(
                                      'Dist: $distChip',
                                      style: const pw.TextStyle(color: PdfColors.blue800, fontSize: 6.5),
                                    ),
                                  ),
                                  pw.SizedBox(width: 4),
                                ],
                                if (timeChip != null) ...[
                                  pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                    decoration: pw.BoxDecoration(
                                      color: PdfColors.orange50,
                                      border: pw.Border.all(color: PdfColors.orange200),
                                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                                    ),
                                    child: pw.Text(
                                      'Time: $timeChip',
                                      style: const pw.TextStyle(color: PdfColors.orange900, fontSize: 6.5),
                                    ),
                                  ),
                                  pw.SizedBox(width: 4),
                                ],
                                if (altChip != null) ...[
                                  pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                    decoration: pw.BoxDecoration(
                                      color: PdfColors.purple50,
                                      border: pw.Border.all(color: PdfColors.purple200),
                                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                                    ),
                                    child: pw.Text(
                                      'Alt: $altChip',
                                      style: const pw.TextStyle(color: PdfColors.purple900, fontSize: 6.5),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                          pw.SizedBox(height: 3),
                          pw.Text(
                            it.description,
                            style: const pw.TextStyle(
                              fontSize: 7.5,
                              color: PdfColors.grey800,
                              lineSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                )
                .toList(),

            pw.SizedBox(height: 16),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (currentTrip.inclusions.isNotEmpty)
                  pw.Expanded(
                    child: _pdfCheckList('INCLUSIONS', currentTrip.inclusions),
                  ),
                if (currentTrip.exclusions.isNotEmpty) ...[
                  pw.SizedBox(width: 14),
                  pw.Expanded(
                    child: _pdfCheckList('EXCLUSIONS', currentTrip.exclusions),
                  ),
                ],
                if (currentTrip.carryList.isNotEmpty) ...[
                  pw.SizedBox(width: 14),
                  pw.Expanded(
                    child: _pdfCheckList('GEAR TO CARRY', currentTrip.carryList),
                  ),
                ],
              ],
            ),
          ],
        ),
      );

      final pdfBytes = await pdf.save();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: '${currentTrip.title.replaceAll(' ', '_')}_Itinerary.pdf',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Official Itinerary document generated!'),
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
              if (currentTrip.minHeight != null && currentTrip.minHeight!.isNotEmpty)
                _techItem(
                  Icons.arrow_downward,
                  'Min Height',
                  currentTrip.minHeight!,
                  itemWidth,
                ),
              if (currentTrip.maxHeight != null && currentTrip.maxHeight!.isNotEmpty)
                _techItem(
                  Icons.arrow_upward,
                  'Max Height',
                  currentTrip.maxHeight!,
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
              if (currentTrip.endPoint != null && currentTrip.endPoint!.isNotEmpty)
                _techItem(
                  Icons.sports_score_outlined,
                  'End',
                  currentTrip.endPoint!,
                  itemWidth,
                ),
              if (currentTrip.district != null && currentTrip.district!.isNotEmpty)
                _techItem(
                  Icons.location_city,
                  'District',
                  currentTrip.district!,
                  itemWidth,
                ),
              if (currentTrip.state != null && currentTrip.state!.isNotEmpty)
                _techItem(
                  Icons.map,
                  'State',
                  currentTrip.state!,
                  itemWidth,
                ),
              _techItem(
                Icons.directions_walk,
                'Distance',
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
                'Category',
                currentTrip.packageType ?? currentTrip.category,
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

  Widget _imgStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  Future<void> _exportItineraryImage() async {
    try {
      final image = await _screenshotController.captureFromWidget(
        Material(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Image.asset('assets/images/app_logo.png', width: 36, height: 36),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'trekwithmussafirr',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFFD32F2F),
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                            Text(
                              'Explore the Unexplored • Master Itinerary',
                              style: TextStyle(fontSize: 9, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD32F2F),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        currentTrip.category.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  currentTrip.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Color(0xFFD32F2F)),
                    const SizedBox(width: 4),
                    Text(
                      currentTrip.location,
                      style: const TextStyle(fontSize: 13, color: Colors.blueGrey, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _imgStat('ALTITUDE', currentTrip.altitude),
                      _imgStat('DURATION', currentTrip.duration),
                      _imgStat('DIFFICULTY', currentTrip.difficulty),
                      _imgStat('PRICE', '₹${currentTrip.basePrice.toInt()}'),
                    ],
                  ),
                ),
                if (currentTrip.description.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'ROUTE & EXPEDITION BRIEFING',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFFD32F2F), letterSpacing: 1),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (currentTrip.tripStory != null && currentTrip.tripStory!.isNotEmpty)
                        ? currentTrip.tripStory!
                        : currentTrip.description,
                    style: const TextStyle(fontSize: 10.5, color: Colors.black87, height: 1.4),
                  ),
                ],
                const SizedBox(height: 20),
                const Text(
                  'DAY-BY-DAY ITINERARY',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFFD32F2F), letterSpacing: 1),
                ),
                const SizedBox(height: 12),
                ...currentTrip.itinerary
                    .map(
                      (it) {
                        final isDark = Theme.of(context).brightness == Brightness.dark;
                        String? distChip = it.distance.isNotEmpty ? it.distance : null;
                        if (distChip == null || distChip.isEmpty) {
                          final kmMatch = RegExp(r'(\d+(?:\.\d+)?(?:\s*[-–to]+\s*\d+(?:\.\d+)?)?)\s*km', caseSensitive: false).firstMatch(it.description);
                          if (kmMatch != null) distChip = '${kmMatch.group(1)} km';
                        }

                        String? timeChip = it.time.isNotEmpty ? it.time : null;
                        if (timeChip == null || timeChip.isEmpty) {
                          final hrsMatch = RegExp(r'(\d+(?:\.\d+)?(?:\s*[-–to]+\s*\d+(?:\.\d+)?)?)\s*(?:hrs|hours|hour|hr)\b', caseSensitive: false).firstMatch(it.description);
                          if (hrsMatch != null) timeChip = '${hrsMatch.group(1)} hrs';
                        }

                        String? altChip;
                        final altMatch = RegExp(r'(\d+(?:,\d+)?(?:\s*[-–to]+\s*\d+(?:,\d+)?)?)\s*(ft|feet|m|meters|meter)\b', caseSensitive: false).firstMatch(it.description);
                        if (altMatch != null) {
                          altChip = '${altMatch.group(1)} ${altMatch.group(2)}';
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD32F2F),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'DAY ${it.day}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        it.title.isNotEmpty ? it.title : 'Stage ${it.day}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (distChip != null || timeChip != null || altChip != null) ...[
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      if (distChip != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.blue.withOpacity(0.2)),
                                          ),
                                          child: Text(
                                            distChip,
                                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                                          ),
                                        ),
                                      if (timeChip != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.orange.withOpacity(0.2)),
                                          ),
                                          child: Text(
                                            timeChip,
                                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.orange),
                                          ),
                                        ),
                                      if (altChip != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.purple.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.purple.withOpacity(0.2)),
                                          ),
                                          child: Text(
                                            altChip,
                                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.purple),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                                if (it.description.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    it.description,
                                    style: const TextStyle(fontSize: 10, color: Colors.black87, height: 1.3),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    )
                    .toList(),
                if (currentTrip.inclusions.isNotEmpty || currentTrip.carryList.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (currentTrip.inclusions.isNotEmpty)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('INCLUSIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.green)),
                              const SizedBox(height: 4),
                              ...currentTrip.inclusions.take(6).map((e) => Text('• $e', style: const TextStyle(fontSize: 9, color: Colors.black87))),
                            ],
                          ),
                        ),
                      if (currentTrip.carryList.isNotEmpty) ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('GEAR TO CARRY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF0D47A1))),
                              const SizedBox(height: 4),
                              ...currentTrip.carryList.take(6).map((e) => Text('• $e', style: const TextStyle(fontSize: 9, color: Colors.black87))),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'trekwithmussafirr • 383 Rajendra Nagar, Dehradun • mussafirr1@gmail.com',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 40, color: Colors.grey.withOpacity(0.5)),
              const SizedBox(height: 12),
              const Text(
                'Information not available',
                style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Inclusions and exclusions details will be updated shortly.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.backpack_outlined, size: 40, color: Colors.grey.withOpacity(0.5)),
              const SizedBox(height: 12),
              const Text(
                'Information not available',
                style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Specific gear carry list for this trip is currently being prepared.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
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
              'Trip Readiness: Gear Grid',
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
    final displayValue = (value.trim().isEmpty || value.trim().toLowerCase() == 'n/a')
        ? 'Information not available'
        : value;
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
            displayValue,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: displayValue == 'Information not available' ? FontWeight.w500 : FontWeight.w900,
              fontSize: displayValue == 'Information not available' ? 9.5 : 11,
              color: displayValue == 'Information not available' ? Colors.grey : null,
            ),
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
          _buildPrecisionCompass(),
          const SizedBox(height: 16),
          _buildTransitConnectivitySection(),
          const SizedBox(height: 16),
          if (_isTrip) _buildSeasonalOutlook(),
          const SizedBox(height: 24),
          if (currentTrip.packages.isNotEmpty) _buildPackagesSection(),
          const Text(
            'Trip Story',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            (currentTrip.tripStory != null && currentTrip.tripStory!.isNotEmpty)
                ? currentTrip.tripStory!
                : currentTrip.description,
            style: const TextStyle(color: Colors.blueGrey, height: 1.6),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
  Widget _buildTransitConnectivitySection() {
    String? airport = currentTrip.airport;
    String? railway = currentTrip.railway;
    String? route = (currentTrip.startPoint != null && currentTrip.endPoint != null && currentTrip.startPoint!.isNotEmpty && currentTrip.endPoint!.isNotEmpty)
        ? '${currentTrip.startPoint} to ${currentTrip.endPoint}'
        : currentTrip.startPoint;

    // Check description tags if not found
    if (airport == null || airport.isEmpty) {
      if (currentTrip.description.contains('Nearest Airport:')) {
        final parts = currentTrip.description.split('Nearest Airport:');
        if (parts.length > 1) {
          airport = parts[1].split('.').first.trim();
        }
      }
    }
    if (railway == null || railway.isEmpty) {
      if (currentTrip.description.contains('Nearest Railway Station:')) {
        final parts = currentTrip.description.split('Nearest Railway Station:');
        if (parts.length > 1) {
          railway = parts[1].split('.').first.trim();
        }
      }
    }
    if (route == null || route.isEmpty) {
      if (currentTrip.description.contains('Route:')) {
        final parts = currentTrip.description.split('Route:');
        if (parts.length > 1) {
          route = parts[1].split('.').first.trim();
        }
      }
    }

    // Check pickup options for fallbacks
    for (final opt in currentTrip.pickupOptions) {
      final loc = opt.location;
      if (airport == null && loc.toLowerCase().contains('airport')) {
        airport = loc.replaceAll(RegExp(r'^(Airport:\s*|Nearest Airport:\s*)', caseSensitive: false), '').trim();
      }
      if (railway == null && (loc.toLowerCase().contains('railway') || loc.toLowerCase().contains('station'))) {
        railway = loc.replaceAll(RegExp(r'^(Railway:\s*|Nearest Railway Station:\s*)', caseSensitive: false), '').trim();
      }
      if (route == null && loc.toLowerCase().contains('base:')) {
        route = loc.replaceAll(RegExp(r'^Base:\s*', caseSensitive: false), '').trim();
      }
    }

    // Set fallback text if data is missing
    const fallbackText = 'Info Not available';
    airport = (airport != null && airport.isNotEmpty) ? airport : fallbackText;
    railway = (railway != null && railway.isNotEmpty) ? railway : fallbackText;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Transit & Connectivity',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.flight_takeoff_rounded, color: Colors.blueAccent, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Airport',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.blueAccent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          airport,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: airport == fallbackText ? FontWeight.normal : FontWeight.w600,
                            color: airport == fallbackText ? Colors.grey : null,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.train_rounded, color: Colors.orange, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Railway',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          railway,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: railway == fallbackText ? FontWeight.normal : FontWeight.w600,
                            color: railway == fallbackText ? Colors.grey : null,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (route != null && route.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.navigation_outlined, size: 12, color: Colors.grey),
                  const SizedBox(width: 6),
                  const Text(
                    'Route: ',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: Text(
                      route,
                      style: const TextStyle(fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (currentTrip.busesCabs != null && currentTrip.busesCabs!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.directions_bus, size: 10, color: Colors.green),
                          const SizedBox(width: 3),
                          Text(
                            'Transit: ${currentTrip.busesCabs}',
                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
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
        'Trip Packages',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
      const SizedBox(height: 16),
      ...currentTrip.packages.map((pkg) {
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16), // Adjusted for clean content density
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade100,
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Icon Container
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12), // Matching card radius looks cleaner than circle
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: Colors.blue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              
              // 2. Text Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      pkg.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pkg.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              
              // 3. Upgraded Price Badge Container
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.15),
                    width: 1,
                  ),
                ),
                child: Text(
                  '₹${pkg.price.toInt()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
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
                        'Trip Preparation',
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
                'PICKUP & TRANSIT HUBS',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1.5,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              if (currentTrip.pickupOptions.isNotEmpty)
                ...currentTrip.pickupOptions.map((p) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.15)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            p.location.toLowerCase().contains('airport')
                                ? Icons.flight_takeoff
                                : (p.location.toLowerCase().contains('railway')
                                    ? Icons.train
                                    : Icons.location_on),
                            color: Colors.blueAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              p.location,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          Text(
                            p.price == 0 ? 'Included' : '+₹${p.price.toInt()}',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              color: p.price == 0 ? Colors.green : Colors.blueAccent,
                            ),
                          ),
                        ],
                      ),
                    ))
              else
                const Text(
                  'Basecamp arrival & departure included in package.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
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
  String? weather = (currentTrip.weather != null && currentTrip.weather!.isNotEmpty) ? currentTrip.weather : null;
  String? tempRange;
  if (currentTrip.minTemp != null && currentTrip.maxTemp != null && currentTrip.minTemp!.isNotEmpty && currentTrip.maxTemp!.isNotEmpty) {
    tempRange = '${currentTrip.minTemp} to ${currentTrip.maxTemp}';
  } else if (currentTrip.minTemp != null && currentTrip.minTemp!.isNotEmpty) {
    tempRange = currentTrip.minTemp;
  } else if (currentTrip.maxTemp != null && currentTrip.maxTemp!.isNotEmpty) {
    tempRange = currentTrip.maxTemp;
  }

  // Fallback to description extraction if not present
  if (weather == null && currentTrip.description.contains('Expected Weather:')) {
    final parts = currentTrip.description.split('Expected Weather:');
    if (parts.length > 1 && parts[1].contains('.')) {
      weather = parts[1].split('.').first.trim();
    }
  }
  if (tempRange == null && currentTrip.description.contains('Temperature Range:')) {
    final parts = currentTrip.description.split('Temperature Range:');
    if (parts.length > 1 && parts[1].contains('.')) {
      tempRange = parts[1].split('.').first.trim();
    }
  }

  // Safety conditional exit
  if (currentTrip.seasonalInfo.isEmpty && weather == null && tempRange == null && currentTrip.bestMonths.isEmpty) {
    return const SizedBox.shrink();
  }

  final hasWeatherCard = weather != null || tempRange != null;
  final hasSeasonalCard = currentTrip.seasonalInfo.isNotEmpty;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Seasonal Climate Outlook',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 12),
      
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasWeatherCard)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.blue.withOpacity(0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start, 
                    children: [
                      const Icon(Icons.wb_sunny_outlined, color: Colors.blue, size: 20),
                      const SizedBox(height: 8),
                      if (weather != null)
                        Text(
                          weather,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey),
                        ),
                      if (tempRange != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          tempRange,
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            
            // Spacer between cards (only if both exist)
            if (hasWeatherCard || hasSeasonalCard) const SizedBox(width: 12), 

          ],
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
  
  Widget _buildItinerary() {
    if (currentTrip.itinerary.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.alt_route_rounded, size: 40, color: Colors.grey.withOpacity(0.5)),
              const SizedBox(height: 12),
              const Text(
                'Information not available',
                style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Day-by-day itinerary details will be updated soon.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Screenshot(
      controller: _screenshotController,
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            ...List.generate(currentTrip.itinerary.length, (index) {
              final step = currentTrip.itinerary[index];
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final dayNum = step.day > 0 ? step.day : (index + 1);

              // Smart parameter extraction from description & fields
              String? distChip = step.distance.isNotEmpty ? step.distance : null;
              if (distChip == null || distChip.isEmpty) {
                final kmMatch = RegExp(r'(\d+(?:\.\d+)?(?:\s*[-–to]+\s*\d+(?:\.\d+)?)?)\s*km', caseSensitive: false).firstMatch(step.description);
                if (kmMatch != null) distChip = '${kmMatch.group(1)} km';
              }

              String? timeChip = step.time.isNotEmpty ? step.time : null;
              if (timeChip == null || timeChip.isEmpty) {
                final hrsMatch = RegExp(r'(\d+(?:\.\d+)?(?:\s*[-–to]+\s*\d+(?:\.\d+)?)?)\s*(?:hrs|hours|hour|hr)\b', caseSensitive: false).firstMatch(step.description);
                if (hrsMatch != null) timeChip = '${hrsMatch.group(1)} hrs';
              }

              String? altChip;
              final altMatch = RegExp(r'(\d+(?:,\d+)?(?:\s*[-–to]+\s*\d+(?:,\d+)?)?)\s*(ft|feet|m|meters|meter)\b', caseSensitive: false).firstMatch(step.description);
              if (altMatch != null) {
                altChip = '${altMatch.group(1)} ${altMatch.group(2)}';
              }

              return FadeInLeft(
                delay: Duration(milliseconds: 40 * index),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.grey.shade200,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Theme.of(context).primaryColor,
                                    Theme.of(context).primaryColor.withOpacity(0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'DAY $dayNum',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                step.title.isNotEmpty ? step.title : 'Stage $dayNum',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (distChip != null || timeChip != null || altChip != null) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (distChip != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(isDark ? 0.15 : 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.directions_walk, size: 12, color: Colors.blueAccent),
                                      const SizedBox(width: 4),
                                      Text(
                                        distChip,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blueAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (timeChip != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(isDark ? 0.15 : 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.orange.withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.timer_outlined, size: 12, color: Colors.orange),
                                      const SizedBox(width: 4),
                                      Text(
                                        timeChip,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (altChip != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withOpacity(isDark ? 0.15 : 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.purple.withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.terrain_rounded, size: 12, color: Colors.purpleAccent),
                                      const SizedBox(width: 4),
                                      Text(
                                        altChip,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.purpleAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          step.description,
                          style: TextStyle(
                            color: isDark ? Colors.grey.shade300 : Colors.blueGrey.shade800,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
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

    // Restrict Admin & Staff roles from booking
    try {
      final p = await Supabase.instance.client.from('profiles').select('role').eq('id', user.id).maybeSingle();
      final role = (p?['role'] ?? '').toString().toLowerCase();
      if (role == 'admin' || role == 'staff' || role == 'employee' || role == 'guide') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Access restricted: Admins and Staff ($role) cannot book treks. Please use an explorer account.'),
              backgroundColor: Colors.orangeAccent.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    } catch (_) {}
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return TripBookingSheet(
          trip: currentTrip,
          isTrip: _isTrip,
          onConfirm: (
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
            address,
            aadharNo,
            pax,
            additional,
            payMethod,
            payProof,
            redeemPoints,
            pointsRedeemed,
          ) {
            Navigator.pop(context);
            _confirmBooking(
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
              address,
              aadharNo,
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
    String address,
    String aadharNo,
    int pax,
    List<Map<String, dynamic>> additionalTravelers,
    String payMethod,
    String? payProof,
    bool redeemPoints,
    int pointsRedeemed,
  ) async {
    BuildContext? progressDialogContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) {
        progressDialogContext = c;
        return const Center(child: CircularProgressIndicator());
      },
    );

    final int durationDays = () {
      final match = RegExp(r'\d+').firstMatch(currentTrip.duration);
      return match != null ? (int.tryParse(match.group(0)!) ?? 1) : 1;
    }();

    final formattedAddons = addons.entries
        .map(
          (e) => {
            'gear_id': e.key,
            'quantity': e.value,
            'price':
                allGears.firstWhere((g) => g.id == e.key).pricePerDay *
                durationDays,
          },
        )
        .toList();

    final user = Supabase.instance.client.auth.currentUser;
    String? currentUserId = user?.id;

    String? groupId;
    try {
      groupId = await DatabaseService().bookTrip(
        tripId: currentTrip.id,
        fullName: hikerName,
        phoneNumber: hikerPhone,
        hikerEmail: hikerEmail,
        address: address,
        aadharNo: aadharNo,
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
      ).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Booking request timeout/error: $e');
    }

    if (progressDialogContext != null && Navigator.canPop(progressDialogContext!)) {
      Navigator.pop(progressDialogContext!);
    } else if (mounted) {
      Navigator.pop(context);
    }

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

      // Generate and download invoice asynchronously in background so UI finishes immediately
      final validGroupId = groupId;
      Future.microtask(() {
        InvoiceService.generateAndDownloadInvoice(
          bookingId: validGroupId,
          tripName: currentTrip.title,
          date: date,
          hikerName: hikerName,
          phoneNumber: hikerPhone,
          address: address,
          aadharNumber: aadharNo,
          pax: pax,
          travelers: additionalTravelers,
          totalPrice: total,
          basePrice: tp,
          pickupPrice: pp,
          pickupLocation: loc,
          email: hikerEmail,
        );
      });

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
