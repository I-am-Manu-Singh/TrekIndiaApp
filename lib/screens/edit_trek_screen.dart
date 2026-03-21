import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trek.dart';

class EditTrekScreen extends StatefulWidget {
  final Trek? trek;
  const EditTrekScreen({super.key, this.trek});

  @override
  State<EditTrekScreen> createState() => _EditTrekScreenState();
}

class _EditTrekScreenState extends State<EditTrekScreen> {
  final _client = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  
  bool get isNew => widget.trek == null;

  late TextEditingController _titleCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _durationCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _discountCtrl;
  late TextEditingController _descriptionCtrl;
  late TextEditingController _imageUrlCtrl;
  late TextEditingController _bestMonthsCtrl;
  late TextEditingController _latCtrl;
  late TextEditingController _lngCtrl;
  late TextEditingController _altCtrl;
  late TextEditingController _diffCtrl;
  late TextEditingController _distCtrl;
  
  List<PickupOption> _pickups = [];
  List<TrekItinerary> _itinerary = [];
  List<Map<String, dynamic>> _localPackages = []; // Using maps for easy inline editing
  List<String> _inclusions = [];
  List<String> _exclusions = [];

  String _selectedCategory = 'Adventure Trek';
  final List<String> _categories = ['Adventure Trek', 'Religious Trek', 'Yatra', 'Weekend Trek', 'International Trek'];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.trek?.title ?? '');
    _locationCtrl = TextEditingController(text: widget.trek?.location ?? '');
    _durationCtrl = TextEditingController(text: widget.trek?.duration ?? '');
    _priceCtrl = TextEditingController(text: (widget.trek?.basePrice ?? 0).toString());
    _discountCtrl = TextEditingController(text: (widget.trek?.discountPercent ?? 0).toString());
    _descriptionCtrl = TextEditingController(text: widget.trek?.description ?? '');
    _imageUrlCtrl = TextEditingController(text: widget.trek?.imageUrl ?? '');
    _bestMonthsCtrl = TextEditingController(text: widget.trek?.bestMonths ?? 'Mar-Jun, Sep-Dec');
    _latCtrl = TextEditingController(text: (widget.trek?.latitude ?? 30.7333).toString());
    _lngCtrl = TextEditingController(text: (widget.trek?.longitude ?? 76.7794).toString());
    _altCtrl = TextEditingController(text: widget.trek?.altitude ?? '');
    _diffCtrl = TextEditingController(text: widget.trek?.difficulty ?? 'Moderate');
    _distCtrl = TextEditingController(text: widget.trek?.totalDistance ?? '');
    _selectedCategory = widget.trek?.category ?? 'Adventure Trek';

    _pickups = List.from(widget.trek?.pickupOptions ?? []);
    _itinerary = List.from(widget.trek?.itinerary ?? [TrekItinerary(day: 1, title: 'Arrival', description: 'Base camp arrival')]);
    _inclusions = List.from(widget.trek?.inclusions ?? []);
    _exclusions = List.from(widget.trek?.exclusions ?? []);
    
    if (!isNew) {
      _fetchPackages();
    }
  }

  Future<void> _fetchPackages() async {
    final res = await _client.from('trek_packages').select().eq('trek_id', widget.trek!.id);
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
      final missionData = {
        'title': _titleCtrl.text.trim().toUpperCase(),
        'location': _locationCtrl.text.trim(),
        'duration': _durationCtrl.text.trim(),
        'base_price': double.tryParse(_priceCtrl.text) ?? 0,
        'discount_percent': double.tryParse(_discountCtrl.text) ?? 0,
        'description': _descriptionCtrl.text.trim(),
        'image_url': _imageUrlCtrl.text.trim(),
        'category': _selectedCategory,
        'best_months': _bestMonthsCtrl.text.trim(),
        'latitude': double.tryParse(_latCtrl.text) ?? 30.7333,
        'longitude': double.tryParse(_lngCtrl.text) ?? 76.7794,
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
        if (isNew) 'created_at': DateTime.now().toIso8601String(),
      };

      String trekId;
      if (isNew) {
        final res = await _client.from('treks').insert(missionData).select().single();
        trekId = res['id'];
      } else {
        trekId = widget.trek!.id;
        await _client.from('treks').update(missionData).eq('id', trekId);
      }

      // Sync Packages
      // For simplicity, we'll delete and re-insert for updates, or handle them one by one
      // But for a better approach:
      await _client.from('trek_packages').delete().eq('trek_id', trekId);
      if (_localPackages.isNotEmpty) {
        await _client.from('trek_packages').insert(_localPackages.map((p) => {
          'trek_id': trekId,
          'name': p['name'],
          'price': p['price'],
          'description': p['description'],
        }).toList());
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isNew ? 'TREK DEPLOYED SUCCESSFULLY' : 'TREK UPDATED SUCCESSFULLY'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('TERMINAL ERROR: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(isNew ? 'NEW TREK DEPLOYMENT' : 'TREK CONFIGURATION', 
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
            _sectionHeader('CORE TREK INTEL'),
            _buildInput('Operation Name', _titleCtrl, Icons.terrain),
            Row(
              children: [
                Expanded(child: _buildInput('Latitude', _latCtrl, Icons.location_on, type: TextInputType.number)),
                const SizedBox(width: 16),
                Expanded(child: _buildInput('Longitude', _lngCtrl, Icons.location_on, type: TextInputType.number)),
              ],
            ),
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
            _buildCategoryPicker(),
            const SizedBox(height: 32),
            
            _sectionHeader('TREK LOGISTICS'),
            Row(
              children: [
                Expanded(child: _buildInput('Total Distance', _distCtrl, Icons.directions_walk)),
                const SizedBox(width: 16),
                Expanded(child: _buildInput('General Location', _locationCtrl, Icons.map)),
              ],
            ),
            
            const SizedBox(height: 16),
            const Text('TREK PACKAGES (INLINE CONFIG)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),
            ..._localPackages.asMap().entries.map((e) => _packageInlineTile(e.key, e.value)).toList(),
            _addBtn('ADD TREK PACKAGE', () {
              setState(() => _localPackages.add({'name': '', 'price': 0.0, 'description': ''}));
            }),
            const SizedBox(height: 32),

            _sectionHeader('EXPEDITION ITINERARY'),
            ..._itinerary.asMap().entries.map((e) => _itineraryTile(e.key, e.value)).toList(),
            _addBtn('ADD TREK DAY', () {
              setState(() => _itinerary.add(TrekItinerary(day: _itinerary.length + 1, title: '', description: '')));
            }),
            const SizedBox(height: 32),

            _sectionHeader('LOGISTICS & PICKUP'),
            ..._pickups.asMap().entries.map((e) => _pickupInlineTile(e.key, e.value)).toList(),
            _addBtn('ADD PICKUP POINT', () {
              setState(() => _pickups.add(PickupOption(location: '', price: 0.0)));
            }),
            const SizedBox(height: 32),

            _sectionHeader('TREK STORY / TREK DETAILS'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
              child: TextField(controller: _descriptionCtrl, maxLines: 8, decoration: const InputDecoration(border: InputBorder.none, hintText: 'Enter full trek story...')),
            ),
            const SizedBox(height: 48),

            SizedBox(
              height: 60,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveChanges,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7B32), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: Text(isNew ? 'LAUNCH TREK DEPLOYMENT' : 'UPDATE TREK DATA', 
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          isExpanded: true,
          onChanged: (v) => setState(() => _selectedCategory = v!),
          items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14)))).toList(),
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

  Widget _itineraryTile(int index, TrekItinerary day) {
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
                    _itinerary[index] = TrekItinerary(day: day.day, title: v, description: day.description, distance: day.distance, time: day.time);
                  },
                  initialValue: day.title,
                  decoration: const InputDecoration(labelText: 'Day Title'),
                ),
                TextFormField(
                  onChanged: (v) {
                    _itinerary[index] = TrekItinerary(day: day.day, title: day.title, description: v, distance: day.distance, time: day.time);
                  },
                  initialValue: day.description,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                Row(
                  children: [
                    Expanded(child: TextFormField(
                      onChanged: (v) {
                        _itinerary[index] = TrekItinerary(day: day.day, title: day.title, description: day.description, distance: v, time: day.time);
                      },
                      initialValue: day.distance,
                      decoration: const InputDecoration(labelText: 'Distance (km)'),
                    )),
                    const SizedBox(width: 16),
                    Expanded(child: TextFormField(
                      onChanged: (v) {
                        _itinerary[index] = TrekItinerary(day: day.day, title: day.title, description: day.description, distance: day.distance, time: v);
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
}
