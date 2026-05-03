import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double radius;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const UserAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.radius = 20,
    this.width,
    this.height,
    this.borderRadius,
  });

  String get _initials {
    if (name == null || name!.trim().isEmpty) return 'T';
    final trimmed = name!.trim();
    final parts = trimmed.split(' ');
    if (parts.length > 1 && parts[0].isNotEmpty && parts[parts.length - 1].isNotEmpty) {
      return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    }
    return trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasImage = imageUrl != null && 
                          imageUrl!.isNotEmpty && 
                          imageUrl != 'null' && 
                          imageUrl!.startsWith('http');
    
    final effectiveWidth = width ?? radius * 2;
    final effectiveHeight = height ?? radius * 2;
    
    // If borderRadius is null, default to circular (ClipOval)
    final bool isCircular = borderRadius == null;

    if (hasImage) {
      return isCircular 
        ? ClipOval(
            child: CachedNetworkImage(
              imageUrl: imageUrl!,
              width: effectiveWidth,
              height: effectiveHeight,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => _initialsWidget(context, effectiveWidth, effectiveHeight, isCircular),
              placeholder: (context, url) => _initialsWidget(context, effectiveWidth, effectiveHeight, isCircular),
            ),
          )
        : ClipRRect(
            borderRadius: borderRadius!,
            child: CachedNetworkImage(
              imageUrl: imageUrl!,
              width: effectiveWidth,
              height: effectiveHeight,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => _initialsWidget(context, effectiveWidth, effectiveHeight, isCircular),
              placeholder: (context, url) => _initialsWidget(context, effectiveWidth, effectiveHeight, isCircular),
            ),
          );
    }
    return _initialsWidget(context, effectiveWidth, effectiveHeight, isCircular);
  }

  Widget _initialsWidget(BuildContext context, double w, double h, bool isCircular) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.8),
        shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircular ? null : borderRadius,
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: (w < h ? w : h) * 0.45,
        ),
      ),
    );
  }
}
