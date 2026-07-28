import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/widgets/el7reef_glass_surface.dart';
import '../../../core/widgets/el7reef_surface.dart';
import '../../../domain/entities/share_payload.dart';
import '../../shareables/controllers/player_share_controller.dart';
import '../../shareables/controllers/player_moment_share_controller.dart';
import '../../shareables/models/player_moment_share_data.dart';
import '../../shareables/models/player_share_data.dart';
import '../../shareables/models/pride_export.dart';
import '../../shareables/services/guest_mvp_claim_link_service.dart';
import '../../shareables/services/share_card_capture_service.dart';
import '../../shareables/widgets/player_moment_share_card.dart';
import '../../shareables/widgets/player_share_card.dart';
import '../../shareables/widgets/pride_identity_avatar.dart';
import '../../shareables/widgets/pride_share_composer_sheet.dart';
import '../controllers/public_player_profile_controller.dart';
import '../models/public_player_profile_data.dart';
import '../services/user_safety_service.dart';

class PublicPlayerProfileScreen extends GetView<PublicPlayerProfileController> {
  const PublicPlayerProfileScreen({super.key});

  static const _shareController = PlayerShareController();
  static const _playerMomentShareController = PlayerMomentShareController();
  static const _captureService = ShareCardCaptureService();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('بروفايل اللاعب'),
          actions: [
            Obx(() {
              final profile = controller.profile.value;
              return IconButton(
                onPressed: profile == null
                    ? null
                    : () => _share(context, profile),
                icon: const Icon(Icons.ios_share_rounded),
                tooltip: 'مشاركة بطاقة اللاعب',
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
              return _ProfileMessageState(
                message: controller.errorMessage.value.isEmpty
                    ? 'تعذر العثور على هذا اللاعب.'
                    : controller.errorMessage.value,
              );
            }
            return _PublicPlayerProfileContent(
              profile: profile,
              controller: controller,
              milestones: _milestoneCards(profile),
              onShareMilestone: (milestones) =>
                  _shareMilestone(context, milestones),
            );
          }),
        ),
      ),
    );
  }

  Future<void> _share(
    BuildContext context,
    PublicPlayerProfileData profile,
  ) async {
    var playerCard = _shareController.build(profile: profile);
    final payload = await _claimablePridePayload(playerCard.sharePayload);
    if (!context.mounted) return;
    playerCard = _copyPlayerCardWithPayload(playerCard, payload);

    final selection = await showPrideShareComposer(
      context: context,
      cardType: playerCard.sharePayload.cardType,
      previewBuilder: (format) =>
          PlayerShareCard(data: playerCard, format: format),
    );
    if (selection == null || !context.mounted) return;
    try {
      final outcome = await _captureService.exportAndShareWidget(
        context: context,
        shareRequest: PrideWidgetShareRequest(
          widget: PlayerShareCard(
            data: playerCard,
            exportMode: true,
            format: selection.format,
          ),
          exportRequest: PrideExportRequest(
            cardType: playerCard.sharePayload.cardType,
            format: selection.format,
            mediaType: selection.mediaType,
            fileName: 'el7reef_player_${profile.id}',
            includeAudio: selection.includeAudio,
          ),
          text: 'بطاقة ${playerCard.displayName} على الحريف',
          payload: playerCard.sharePayload,
        ),
      );
      if (context.mounted) showPrideShareFallbackNotice(context, outcome);
    } catch (error, stackTrace) {
      AppLogger.error('PublicPlayerProfileScreen._share', error, stackTrace);
      Get.snackbar('تعذر المشاركة', 'تعذر تجهيز بطاقة اللاعب.');
    }
  }

  List<PlayerMilestoneShareData> _milestoneCards(
    PublicPlayerProfileData profile,
  ) {
    if (!FeatureFlags.prideShareCatalogV2Enabled) {
      return const <PlayerMilestoneShareData>[];
    }
    return PlayerMilestoneMetric.values
        .map(
          (metric) => _playerMomentShareController.buildMilestoneIfEligible(
            profile: profile,
            metric: metric,
          ),
        )
        .whereType<PlayerMilestoneShareData>()
        .toList(growable: false);
  }

  Future<void> _shareMilestone(
    BuildContext context,
    List<PlayerMilestoneShareData> milestones,
  ) async {
    if (milestones.isEmpty) return;
    final selected = milestones.length == 1
        ? milestones.single
        : await showModalBottomSheet<PlayerMilestoneShareData>(
            context: context,
            useSafeArea: true,
            showDragHandle: true,
            builder: (_) => _MilestonePickerSheet(milestones: milestones),
          );
    if (selected == null || !context.mounted) return;

    var shareData = selected;
    final payload = await _claimablePridePayload(shareData.sharePayload);
    if (!context.mounted) return;
    shareData = shareData.copyWith(sharePayload: payload);

    final selection = await showPrideShareComposer(
      context: context,
      cardType: shareData.sharePayload.cardType,
      previewBuilder: (format) => PlayerMomentShareCard(
        data: shareData,
        format: format,
        includeGrowthLink: FeatureFlags.prideGrowthLinksEnabled,
      ),
    );
    if (selection == null || !context.mounted) return;

    try {
      final outcome = await _captureService.exportAndShareWidget(
        context: context,
        shareRequest: PrideWidgetShareRequest(
          widget: PlayerMomentShareCard(
            data: shareData,
            exportMode: true,
            format: selection.format,
            includeGrowthLink: FeatureFlags.prideGrowthLinksEnabled,
          ),
          exportRequest: PrideExportRequest(
            cardType: shareData.sharePayload.cardType,
            format: selection.format,
            mediaType: selection.mediaType,
            fileName:
                'el7reef_milestone_${shareData.metric.name}_${shareData.actor.id}_${shareData.milestone}',
            includeAudio: selection.includeAudio,
          ),
          text:
              '${shareData.playerName} وصل إلى ${shareData.milestone} ${shareData.metricLabel} على الحريف',
          payload: shareData.sharePayload,
        ),
      );
      if (context.mounted) showPrideShareFallbackNotice(context, outcome);
    } catch (error, stackTrace) {
      AppLogger.error(
        'PublicPlayerProfileScreen._shareMilestone',
        error,
        stackTrace,
      );
      Get.snackbar('تعذر المشاركة', 'تعذر تجهيز كارت الإنجاز.');
    }
  }

  Future<SharePayload> _claimablePridePayload(SharePayload payload) async {
    if (!FeatureFlags.prideGrowthLinksEnabled ||
        !Get.isRegistered<GuestMvpClaimLinkService>()) {
      return payload;
    }
    final actorId = Get.isRegistered<AuthService>()
        ? Get.find<AuthService>().currentUserId
        : null;
    try {
      return await Get.find<GuestMvpClaimLinkService>()
          .attachClaimUrl(payload: payload, actorId: actorId)
          .timeout(sharePreparationTimeout);
    } on TimeoutException {
      return payload;
    } catch (error) {
      AppLogger.warning(
        'PublicPlayerProfileScreen._claimablePridePayload',
        error,
      );
      return payload;
    }
  }

  PlayerShareData _copyPlayerCardWithPayload(
    PlayerShareData playerCard,
    SharePayload payload,
  ) {
    return PlayerShareData(
      displayName: playerCard.displayName,
      initials: playerCard.initials,
      photoUrl: playerCard.photoUrl,
      totalGoals: playerCard.totalGoals,
      totalMvps: playerCard.totalMvps,
      isGuest: playerCard.isGuest,
      sharePayload: payload,
    );
  }
}

