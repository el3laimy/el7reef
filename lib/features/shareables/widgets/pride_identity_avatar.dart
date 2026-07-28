import 'package:flutter/material.dart';

import '../../../app/theme/app_media_colors.dart';
import '../../../core/identity/identity_visual.dart';

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
    this.accent = AppMediaColors.actionPrimary,
    this.fallbackIcon = Icons.person_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedSource = imageUrl?.trim();
    final fallback = _FallbackAvatar(
      initials: initials,
      size: size,
      accent: accent,
      fallbackIcon: fallbackIcon,
    );
    // Keep the direct fallback path pixel-stable for existing Pride exports.
    if (normalizedSource == null || normalizedSource.isEmpty) return fallback;
    return ClipOval(
      child: IdentityVisual(
        source: normalizedSource,
        size: size,
        fit: BoxFit.cover,
        semanticLabel: 'صورة الهوية',
        appearance: IdentityVisualAppearance.onDarkMedia,
        fallbackBuilder: (_) => fallback,
        placeholderBuilder: (_) => fallback,
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
          color: AppMediaColors.textPrimary.withValues(alpha: 0.48),
          width: 2,
        ),
      ),
      child: normalizedInitials.isEmpty
          ? Icon(
              fallbackIcon,
              color: AppMediaColors.inkOnAccent,
              size: size * 0.42,
            )
          : Text(
              normalizedInitials,
              style: TextStyle(
                color: AppMediaColors.inkOnAccent,
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
