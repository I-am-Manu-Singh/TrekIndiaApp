import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';

class AddBlogScreen extends StatefulWidget {
  const AddBlogScreen({super.key});

  @override
  State<AddBlogScreen> createState() => _AddBlogScreenState();
}

class _AddBlogScreenState extends State<AddBlogScreen> {
  final _client = Supabase.instance.client;
  final _titleCtrl = TextEditingController();
  final _coverCtrl = TextEditingController();
  final _readTimeCtrl = TextEditingController(text: '5 min');
  final _contentCtrl = TextEditingController();
  final List<String> _imageUrls = [];
  final List<String> _tags = [];
  final _tagCtrl = TextEditingController();

  bool _isSaving = false;

  final List<String> _suggestedTags = ['Summit', 'Review', 'Gear', 'Wildlife', 'History', 'Wellness', 'Solo', 'Group'];

  Future<void> _saveBlog() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    final user = _client.auth.currentUser;

    if (title.isEmpty || content.isEmpty || user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PLEASE ENSURE TITLE AND CONTENT ARE POPULATED.')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _client.from('blogs').insert({
        'author_id': user.id,
        'title': title,
        'content': content,
        'image_url': _coverCtrl.text.trim(),
        'read_time': _readTimeCtrl.text.trim(),
        'gallery': _imageUrls.where((u) => u.isNotEmpty).toList(),
        'tags': _tags,
        'category': _tags.isNotEmpty ? _tags.first : 'Trekking',
      });
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('STORY ARCHIVED IN THE TREKKER DAILY.')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('TRANSTREK ERROR: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: const Text('CREATE A STORY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        backgroundColor: const Color(0xFF2E7B32),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Story Metadata', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 16),
            _iconicInput(Icons.text_fields_outlined, _titleCtrl, label: 'Story Title'),
            const SizedBox(height: 12),
            _iconicInput(Icons.image_outlined, _coverCtrl, label: 'Cover Image URL'),
            const SizedBox(height: 12),
            _iconicInput(Icons.timer_outlined, _readTimeCtrl, label: 'Estimated Read Time'),
            const SizedBox(height: 32),
            const Text('Story Intelligence Tags', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ..._tags.map((tag) => Chip(
                  label: Text(tag),
                  onDeleted: () => setState(() => _tags.remove(tag)),
                  backgroundColor: const Color(0xFFE8F5E9),
                  deleteIconColor: Colors.red,
                )),
                ActionChip(
                  label: const Icon(Icons.add, size: 16),
                  onPressed: () => _showTagPicker(),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text('Visual Intel (Gallery)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 16),
            ..._imageUrls.asMap().entries.map((entry) => _removableUrl(entry.key)).toList(),
            const SizedBox(height: 16),
            _addLink('ADD VISUAL ASSET', () => setState(() => _imageUrls.add(''))),
            const SizedBox(height: 32),
            const Text('INTEL NARRATIVE', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            _largeInput(_contentCtrl),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveBlog,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: _isSaving 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('DEPLOY STORY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showTagPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SELECT TAGS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              children: _suggestedTags.map((tag) => ChoiceChip(
                label: Text(tag),
                selected: _tags.contains(tag),
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        if (!_tags.contains(tag)) _tags.add(tag);
                      } else {
                        _tags.remove(tag);
                      }
                    });
                  },
              )).toList(),
            ),
            const SizedBox(height: 24),
            const Text('ADD CUSTOM TAG', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagCtrl,
                    decoration: InputDecoration(
                      hintText: 'Enter new tag',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onSubmitted: (value) {
                      final customTag = value.trim();
                      if (customTag.isNotEmpty && !_tags.contains(customTag)) {
                        setState(() {
                          _tags.add(customTag);
                          _tagCtrl.clear();
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final customTag = _tagCtrl.text.trim();
                    if (customTag.isNotEmpty && !_tags.contains(customTag)) {
                      setState(() {
                        _tags.add(customTag);
                        _tagCtrl.clear();
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7B32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: const Text('ADD', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconicInput(IconData icon, TextEditingController ctrl, {String? label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) Text(label, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.black54),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: ctrl, decoration: InputDecoration(border: InputBorder.none, hintText: label), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _removableUrl(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade50)),
      child: Row(
        children: [
          Expanded(child: TextField(
            onChanged: (val) => _imageUrls[index] = val,
            decoration: const InputDecoration(border: InputBorder.none, hintText: 'Asset URL...'),
            style: const TextStyle(fontSize: 14),
          )),
          IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20), onPressed: () => setState(() => _imageUrls.removeAt(index))),
        ],
      ),
    );
  }

  Widget _largeInput(TextEditingController ctrl) {
    return Container(
      padding: const EdgeInsets.all(20),
      height: 400,
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)),
      child: TextField(controller: ctrl, maxLines: 30, decoration: const InputDecoration(border: InputBorder.none, hintText: 'Compose your intel...'), style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.6)),
    );
  }

  Widget _addLink(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF2E7B32), size: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Color(0xFF2E7B32), fontSize: 10, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