class _PublicPlayerProfileContent extends StatelessWidget {
  final PublicPlayerProfileData profile;
  final PublicPlayerProfileController controller;
  final List<PlayerMilestoneShareData> milestones;
  final ValueChanged<List<PlayerMilestoneShareData>> onShareMilestone;

  const _PublicPlayerProfileContent({
    required this.profile,
    required this.controller,
    required this.milestones,
    required this.onShareMilestone,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.pagePadding),
      children: [
        El7reefGlassSurface(
          role: El7reefGlassRole.hero,
          padding: const EdgeInsets.all(AppDimensions.lg),
          radius: AppDimensions.radiusLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  PrideIdentityAvatar(
                    imageUrl: profile.photoUrl,
                    initials: _initials(profile.displayName),
                    size: 56,
                    accent: profile.isGuest
                        ? AppColors.info
                        : AppColors.actionPrimary,
                    fallbackIcon: profile.isGuest
                        ? Icons.person_outline_rounded
                        : Icons.person_rounded,
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
        if (milestones.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.md),
          _MilestoneShareAction(
            milestones: milestones,
            onPressed: () => onShareMilestone(milestones),
          ),
        ],
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
        if (controller.canReportProfile || controller.canBlockPlayer) ...[
          const SizedBox(height: AppDimensions.md),
          _SafetyActions(controller: controller),
        ],
      ],
    );
  }

  String _initials(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? 'ح' : normalized.substring(0, 1);
  }
}

class _MilestoneShareAction extends StatelessWidget {
  final List<PlayerMilestoneShareData> milestones;
  final VoidCallback onPressed;

  const _MilestoneShareAction({
    required this.milestones,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final first = milestones.first;
    final description = milestones.length == 1
        ? 'إنجاز ${first.milestone} ${_metricLabel(first.metric)} جاهز بكارت يليق بيك.'
        : 'عندك إنجاز أهداف وإنجاز نجومية، اختار اللحظة اللي هتشاركها.';
    return El7reefSurface(
      elevated: true,
      borderColor: AppColors.achievement.withValues(alpha: 0.34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.military_tech_rounded,
                color: AppColors.achievement,
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Text(
                  'إنجاز يستحق يتشاف',
                  style: AppTextStyles.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            description,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondaryTinted,
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('شارك إنجازك'),
          ),
        ],
      ),
    );
  }

  String _metricLabel(PlayerMilestoneMetric metric) => switch (metric) {
    PlayerMilestoneMetric.goals => 'هدف',
    PlayerMilestoneMetric.mvps => 'مرات MVP',
  };
}

