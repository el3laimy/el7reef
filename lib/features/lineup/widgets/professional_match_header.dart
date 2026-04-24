import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/match_status.dart';

class ProfessionalMatchHeader extends StatelessWidget {
  final String homeName;
  final String awayName;
  final String? homeLogoUrl;
  final String? awayLogoUrl;
  final int? homeScore;
  final int? awayScore;
  final MatchStatus? status;
  final DateTime? startedAt;
  final String? tournamentName;
  final String? roundName;
  final String? location;
  final VoidCallback? onShare;
  final VoidCallback? onMore;

  const ProfessionalMatchHeader({
    super.key,
    required this.homeName,
    required this.awayName,
    this.homeLogoUrl,
    this.awayLogoUrl,
    this.homeScore,
    this.awayScore,
    this.status,
    this.startedAt,
    this.tournamentName,
    this.roundName,
    this.location,
    this.onShare,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final live = status == MatchStatus.live;
    final scoreLabel = homeScore == null && awayScore == null
        ? 'VS'
        : '${homeScore ?? 0} - ${awayScore ?? 0}';

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF07111F), Color(0xFF102031), Color(0xFF141827)],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.1, -0.4),
                    radius: 1.1,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.lg),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            if ((tournamentName ?? '').isNotEmpty)
                              Text(
                                tournamentName!,
                                style: AppTextStyles.titleMedium.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              )
                            else
                              Text(
                                'تشكيلة المباراة',
                                style: AppTextStyles.titleMedium,
                                textAlign: TextAlign.center,
                              ),
                            if ((roundName ?? '').isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                roundName!,
                                style: AppTextStyles.labelMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (onShare != null)
                        _HeaderIconButton(
                          icon: Icons.share_rounded,
                          tooltip: 'مشاركة',
                          onPressed: onShare!,
                        ),
                      if (onMore != null) ...[
                        const SizedBox(width: AppDimensions.xs),
                        _HeaderIconButton(
                          icon: Icons.more_vert_rounded,
                          tooltip: 'المزيد',
                          onPressed: onMore!,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppDimensions.lg),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _TeamIdentity(
                          name: homeName,
                          logoUrl: homeLogoUrl,
                          fallbackColor: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.34),
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusMd,
                              ),
                              border: Border.all(
                                color: _statusColor(
                                  status,
                                ).withValues(alpha: 0.45),
                              ),
                            ),
                            child: Text(
                              scoreLabel,
                              style: AppTextStyles.displaySmall.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _StatusPill(
                            label: live
                                ? _liveTimerLabel(startedAt)
                                : _statusLabel(status),
                            color: _statusColor(status),
                            live: live,
                          ),
                        ],
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      Expanded(
                        child: _TeamIdentity(
                          name: awayName,
                          logoUrl: awayLogoUrl,
                          fallbackColor: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                  if ((location ?? '').isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            location!,
                            style: AppTextStyles.labelSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(MatchStatus? status) {
    return switch (status) {
      MatchStatus.live => AppColors.primaryLight,
      MatchStatus.completed || MatchStatus.settled => AppColors.secondary,
      MatchStatus.cancelled || MatchStatus.frozen => AppColors.error,
      MatchStatus.open || MatchStatus.full => AppColors.warning,
      _ => AppColors.textMuted,
    };
  }

  String _statusLabel(MatchStatus? status) {
    return switch (status) {
      MatchStatus.open => 'لم تبدأ بعد',
      MatchStatus.full => 'جاهزة',
      MatchStatus.live => 'جارية الآن',
      MatchStatus.completed => 'منتهية',
      MatchStatus.pendingReview => 'بانتظار المراجعة',
      MatchStatus.ratingWindow => 'نافذة التقييم',
      MatchStatus.settled => 'مقفلة',
      MatchStatus.frozen => 'مجمّدة',
      MatchStatus.cancelled => 'ملغاة',
      null => 'لم تبدأ بعد',
    };
  }

  String _liveTimerLabel(DateTime? startedAt) {
    if (startedAt == null) {
      return 'LIVE';
    }
    final elapsed = DateTime.now().difference(startedAt);
    final minutes = elapsed.inMinutes.clamp(0, 999);
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds LIVE';
  }
}

class _TeamIdentity extends StatelessWidget {
  final String name;
  final String? logoUrl;
  final Color fallbackColor;

  const _TeamIdentity({
    required this.name,
    this.logoUrl,
    required this.fallbackColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                fallbackColor.withValues(alpha: 0.95),
                fallbackColor.withValues(alpha: 0.42),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          ),
          clipBehavior: Clip.antiAlias,
          child: logoUrl == null || logoUrl!.isEmpty
              ? Center(
                  child: Text(
                    _initial(name),
                    style: AppTextStyles.headlineMedium.copyWith(
                      color: Colors.white,
                    ),
                  ),
                )
              : Image.network(
                  logoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Text(
                      _initial(name),
                      style: AppTextStyles.headlineMedium.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: AppDimensions.sm),
        Text(
          name,
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.textPrimary,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _initial(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '?' : trimmed.characters.first;
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool live;

  const _StatusPill({
    required this.label,
    required this.color,
    this.live = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (live) ...[
            Icon(Icons.circle, size: 7, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Icon(icon, color: AppColors.textPrimary, size: 20),
        ),
      ),
    );
  }
}
