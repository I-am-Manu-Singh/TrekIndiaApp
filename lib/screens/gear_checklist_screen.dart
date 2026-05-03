import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';

class GearChecklistScreen extends StatefulWidget {
  final String tripId;
  final String tripTitle;
  final List<String> carryList;

  const GearChecklistScreen({super.key, required this.tripId, required this.tripTitle, this.carryList = const []});

  @override
  State<GearChecklistScreen> createState() => _GearChecklistScreenState();
}

class _GearChecklistScreenState extends State<GearChecklistScreen> {
  final _currentUser = Supabase.instance.client.auth.currentUser;
  List<dynamic> _checklist = [];
  bool _isLoading = true;

  final List<String> _defaultGear = [
    'Tripking Shoes',
    'Rucksack (50L-60L)',
    'Warm Down Jacket',
    'Thermal Innerwear',
    'Tripking Pants x2',
    'Full Sleeve T-Shirts x3',
    'Woolen Socks x3',
    'Gloves (Waterproof)',
    'Sunglasses (UV Protection)',
    'Head Torch',
    'Water Bottle (1L)',
    'Personal Medicine Kit',
  ];

  @override
  void initState() {
    super.initState();
    _fetchChecklist();
  }

  Future<void> _fetchChecklist() async {
    if (_currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('gear_checklists')
          .select('*')
          .eq('user_id', _currentUser!.id)
          .eq('trip_id', widget.tripId)
          .order('created_at', ascending: true);

      if (response.isEmpty && mounted) {
        // Hydrate items from provided carryList or fall back to default
        final gearToUse = widget.carryList.isNotEmpty ? widget.carryList : _defaultGear;
        for (final item in gearToUse) {
          await Supabase.instance.client.from('gear_checklists').insert({
            'user_id': _currentUser!.id,
            'trip_id': widget.tripId,
            'item_name': item,
            'is_packed': false,
          });
        }
        // Fetch again after hydration
        final hydratedResponse = await Supabase.instance.client
            .from('gear_checklists')
            .select('*')
            .eq('user_id', _currentUser!.id)
            .eq('trip_id', widget.tripId)
            .order('created_at', ascending: true);
        
        if (mounted) {
          setState(() {
            _checklist = hydratedResponse;
            _isLoading = false;
          });
        }
      } else if (mounted) {
        setState(() {
          _checklist = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print('Error fetching checklist: $e');
    }
  }

  Future<void> _toggleItem(int index, String id, bool currentValue) async {
    if (_currentUser == null) return;
    
    // Optimistic UI update
    setState(() {
      _checklist[index]['is_packed'] = !currentValue;
    });

    try {
      await Supabase.instance.client
          .from('gear_checklists')
          .update({'is_packed': !currentValue})
          .eq('id', id);
    } catch (e) {
       // Revert on error
      setState(() {
        _checklist[index]['is_packed'] = currentValue;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update item')));
    }
  }

  Future<void> _addItem(String name) async {
    if (_currentUser == null || name.isEmpty) return;
    try {
      await Supabase.instance.client.from('gear_checklists').insert({
        'user_id': _currentUser!.id,
        'trip_id': widget.tripId,
        'item_name': name,
        'is_packed': false,
      });
      _fetchChecklist();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add: $e')));
    }
  }

  void _showAddDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Add Trip Gear'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Hiking Poles, Camera...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              _addItem(ctrl.text.trim());
              Navigator.pop(c);
            }, 
            child: const Text('Add to Pack')
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
   if (_currentUser == null) {
  return Scaffold(
    appBar: AppBar(
      title: Text(
        'Gear Checklist - ${widget.tripTitle}',
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 16,
          color: Colors.white,
          letterSpacing: 1.5,
        ),
      ),
      backgroundColor: const Color(0xFFD32F2F),
      elevation: 0,
    ),
    body: const Center(
      child: Text(
        'Please log in to manage your gear checklist.',
      ),
    ),
  );
}

    final packedCount = _checklist.where((item) => item['is_packed'] == true).length;
    final totalCount = _checklist.length;
    final progress = totalCount == 0 ? 0.0 : packedCount / totalCount;

    return Scaffold(
     appBar: AppBar(
  title: const Text(
    'Gear Tracker',
    style: TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 18,
      letterSpacing: 0.5,
    ),
  ),
  centerTitle: true,
  backgroundColor: const Color(0xFFD32F2F), // your previous red
  foregroundColor: Colors.white,
  elevation: 0,
  surfaceTintColor: Colors.transparent, // avoids weird overlay
),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
  padding: const EdgeInsets.all(24),
  decoration: const BoxDecoration(
    color: Color(0xFFD32F2F), // <-- same red as AppBar
    borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
  ),
  child: FadeInDown(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.tripTitle,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'LOADOUT PROGRESS',
              style: TextStyle(
                color: Colors.white70, // <-- softer than grey on red
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            Text(
              '$packedCount / $totalCount ITEMS',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white, // <-- green looked weird on red
                fontSize: 10,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation<Color>(
              progress == 1.0
                  ? Colors.greenAccent // keep success feedback
                  : Colors.white,
            ),
          ),
        ),
      ],
    ),
  ),
),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _checklist.length,
                    itemBuilder: (context, index) {
                      final item = _checklist[index];
                      final isPacked = item['is_packed'] == true;
                      
                      return FadeInUp(
                        delay: Duration(milliseconds: 30 * index),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: ListTile(
                            leading: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isPacked ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.05),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isPacked ? Icons.check_circle : Icons.panorama_fish_eye,
                                color: isPacked ? Colors.green : Colors.grey,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              item['item_name'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                decoration: isPacked ? TextDecoration.lineThrough : null,
                                color: isPacked ? Colors.grey : Colors.black87,
                              ),
                            ),
                            trailing: Checkbox(
                              value: isPacked,
                              activeColor: Colors.green,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                              onChanged: (v) => _toggleItem(index, item['id'], isPacked),
                            ),
                            onTap: () => _toggleItem(index, item['id'], isPacked),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
     floatingActionButton: FloatingActionButton(
  onPressed: _showAddDialog,
  backgroundColor: Colors.black,
  elevation: 8,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  ),
  child: const Icon(
    Icons.add,
    color: Colors.white,
    size: 26,
  ),
),
    );
  }
}