class _MilestonePickerSheet extends StatelessWidget {
  final List<PlayerMilestoneShareData> milestones;

  const _MilestonePickerSheet({required this.milestones});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.lg,
          0,
          AppDimensions.lg,
          AppDimensions.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('اختار الإنجاز', style: AppTextStyles.headlineSmall),
            const SizedBox(height: AppDimensions.xs),
            Text(
              'الكارت يعرض أعلى عتبة حققتها من أرقام بروفايلك.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondaryTinted,
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            for (final milestone in milestones)
              ListTile(
                contentPadding: EdgeInsets.zero,
                minTileHeight: 56,
                leading: CircleAvatar(
                  backgroundColor: AppColors.achievementSurface,
                  foregroundColor: AppColors.achievement,
                  child: Icon(
                    milestone.metric == PlayerMilestoneMetric.goals
                        ? Icons.sports_soccer_rounded
                        : Icons.workspace_premium_rounded,
                  ),
                ),
                title: Text(
                  '${milestone.milestone} ${_metricLabel(milestone.metric)}',
                  style: AppTextStyles.titleMedium,
                ),
                subtitle: Text('إجمالي البروفايل: ${milestone.currentTotal}'),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => Navigator.of(context).pop(milestone),
              ),
          ],
        ),
      ),
    );
  }

  String _metricLabel(PlayerMilestoneMetric metric) => switch (metric) {
    PlayerMilestoneMetric.goals => 'هدف',
    PlayerMilestoneMetric.mvps => 'مرات MVP',
  };
}

class _SafetyActions extends StatelessWidget {
  final PublicPlayerProfileController controller;

  const _SafetyActions({required this.controller});

  @override
  Widget build(BuildContext context) {
    return El7reefSolidSurface(
      padding: const EdgeInsets.all(AppDimensions.md),
      radius: AppDimensions.radiusMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('الأمان', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppDimensions.sm),
          if (controller.canReportProfile)
            OutlinedButton.icon(
              onPressed: () => _showReportSheet(context),
              icon: const Icon(Icons.flag_outlined),
              label: const Text('الإبلاغ عن البروفايل'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          if (controller.canBlockPlayer) ...[
            const SizedBox(height: AppDimensions.sm),
            OutlinedButton.icon(
              onPressed: () => _confirmBlock(context),
              icon: const Icon(Icons.block_rounded),
              label: const Text('حظر اللاعب'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showReportSheet(BuildContext context) async {
    final reportRequest = await showModalBottomSheet<_ReportProfileRequest>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ReportProfileSheet(),
    );
    if (reportRequest != null) {
      await controller.reportProfile(
        reason: reportRequest.reason,
        details: reportRequest.details,
      );
    }
  }

  Future<void> _confirmBlock(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حظر اللاعب؟'),
        content: const Text(
          'سيُزال من علاقاتك ولن يظهر ضمن تفاعلاتك الاجتماعية.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('حظر اللاعب'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.blockPlayer();
    }
  }
}

class _ReportProfileRequest {
  final UserReportReason reason;
  final String details;

  const _ReportProfileRequest({required this.reason, required this.details});
}

class _ReportProfileSheet extends StatefulWidget {
  const _ReportProfileSheet();

  @override
  State<_ReportProfileSheet> createState() => _ReportProfileSheetState();
}

class _ReportProfileSheetState extends State<_ReportProfileSheet> {
  final TextEditingController _detailsController = TextEditingController();
  UserReportReason _selectedReason = UserReportReason.harassment;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppDimensions.pagePadding,
          0,
          AppDimensions.pagePadding,
          MediaQuery.viewInsetsOf(context).bottom + AppDimensions.pagePadding,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('الإبلاغ عن البروفايل', style: AppTextStyles.titleLarge),
              const SizedBox(height: AppDimensions.xs),
              Text(
                'اختر السبب الأقرب. يصل البلاغ لفريق المراجعة ولا يظهر لصاحب البروفايل.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              _buildReasonSelector(),
              TextField(
                controller: _detailsController,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'تفاصيل إضافية (اختياري)',
                ),
              ),
              const SizedBox(height: AppDimensions.md),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.send_rounded),
                label: const Text('إرسال البلاغ'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReasonSelector() {
    return RadioGroup<UserReportReason>(
      groupValue: _selectedReason,
      onChanged: (reason) {
        if (reason != null) setState(() => _selectedReason = reason);
      },
      child: Column(
        children: [
          for (final reason in UserReportReason.values)
            RadioListTile<UserReportReason>(
              value: reason,
              title: Text(reason.label),
              contentPadding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }

  void _submit() {
    Navigator.of(context).pop(
      _ReportProfileRequest(
        reason: _selectedReason,
        details: _detailsController.text,
      ),
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
        color: AppColors.infoSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.info),
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
    return El7reefSolidSurface(
      padding: const EdgeInsets.all(AppDimensions.md),
      radius: AppDimensions.radiusMd,
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
    return El7reefSolidSurface(
      padding: const EdgeInsets.all(AppDimensions.md),
      radius: AppDimensions.radiusMd,
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
