import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditBlogScreen extends StatefulWidget {
  final Map<String, dynamic> blog;
  const EditBlogScreen({super.key, required this.blog});

  @override
  State<EditBlogScreen> createState() => _EditBlogScreenState();
}

class _EditBlogScreenState extends State<EditBlogScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _imageUrlCtrl;
  late TextEditingController _galleryCtrl;
  late TextEditingController _contentCtrl;
  late TextEditingController _readTimeCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.blog['title']);
    _imageUrlCtrl = TextEditingController(text: widget.blog['image_url']);
    final List<dynamic> gallery = widget.blog['gallery'] ?? [];
    _galleryCtrl = TextEditingController(text: gallery.join(', '));
    _contentCtrl = TextEditingController(text: widget.blog['content']);
    _readTimeCtrl = TextEditingController(text: widget.blog['read_time'] ?? '5 min');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _imageUrlCtrl.dispose();
    _galleryCtrl.dispose();
    _contentCtrl.dispose();
    _readTimeCtrl.dispose();
    super.dispose();
  }

  Future<void> _updateBlog() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final List<String> gallery = _galleryCtrl.text.split(',').where((s) => s.trim().isNotEmpty).map((s) => s.trim()).toList();

      await Supabase.instance.client.from('blogs').update({
        'title': _titleCtrl.text.trim(),
        'image_url': _imageUrlCtrl.text.trim(),
        'gallery': gallery,
        'content': _contentCtrl.text.trim(),
        'read_time': _readTimeCtrl.text.trim(),
      }).eq('id', widget.blog['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Blog updated successfully!'), backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteBlog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Blog?'),
        content: const Text('This action is permanent.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      )
    );

    if (confirmed == true) {
      setState(() => _isSaving = true);
      try {
        await Supabase.instance.client.from('blogs').delete().eq('id', widget.blog['id']);
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Blog deleted.')));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Blog Story', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: _deleteBlog),
        ],
      ),
      body: _isSaving 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(labelText: 'Blog Title', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'Enter title' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _imageUrlCtrl,
                      decoration: const InputDecoration(labelText: 'Cover Image URL', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'Enter image URL' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _galleryCtrl,
                      decoration: const InputDecoration(labelText: 'Gallery URLs (Comma separated)', border: OutlineInputBorder(), hintText: 'url1, url2, url3'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _readTimeCtrl,
                      decoration: const InputDecoration(labelText: 'Estimated Read Time', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'Enter read time' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _contentCtrl,
                      decoration: const InputDecoration(labelText: 'Content', border: OutlineInputBorder(), alignLabelWithHint: true),
                      maxLines: 15,
                      validator: (v) => v!.isEmpty ? 'Enter content' : null,
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        onPressed: _updateBlog,
                        child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
                      ),
                    )
                  ],
                ),
              ),
            ),
    );
  }
}
