import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class AddReviewScreen extends StatefulWidget {
  final String tripId;
  const AddReviewScreen({super.key, required this.tripId});

  @override
  State<AddReviewScreen> createState() => _AddReviewScreenState();
}

class _AddReviewScreenState extends State<AddReviewScreen> {
  final _commentCtrl = TextEditingController();
  final _likedCtrl = TextEditingController();
  final _dislikedCtrl = TextEditingController();
  String _difficultyRating = 'Moderate';
  double _rating = 5.0;
  bool _isSaving = false;
  final List<String> _mediaUrls = [];

  void _addSimulatedMedia() {
    if (_mediaUrls.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum 5 media files allowed.')));
      return;
    }
    setState(() {
      _mediaUrls.add('https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?q=80&w=400&auto=format&fit=crop');
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Simulated: Media file attached.')));
  }

  Future<void> _submitReview() async {
    if (_commentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add a comment')));
      return;
    }
    
    setState(() => _isSaving = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final profile = await Supabase.instance.client.from('profiles').select('full_name, avatar_url').eq('id', user.id).maybeSingle();
      
      String derivedName = 'Trip';
      if (profile != null && profile['full_name'] != null && profile['full_name'].toString().isNotEmpty) {
        derivedName = profile['full_name'];
      } else if (user.userMetadata?['full_name'] != null) {
        derivedName = user.userMetadata?['full_name'];
      } else if (user.email != null) {
        derivedName = user.email!.split('@')[0];
      }

      await Supabase.instance.client.from('reviews').insert({
        'trip_id': widget.tripId,
        'user_id': user.id,
        'user_name': derivedName,
        'image_url': profile?['avatar_url'] ?? user.userMetadata?['avatar_url'] ?? 'https://i.pravatar.cc/150?img=1',
        'rating': _rating, 
        'comment': _commentCtrl.text.trim(),
        'liked': _likedCtrl.text.trim(),
        'disliked': _dislikedCtrl.text.trim(),
        'difficulty_rating': _difficultyRating,
        'media_urls': _mediaUrls,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review submitted!')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Write a Review', style: TextStyle(fontWeight: FontWeight.bold))),
      body: _isSaving 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Rate your experience', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Center(
                  child: RatingBar.builder(
                    initialRating: _rating,
                    minRating: 1,
                    direction: Axis.horizontal,
                    allowHalfRating: true,
                    itemCount: 5,
                    itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                    itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                    onRatingUpdate: (rating) => setState(() => _rating = rating),
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _commentCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Overall Experience',
                    hintText: 'Share details of your experience...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _likedCtrl,
                  decoration: const InputDecoration(
                    labelText: 'What did you like?',
                    hintText: 'e.g. Views, Food, Guide...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.thumb_up_alt_outlined, color: Colors.green),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _dislikedCtrl,
                  decoration: const InputDecoration(
                    labelText: 'What did you dislike?',
                    hintText: 'e.g. Tough climb, Cold nights...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.thumb_down_alt_outlined, color: Colors.red),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('How was the difficulty?', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['Easy', 'Moderate', 'Difficult', 'Technical'].map((d) => 
                    ChoiceChip(
                      label: Text(d),
                      selected: _difficultyRating == d,
                      onSelected: (selected) {
                        if (selected) setState(() => _difficultyRating = d);
                      },
                    )
                  ).toList(),
                ),
                const SizedBox(height: 24),
                const Text('Add Photos / Videos (Max 5)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (_mediaUrls.isNotEmpty)
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _mediaUrls.length,
                      itemBuilder: (context, index) => Stack(
                        children: [
                          Container(
                            width: 80,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              image: DecorationImage(image: NetworkImage(_mediaUrls[index]), fit: BoxFit.cover),
                            ),
                          ),
                          Positioned(
                            right: 4,
                            top: 0,
                            child: IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.white, size: 18),
                              onPressed: () => setState(() => _mediaUrls.removeAt(index)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _addSimulatedMedia,
                  child: Container(
                    height: 80,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined, size: 24, color: Colors.blueAccent),
                        SizedBox(width: 12),
                        Text('Attach Photo/Video', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _submitReview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Text('Submit Review', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            )
          ),
    );
  }
}
