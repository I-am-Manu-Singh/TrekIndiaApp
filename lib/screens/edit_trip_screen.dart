import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trip.dart';
import '../services/database_service.dart';

class EditTripScreen extends StatefulWidget {
  final Trip? trip;
  const EditTripScreen({super.key, this.trip});

  @override
  State<EditTripScreen> createState() => _EditTripScreenState();
}

class _EditTripScreenState extends State<EditTripScreen> {
  final _client = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  bool get isNew => widget.trip == null;

  // Cover images — up to 5 URL controllers (first = primary cover)
  static const int _maxCoverImages = 5;
  late List<TextEditingController> _coverImageCtrls;

  late TextEditingController _titleCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _durationCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _discountCtrl;
  late TextEditingController _descriptionCtrl;
  late TextEditingController _bestMonthsCtrl;
  late TextEditingController _googleMapLinkCtrl;
  late TextEditingController _termsCtrl;
  late TextEditingController _cancellationCtrl;
  late TextEditingController _travelerFormCtrl;
  late TextEditingController _altCtrl;
  late TextEditingController _diffCtrl;
  late TextEditingController _distCtrl;
  late TextEditingController _peakElevCtrl;
  late TextEditingController _trailTypeCtrl;
  late TextEditingController _orientationCtrl;
  late TextEditingController _startPointCtrl;
  late TextEditingController _packageTypeCtrl;
  late TextEditingController _ratingCtrl;
  late TextEditingController _seasonalInfoCtrl;
  late TextEditingController _rewardPointsCtrl;

  List<PickupOption> _pickups = [];
  List<TripItinerary> _itinerary = [];
  List<Map<String, dynamic>> _localPackages = [];
  List<String> _inclusions = [];
  List<String> _exclusions = [];
  List<String> _carryList = [];
  List<String> _extraImages = [];

  List<TripCategory> _availableCategories = [];
  String _selectedCategory = 'Adventure Trip';
  bool _isLoading = false;
  bool _isCategoriesLoading = true;

  @override
  void initState() {
    super.initState();

    // Build cover image controllers from existing data
    final existingCover = widget.trip?.imageUrl ?? '';
    final existingExtra = widget.trip?.images ?? [];
    // Merge: primary + up to 4 extra = up to 5 total
    final allCoverUrls = [existingCover, ...existingExtra].take(_maxCoverImages).toList();
    // Always start with at least 1 controller
    _coverImageCtrls = List.generate(
      allCoverUrls.isEmpty ? 1 : allCoverUrls.length,
      (i) => TextEditingController(text: i < allCoverUrls.length ? allCoverUrls[i] : ''),
    );

    _titleCtrl = TextEditingController(text: widget.trip?.title ?? '');
    _locationCtrl = TextEditingController(text: widget.trip?.location ?? '');
    _durationCtrl = TextEditingController(text: widget.trip?.duration ?? '');
    _priceCtrl = TextEditingController(text: (widget.trip?.basePrice ?? 0).toString());
    _discountCtrl = TextEditingController(text: (widget.trip?.discountPercent ?? 0).toString());
    _descriptionCtrl = TextEditingController(text: widget.trip?.description ?? '');
    _bestMonthsCtrl = TextEditingController(text: widget.trip?.bestMonths ?? 'Mar-Jun, Sep-Dec');
    _googleMapLinkCtrl = TextEditingController(text: widget.trip?.googleMapLink ?? '');
    _termsCtrl = TextEditingController(text: widget.trip?.termsConditions ?? '');
    _cancellationCtrl = TextEditingController(text: widget.trip?.cancellationPolicy ?? '');
    _travelerFormCtrl = TextEditingController(text: widget.trip?.travelerFormUrl ?? '');
    _altCtrl = TextEditingController(text: widget.trip?.altitude ?? '');
    _diffCtrl = TextEditingController(text: widget.trip?.difficulty ?? 'Moderate');
    _distCtrl = TextEditingController(text: widget.trip?.totalDistance ?? '');
    _peakElevCtrl = TextEditingController(text: widget.trip?.peakElevation ?? 'N/A');
    _trailTypeCtrl = TextEditingController(text: widget.trip?.trailType ?? 'Mixed');
    _orientationCtrl = TextEditingController(text: widget.trip?.orientation ?? 'North');
    _startPointCtrl = TextEditingController(text: widget.trip?.startPoint ?? '');
    _packageTypeCtrl = TextEditingController(text: widget.trip?.packageType ?? 'Standard');
    _ratingCtrl = TextEditingController(text: (widget.trip?.rating ?? 5.0).toString());
    _seasonalInfoCtrl = TextEditingController(text: jsonEncode(widget.trip?.seasonalInfo ?? {}));
    _rewardPointsCtrl = TextEditingController(text: (widget.trip?.rewardPoints ?? 0).toString());
    _selectedCategory = widget.trip?.category ?? 'Adventure Trip';

    _pickups = List.from(widget.trip?.pickupOptions ?? []);
    _itinerary = List.from(widget.trip?.itinerary ?? [TripItinerary(day: 1, title: 'Arrival', description: 'Base camp arrival')]);
    _inclusions = List.from(widget.trip?.inclusions ?? []);
    _exclusions = List.from(widget.trip?.exclusions ?? []);
    _carryList = List.from(widget.trip?.carryList ?? []);
    // Extra images now handled by _coverImageCtrls — keep _extraImages only for non-cover gallery
    _extraImages = [];

    _fetchCategories();
    if (!isNew) {
      _fetchPackages();
    }
  }

