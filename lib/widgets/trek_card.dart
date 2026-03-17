import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:animate_do/animate_do.dart';
import '../models/trek.dart';
import '../screens/trek_detail_screen.dart';

class TrekCard extends StatelessWidget {
  final Trek trek;
  const TrekCard({super.key, required this.trek});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 500),
            pageBuilder: (context, animation, secondaryAnimation) => TrekDetailScreen(trek: trek),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      },
      child: FadeInUp(
        child: Container(
          height: 180, // Resilient height to prevent overlap
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            children: [
              // 📸 LEFT SIDE: Image + Badges
              Stack(
                children: [
                  Hero(
                    tag: 'trek_image_${trek.id}',
                    child: ClipRRect(
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
                      child: CachedNetworkImage(
                        imageUrl: trek.imageUrl,
                        width: 130,
                        height: 180,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(width: 120, color: Colors.grey[200]),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _glassBadge(trek.rating.toString(), Icons.star, Colors.amber),
                  ),
                  if (trek.rating >= 4.8)
                    Positioned(
                      bottom: 10,
                      left: 10,
                      child: _glassBadge('ELITE', Icons.auto_awesome, Colors.white),
                    ),
                ],
              ),
              
              // 📝 RIGHT SIDE: Tactical Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              trek.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                            ),
                          ),
                          Text(
                            '₹${trek.discountedPrice.toInt()}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 10, color: Colors.grey),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              trek.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Divider(height: 8, color: Colors.black12),
                      
                      // 🛰️ TELEMETRY GRID (The "WOW" info)
                      Expanded(
                        child: GridView(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisExtent: 22, // Increased height per item
                            crossAxisSpacing: 4,
                            mainAxisSpacing: 4,
                          ),
                          children: [
                            _telemetryItem(Icons.explore_outlined, trek.orientation),
                            _telemetryItem(Icons.gps_fixed, '${trek.latitude.toStringAsFixed(1)}, ${trek.longitude.toStringAsFixed(1)}'),
                            _telemetryItem(Icons.filter_hdr_outlined, trek.peakElevation),
                            _telemetryItem(Icons.terrain_outlined, trek.trailType),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      // 🚦 DIFFICULTY & DURATION
                      Row(
                        children: [
                          _miniChip(trek.duration, Colors.blue),
                          const SizedBox(width: 12),
                          Expanded(child: _difficultyProgress(trek.difficulty)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 10),
          const SizedBox(width: 2),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _telemetryItem(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: Colors.blueAccent),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey),
          ),
        ),
      ],
    );
  }

  Widget _miniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900)),
    );
  }

  Widget _difficultyProgress(String difficulty) {
    Color color = Colors.green;
    double progress = 0.3;
    if (difficulty.toLowerCase().contains('mod')) { color = Colors.orange; progress = 0.6; }
    else if (difficulty.toLowerCase().contains('hard')) { color = Colors.red; progress = 0.9; }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('DIFFICULTY', style: TextStyle(fontSize: 7, color: Colors.grey, fontWeight: FontWeight.w900)),
            Text(difficulty.toUpperCase(), style: TextStyle(fontSize: 7, color: color, fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 3,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
