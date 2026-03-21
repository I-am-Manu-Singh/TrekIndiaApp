import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/trek.dart';
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
import 'dart:io';
import 'chat_screen.dart';
import '../widgets/user_avatar.dart';
import 'gear_checklist_screen.dart';
import 'edit_trek_screen.dart';

class TrekDetailScreen extends StatefulWidget {
  final Trek trek;
  const TrekDetailScreen({super.key, required this.trek});

  @override
  State<TrekDetailScreen> createState() => _TrekDetailScreenState();
}

class _TrekDetailScreenState extends State<TrekDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSaved = false;
  List<dynamic> _reviews = [];
  bool _isLoadingReviews = true;
  bool _canReview = false;
  int _currentImageIndex = 0;
  final ScreenshotController _screenshotController = ScreenshotController();
  String _role = 'user';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _checkSavedStatus();
    _checkReviewEligibility();
    _fetchReviews();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final res = await Supabase.instance.client.from('profiles').select('role').eq('id', user.id).single();
      if (mounted) setState(() => _role = res['role'] ?? 'user');
    } catch (_) {}
  }

  Future<void> _checkSavedStatus() async {
    final isSaved = await PreferencesService().isTrekSaved(widget.trek.id);
    if (mounted) setState(() => _isSaved = isSaved);
  }
  
  Future<void> _checkReviewEligibility() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    
    // Check if user has a booking for this trek
    try {
      final res = await Supabase.instance.client.from('bookings').select('id').eq('trek_id', widget.trek.id).eq('user_id', user.id).limit(1);
      if (res.isNotEmpty && mounted) {
        setState(() => _canReview = true);
      }
    } catch (_) {}
  }

  Future<void> _fetchReviews() async {
    try {
      final response = await Supabase.instance.client
          .from('reviews')
          .select()
          .eq('trek_id', widget.trek.id)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _reviews = response as List;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }

  Future<void> _toggleSaved() async {
    await PreferencesService().toggleSavedTrek(widget.trek.id);
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
              flexibleSpace: FlexibleSpaceBar(
                background: _buildImageGallery(),
              ),
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      color: Colors.black.withOpacity(0.3),
                      child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                    ),
                  ),
                ),
              ),
              actions: [
                if (_role == 'admin')
                  _buildAppBarAction(Icons.edit, () async {
                    final r = await Navigator.push(context, MaterialPageRoute(builder: (c) => EditTrekScreen(trek: widget.trek)));
                    if (r == true) Navigator.pop(context); // Refresh parent
                  }),
                _buildAppBarAction(Icons.share, () => Share.share('Check out ${widget.trek.title} on Trek India!')),
                _buildAppBarAction(_isSaved ? Icons.favorite : Icons.favorite_border, _toggleSaved, color: _isSaved ? Colors.red : Colors.white),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 6),
                    _buildLocationAndOfficialActions(),
                    const SizedBox(height: 8),
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
                    tabs: const [
                      Tab(text: 'General'),
                      Tab(text: 'Itinerary'),
                      Tab(text: 'Inclusions'),
                      Tab(text: 'Preparation'),
                      Tab(text: 'Carry List'),
                      Tab(text: 'Reviews'),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverview(),
              _buildItinerary(),
              _buildInclusionsExclusions(),
              _buildPreparationTab(),
              _buildCarryList(),
              _buildReviews(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildAppBarAction(IconData icon, VoidCallback onTap, {Color color = Colors.white}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Colors.black.withOpacity(0.3),
            child: IconButton(icon: Icon(icon, color: color), onPressed: onTap),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return FadeInUp(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(widget.trek.title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: Theme.of(context).primaryColor, borderRadius: BorderRadius.circular(15)),
            child: Text('₹${widget.trek.discountedPrice.toInt()}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          )
        ],
      ),
    );
  }

  Widget _buildLocationAndOfficialActions() {
    return FadeInUp(
      delay: const Duration(milliseconds: 100),
      child: Row(
        children: [
          Icon(Icons.location_on, color: Theme.of(context).colorScheme.secondary, size: 20),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              widget.trek.location, 
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            )
          ),
          const SizedBox(width: 12),
          _tacticalIconBtn(Icons.travel_explore, 'FLYOVER', Colors.blue, _openFlyover),
          const SizedBox(width: 8),
          _tacticalIconBtn(Icons.support_agent, 'SUPPORT', Colors.blueGrey, _showSupportDetails),
        ],
      ),
    );
  }

  Widget _tacticalIconBtn(IconData icon, String label, Color color, VoidCallback onTap) {
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
            Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveActions() {
    return const SizedBox.shrink(); // Relocated to Itinerary Tab
  }

  void _openFlyover() {
    final lat = widget.trek.latitude;
    final lng = widget.trek.longitude;
    final url = 'https://www.google.com/maps/@$lat,$lng,1500m/data=!3m1!1e3!5m1!1e4?entry=ttu';
    Navigator.push(context, MaterialPageRoute(builder: (c) => WebViewFlyoverScreen(url: url, title: 'Expedition Flyover')));
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
                      pw.Text('EXPEDITION RECORD', style: pw.TextStyle(color: PdfColors.blue900, fontSize: 10, fontWeight: pw.FontWeight.bold, letterSpacing: 2)),
                      pw.Text(widget.trek.title.toUpperCase(), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                    ]
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(color: PdfColors.blue900, borderRadius: pw.BorderRadius.circular(6)),
                    child: pw.Text('OFFICIAL BRIEFING', style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold)),
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
                  pw.Text('Generated by Trek India App', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                  pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                ],
              )
            ]
          ),
          build: (context) => [
            pw.Row(
              children: [
                _pdfStatBox('LOCATION', widget.trek.location),
                _pdfStatBox('DIFFICULTY', widget.trek.difficulty),
                _pdfStatBox('ALTITUDE', widget.trek.altitude),
                _pdfStatBox('DURATION', widget.trek.duration),
              ]
            ),
            pw.SizedBox(height: 24),
            pw.Text('OPERATIONAL OVERVIEW', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColors.blue800)),
            pw.SizedBox(height: 8),
            pw.Text(widget.trek.description, style: const pw.TextStyle(fontSize: 10, lineSpacing: 2)),
            
            pw.SizedBox(height: 24),
            pw.Text('TREK DAILY PLAN (ITINERARY)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColors.blue800)),
            pw.SizedBox(height: 12),
            ...widget.trek.itinerary.map((it) => pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border(left: pw.BorderSide(color: PdfColors.blue900, width: 3)),
                color: PdfColors.grey50,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('DAY ${it.day}: ${it.title}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      if (it.time.isNotEmpty) pw.Text(it.time, style: pw.TextStyle(color: PdfColors.orange800, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ]
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(it.description, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                  if (it.distance.isNotEmpty) pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 4),
                    child: pw.Text('Distance Threshold: ${it.distance}', style: pw.TextStyle(color: PdfColors.blue, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
            )).toList(),

            pw.SizedBox(height: 24),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: _pdfCheckList('INCLUSIONS', widget.trek.inclusions)),
                pw.SizedBox(width: 20),
                pw.Expanded(child: _pdfCheckList('GEAR TO CARRY', widget.trek.carryList)),
              ]
            ),
          ],
        ),
      );

      final pdfBytes = await pdf.save();
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdfBytes);
      
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Itinerary generated successfully!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

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
                const Text('EXPEDITION ITINERARY', style: TextStyle(fontSize: 10, color: Color(0xFF0D47A1), fontWeight: FontWeight.w900, letterSpacing: 2)),
                const SizedBox(height: 8),
                Text(widget.trek.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
                Text(widget.trek.location, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 30),
                const Divider(),
                const SizedBox(height: 20),
                ...widget.trek.itinerary.map((it) => Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(color: Color(0xFF0D47A1), shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text('${it.day}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(it.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black))),
                                if (it.time.isNotEmpty) Text(it.time, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(it.description, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                            if (it.distance.isNotEmpty) Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('DISTANCE: ${it.distance}', style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )).toList(),
                const SizedBox(height: 30),
                const Divider(),
                const SizedBox(height: 10),
                const Center(child: Text('Booked via Trek India App', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
        ),
      );

      final directory = await getApplicationDocumentsDirectory();
      final imagePath = await File('${directory.path}/${widget.trek.id}_itinerary.png').create();
      await imagePath.writeAsBytes(image);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Itinerary image saved to documents!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(label: 'SHARE', textColor: Colors.white, onPressed: () {
            Share.shareXFiles([XFile(imagePath.path)], text: 'Check out my itinerary for ${widget.trek.title}!');
          }),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to export image: $e'), backgroundColor: Colors.red));
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 24),
                const Text('Expedition Readiness Quiz', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
                const SizedBox(height: 10),
                Text('Assess your preparation for ${widget.trek.title}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 30),
                _quizItem('Can you trek 10km with a 5kg pack?', Icons.fitness_center, answers[0]!, (v) => setSheetState(() => answers[0] = v!)),
                _quizItem('Have you trained at 2000m+ before?', Icons.terrain, answers[1]!, (v) => setSheetState(() => answers[1] = v!)),
                _quizItem('Do you have high-altitude insurance?', Icons.security, answers[2]!, (v) => setSheetState(() => answers[2] = v!)),
                _quizItem('Can you sustain 5km/hr for 30 mins?', Icons.bolt, answers[3]!, (v) => setSheetState(() => answers[3] = v!)),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {
                    final score = (answers.values.where((v) => v).length / answers.length) * 100;
                    Navigator.pop(context);
                    _showSimulatedAction('Assessment Complete: You are ${score.toInt()}% ready for this expedition!');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: const Text('CALCULATE MY SCORE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _quizItem(String question, IconData icon, bool value, Function(bool?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor),
          const SizedBox(width: 16),
          Expanded(child: Text(question, style: const TextStyle(fontWeight: FontWeight.bold))),
          Checkbox(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5)),
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
      )
    );
  }


  Widget _buildImageGallery() {
    final images = [widget.trek.imageUrl, ...widget.trek.images];
    return Stack(
      children: [
        PageView.builder(
          itemCount: images.length,
          onPageChanged: (index) => setState(() => _currentImageIndex = index),
          itemBuilder: (context, index) => Hero(
            tag: index == 0 ? 'trek_image_${widget.trek.id}' : 'trek_image_extra_${widget.trek.id}_$index',
            child: CachedNetworkImage(
              imageUrl: images[index],
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(images.length, (index) => Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: _currentImageIndex == index ? Colors.white : Colors.white.withOpacity(0.5),
                shape: BoxShape.circle
              ),
            )),
          ),
        ),
        Positioned(
          bottom: 20,
          right: 20,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(15)),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    Text('${widget.trek.rating}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(15)),
                child: Row(
                  children: [
                    const Icon(Icons.image_outlined, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text('${images.length} Photos', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
    if (widget.trek.altitude.contains('4,000') || widget.trek.altitude.contains('5,000')) temp = -2;
    else if (widget.trek.location.toLowerCase().contains('himachal') || widget.trek.location.toLowerCase().contains('uttarakhand')) temp = 8;
    
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
                  const Text('Base Camp Weather', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  Text('${temp}°C • Clear Skies • No Rain', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: const Text('LIVE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.red)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInclusionsExclusions() {
    final inclusions = widget.trek.inclusions.isNotEmpty ? widget.trek.inclusions : ['Stay in Tents', 'All Meals', 'Expert Guides', 'Technical Gear', 'Mule Support'];
    final exclusions = widget.trek.exclusions.isNotEmpty ? widget.trek.exclusions : ['Personal Expenses', 'Insurance', 'Emergency Transport', 'Cost of Porter for Personal Bag'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCheckList('What is Included', inclusions, Colors.green),
          const SizedBox(height: 24),
          _buildCheckList('What is Not Included', exclusions, Colors.redAccent),
        ],
      ),
    );
  }

  Widget _buildCheckList(String title, List<String> items, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 12),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            children: [
              Icon(color == Colors.green ? Icons.check_circle_outline : Icons.cancel_outlined, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(item, style: const TextStyle(fontSize: 14, color: Colors.blueGrey))),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildCarryList() {
    final items = widget.trek.carryList.isNotEmpty ? widget.trek.carryList : [
      'Sturdy Trekking Shoes (Mandatory)',
      'Rucksack (50-60 Ltr)',
      'Headtorch with extra batteries',
      'Layered Clothing (Thermals, Fleece, Jacket)',
      'Trekking Poles',
      'Personal Toiletries & Medical Kit',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Essential Carry List', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 12),
          Text('Everything you need for the ${widget.trek.title} adventure.', style: const TextStyle(color: Colors.grey, fontSize: 14)),
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
        final data = snapshot.data ?? {'packed': 0, 'total': widget.trek.carryList.isNotEmpty ? widget.trek.carryList.length : 6};
        int checked = data['packed']!;
        int total = data['total']!;
        double progress = total == 0 ? 0.0 : checked / total;
        final items = widget.trek.carryList.isNotEmpty ? widget.trek.carryList : [
          'Trekking Shoes', 'Rucksack', 'Headtorch', 'Layered Clothing', 'Trekking Poles', 'Medical Kit'
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
                border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                    strokeWidth: 8,
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${(progress * 100).toInt()}% READY', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                      Text('$checked of $total items packed', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: () => setState(() {}),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showManagePackingList(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor, 
                foregroundColor: Colors.white, 
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              icon: const Icon(Icons.inventory_2_outlined, size: 18),
              label: const Text('MANAGE MY PACKING LIST', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            const SizedBox(height: 24),
            const Text('TREK READINESS: GEAR GRID', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5, color: Colors.grey)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.05)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 14, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(child: Text(item, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      }
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
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
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

  Widget _techItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor, size: 20),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
      ],
    );
  }

  Widget _buildOverview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Trek Coordinates', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          _buildPrecisionCompass(),
          const SizedBox(height: 12),
          _buildSeasonalOutlook(),
          const SizedBox(height: 24),
          if (widget.trek.packages.isNotEmpty) _buildPackagesSection(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildPackagesSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('TREK PACKAGES', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ...widget.trek.packages.map((pkg) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.inventory_2_outlined, color: Colors.blueAccent, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(pkg.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(pkg.description, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ])),
              Text('₹${pkg.price.toInt()}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ],
          ),
        )).toList(),
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
          .eq('trek_id', widget.trek.id);
      
      final list = res as List;
      if (list.isEmpty) {
         return {'packed': 0, 'total': widget.trek.carryList.isNotEmpty ? widget.trek.carryList.length : 6};
      }
      int packed = list.where((item) => item['is_packed'] == true).length;
      return {'packed': packed, 'total': list.length};
    } catch (_) { 
       return {'packed': 0, 'total': widget.trek.carryList.isNotEmpty ? widget.trek.carryList.length : 6}; 
    }
  }

  Widget _buildProPreparationGuide() {
    int temp = 8;
    if (widget.trek.altitude.contains('4,000') || widget.trek.altitude.contains('5,000')) temp = -5;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return FutureBuilder<Map<String, int>>(
      future: _getGearProgressCounts(),
      builder: (context, snapshot) {
        final data = snapshot.data ?? {'packed': 0, 'total': widget.trek.carryList.isNotEmpty ? widget.trek.carryList.length : 6};
        int checked = data['packed']!;
        int total = data['total']!;
        double progress = total == 0 ? 0.0 : checked / total;

        return Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.1)),
            boxShadow: [isDark 
              ? BoxShadow(color: Colors.blueAccent.withOpacity(0.1), blurRadius: 20)
              : BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8))
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
                      Text('TREK PREPARATION', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: isDark ? Colors.white : Colors.black, letterSpacing: 1.5)),
                      const Text('Trek Briefing & Stamina Goals', style: TextStyle(color: Colors.grey, fontSize: 10)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Text('${(progress * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress, 
                  backgroundColor: isDark ? Colors.white10 : Colors.black12, 
                  valueColor: AlwaysStoppedAnimation<Color>((progress > 0.8) ? Colors.greenAccent : Colors.orangeAccent),
                  minHeight: 8
                ),
              ),
              const SizedBox(height: 24),
              _proPrepItem(Icons.thermostat, 'Altitude Temp Cap:', '${temp}°C', 'Crucial gear thermal rating required.'),
              const SizedBox(height: 16),
              _proPrepItem(Icons.fitness_center, 'Cardio Threshold:', '5km / 28m', 'Target stamina for high-altitude climb.'),
              const SizedBox(height: 16),
              _proPrepItem(Icons.water_drop, 'Hydration Plan:', '4-5 Ltrs/Day', 'Mandatory for AMS prevention.'),
              const SizedBox(height: 16),
              _proPrepItem(Icons.medical_services_outlined, 'Acclimatization:', '300m Ascent', 'Daily sleep-low-climb-high limit.'),
            ],
          ),
        );
      }
    );
  }

  Widget _buildQuizBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue[900]!, Colors.blue[600]!]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Are you prepared?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 4),
                Text('Take our 1-min readiness quiz for this altitude.', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _showReadinessQuiz(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white, 
              foregroundColor: Colors.blue[900], 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            ),
            child: const Text('Start Quiz', style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
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
                  Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Expanded(child: Text(value, style: TextStyle(fontWeight: FontWeight.w900, color: Theme.of(context).primaryColor, fontSize: 13), textAlign: TextAlign.end, overflow: TextOverflow.ellipsis)),
                ],
              ),
              const SizedBox(height: 4),
              Text(tip, style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildSeasonalOutlook() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Seasonal Climate Outlook', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _seasonCard('MAR - JUN', 'Best High Alt Views', '8°C to 20°C', Colors.orange),
              _seasonCard('JUL - AUG', 'Lush Landscapes', '12°C to 22°C', Colors.green),
              _seasonCard('SEP - NOV', 'Crystal Clear Skies', '5°C to 15°C', Colors.blue),
              _seasonCard('DEC - FEB', 'Deep Snow Trails', '-10°C to 5°C', Colors.cyan),
            ],
          ),
        )
      ],
    );
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
          Text(month, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
          const SizedBox(height: 4),
          Text(note, style: const TextStyle(fontSize: 10, color: Colors.blueGrey), maxLines: 1, overflow: TextOverflow.ellipsis),
          const Spacer(),
          Text(temp, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                      _exportItineraryImage
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _actionButton(
                      Icons.picture_as_pdf_outlined, 
                      'EXPORT PDF', 
                      Colors.redAccent, 
                      _exportItineraryPdf
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              ...List.generate(widget.trek.itinerary.length, (index) {
                final step = widget.trek.itinerary[index];
                return FadeInLeft(
                  delay: Duration(milliseconds: 50 * index),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Column(
                          children: [
                            CircleAvatar(radius: 12, backgroundColor: Theme.of(context).primaryColor, child: Text('${index+1}', style: const TextStyle(color: Colors.white, fontSize: 10))),
                            Expanded(child: VerticalDivider(color: Theme.of(context).primaryColor.withOpacity(0.3), thickness: 2)),
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
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text(step.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                    if (step.time.isNotEmpty) Text(step.time, style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(step.description, style: const TextStyle(color: Colors.grey)),
                                if (step.distance.isNotEmpty) Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Row(children: [
                                    const Icon(Icons.directions_walk, size: 14, color: Colors.blueAccent),
                                    const SizedBox(width: 4),
                                    Text(step.distance, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.blueAccent)),
                                  ]),
                                )
                              ],
                            ),
                          ),
                        )
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

  Widget _buildReviews() {
    if (_isLoadingReviews) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24), // Explicit padding for review button
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                if (!_canReview) {
                  _showSimulatedAction('Reviewing is allowed only after completing the trek expedition.');
                  return;
                }
                final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddReviewScreen(trekId: widget.trek.id)));
                if (result == true) {
                  setState(() => _isLoadingReviews = true);
                  _fetchReviews();
                }
              },
              icon: const Icon(Icons.rate_review),
              label: const Text('Write a Review'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ),
        ),
        if (_reviews.isEmpty)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rate_review_outlined, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No reviews yet. Be the first to share your experience!', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              itemCount: _reviews.length,
              itemBuilder: (context, index) {
                final r = _reviews[index];
                return FadeInUp(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                               UserAvatar(
                                 imageUrl: r['image_url'],
                                 name: r['user_name'],
                                 radius: 20,
                               ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(r['user_name'] ?? 'Trekker', style: const TextStyle(fontWeight: FontWeight.bold))),
                              RatingBarIndicator(rating: double.tryParse(r['rating'].toString()) ?? 5.0, itemBuilder: (c, i) => const Icon(Icons.star, color: Colors.amber), itemCount: 5, itemSize: 15),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(r['comment'] ?? '', style: const TextStyle(fontStyle: FontStyle.italic)),
                          const SizedBox(height: 12),
                          _buildReviewTag(Icons.thumb_up_alt_outlined, 'Liked: ', r['liked'] ?? '', Colors.green),
                          _buildReviewTag(Icons.thumb_down_alt_outlined, 'Disliked: ', r['disliked'] ?? 'None', Colors.red),
                          _buildReviewTag(Icons.trending_up, 'Difficulty: ', r['difficulty_rating'] ?? 'Medium', Colors.orange),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildReviewTag(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
      child: ElevatedButton(
        onPressed: () => _showBookingSheet(context),
        style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        child: const Text('Book Your Adventure', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  void _showBookingSheet(BuildContext context) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 14));
    List<Gear> availableGears = [];
    Map<String, int> selectedAddons = {};
    PickupOption? selectedPickup = widget.trek.pickupOptions.isNotEmpty ? widget.trek.pickupOptions.first : null;
    bool isGearsLoading = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            if (isGearsLoading) {
              DatabaseService().fetchGears().then((gears) {
                if (mounted) setSheetState(() { availableGears = gears; isGearsLoading = false; });
              });
            }

            final String monthKey = DateFormat('MMM').format(selectedDate);
            final String seasonalOutlook = widget.trek.seasonalInfo[monthKey] ?? "Normal Himalayan conditions";
            final isDark = Theme.of(context).brightness == Brightness.dark;

            final double trekPrice = widget.trek.discountedPrice;
            final double pickupPrice = selectedPickup?.price ?? 0;
            
            double calculateAddonsTotal() {
              double total = 0;
              selectedAddons.forEach((id, qty) {
                final gear = availableGears.firstWhere((g) => g.id == id);
                total += gear.pricePerDay * qty * int.parse(widget.trek.duration.split(' ')[0]);
              });
              return total;
            }

            final double grandTotal = trekPrice + pickupPrice + calculateAddonsTotal();

            return Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  // Stick Trek Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
                    ),
                    child: Column(
                      children: [
                        Container(height: 4, width: 40, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(sheetContext)),
                            const Text('Customize Your Journey', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
                            const SizedBox(width: 48), // Balance spacing
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          Expanded(
                            child: ListView(
                              children: [
                                // DATE PICKER & SEASONAL INFO
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.blue.withOpacity(0.1))),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Departure Date', style: TextStyle(fontSize: 12, color: Colors.blue)),
                                              Text(DateFormat('dd MMM yyyy').format(selectedDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                            ],
                                          ),
                                          TextButton.icon(
                                            onPressed: () async {
                                              final date = await showDatePicker(
                                                context: context, 
                                                initialDate: selectedDate, 
                                                firstDate: DateTime.now().add(const Duration(days: 7)), 
                                                lastDate: DateTime.now().add(const Duration(days: 365))
                                              );
                                              if (date != null) setSheetState(() => selectedDate = date);
                                            }, 
                                            icon: const Icon(Icons.edit_calendar), 
                                            label: const Text('Change')
                                          )
                                        ],
                                      ),
                                      const Divider(),
                                      Row(
                                        children: [
                                          const Icon(Icons.wb_sunny_outlined, size: 16, color: Colors.orange),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Landscape Outlook: $seasonalOutlook', 
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)
                                            )
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(height: 20),
                                const Text('Pickup Point', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                                ...widget.trek.pickupOptions.map((opt) => RadioListTile<PickupOption>(
                                  value: opt,
                                  groupValue: selectedPickup,
                                  title: Text(opt.location),
                                  contentPadding: EdgeInsets.zero,
                                  secondary: Text('+₹${opt.price.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  onChanged: (val) => setSheetState(() => selectedPickup = val),
                                )),
                                const Divider(),
                                const Text('Optional Gear Rentals', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 10),
                                if (isGearsLoading) const Center(child: CircularProgressIndicator())
                                else Container(
                                  height: 280,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05), 
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05)),
                                  ),
                                  child: ListView.builder(
                                    itemCount: availableGears.length,
                                    itemBuilder: (c, idx) {
                                      final gear = availableGears[idx];
                                      return Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).cardColor,
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)],
                                        ),
                                        child: ListTile(
                                          dense: true,
                                          title: Text(gear.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          subtitle: Text('₹${gear.pricePerDay.toInt()}/day', style: const TextStyle(fontSize: 10)),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (selectedAddons.containsKey(gear.id)) ...[
                                                IconButton(
                                                  onPressed: () => setSheetState(() {
                                                    if (selectedAddons[gear.id]! > 1) {
                                                      selectedAddons[gear.id] = selectedAddons[gear.id]! - 1;
                                                    } else {
                                                      selectedAddons.remove(gear.id);
                                                    }
                                                  }), 
                                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20)
                                                ),
                                                Text('${selectedAddons[gear.id]}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                              ],
                                              IconButton(
                                                onPressed: () => setSheetState(() => selectedAddons[gear.id] = (selectedAddons[gear.id] ?? 0) + 1), 
                                                icon: const Icon(Icons.add_circle, color: Colors.green, size: 24)
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                          // Premium Cost Breakdown
                          Container(
                            padding: const EdgeInsets.all(20),
                            margin: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              children: [
                                _totalRow('Expedition Fee', '₹${trekPrice.toInt()}'),
                                _totalRow('Trek Pickup', '₹${pickupPrice.toInt()}'),
                                _totalRow('Logistics Addons', '₹${calculateAddonsTotal().toInt()}'),
                                const Divider(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('TREK TOTAL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                                    Text('₹${grandTotal.toInt()}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Theme.of(context).primaryColor)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(sheetContext);
                              _showMockPaymentFlow(grandTotal, trekPrice, pickupPrice, selectedPickup?.location ?? '', selectedDate, selectedAddons, availableGears);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black, 
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 58), 
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              elevation: 10,
                              shadowColor: Colors.black45,
                            ),
                            child: const Text('CONFIRM TREK DEPLOYMENT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      }
    );
  }

  Widget _totalRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
          Text(val, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
        ],
      ),
    );
  }

  void _showMockPaymentFlow(double grandTotal, double trekPrice, double pickupPrice, String pickupLoc, DateTime date, Map<String, int> addons, List<Gear> availableGears) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
        child: MockPaymentFlow(
          total: grandTotal,
          onComplete: () {
            Navigator.pop(context);
            _confirmBooking(grandTotal, trekPrice, pickupPrice, pickupLoc, date, addons, availableGears);
          },
        ),
      ),
    );
  }

  Future<void> _confirmBooking(double total, double tp, double pp, String loc, DateTime date, Map<String, int> addons, List<Gear> allGears) async {
    showDialog(context: context, builder: (c) => const Center(child: CircularProgressIndicator()));
    
    final formattedAddons = addons.entries.map((e) => {
      'gear_id': e.key,
      'quantity': e.value,
      'price': allGears.firstWhere((g) => g.id == e.key).pricePerDay * int.parse(widget.trek.duration.split(' ')[0])
    }).toList();

   final user = Supabase.instance.client.auth.currentUser;

    final profile = await Supabase.instance.client
        .from('profiles')
        .select('full_name')
        .eq('id', user!.id)
        .single();

    final String fullName = profile['full_name']; // 👈 THIS LINE WAS MISSING

    final String? groupId = await DatabaseService().bookTrek(
      trekId: widget.trek.id,
      fullName: fullName, // now Dart stops crying
      trekTitle: widget.trek.title,
      trekDate: date,
      trekPrice: tp,
      pickupPrice: pp,
      pickupLocation: loc,
      totalPrice: total,
      addons: formattedAddons,
    );
    if (mounted) Navigator.pop(context);

    if (groupId != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Successfully Booked! Your trek group is active now.'), backgroundColor: Colors.green));
      
      // Auto-open chat
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            roomId: groupId, 
            title: '${widget.trek.title} Group'
          )
        )
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking failed. Please try again.'), backgroundColor: Colors.red));
    }
  }

  Widget _buildPrecisionCompass() {
    return FadeInUp(
      delay: const Duration(milliseconds: 100),
      child: GridView.count(
        padding: EdgeInsets.zero, // TREK CRITICAL: Remove residual vertical padding
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.1,
        children: [
          _individualTechCard(Icons.explore, 'ORIENTATION', 'North-East'),
          _individualTechCard(Icons.location_on, 'COORDINATES', '${widget.trek.latitude.toStringAsFixed(1)}° N'),
          _individualTechCard(Icons.height, 'ELEVATION', widget.trek.altitude),
          _individualTechCard(Icons.terrain, 'DIFFICULTY', widget.trek.difficulty),
          _individualTechCard(Icons.timer_outlined, 'DURATION', widget.trek.duration),
          _individualTechCard(Icons.landscape_outlined, 'PEAK', widget.trek.peakElevation),
          _individualTechCard(Icons.route_outlined, 'TRAIL TYPE', widget.trek.trailType),
          _individualTechCard(Icons.calendar_month, 'BEST TIME', 'Mar - Jun'),
          _individualTechCard(Icons.people_outline, 'GROUP SIZE', '12-15 Pax'),
        ],
      )
    );
  }

  Widget _buildPreparationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProPreparationGuide(),
          const SizedBox(height: 24),
          _buildQuizBanner(),
        ],
      ),
    );
  }

  Widget _individualTechCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).primaryColor),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 7, color: Colors.grey, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _compassItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).primaryColor),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showManagePackingList() {
    Navigator.push(context, MaterialPageRoute(builder: (c) => GearChecklistScreen(trekId: widget.trek.id, trekTitle: widget.trek.title, carryList: widget.trek.carryList)));
  }

  void _showSupportDetails() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (c) => Container(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Expedition Support', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Official coordination partner for Trek India.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            _supportItem(Icons.phone, 'Support Hotline', '+91 9876543210'),
            _supportItem(Icons.email_outlined, 'Official Email', 'explore@trekindia.com'),
            _supportItem(Icons.location_on_outlined, 'Headquarters', 'Base Camp One, Manali, HP, India'),
            const SizedBox(height: 30),
            const Text('Our experts are available 24/7 during your trek to ensure maximum safety and guidance.', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.blueGrey)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _supportItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.blueGrey, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfStatBox(String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.only(right: 8),
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: pw.TextStyle(color: PdfColors.grey700, fontSize: 6, fontWeight: pw.FontWeight.bold)),
            pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  pw.Widget _pdfCheckList(String title, List<String> items) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.blue900)),
        pw.SizedBox(height: 8),
        ...items.map((item) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Row(
            children: [
              pw.Container(width: 4, height: 4, decoration: const pw.BoxDecoration(color: PdfColors.blue, shape: pw.BoxShape.circle)),
              pw.SizedBox(width: 8),
              pw.Expanded(child: pw.Text(item, style: const pw.TextStyle(fontSize: 8))),
            ],
          ),
        )).toList(),
      ],
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate({required this.child, required this.preferredHeight});

  final Widget child;
  final double preferredHeight;

  @override
  double get minExtent => preferredHeight + (WidgetsBinding.instance.platformDispatcher.implicitView?.padding.top ?? 44) / (WidgetsBinding.instance.platformDispatcher.implicitView?.devicePixelRatio ?? 1);
  @override
  double get maxExtent => preferredHeight + (WidgetsBinding.instance.platformDispatcher.implicitView?.padding.top ?? 44) / (WidgetsBinding.instance.platformDispatcher.implicitView?.devicePixelRatio ?? 1);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(top: true, bottom: false, child: child),
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