  @override
  void dispose() {
    for (final c in _coverImageCtrls) { c.dispose(); }
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _durationCtrl.dispose();
    _priceCtrl.dispose();
    _discountCtrl.dispose();
    _descriptionCtrl.dispose();
    _bestMonthsCtrl.dispose();
    _googleMapLinkCtrl.dispose();
    _termsCtrl.dispose();
    _cancellationCtrl.dispose();
    _travelerFormCtrl.dispose();
    _altCtrl.dispose();
    _diffCtrl.dispose();
    _distCtrl.dispose();
    _peakElevCtrl.dispose();
    _trailTypeCtrl.dispose();
    _orientationCtrl.dispose();
    _startPointCtrl.dispose();
    _packageTypeCtrl.dispose();
    _ratingCtrl.dispose();
    _seasonalInfoCtrl.dispose();
    _rewardPointsCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    setState(() => _isCategoriesLoading = true);
    final cats = await DatabaseService().fetchCategories();
    if (mounted) {
      setState(() {
        _availableCategories = cats;
        _isCategoriesLoading = false;
        if (_availableCategories.isNotEmpty && !cats.any((c) => c.name == _selectedCategory)) {
          _selectedCategory = _availableCategories.first.name;
        }
      });
    }
  }

  Future<void> _fetchPackages() async {
    final res = await _client.from('trip_packages').select().eq('trip_id', widget.trip!.id);
    if (mounted) {
      setState(() {
        _localPackages = (res as List).map((i) => {
          'id': i['id'],
          'name': i['name'],
          'price': i['price'],
          'description': i['description'],
          'reward_points': i['reward_points'] ?? 0,
        }).toList();
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      // Collect all non-empty cover image URLs
      final allCoverUrls = _coverImageCtrls
          .map((c) => c.text.trim())
          .where((url) => url.isNotEmpty)
          .toList();

      final primaryImageUrl = allCoverUrls.isNotEmpty ? allCoverUrls.first : '';
      // Remaining cover images go into 'images' array (carousel slots 2-5)
      final extraCoverImages = allCoverUrls.length > 1 ? allCoverUrls.sublist(1) : <String>[];

      final tripData = {
        'title': _titleCtrl.text.trim().toUpperCase(),
        'location': _locationCtrl.text.trim(),
        'duration': _durationCtrl.text.trim(),
        'base_price': double.tryParse(_priceCtrl.text) ?? 0,
        'discount_percent': double.tryParse(_discountCtrl.text) ?? 0,
        'description': _descriptionCtrl.text.trim(),
        'image_url': primaryImageUrl,
        'images': extraCoverImages,
        'category': _selectedCategory,
        'best_months': _bestMonthsCtrl.text.trim(),
        'google_map_link': _googleMapLinkCtrl.text.trim(),
        'terms_conditions': _termsCtrl.text.trim(),
        'cancellation_policy': _cancellationCtrl.text.trim(),
        'traveler_form_url': _travelerFormCtrl.text.trim(),
        'altitude': _altCtrl.text.trim(),
        'difficulty': _diffCtrl.text.trim(),
        'total_distance': _distCtrl.text.trim(),
        'pickup_options': _pickups.map((p) => {'location': p.location, 'price': p.price}).toList(),
        'itinerary': _itinerary.map((i) => {
          'day': i.day,
          'title': i.title,
          'description': i.description,
          'distance': i.distance,
          'time': i.time,
          'image': i.imageUrl
        }).toList(),
        'inclusions': _inclusions,
        'exclusions': _exclusions,
        'peak_elevation': _peakElevCtrl.text.trim(),
        'trail_type': _trailTypeCtrl.text.trim(),
        'orientation': _orientationCtrl.text.trim(),
        'start_point': _startPointCtrl.text.trim(),
        'package_type': _packageTypeCtrl.text.trim(),
        'rating': double.tryParse(_ratingCtrl.text) ?? 5.0,
        'carry_list': _carryList,
        'seasonal_info': _parseSeasonalInfo(),
        'reward_points': int.tryParse(_rewardPointsCtrl.text) ?? 0,
        if (isNew) 'created_at': DateTime.now().toIso8601String(),
      };

      String tripId;
      if (isNew) {
        final res = await _client.from('trips').insert(tripData).select().single();
        tripId = res['id'];
      } else {
        tripId = widget.trip!.id;
        await _client.from('trips').update(tripData).eq('id', tripId);
      }

      // Sync Packages (delete all then re-insert)
      await _client.from('trip_packages').delete().eq('trip_id', tripId);
      if (_localPackages.isNotEmpty) {
        await _client.from('trip_packages').insert(_localPackages.map((p) => {
          'trip_id': tripId,
          'name': p['name'],
          'price': p['price'],
          'description': p['description'],
          'reward_points': p['reward_points'] ?? 0,
        }).toList());
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isNew ? 'TRIP DEPLOYED SUCCESSFULLY' : 'TRIP UPDATED SUCCESSFULLY'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ERROR: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _parseSeasonalInfo() {
    try {
      return jsonDecode(_seasonalInfoCtrl.text);
    } catch (e) {
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF18181B) : Colors.white;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade200;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF09090B) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(isNew ? 'NEW EXPEDITION' : 'EDIT EXPEDITION',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2)),
        actions: [
          if (_isLoading) const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
          if (!_isLoading) IconButton(icon: const Icon(Icons.rocket_launch_outlined), onPressed: _saveChanges, tooltip: 'Save Trip'),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // ── COVER IMAGES ────────────────────────────────────────────────
            _sectionHeader('COVER IMAGES (UP TO 5)', Icons.photo_library_outlined),
            _buildCoverImagesSection(cardColor, borderColor),
            const SizedBox(height: 24),

            // ── CORE INFO ───────────────────────────────────────────────────
            _sectionHeader('CORE TRIP INFO', Icons.terrain),
            _buildInput('Operation Name / Title', _titleCtrl, Icons.terrain, cardColor, borderColor),
            _buildInput('Google Map Link', _googleMapLinkCtrl, Icons.pin_drop, cardColor, borderColor),
            Row(
              children: [
                Expanded(child: _buildInput('Duration', _durationCtrl, Icons.timer, cardColor, borderColor)),
                const SizedBox(width: 16),
                Expanded(child: _buildInput('Max Altitude', _altCtrl, Icons.landscape, cardColor, borderColor)),
              ],
            ),
            Row(
              children: [
                Expanded(child: _buildInput('Base Price (₹)', _priceCtrl, Icons.payments_outlined, cardColor, borderColor, type: TextInputType.number)),
                const SizedBox(width: 16),
                Expanded(child: _buildInput('Discount %', _discountCtrl, Icons.percent, cardColor, borderColor, type: TextInputType.number)),
              ],
            ),
            Row(
              children: [
                Expanded(child: _buildInput('Difficulty', _diffCtrl, Icons.speed, cardColor, borderColor)),
                const SizedBox(width: 16),
                Expanded(child: _buildInput('Rating (1-5)', _ratingCtrl, Icons.star, cardColor, borderColor, type: TextInputType.number)),
              ],
            ),
            _buildInput('Best Months', _bestMonthsCtrl, Icons.calendar_month, cardColor, borderColor),

            // ── REWARD POINTS ────────────────────────────────────────────────
            const SizedBox(height: 8),
            _buildRewardPointsField(cardColor, borderColor),
            const SizedBox(height: 24),

            // ── HIGH FIDELITY SPECS ─────────────────────────────────────────
            _sectionHeader('HIGH FIDELITY SPECS', Icons.tune),
            Row(
              children: [
                Expanded(child: _buildInput('Peak Elevation', _peakElevCtrl, Icons.height, cardColor, borderColor)),
                const SizedBox(width: 16),
                Expanded(child: _buildInput('Orientation', _orientationCtrl, Icons.explore_outlined, cardColor, borderColor)),
              ],
            ),
            Row(
              children: [
                Expanded(child: _buildInput('Start Point', _startPointCtrl, Icons.flag_outlined, cardColor, borderColor)),
                const SizedBox(width: 16),
                Expanded(child: _buildInput('Package Type', _packageTypeCtrl, Icons.inventory_2_outlined, cardColor, borderColor)),
              ],
            ),
            _buildInput('Trail Type (e.g. Rugged, Coastal)', _trailTypeCtrl, Icons.route_outlined, cardColor, borderColor),
            _buildCategoryPicker(cardColor, borderColor),
            const SizedBox(height: 24),

            // ── LOGISTICS ────────────────────────────────────────────────────
            _sectionHeader('LOGISTICS & ACCESSIBILITY', Icons.route),
            Row(
              children: [
                Expanded(child: _buildInput('Total Distance', _distCtrl, Icons.directions_walk, cardColor, borderColor)),
                const SizedBox(width: 16),
                Expanded(child: _buildInput('General Location', _locationCtrl, Icons.map, cardColor, borderColor)),
              ],
            ),
            const SizedBox(height: 24),

            // ── PACKAGES ─────────────────────────────────────────────────────
            _sectionHeader('PRICING PACKAGES', Icons.inventory_2),
            ..._localPackages.asMap().entries.map((e) => _packageInlineTile(e.key, e.value, cardColor, borderColor)).toList(),
            _addBtn('ADD PRICING PACKAGE', () {
              setState(() => _localPackages.add({'name': '', 'price': 0.0, 'description': '', 'reward_points': 0}));
            }),
            const SizedBox(height: 24),

            // ── ITINERARY ────────────────────────────────────────────────────
            _sectionHeader('ITINERARY & TIMELINE', Icons.list_alt),
            ..._itinerary.asMap().entries.map((e) => _itineraryTile(e.key, e.value)).toList(),
            _addBtn('ADD DAY / STEP', () {
              setState(() => _itinerary.add(TripItinerary(day: _itinerary.length + 1, title: '', description: '')));
            }),
            const SizedBox(height: 24),

            // ── PICKUP POINTS ─────────────────────────────────────────────────
            _sectionHeader('PICKUP POINTS', Icons.directions_bus),
            ..._pickups.asMap().entries.map((e) => _pickupInlineTile(e.key, e.value, cardColor, borderColor)).toList(),
            _addBtn('ADD PICKUP POINT', () {
              setState(() => _pickups.add(PickupOption(location: '', price: 0.0)));
            }),
            const SizedBox(height: 24),

            // ── INCLUSIONS & EXCLUSIONS ──────────────────────────────────────
            _sectionHeader('INCLUSIONS & EXCLUSIONS', Icons.checklist),
            const Text('INCLUSIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            ..._inclusions.asMap().entries.map((e) => _listEditorTile(e.key, e.value, _inclusions, cardColor, borderColor)).toList(),
            _addBtn('ADD INCLUSION', () => setState(() => _inclusions.add(''))),
            const SizedBox(height: 16),
            const Text('EXCLUSIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            ..._exclusions.asMap().entries.map((e) => _listEditorTile(e.key, e.value, _exclusions, cardColor, borderColor)).toList(),
            _addBtn('ADD EXCLUSION', () => setState(() => _exclusions.add(''))),
            const SizedBox(height: 24),

            // ── CARRY LIST ───────────────────────────────────────────────────
            _sectionHeader('CARRY LIST (ESSENTIAL GEAR)', Icons.backpack),
            ..._carryList.asMap().entries.map((e) => _listEditorTile(e.key, e.value, _carryList, cardColor, borderColor, label: 'Gear Item')).toList(),
            _addBtn('ADD GEAR ITEM', () => setState(() => _carryList.add(''))),
            const SizedBox(height: 24),

            // ── SEASONAL INFO ────────────────────────────────────────────────
            _sectionHeader('SEASONAL DYNAMICS (JSON)', Icons.wb_sunny_outlined),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15), border: Border.all(color: borderColor)),
              child: TextField(
                controller: _seasonalInfoCtrl,
                maxLines: 4,
                style: const TextStyle(fontFamily: 'Courier', fontSize: 12),
                decoration: const InputDecoration(border: InputBorder.none, hintText: '{"summer": "Best", "winter": "Closed"}'),
              ),
            ),
            const SizedBox(height: 24),

            // ── DESCRIPTION ───────────────────────────────────────────────────
            _sectionHeader('TRIP STORY / NARRATIVE', Icons.description),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15), border: Border.all(color: borderColor)),
              child: TextField(controller: _descriptionCtrl, maxLines: 8, decoration: const InputDecoration(border: InputBorder.none, hintText: 'Enter full trip story...')),
            ),
            const SizedBox(height: 24),

            // ── LEGAL ─────────────────────────────────────────────────────────
            _sectionHeader('LEGAL & POLICIES', Icons.gavel),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15), border: Border.all(color: borderColor)),
              child: TextField(controller: _termsCtrl, maxLines: 4, decoration: const InputDecoration(border: InputBorder.none, hintText: 'Terms & Conditions...')),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15), border: Border.all(color: borderColor)),
              child: TextField(controller: _cancellationCtrl, maxLines: 4, decoration: const InputDecoration(border: InputBorder.none, hintText: 'Cancellation Policy...')),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15), border: Border.all(color: borderColor)),
              child: TextField(controller: _travelerFormCtrl, decoration: const InputDecoration(border: InputBorder.none, hintText: 'Traveler Details Google Form URL...', icon: Icon(Icons.link))),
            ),
            const SizedBox(height: 48),

            // ── SAVE BUTTON ────────────────────────────────────────────────────
            SizedBox(
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveChanges,
                icon: Icon(isNew ? Icons.rocket_launch : Icons.save_outlined, color: Colors.white),
                label: Text(isNew ? 'LAUNCH EXPEDITION' : 'SAVE CHANGES',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Cover Images Section (up to 5 URL fields)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCoverImagesSection(Color cardColor, Color borderColor) {
    return Column(
      children: [
        ..._coverImageCtrls.asMap().entries.map((entry) {
          final i = entry.key;
          final ctrl = entry.value;
          final isPrimary = i == 0;
          return FadeInUp(
            delay: Duration(milliseconds: i * 60),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isPrimary ? const Color(0xFFD32F2F).withOpacity(0.4) : borderColor,
                  width: isPrimary ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isPrimary ? Icons.star_rounded : Icons.image_outlined,
                    size: 18,
                    color: isPrimary ? const Color(0xFFD32F2F) : Colors.grey,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      decoration: InputDecoration(
                        labelText: isPrimary ? 'Cover Image 1 (Primary)' : 'Cover Image ${i + 1}',
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: isPrimary ? const Color(0xFFD32F2F) : Colors.grey,
                        ),
                        border: InputBorder.none,
                        hintText: 'https://...',
                        hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ),
                  if (!isPrimary)
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.grey, size: 20),
                      onPressed: () => setState(() {
                        _coverImageCtrls.removeAt(i);
                      }),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
        if (_coverImageCtrls.length < _maxCoverImages)
          _addBtn('ADD COVER IMAGE (${_coverImageCtrls.length}/$_maxCoverImages)', () {
            setState(() => _coverImageCtrls.add(TextEditingController()));
          }),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Reward Points Field
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildRewardPointsField(Color cardColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.4), width: 1.5),
        gradient: LinearGradient(
          colors: [Colors.amber.withOpacity(0.04), cardColor],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _rewardPointsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Reward Points Awarded on Booking',
                labelStyle: TextStyle(fontSize: 12, color: Colors.amber),
                hintText: 'e.g. 500',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                border: InputBorder.none,
                helperText: 'Points credited to user wallet after booking confirmation',
                helperStyle: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────
  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.blueGrey)),
        ],
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, IconData icon, Color cardColor, Color borderColor, {TextInputType type = TextInputType.text}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        decoration: InputDecoration(
          icon: Icon(icon, size: 18, color: Colors.grey),
          labelText: label,
          border: InputBorder.none,
          labelStyle: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildCategoryPicker(Color cardColor, Color borderColor) {
    if (_isCategoriesLoading) return const Center(child: CircularProgressIndicator());
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          onChanged: (v) => setState(() => _selectedCategory = v!),
          items: _availableCategories.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name, style: const TextStyle(fontSize: 14)))).toList(),
        ),
      ),
    );
  }

  Widget _packageInlineTile(int index, Map<String, dynamic> pkg, Color cardColor, Color borderColor) {
    return FadeInUp(
      delay: Duration(milliseconds: index * 50),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: TextFormField(
                  initialValue: pkg['name'],
                  onChanged: (v) => _localPackages[index]['name'] = v,
                  decoration: const InputDecoration(labelText: 'Package Name', border: InputBorder.none, labelStyle: TextStyle(fontSize: 11)),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                )),
                const SizedBox(width: 12),
                SizedBox(width: 90, child: TextFormField(
                  initialValue: pkg['price'].toString(),
                  onChanged: (v) => _localPackages[index]['price'] = double.tryParse(v) ?? 0.0,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Price ₹', border: InputBorder.none, labelStyle: TextStyle(fontSize: 11)),
                  style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13),
                )),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.grey, size: 20),
                  onPressed: () => setState(() => _localPackages.removeAt(index)),
                ),
              ],
            ),
            TextFormField(
              initialValue: pkg['description'],
              onChanged: (v) => _localPackages[index]['description'] = v,
              decoration: const InputDecoration(labelText: 'Description / Inclusions', border: InputBorder.none, labelStyle: TextStyle(fontSize: 10)),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            // Reward points row for this package
            Row(
              children: [
                const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 16),
                const SizedBox(width: 8),
                SizedBox(
                  width: 160,
                  child: TextFormField(
                    initialValue: (pkg['reward_points'] ?? 0).toString(),
                    onChanged: (v) => _localPackages[index]['reward_points'] = int.tryParse(v) ?? 0,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Reward Pts for this package',
                      border: InputBorder.none,
                      labelStyle: TextStyle(fontSize: 10, color: Colors.amber),
                    ),
                    style: const TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('pts', style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _itineraryTile(int index, TripItinerary day) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        title: Text('DAY ${day.day}: ${day.title.isNotEmpty ? day.title : "TBD"}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
              onPressed: () => setState(() => _itinerary.removeAt(index)),
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextFormField(
                  onChanged: (v) {
                    _itinerary[index] = TripItinerary(day: day.day, title: v, description: day.description, distance: day.distance, time: day.time);
                  },
                  initialValue: day.title,
                  decoration: const InputDecoration(labelText: 'Day Title'),
                ),
                TextFormField(
                  onChanged: (v) {
                    _itinerary[index] = TripItinerary(day: day.day, title: day.title, description: v, distance: day.distance, time: day.time);
                  },
                  initialValue: day.description,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                Row(
                  children: [
                    Expanded(child: TextFormField(
                      onChanged: (v) {
                        _itinerary[index] = TripItinerary(day: day.day, title: day.title, description: day.description, distance: v, time: day.time);
                      },
                      initialValue: day.distance,
                      decoration: const InputDecoration(labelText: 'Distance (km)'),
                    )),
                    const SizedBox(width: 16),
                    Expanded(child: TextFormField(
                      onChanged: (v) {
                        _itinerary[index] = TripItinerary(day: day.day, title: day.title, description: day.description, distance: day.distance, time: v);
                      },
                      initialValue: day.time,
                      decoration: const InputDecoration(labelText: 'Est. Time'),
                    )),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _pickupInlineTile(int index, PickupOption p, Color cardColor, Color borderColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15), border: Border.all(color: borderColor)),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: TextFormField(
            initialValue: p.location,
            onChanged: (v) => _pickups[index] = PickupOption(location: v, price: _pickups[index].price),
            decoration: const InputDecoration(labelText: 'Pickup Location', border: InputBorder.none, labelStyle: TextStyle(fontSize: 11)),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          )),
          const SizedBox(width: 12),
          SizedBox(width: 70, child: TextFormField(
            initialValue: p.price.toString(),
            onChanged: (v) => _pickups[index] = PickupOption(location: _pickups[index].location, price: double.tryParse(v) ?? 0.0),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Cost ₹', border: InputBorder.none, labelStyle: TextStyle(fontSize: 11)),
            style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13),
          )),
          IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.grey, size: 20), onPressed: () => setState(() => _pickups.removeAt(index))),
        ],
      ),
    );
  }

  Widget _addBtn(String label, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add_circle_outline, size: 16, color: Color(0xFF2E7B32)),
      label: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2E7B32))),
    );
  }

  Widget _listEditorTile(int index, String value, List<String> list, Color cardColor, Color borderColor, {String label = 'Entry'}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
      child: Row(
        children: [
          Expanded(child: TextFormField(
            initialValue: value,
            onChanged: (v) => list[index] = v,
            decoration: InputDecoration(labelText: label, border: InputBorder.none, labelStyle: const TextStyle(fontSize: 11)),
            style: const TextStyle(fontSize: 12),
          )),
          IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey), onPressed: () => setState(() => list.removeAt(index))),
        ],
      ),
    );
  }
}
