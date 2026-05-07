import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/glassmorphic_container.dart';
import '../controllers/public_player_profile_controller.dart';
import '../models/public_player_profile_data.dart';

class PublicPlayerProfileScreen extends GetView<PublicPlayerProfileController> {
  const PublicPlayerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('بروفايل اللاعب')),
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: Obx(() {
            if (controller.isLoading.value) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            final profile = controller.profile.value;
            if (profile == null) {
              return _ProfileMessageState(
                message: controller.errorMessage.value.isEmpty
                    ? 'تعذر العثور على هذا اللاعب.'
                    : controller.errorMessage.value,
              );
            }
            return _PublicPlayerProfileContent(
              profile: profile,
              controller: controller,
            );
          }),
        ),
      ),
    );
  }
}

class _PublicPlayerProfileContent extends StatelessWidget {
  final PublicPlayerProfileData profile;
  final PublicPlayerProfileController controller;

  const _PublicPlayerProfileContent({
    required this.profile,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.pagePadding),
      children: [
        GlassmorphicContainer(
          padding: const EdgeInsets.all(AppDimensions.lg),
          borderRadius: AppDimensions.radiusLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.18),
                    child: Icon(
                      profile.isGuest
                          ? Icons.person_outline_rounded
                          : Icons.person_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.displayName,
                          style: AppTextStyles.headlineSmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppDimensions.xs),
                        _KindBadge(label: profile.badgeLabel),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.lg),
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      label: 'أهداف',
                      value: profile.totalGoals,
                      icon: Icons.sports_soccer_rounded,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    child: _StatTile(
                      label: 'نجومية المباراة',
                      value: profile.totalMvps,
                      icon: Icons.workspace_premium_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (profile.linkedPlayerId != null) ...[
          const SizedBox(height: AppDimensions.md),
          _InfoPanel(message: 'هذا الضيف مربوط ببروفايل لاعب مسجل.'),
        ],
        if (profile.showClaimPlaceholder) ...[
          const SizedBox(height: AppDimensions.md),
          if (controller.hasValidGuestClaimPayload)
            _ClaimAction(onPressed: controller.openGuestClaim)
          else if (controller.guestClaimWarningMessage != null)
            _InfoPanel(message: controller.guestClaimWarningMessage!)
          else
            _ClaimPlaceholder(),
        ],
      ],
    );
  }
}

class _KindBadge extends StatelessWidget {
  final String label;

  const _KindBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.secondary),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(height: AppDimensions.sm),
          Text('$value', style: AppTextStyles.headlineMedium),
          const SizedBox(height: AppDimensions.xs),
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ClaimPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _InfoPanel(
      message: 'ده أنت؟ اطلب رابط الدعوة من منظم البطولة أو قائد الفريق.',
    );
  }
}

class _ClaimAction extends StatelessWidget {
  final VoidCallback onPressed;

  const _ClaimAction({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GlassmorphicContainer(
      padding: const EdgeInsets.all(AppDimensions.md),
      borderRadius: AppDimensions.radiusMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'رابط الدعوة جاهز لهذا البروفايل.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.md),
          ElevatedButton(
            onPressed: onPressed,
            child: const Text('استلم البروفايل'),
          ),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final String message;

  const _InfoPanel({required this.message});

  @override
  Widget build(BuildContext context) {
    return GlassmorphicContainer(
      padding: const EdgeInsets.all(AppDimensions.md),
      borderRadius: AppDimensions.radiusMd,
      child: Text(
        message,
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _ProfileMessageState extends StatelessWidget {
  final String message;

  const _ProfileMessageState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.xl),
        child: Text(
          message,
          style: AppTextStyles.titleMedium,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
