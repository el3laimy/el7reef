import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

class PrideIdentityAvatar extends StatelessWidget {
  final String? imageUrl;
  final String initials;
  final double size;
  final Color accent;
  final IconData fallbackIcon;

  const PrideIdentityAvatar({
    super.key,
    this.imageUrl,
    required this.initials,
    required this.size,
    this.accent = AppColors.primary,
    this.fallbackIcon = Icons.person_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final fallback = _FallbackAvatar(
      initials: initials,
      size: size,
      accent: accent,
      fallbackIcon: fallbackIcon,
    );
    if (url == null || url.isEmpty) return fallback;

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}

class _FallbackAvatar extends StatelessWidget {
  final String initials;
  final double size;
  final Color accent;
  final IconData fallbackIcon;

  const _FallbackAvatar({
    required this.initials,
    required this.size,
    required this.accent,
    required this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedInitials = initials.trim();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [accent, accent.withValues(alpha: 0.55)],
        ),
        border: Border.all(
          color: AppColors.textPrimaryTinted.withValues(alpha: 0.48),
          width: 2,
        ),
      ),
      child: normalizedInitials.isEmpty
          ? Icon(
              fallbackIcon,
              color: AppColors.textOnPrimary,
              size: size * 0.42,
            )
          : Text(
              normalizedInitials,
              style: TextStyle(
                color: AppColors.textOnPrimary,
                fontSize: size * 0.30,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
    );
  }
}
