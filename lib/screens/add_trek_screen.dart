import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddTrekScreen extends StatefulWidget {
  final Map<String, dynamic>? editTrek;
  const AddTrekScreen({super.key, this.editTrek});

  @override
  State<AddTrekScreen> createState() => _AddTrekScreenState();
}

class _AddTrekScreenState extends State<AddTrekScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _durationController = TextEditingController();
  final _difficultyController = TextEditingController();
  final _altitudeController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _distanceController = TextEditingController();
  final _extraImagesController = TextEditingController();
  final _inclusionsController = TextEditingController();
  final _exclusionsController = TextEditingController();
  final _carryListController = TextEditingController();
  final _latController = TextEditingController(text: '30.7333');
  final _lngController = TextEditingController(text: '76.7794');
  final _itineraryController = TextEditingController(text: '[]');
  final _pickupController = TextEditingController(text: '[]');
  final _bestMonthsController = TextEditingController(text: 'Mar-Jun, Sep-Dec');
  String _selectedCategory = 'Adventure Trek';
  
  final List<String> _categories = [
    'Adventure Trek', 
    'Religious Trek', 
    'Yatra', 
    'Weekend Trek', 
    'International Trek'
  ];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.editTrek != null) {
      final t = widget.editTrek!;
      _titleController.text = t['title'] ?? '';
      _locationController.text = t['location'] ?? '';
      _durationController.text = t['duration'] ?? '';
      _difficultyController.text = t['difficulty'] ?? '';
      _altitudeController.text = t['altitude'] ?? '';
      _priceController.text = (t['base_price'] ?? 0).toString();
      _descriptionController.text = t['description'] ?? '';
      _imageUrlController.text = t['image_url'] ?? '';
      _distanceController.text = t['total_distance'] ?? '';
      _extraImagesController.text = (t['images'] as List?)?.join(', ') ?? '';
      _inclusionsController.text = (t['inclusions'] as List?)?.join(', ') ?? '';
      _exclusionsController.text = (t['exclusions'] as List?)?.join(', ') ?? '';
      _carryListController.text = (t['carry_list'] as List?)?.join(', ') ?? '';
      _latController.text = (t['latitude'] ?? 30.7333).toString();
      _lngController.text = (t['longitude'] ?? 76.7794).toString();
      _itineraryController.text = jsonEncode(t['itinerary'] ?? []);
      _pickupController.text = jsonEncode(t['pickup_options'] ?? []);
      _bestMonthsController.text = t['best_months'] ?? 'Mar-Jun, Sep-Dec';
      _selectedCategory = t['category'] ?? 'Adventure Trek';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _durationController.dispose();
    _difficultyController.dispose();
    _altitudeController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _distanceController.dispose();
    _extraImagesController.dispose();
    _inclusionsController.dispose();
    _exclusionsController.dispose();
    _carryListController.dispose();
    super.dispose();
  }

  Future<void> _submitTrek() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    try {
      final data = {
        'title': _titleController.text,
        'location': _locationController.text,
        'duration': _durationController.text,
        'difficulty': _difficultyController.text,
        'altitude': _altitudeController.text,
        'base_price': double.parse(_priceController.text),
        'discount_percent': 0.0,
        'description': _descriptionController.text,
        'image_url': _imageUrlController.text,
        'images': _extraImagesController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        'inclusions': _inclusionsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        'exclusions': _exclusionsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        'carry_list': _carryListController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        'category': _selectedCategory,
        'total_distance': _distanceController.text,
        'best_months': _bestMonthsController.text,
        'latitude': double.tryParse(_latController.text) ?? 30.7333,
        'longitude': double.tryParse(_lngController.text) ?? 76.7794,
        'rating': 5.0, 
        'itinerary': jsonDecode(_itineraryController.text), 
        'pickup_options': jsonDecode(_pickupController.text),
      };

      if (widget.editTrek != null) {
        await Supabase.instance.client.from('treks').update(data).eq('id', widget.editTrek!['id']);
      } else {
        await Supabase.instance.client.from('treks').insert(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.editTrek != null ? 'Trek Updated!' : 'Trek published!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.editTrek != null ? 'REFINE EXPEDITION' : 'LAUNCH NEW MISSION', style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 13)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle('Basic Information'),
              const SizedBox(height: 16),
              _buildTextField(_titleController, 'Trek Title', Icons.title),
              _buildTextField(_locationController, 'Region/State', Icons.location_on),
              
              Row(
                children: [
                  Expanded(child: _buildTextField(_durationController, 'Duration', Icons.timer)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTextField(_difficultyController, 'Difficulty', Icons.terrain)),
                ],
              ),
              
              _buildDropdown(),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(child: _buildTextField(_altitudeController, 'Max Altitude', Icons.height)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTextField(_distanceController, 'Total Distance', Icons.directions_walk)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTextField(_priceController, 'Base Price (₹)', Icons.currency_rupee, keyboardType: TextInputType.number)),
                ],
              ),
              
              _buildTextField(_imageUrlController, 'Cover Image URL', Icons.image, keyboardType: TextInputType.url),
              _buildTextField(_extraImagesController, 'Extra Images (Comma separated)', Icons.collections_bookmark_outlined, maxLines: 2),
              _buildTextField(_inclusionsController, 'Inclusions (Comma separated)', Icons.check_circle_outline, maxLines: 2),
              _buildTextField(_exclusionsController, 'Exclusions (Comma separated)', Icons.cancel_outlined, maxLines: 2),
              _buildTextField(_carryListController, 'Carry List (Comma separated)', Icons.backpack_outlined, maxLines: 2),
              Row(
                children: [
                   Expanded(child: _buildTextField(_latController, 'Latitude', Icons.location_on, keyboardType: TextInputType.number)),
                   const SizedBox(width: 12),
                   Expanded(child: _buildTextField(_lngController, 'Longitude', Icons.location_on, keyboardType: TextInputType.number)),
                ],
              ),
              _buildTextField(_bestMonthsController, 'Best Months', Icons.calendar_month),
              const SizedBox(height: 8),
              const Text('Pickup Options (JSON List)', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
              _buildTextField(_pickupController, '', Icons.map, maxLines: 2),
              const Text('Expedition Itinerary (JSON List)', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
              _buildTextField(_itineraryController, '', Icons.list, maxLines: 4),
              _buildTextField(_descriptionController, 'Full Story / Details', Icons.description, maxLines: 6),
              
              const SizedBox(height: 30),
              FadeInUp(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitTrek,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(widget.editTrek != null ? 'Update Trek' : 'Launch Trek', style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return FadeInLeft(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildDropdown() {
    return FadeInUp(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: DropdownButtonFormField<String>(
          value: _selectedCategory,
          decoration: InputDecoration(
            labelText: 'Category',
            prefixIcon: const Icon(Icons.category),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
            filled: true,
            fillColor: Theme.of(context).cardColor,
          ),
          items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setState(() => _selectedCategory = v!),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {int maxLines = 1, TextInputType? keyboardType}) {
    return FadeInUp(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: (value) => value!.isEmpty ? 'Required' : null,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: maxLines == 1 ? Icon(icon) : null,
            alignLabelWithHint: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
            filled: true,
            fillColor: Theme.of(context).cardColor,
          ),
        ),
      ),
    );
  }
}