class MockPaymentFlow extends StatefulWidget {
  final double total;
  final VoidCallback onComplete;

  const MockPaymentFlow({super.key, required this.total, required this.onComplete});

  @override
  State<MockPaymentFlow> createState() => _MockPaymentFlowState();
}

class _MockPaymentFlowState extends State<MockPaymentFlow> {
  int _step = 0;
  final List<String> _statusMessages = [
    "Verifying tactical payment gateway...",
    "Securing transaction with end-to-end encryption...",
    "Processing payment with central command bank...",
    "Finalizing mission booking details...",
    "Trek status: CONFIRMED"
  ];

  @override
  void initState() {
    super.initState();
    _startFlow();
  }

  void _startFlow() async {
    for (int i = 1; i <= _statusMessages.length; i++) {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) setState(() => _step = i);
    }
    await Future.delayed(const Duration(milliseconds: 1000));
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    bool isComplete = _step == _statusMessages.length;
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _step < _statusMessages.length 
            ? const SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(strokeWidth: 8, color: Colors.blueAccent),
              )
            : FadeIn(
                child: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 80),
              ),
          const SizedBox(height: 40),
          Text(
            isComplete ? "BOOKING SUCCESSFUL" : "PROCESSING PAYMENT",
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 1),
          ),
          const SizedBox(height: 12),
          Text(
            "₹${widget.total.toInt()}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 32, color: Colors.blueAccent),
          ),
          const SizedBox(height: 40),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: Text(
              _statusMessages[_step < _statusMessages.length ? _step : _statusMessages.length - 1],
              key: ValueKey(_step),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          const SizedBox(height: 40),
          if (!isComplete)
            const Text(
              "PLEASE DO NOT REFRESH OR HIDE APP",
              style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }
}
