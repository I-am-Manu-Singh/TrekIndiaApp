import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:animate_do/animate_do.dart';
import '../models/trek.dart';
import '../screens/trek_detail_screen.dart';

class TrekCard extends StatelessWidget {
  final Trek trek;
  final EdgeInsets? margin;
  final BorderRadius? borderRadius;
  const TrekCard({super.key, required this.trek, this.margin, this.borderRadius});

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
          height: 130, // Optimized Trek Thinning for high-density mission flow
          margin: margin ?? const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: borderRadius ?? BorderRadius.circular(20),
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4)),
            ],
            border: Border.all(color: Colors.black.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              // 📸 LEFT SIDE: Image + Badges
              Stack(
                children: [
                  Hero(
                    tag: 'trek_image_${trek.id}',
                    child: ClipRRect(
                      borderRadius: (borderRadius ?? BorderRadius.circular(20)).copyWith(
                        topRight: Radius.zero, bottomRight: Radius.zero,
                      ),
                      child: CachedNetworkImage(
                        imageUrl: trek.imageUrl,
                        width: 100,
                        height: 130,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(width: 100, color: Colors.grey[100]),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: _glassBadge(trek.rating.toString(), Icons.star, Colors.amber),
                  ),
                ],
              ),
              
              // 📝 RIGHT SIDE: Trek Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              trek.title.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: -0.2),
                            ),
                          ),
                          Text(
                            '₹${trek.discountedPrice.toInt()}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 8, color: Colors.grey),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              trek.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.grey, fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Divider(height: 1, color: Colors.black12),
                      
                      // 🛰️ TELEMETRY GRID
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: GridView(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisExtent: 14,
                              crossAxisSpacing: 4,
                              mainAxisSpacing: 2,
                            ),
                            children: [
                              _telemetryItem(Icons.filter_hdr_outlined, trek.peakElevation),
                              _telemetryItem(Icons.terrain_outlined, trek.trailType),
                              _telemetryItem(Icons.timer_outlined, trek.duration),
                              _telemetryItem(Icons.explore_outlined, trek.orientation),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 4),
                      // 🚦 DIFFICULTY HUD
                      _difficultyProgress(trek.difficulty),
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
