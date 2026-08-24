import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:animate_do/animate_do.dart';
import '../widgets/user_avatar.dart';
import '../screens/add_review_screen.dart';

class TripReviewsSection extends StatefulWidget {
  final String tripId;
  final bool canReview;

  const TripReviewsSection({
    super.key,
    required this.tripId,
    required this.canReview,
  });

  @override
  State<TripReviewsSection> createState() => _TripReviewsSectionState();
}

class _TripReviewsSectionState extends State<TripReviewsSection> {
  List<dynamic> _reviews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  Future<void> _fetchReviews() async {
    try {
      final response = await Supabase.instance.client
          .from('reviews')
          .select()
          .eq('trip_id', widget.tripId)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _reviews = response as List;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final user = Supabase.instance.client.auth.currentUser;
                if (user == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Please log in to submit a verified explorer review.'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    )
                  );
                  return;
                }
                final result = await Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => AddReviewScreen(tripId: widget.tripId))
                );
                if (result == true) {
                  setState(() => _isLoading = true);
                  _fetchReviews();
                }
              },
              icon: const Icon(Icons.rate_review),
              label: const Text('Write a Review'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ),
        ),
        if (_reviews.isEmpty)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rate_review_outlined, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No reviews yet. Be the first to share your experience!', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              itemCount: _reviews.length,
              itemBuilder: (context, index) {
                final r = _reviews[index];
                return FadeInUp(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                               UserAvatar(
                                 imageUrl: r['image_url'],
                                 name: r['user_name'],
                                 radius: 20,
                               ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(r['user_name'] ?? 'Hiker', style: const TextStyle(fontWeight: FontWeight.bold))),
                              RatingBarIndicator(
                                rating: double.tryParse(r['rating'].toString()) ?? 5.0, 
                                itemBuilder: (c, i) => const Icon(Icons.star, color: Colors.amber), 
                                itemCount: 5, 
                                itemSize: 15
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(r['comment'] ?? '', style: const TextStyle(fontStyle: FontStyle.italic)),
                          const SizedBox(height: 12),
                          _buildReviewTag(Icons.thumb_up_alt_outlined, 'Liked: ', r['liked'] ?? '', Colors.green),
                          _buildReviewTag(Icons.thumb_down_alt_outlined, 'Disliked: ', r['disliked'] ?? 'None', Colors.red),
                          _buildReviewTag(Icons.trending_up, 'Difficulty: ', r['difficulty_rating'] ?? 'Medium', Colors.orange),
                          
                          if (r['media_urls'] != null && (r['media_urls'] as List).isNotEmpty) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 60,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: (r['media_urls'] as List).length,
                                itemBuilder: (context, mIndex) => Container(
                                  width: 60,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    image: DecorationImage(
                                      image: NetworkImage(r['media_urls'][mIndex]),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildReviewTag(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
