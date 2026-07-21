import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/el7reef_glass_surface.dart';
import '../../shareables/controllers/team_share_controller.dart';
import '../../shareables/models/team_share_data.dart';
import '../../shareables/services/share_card_capture_service.dart';
import '../../shareables/widgets/pride_identity_avatar.dart';
import '../../shareables/widgets/pride_card_format_picker.dart';
import '../../shareables/widgets/team_share_card.dart';
import '../controllers/public_team_profile_controller.dart';
import '../models/public_team_profile_data.dart';

class PublicTeamProfileScreen extends GetView<PublicTeamProfileController> {
  const PublicTeamProfileScreen({super.key});

  static const _shareController = TeamShareController();
  static const _captureService = ShareCardCaptureService();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('بطاقة الفريق'),
          actions: [
            Obx(() {
              final profile = controller.profile.value;
              return IconButton(
                onPressed: profile == null
                    ? null
                    : () => _share(context, profile),
                icon: const Icon(Icons.ios_share_rounded),
                tooltip: 'مشاركة بطاقة الفريق',
              );
            }),
          ],
        ),
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
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.xl),
                  child: Text(
                    controller.errorMessage.value.isEmpty
                        ? 'تعذر العثور على هذا الفريق.'
                        : controller.errorMessage.value,
                    style: AppTextStyles.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return _PublicTeamContent(profile: profile);
          }),
        ),
      ),
    );
  }

  Future<void> _share(
    BuildContext context,
    PublicTeamProfileData profile,
  ) async {
    final data = _shareData(profile);
    final format = await showPrideCardFormatPicker(context);
    if (format == null || !context.mounted) return;
    try {
      await _captureService.captureAndShareWidget(
        context: context,
        widget: TeamShareCard(data: data, exportMode: true, format: format),
        fileName: 'el7reef_team_${profile.id}',
        text: 'بطاقة فريق ${data.teamName} على الحريف',
        payload: data.sharePayload,
      );
    } catch (_) {
      Get.snackbar('تعذر المشاركة', 'تعذر تجهيز بطاقة الفريق.');
    }
  }

  TeamShareData _shareData(PublicTeamProfileData profile) {
    return _shareController.buildPublic(profile);
  }
}

class _PublicTeamContent extends StatelessWidget {
  final PublicTeamProfileData profile;

  const _PublicTeamContent({required this.profile});

  @override
  Widget build(BuildContext context) {
    final metrics = <({String label, int value})>[
      if (profile.playerCount case final value?)
        (label: 'لاعبين', value: value),
      if (profile.wins case final value?) (label: 'فوز', value: value),
      if (profile.totalMatches case final value?)
        (label: 'مباريات', value: value),
    ];
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.pagePadding),
      children: [
        El7reefGlassSurface(
          variant: El7reefGlassVariant.pride,
          padding: const EdgeInsets.all(AppDimensions.lg),
          radius: AppDimensions.radiusXl,
          child: Column(
            children: [
              PrideIdentityAvatar(
                imageUrl: profile.logoUrl,
                initials: profile.name.characters.take(2).toString(),
                size: 96,
                accent: AppColors.primary,
                fallbackIcon: Icons.shield_rounded,
              ),
              const SizedBox(height: AppDimensions.md),
              Text(
                profile.name,
                style: AppTextStyles.headlineMedium,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppDimensions.xs),
              Text(
                profile.kindLabel,
                style: AppTextStyles.labelMedium.copyWith(
                  color: profile.isGuestTeam
                      ? AppColors.secondary
                      : AppColors.primary,
                ),
              ),
              if (metrics.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.lg),
                Row(
                  children: [
                    for (var index = 0; index < metrics.length; index += 1) ...[
                      if (index > 0) const SizedBox(width: AppDimensions.sm),
                      Expanded(
                        child: _TeamMetric(
                          label: metrics[index].label,
                          value: metrics[index].value,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TeamMetric extends StatelessWidget {
  final String label;
  final int value;

  const _TeamMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Column(
        children: [
          Text('$value', style: AppTextStyles.titleLarge),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.labelSmall),
        ],
      ),
    );
  }
}
