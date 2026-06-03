import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';

class EditBlogScreen extends StatefulWidget {
  final dynamic blog;
  const EditBlogScreen({super.key, required this.blog});

  @override
  State<EditBlogScreen> createState() => _EditBlogScreenState();
}

class _EditBlogScreenState extends State<EditBlogScreen> {
  final _client = Supabase.instance.client;
  late TextEditingController _titleCtrl;
  late TextEditingController _coverCtrl;
  late TextEditingController _readTimeCtrl;
  late TextEditingController _contentCtrl;
  List<String> _imageUrls = [];
  List<String> _tags = [];

  bool _isAuthorized = false;
  bool _isSaving = false;
  final List<String> _suggestedTags = ['Summit', 'Review', 'Gear', 'Wildlife', 'History', 'Wellness', 'Solo', 'Group'];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.blog['title']);
    _coverCtrl = TextEditingController(text: widget.blog['image_url']);
    _readTimeCtrl = TextEditingController(text: widget.blog['read_time'] ?? '5 min');
    _contentCtrl = TextEditingController(text: widget.blog['content']);
    _imageUrls = List<String>.from(widget.blog['gallery'] ?? []);
    _tags = List<String>.from(widget.blog['tags'] ?? []);
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final profileRes = await _client.from('profiles').select('role').eq('id', user.id).maybeSingle();
    final role = profileRes?['role']?.toString().toUpperCase() ?? 'USER';
    final authorId = widget.blog['user_id'] ?? widget.blog['author_id'];

    if (role == 'ADMIN' || user.id == authorId) {
      if (mounted) setState(() => _isAuthorized = true);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('UNAUTHORIZED: ONLY THE TRIP ARCHITECT OR trekwithmussafirr CAN EDIT THIS INFO.')));
        Navigator.pop(context);
      }
    }
  }

  Future<void> _updateBlog() async {
    setState(() => _isSaving = true);
    try {
      await _client.from('blogs').update({
        'title': _titleCtrl.text.trim(),
        'image_url': _coverCtrl.text.trim(),
        'read_time': _readTimeCtrl.text.trim(),
        'content': _contentCtrl.text.trim(),
        'gallery': _imageUrls.where((u) => u.isNotEmpty).toList(),
        'tags': _tags,
        'category': _tags.isNotEmpty ? _tags.first : 'Tripking',
      }).eq('id', widget.blog['id']);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('INFO SYNCHRONIZED SUCCESSFULLY.')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ERROR: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: const Text('EDIT STORY INFO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        backgroundColor: const Color(0xFFD32F2F),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.white), onPressed: () => _confirmDelete()),
        ],
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
            const Text('Intel Tags', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
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
            const Text('Intel Narrative', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            _largeInput(_contentCtrl),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _updateBlog,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: _isSaving 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('SYNCHRONIZE INFO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showTagPicker() {
    final TextEditingController _tagCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('SELECT OR ADD TAGS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
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
                    setModalState(() {});
                  },
                )).toList(),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: TextField(
                    controller: _tagCtrl,
                    decoration: const InputDecoration(hintText: 'Custom Tag...', border: OutlineInputBorder()),
                  )),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: () {
                    final t = _tagCtrl.text.trim();
                    if (t.isNotEmpty && !_tags.contains(t)) {
                      setState(() => _tags.add(t));
                      setModalState(() => _tagCtrl.clear());
                    }
                  }, child: const Text('ADD')),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Story?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          TextButton(onPressed: () async {
            Navigator.pop(c);
            await _client.from('blogs').delete().eq('id', widget.blog['id']);
            if (mounted) Navigator.pop(context, true);
          }, child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
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
              Expanded(child: TextField(controller: ctrl, decoration: const InputDecoration(border: InputBorder.none), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87))),
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
          Expanded(child: TextFormField(
            initialValue: _imageUrls[index],
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
      height: 350,
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)),
      child: TextField(controller: ctrl, maxLines: 20, decoration: const InputDecoration(border: InputBorder.none, hintText: 'Narrative content...'), style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.6)),
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
          Text(label, style: const TextStyle(color: Color(0xFF2E7B32), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        ],
      ),
    );
  }
}
