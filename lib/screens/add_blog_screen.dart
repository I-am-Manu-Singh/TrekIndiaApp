import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddBlogScreen extends StatefulWidget {
  const AddBlogScreen({super.key});

  @override
  State<AddBlogScreen> createState() => _AddBlogScreenState();
}

class _AddBlogScreenState extends State<AddBlogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _imageUrlCtrl = TextEditingController();
  final _galleryCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _readTimeCtrl = TextEditingController(text: '5 min');
  bool _isSaving = false;

  Future<void> _saveBlog() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final profile = await Supabase.instance.client.from('profiles').select('full_name').eq('id', user!.id).single();
      final authorName = profile['full_name'] ?? 'Trekker';

      final List<String> gallery = _galleryCtrl.text.split(',').where((s) => s.trim().isNotEmpty).map((s) => s.trim()).toList();

      await Supabase.instance.client.from('blogs').insert({
        'title': _titleCtrl.text.trim(),
        'image_url': _imageUrlCtrl.text.trim(),
        'gallery': gallery,
        'content': _contentCtrl.text.trim(),
        'read_time': _readTimeCtrl.text.trim(),
        'author': authorName,
        'author_id': user.id,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Blog published successfully!')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Write a Blog', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
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
                      decoration: const InputDecoration(labelText: 'Estimated Read Time (e.g. 5 min)', border: OutlineInputBorder()),
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
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        onPressed: _saveBlog,
                        child: const Text('Publish Blog', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    )
                  ],
                ),
              ),
            ),
    );
  }
}
