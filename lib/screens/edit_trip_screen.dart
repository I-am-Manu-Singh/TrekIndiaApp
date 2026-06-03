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

  late TextEditingController _titleCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _durationCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _discountCtrl;
  late TextEditingController _descriptionCtrl;
  late TextEditingController _imageUrlCtrl;
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
  
  List<PickupOption> _pickups = [];
  List<TripItinerary> _itinerary = [];
  List<Map<String, dynamic>> _localPackages = []; // Using maps for easy inline editing
  List<String> _inclusions = [];
  List<String> _exclusions = [];
  List<String> _carryList = [];
  late TextEditingController _ratingCtrl;
  late TextEditingController _seasonalInfoCtrl;
  List<String> _extraImages = [];

  List<TripCategory> _availableCategories = [];
  String _selectedCategory = 'Adventure Trip';
  bool _isLoading = false;
  bool _isCategoriesLoading = true;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.trip?.title ?? '');
    _locationCtrl = TextEditingController(text: widget.trip?.location ?? '');
    _durationCtrl = TextEditingController(text: widget.trip?.duration ?? '');
    _priceCtrl = TextEditingController(text: (widget.trip?.basePrice ?? 0).toString());
    _discountCtrl = TextEditingController(text: (widget.trip?.discountPercent ?? 0).toString());
    _descriptionCtrl = TextEditingController(text: widget.trip?.description ?? '');
    _imageUrlCtrl = TextEditingController(text: widget.trip?.imageUrl ?? '');
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
    _selectedCategory = widget.trip?.category ?? 'Adventure Trip';

    _pickups = List.from(widget.trip?.pickupOptions ?? []);
    _itinerary = List.from(widget.trip?.itinerary ?? [TripItinerary(day: 1, title: 'Arrival', description: 'Base camp arrival')]);
    _inclusions = List.from(widget.trip?.inclusions ?? []);
    _exclusions = List.from(widget.trip?.exclusions ?? []);
    _carryList = List.from(widget.trip?.carryList ?? []);
    _extraImages = List.from(widget.trip?.images ?? []);
    
    _fetchCategories();
    if (!isNew) {
      _fetchPackages();
    }
  }

  Future<void> _fetchCategories() async {
    setState(() => _isCategoriesLoading = true);
    final cats = await DatabaseService().fetchCategories();
    if (mounted) {
      setState(() {
        _availableCategories = cats;
        _isCategoriesLoading = false;
        // Ensure selected category exists in the fetched list, else default to first
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
        }).toList();
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final tripData = {
        'title': _titleCtrl.text.trim().toUpperCase(),
        'location': _locationCtrl.text.trim(),
        'duration': _durationCtrl.text.trim(),
        'base_price': double.tryParse(_priceCtrl.text) ?? 0,
        'discount_percent': double.tryParse(_discountCtrl.text) ?? 0,
        'description': _descriptionCtrl.text.trim(),
        'image_url': _imageUrlCtrl.text.trim(),
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
        'images': _extraImages,
        'peak_elevation': _peakElevCtrl.text.trim(),
        'trail_type': _trailTypeCtrl.text.trim(),
        'orientation': _orientationCtrl.text.trim(),
        'start_point': _startPointCtrl.text.trim(),
        'package_type': _packageTypeCtrl.text.trim(),
        'rating': double.tryParse(_ratingCtrl.text) ?? 5.0,
        'carry_list': _carryList,
        'seasonal_info': _parseSeasonalInfo(),
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

      // Sync Packages
      await _client.from('trip_packages').delete().eq('trip_id', tripId);
      if (_localPackages.isNotEmpty) {
        await _client.from('trip_packages').insert(_localPackages.map((p) => {
          'trip_id': tripId,
          'name': p['name'],
          'price': p['price'],
          'description': p['description'],
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
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('DASHBOARD ERROR: $e'), backgroundColor: Colors.red));
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(isNew ? 'NEW EXPEDITION' : 'TRIP CUSTOMIZATION', 
                   style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2)),
        actions: [
          if (_isLoading) const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          if (!_isLoading) IconButton(icon: const Icon(Icons.rocket_launch_outlined), onPressed: _saveChanges),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _sectionHeader('CORE TRIP INFO'),
            _buildInput('Operation Name', _titleCtrl, Icons.terrain),
            _buildInput('Google Map Link', _googleMapLinkCtrl, Icons.pin_drop),
            Row(
              children: [
                Expanded(child: _buildInput('Duration', _durationCtrl, Icons.timer)),
                const SizedBox(width: 16),
                Expanded(child: _buildInput('Max Altitude', _altCtrl, Icons.landscape)),
              ],
            ),
            Row(
              children: [
                Expanded(child: _buildInput('Base Price', _priceCtrl, Icons.payments_outlined, type: TextInputType.number)),
                const SizedBox(width: 16),
                Expanded(child: _buildInput('Discount %', _discountCtrl, Icons.percent, type: TextInputType.number)),
              ],
            ),
            _buildInput('Difficulty Level (e.g. Moderate)', _diffCtrl, Icons.speed),
            _buildInput('Best Months', _bestMonthsCtrl, Icons.calendar_month),
            _buildInput('Cover Image URL', _imageUrlCtrl, Icons.image),
            
            _sectionHeader('HIGH FIDELITY SPECS'),
            Row(
              children: [
                Expanded(child: _buildInput('Peak Elevation', _peakElevCtrl, Icons.height)),
                const SizedBox(width: 16),
                Expanded(child: _buildInput('Orientation', _orientationCtrl, Icons.explore_outlined)),
              ],
            ),
            Row(
              children: [
                Expanded(child: _buildInput('Start Point', _startPointCtrl, Icons.flag_outlined)),
                const SizedBox(width: 16),
                Expanded(child: _buildInput('Package Type', _packageTypeCtrl, Icons.inventory_2_outlined)),
              ],
            ),
            _buildInput('Trail Type (e.g. Rugged, Coastal)', _trailTypeCtrl, Icons.route_outlined),
            _buildInput('Rating (1-5)', _ratingCtrl, Icons.star, type: TextInputType.number),
            
            _buildCategoryPicker(),
            const SizedBox(height: 32),
            
            _sectionHeader('LOGISTICS & ACCESSIBILITY'),
            Row(
              children: [
                Expanded(child: _buildInput('Total Distance', _distCtrl, Icons.directions_walk)),
                const SizedBox(width: 16),
                Expanded(child: _buildInput('General Location', _locationCtrl, Icons.map)),
              ],
            ),
            
            const SizedBox(height: 16),
            const Text('INVENTORY PACKAGES (INLINE CONFIG)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),
            ..._localPackages.asMap().entries.map((e) => _packageInlineTile(e.key, e.value)).toList(),
            _addBtn('ADD PRICING PACKAGE', () {
              setState(() => _localPackages.add({'name': '', 'price': 0.0, 'description': ''}));
            }),
            const SizedBox(height: 32),

            _sectionHeader('ITINERARY & TIMELINE'),
            ..._itinerary.asMap().entries.map((e) => _itineraryTile(e.key, e.value)).toList(),
            _addBtn('ADD DAY / STEP', () {
              setState(() => _itinerary.add(TripItinerary(day: _itinerary.length + 1, title: '', description: '')));
            }),
            const SizedBox(height: 32),

            _sectionHeader('LOGISTICS & PICKUP'),
            ..._pickups.asMap().entries.map((e) => _pickupInlineTile(e.key, e.value)).toList(),
            _addBtn('ADD PICKUP POINT', () {
              setState(() => _pickups.add(PickupOption(location: '', price: 0.0)));
            }),
            const SizedBox(height: 32),

            _sectionHeader('INCLUSIONS & EXCLUSIONS'),
            const Text('INCLUSIONS (ONE PER LINE)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            ..._inclusions.asMap().entries.map((e) => _listEditorTile(e.key, e.value, _inclusions)).toList(),
            _addBtn('ADD INCLUSION', () => setState(() => _inclusions.add(''))),
            const SizedBox(height: 16),
            const Text('EXCLUSIONS (ONE PER LINE)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            ..._exclusions.asMap().entries.map((e) => _listEditorTile(e.key, e.value, _exclusions)).toList(),
            _addBtn('ADD EXCLUSION', () => setState(() => _exclusions.add(''))),
            const SizedBox(height: 32),

            _sectionHeader('EXTRA IMAGE GALLERY'),
            ..._extraImages.asMap().entries.map((e) => _listEditorTile(e.key, e.value, _extraImages, label: 'Image URL')).toList(),
            _addBtn('ADD GALLERY IMAGE', () => setState(() => _extraImages.add(''))),
            const SizedBox(height: 32),

            _sectionHeader('CARRY LIST (ESSENTIAL GEAR)'),
            ..._carryList.asMap().entries.map((e) => _listEditorTile(e.key, e.value, _carryList, label: 'Gear Item')).toList(),
            _addBtn('ADD GEAR ITEM', () => setState(() => _carryList.add(''))),
            const SizedBox(height: 32),

            _sectionHeader('SEASONAL DYNAMICS (JSON)'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
              child: TextField(
                controller: _seasonalInfoCtrl,
                maxLines: 4,
                style: const TextStyle(fontFamily: 'Courier', fontSize: 12),
                decoration: const InputDecoration(border: InputBorder.none, hintText: '{"summer": "Best", "winter": "Closed"}'),
              ),
            ),
            const SizedBox(height: 32),

            _sectionHeader('TRIP STORY / NARRATIVE'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
              child: TextField(controller: _descriptionCtrl, maxLines: 8, decoration: const InputDecoration(border: InputBorder.none, hintText: 'Enter full trip story...')),
            ),
            const SizedBox(height: 32),

            _sectionHeader('LEGAL & POLICIES'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
              child: TextField(controller: _termsCtrl, maxLines: 4, decoration: const InputDecoration(border: InputBorder.none, hintText: 'Terms & Conditions...')),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
              child: TextField(controller: _cancellationCtrl, maxLines: 4, decoration: const InputDecoration(border: InputBorder.none, hintText: 'Cancellation Policy...')),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
              child: TextField(controller: _travelerFormCtrl, decoration: const InputDecoration(border: InputBorder.none, hintText: 'Google Form URL for Traveler Details...', icon: Icon(Icons.link))),
            ),
            const SizedBox(height: 48),

            SizedBox(
              height: 60,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveChanges,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: Text(isNew ? 'LAUNCH TRIP' : 'UPDATE TRIP DATA', 
                           style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.blueGrey)),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, IconData icon, {TextInputType type = TextInputType.text}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        decoration: InputDecoration(icon: Icon(icon, size: 18), labelText: label, border: InputBorder.none, labelStyle: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _buildCategoryPicker() {
    if (_isCategoriesLoading) return const Center(child: CircularProgressIndicator());
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          isExpanded: true,
          onChanged: (v) => setState(() => _selectedCategory = v!),
          items: _availableCategories.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name, style: const TextStyle(fontSize: 14)))).toList(),
        ),
      ),
    );
  }

  Widget _packageInlineTile(int index, Map<String, dynamic> pkg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
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
              SizedBox(width: 80, child: TextFormField(
                initialValue: pkg['price'].toString(),
                onChanged: (v) => _localPackages[index]['price'] = double.tryParse(v) ?? 0.0,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price', border: InputBorder.none, labelStyle: TextStyle(fontSize: 11)),
                style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13),
              )),
              IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.grey, size: 20), onPressed: () => setState(() => _localPackages.removeAt(index))),
            ],
          ),
          TextFormField(
            initialValue: pkg['description'],
            onChanged: (v) => _localPackages[index]['description'] = v,
            decoration: const InputDecoration(labelText: 'Description / Inclusions', border: InputBorder.none, labelStyle: TextStyle(fontSize: 10)),
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _itineraryTile(int index, TripItinerary day) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        title: Text('DAY ${day.day}: ${day.title.isNotEmpty ? day.title : "TBD"}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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

  Widget _pickupInlineTile(int index, PickupOption p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
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
            decoration: const InputDecoration(labelText: 'Cost', border: InputBorder.none, labelStyle: TextStyle(fontSize: 11)),
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
      label: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2E7B32)))
    );
  }

  Widget _listEditorTile(int index, String value, List<String> list, {String label = 'Entry'}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
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
