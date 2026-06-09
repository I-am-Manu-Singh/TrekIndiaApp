import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:animate_do/animate_do.dart';
import '../models/trip.dart';
import '../screens/trip_detail_screen.dart';

class UnifiedTripCard extends StatelessWidget {
  final Trip trip;
  final TripCategory? categoryMeta;
  final EdgeInsets? margin;
  final String? heroTag;
  final double? width;
  final BorderRadius? borderRadius;
  final VoidCallback? onRefresh;
  final bool showFooter;
  final bool showPrice;
  final Widget? customFooter;

  const UnifiedTripCard({
    super.key,
    required this.trip,
    this.categoryMeta,
    this.margin,
    this.heroTag,
    this.width,
    this.borderRadius,
    this.onRefresh,
    this.showFooter = true,
    this.showPrice = true,
    this.customFooter,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String cat = (trip.category ?? 'Adventure').toLowerCase();
    final bool isPackage = cat.contains('package') || cat.contains('vacation');

    // UI Tokens
    final primaryColor = Theme.of(context).primaryColor;
    final cardBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final shadowColor = Colors.black.withOpacity(isDark ? 0.3 : 0.08);

    final card = GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 500),
            pageBuilder: (context, animation, secondaryAnimation) =>
                TripDetailScreen(trip: trip, heroTag: heroTag),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
          ),
        );
        if (result == true && onRefresh != null) {
          onRefresh!();
        }
      },
      child: Container(
        width: width ?? 300,
        margin: margin ?? const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: borderRadius ?? BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.04),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📸 IMAGE SECTION
            _buildImageSection(context, isDark, isPackage),

            // 📝 CONTENT SECTION
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleAndCategory(isDark, primaryColor),
                  const SizedBox(height: 2),
                  _buildLocationInfo(isDark),
                  if (showFooter || showPrice || customFooter != null) ...[
                    const SizedBox(height: 4),
                    customFooter ??
                        _buildPriceAndFooter(isDark, primaryColor, isPackage),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (kIsWeb) return card;

    return FadeInUp(duration: const Duration(milliseconds: 400), child: card);
  }

  Widget _buildImageSection(BuildContext context, bool isDark, bool isPackage) {
    final primaryColor = Theme.of(context).primaryColor;
    return Stack(
      children: [
        Hero(
          tag: heroTag ?? 'trip_img_${trip.id}',
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: CachedNetworkImage(
              imageUrl: trip.imageUrl ?? '',
              height: 140, // 👈 UNIFORM COMPACT HEIGHT
              width: double.infinity,
              fit: BoxFit.cover,
              maxWidthDiskCache: 900,
              maxHeightDiskCache: 420,
              placeholder: (context, url) => Container(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
              ),
              errorWidget: (context, url, error) => Container(
                color: isDark
                    ? const Color(0xFF424242)
                    : const Color(0xFFEEEEEE),
                padding: const EdgeInsets.all(20),
                child: Opacity(
                  opacity: 0.25,
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (c, e, s) => Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.terrain_outlined,
                          size: 40,
                          color: primaryColor.withOpacity(0.2),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'trekwithmussafirr',
                          style: TextStyle(
                            color: primaryColor.withOpacity(0.3),
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Rating Badge
        Positioned(
          bottom: 6,
          left: 6,
          child: _glassBadge(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                const SizedBox(width: 2),
                Text(
                  (trip.rating ?? 5.0).toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Difficulty Badge (Only for Treks)
        if (!isPackage && (trip.difficulty ?? '').isNotEmpty)
          Positioned(
            bottom: 6,
            right: 6,
            child: _glassBadge(
              Text(
                trip.difficulty!.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 8,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTitleAndCategory(bool isDark, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              (trip.category ?? 'Trip').toUpperCase(),
              style: TextStyle(
                color: primaryColor,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            if ((trip.duration ?? '').isNotEmpty)
              Text(
                trip.duration!.toUpperCase(),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          trip.title ?? 'Untitled Adventure',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationInfo(bool isDark) {
    return Row(
      children: [
        Icon(
          Icons.location_on_outlined,
          size: 14,
          color: isDark ? Colors.white60 : Colors.grey,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            (trip.location ?? 'Global').isNotEmpty ? trip.location! : 'Global',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceAndFooter(bool isDark, Color primaryColor, bool isPackage) {
    final double originalPrice = trip.basePrice ?? 0.0;
    final double discountPrice = trip.discountedPrice ?? 0.0;
    final bool hasDiscount = originalPrice > discountPrice;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (showPrice)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (hasDiscount)
                    Text(
                      '₹${originalPrice.toInt()}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        decoration: TextDecoration.lineThrough,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (hasDiscount) const SizedBox(width: 6),
                  Text(
                    '₹${discountPrice.toInt()}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'PER PERSON',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        if (showFooter)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              isPackage ? 'VIEW DEAL' : 'BOOK NOW',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
          ),
      ],
    );
  }

  Widget _glassBadge(Widget child) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: BackdropFilter(
        filter: ColorFilter.mode(
          Colors.black.withOpacity(0.4),
          BlendMode.srcOver,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: child,
        ),
      ),
    );
  }
}
