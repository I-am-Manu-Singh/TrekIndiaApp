import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';

class AdminCategoryManagementScreen extends StatefulWidget {
  const AdminCategoryManagementScreen({super.key});

  @override
  State<AdminCategoryManagementScreen> createState() => _AdminCategoryManagementScreenState();
}

class _AdminCategoryManagementScreenState extends State<AdminCategoryManagementScreen> {
  final _client = Supabase.instance.client;
  List<dynamic> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    setState(() => _isLoading = true);
    try {
      final res = await _client.from('trip_categories').select().order('name', ascending: true);
      if (mounted) setState(() { _categories = res; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addCategory() async {
    final nameCtrl = TextEditingController();
    final iconCtrl = TextEditingController();
    
    final res = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('New Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Category Name')),
            TextField(controller: iconCtrl, decoration: const InputDecoration(labelText: 'Icon Name (Optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Add')),
        ],
      )
    );

    if (res == true && nameCtrl.text.isNotEmpty) {
      try {
        await _client.from('trip_categories').insert({'name': nameCtrl.text.trim(), 'icon': iconCtrl.text.trim()});
        _fetchCategories();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteCategory(String id) async {
    try {
      await _client.from('trip_categories').delete().eq('id', id);
      _fetchCategories();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
              return FadeInRight(
                delay: Duration(milliseconds: index * 50),
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                      child: const Icon(Icons.category_outlined, size: 20),
                    ),
                    title: Text(cat['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(cat['icon'] ?? 'No icon specified', style: const TextStyle(fontSize: 10)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteCategory(cat['id']),
                    ),
                  ),
                ),
              );
            },
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCategory,
        label: const Text('ADD CATEGORY'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.black,
      ),
    );
  }
}
