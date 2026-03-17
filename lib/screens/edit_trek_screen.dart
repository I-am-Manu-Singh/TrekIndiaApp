import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trek.dart';

class EditTrekScreen extends StatefulWidget {
  final Trek trek;
  const EditTrekScreen({super.key, required this.trek});

  @override
  State<EditTrekScreen> createState() => _EditTrekScreenState();
}

class _EditTrekScreenState extends State<EditTrekScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _durationController;
  late TextEditingController _difficultyController;
  late TextEditingController _altitudeController;
  late TextEditingController _priceController;
  late TextEditingController _discountController;
  late TextEditingController _descriptionController;
  late TextEditingController _imageUrlController;
  late TextEditingController _pickupController;
  late TextEditingController _distanceController;
  late TextEditingController _extraImagesController;
  late TextEditingController _inclusionsController;
  late TextEditingController _exclusionsController;
  late TextEditingController _carryListController;
  late TextEditingController _latController;
  late TextEditingController _lngController;
  late TextEditingController _itineraryController;
  late TextEditingController _bestMonthsController;
  
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
    _titleController = TextEditingController(text: widget.trek.title);
    _locationController = TextEditingController(text: widget.trek.location);
    _durationController = TextEditingController(text: widget.trek.duration);
    _difficultyController = TextEditingController(text: widget.trek.difficulty);
    _altitudeController = TextEditingController(text: widget.trek.altitude);
    _priceController = TextEditingController(text: widget.trek.basePrice.toString());
    _discountController = TextEditingController(text: widget.trek.discountPercent.toString());
    _descriptionController = TextEditingController(text: widget.trek.description);
    _imageUrlController = TextEditingController(text: widget.trek.imageUrl);
    _distanceController = TextEditingController(text: widget.trek.totalDistance);
    _extraImagesController = TextEditingController(text: widget.trek.images.join(', '));
    _inclusionsController = TextEditingController(text: widget.trek.inclusions.join(', '));
    _exclusionsController = TextEditingController(text: widget.trek.exclusions.join(', '));
    _carryListController = TextEditingController(text: widget.trek.carryList.join(', '));
    _latController = TextEditingController(text: widget.trek.latitude.toString());
    _lngController = TextEditingController(text: widget.trek.longitude.toString());
    _selectedCategory = widget.trek.category;
    
    final pickupData = widget.trek.pickupOptions.map((o) => {'location': o.location, 'price': o.price}).toList();
    _pickupController = TextEditingController(text: jsonEncode(pickupData));

    final itineraryData = widget.trek.itinerary.map((i) => {
      'day': i.day,
      'title': i.title,
      'description': i.description,
      'distance': i.distance,
      'time': i.time,
      'image': i.imageUrl,
    }).toList();
    _itineraryController = TextEditingController(text: jsonEncode(itineraryData));
    _bestMonthsController = TextEditingController(text: widget.trek.bestMonths);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _durationController.dispose();
    _difficultyController.dispose();
    _altitudeController.dispose();
    _priceController.dispose();
    _discountController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _pickupController.dispose();
    _distanceController.dispose();
    _extraImagesController.dispose();
    _inclusionsController.dispose();
    _exclusionsController.dispose();
    _carryListController.dispose();
    super.dispose();
  }

  Future<void> _updateTrek() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final pickupJson = jsonDecode(_pickupController.text);
      final itineraryJson = jsonDecode(_itineraryController.text);
      final List<String> extraImages = _extraImagesController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      final List<String> inclusions = _inclusionsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      final List<String> exclusions = _exclusionsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      final List<String> carryList = _carryListController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

      await Supabase.instance.client.from('treks').update({
        'title': _titleController.text,
        'location': _locationController.text,
        'duration': _durationController.text,
        'difficulty': _difficultyController.text,
        'altitude': _altitudeController.text,
        'base_price': double.parse(_priceController.text),
        'discount_percent': double.parse(_discountController.text),
        'description': _descriptionController.text,
        'image_url': _imageUrlController.text,
        'images': extraImages,
        'inclusions': inclusions,
        'exclusions': exclusions,
        'carry_list': carryList,
        'pickup_options': pickupJson,
        'itinerary': itineraryJson,
        'category': _selectedCategory,
        'total_distance': _distanceController.text,
        'best_months': _bestMonthsController.text,
        'latitude': double.tryParse(_latController.text) ?? 30.7333,
        'longitude': double.tryParse(_lngController.text) ?? 76.7794,
      }).eq('id', widget.trek.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trek updated!'), backgroundColor: Colors.green));
        Navigator.pop(context, true); 
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin: Edit Package'), backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FadeInDown(child: const Text('Pricing & Categorization', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
              const SizedBox(height: 20),
              _buildTextField(_titleController, 'Trek Title', Icons.title),
              Row(
                children: [
                  Expanded(child: _buildTextField(_priceController, 'Base Price', Icons.currency_rupee, keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTextField(_discountController, 'Discount %', Icons.percent, keyboardType: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Target Category', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade300)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    onChanged: (val) => setState(() => _selectedCategory = val!),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Pickup Options (JSON)', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              _buildTextField(_pickupController, '', Icons.map, maxLines: 3),
              const Divider(height: 40),
              _buildTextField(_durationController, 'Duration', Icons.timer),
              _buildTextField(_distanceController, 'Total Distance', Icons.directions_walk),
              _buildTextField(_bestMonthsController, 'Best Months (e.g. Mar-Jun)', Icons.calendar_month),
              const SizedBox(height: 16),
              const Text('Expedition Itinerary (JSON)', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              _buildTextField(_itineraryController, '', Icons.list, maxLines: 5),
              _buildTextField(_imageUrlController, 'Cover Image URL', Icons.image, keyboardType: TextInputType.url),
              _buildTextField(_extraImagesController, 'Extra Images (Comma separated)', Icons.collections, maxLines: 2),
              _buildTextField(_inclusionsController, 'Inclusions (Comma separated)', Icons.check_circle, maxLines: 2),
              _buildTextField(_exclusionsController, 'Exclusions (Comma separated)', Icons.cancel, maxLines: 2),
              _buildTextField(_carryListController, 'Carry List (Comma separated)', Icons.shopping_bag, maxLines: 2),
              Row(
                children: [
                   Expanded(child: _buildTextField(_latController, 'Latitude', Icons.location_on, keyboardType: TextInputType.number)),
                   const SizedBox(width: 12),
                   Expanded(child: _buildTextField(_lngController, 'Longitude', Icons.location_on, keyboardType: TextInputType.number)),
                ],
              ),
              _buildTextField(_descriptionController, 'Description', Icons.description, maxLines: 5),
              const SizedBox(height: 30),
              _buildPrimaryButton('Update Package', _updateTrek),
              const SizedBox(height: 40),
            ],
          ),
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
            filled: true,
            fillColor: Theme.of(context).cardColor,
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(String label, VoidCallback onPressed) {
    return FadeInUp(
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(label, style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
