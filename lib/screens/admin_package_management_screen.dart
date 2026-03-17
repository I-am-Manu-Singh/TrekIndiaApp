import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trek.dart';
import '../services/database_service.dart';
import 'edit_trek_screen.dart';
import 'add_trek_screen.dart';

class AdminPackageManagementScreen extends StatefulWidget {
  const AdminPackageManagementScreen({super.key});

  @override
  State<AdminPackageManagementScreen> createState() => _AdminPackageManagementScreenState();
}

class _AdminPackageManagementScreenState extends State<AdminPackageManagementScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<Trek> _allTreks = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTreks();
  }

  Future<void> _loadTreks() async {
    setState(() => _isLoading = true);
    final treks = await _dbService.fetchTreks();
    if (mounted) {
      setState(() {
        _allTreks = treks;
        _isLoading = false;
      });
    }
  }

  List<Trek> get _filteredTreks {
    if (_searchQuery.isEmpty) return _allTreks;
    return _allTreks.where((t) => 
      t.title.toLowerCase().contains(_searchQuery.toLowerCase()) || 
      t.location.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      t.category.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  Future<void> _deleteTrek(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Package?'),
        content: const Text('This will permanently remove this trek package and all associated booking options.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      )
    );

    if (confirmed == true) {
      try {
        await Supabase.instance.client.from('treks').delete().eq('id', id);
        _loadTreks();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Package deleted successfully.')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Package Control', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () async {
            final r = await Navigator.push(context, MaterialPageRoute(builder: (c) => const AddTrekScreen()));
            if (r == true) _loadTreks();
          }),
        ],
      ),
      body: Column(
        children: [
          _buildSearchHeader(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _buildTrekList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Inventory Search', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100], borderRadius: BorderRadius.circular(15)),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search by title, region or category...',
                border: InputBorder.none,
                hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                icon: const Icon(Icons.search, size: 20, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                }) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrekList() {
    final treks = _filteredTreks;
    if (treks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('No packages match your search.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: treks.length,
      itemBuilder: (context, index) {
        final t = treks[index];
        return FadeInUp(
          delay: Duration(milliseconds: index * 20),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
            ),
            child: Row(
              children: [
                Hero(
                  tag: 'manage_${t.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.network(t.imageUrl, width: 80, height: 80, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(width: 80, height: 80, color: Colors.grey[200], child: const Icon(Icons.image))),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text(t.category.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.blue)),
                      ),
                      const SizedBox(height: 4),
                      Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('${t.location} • ${t.duration}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text('₹${t.basePrice.toInt()}', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.green, fontSize: 13)),
                    ],
                  ),
                ),
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_note, color: Colors.blue), 
                      onPressed: () async {
                        final r = await Navigator.push(context, MaterialPageRoute(builder: (c) => EditTrekScreen(trek: t)));
                        if (r == true) _loadTreks();
                      }
                    ),
                    IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _deleteTrek(t.id)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
