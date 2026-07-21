import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/app_logger.dart';
import '../../../domain/entities/share_payload.dart';
import '../models/champion_share_data.dart';
import '../models/pride_export.dart';
import '../services/share_card_capture_service.dart';
import 'champion_share_card.dart';
import 'pride_share_composer_sheet.dart';

class ChampionCelebrationSheet extends StatelessWidget {
  final ChampionShareData data;
  final VoidCallback onViewTournament;

  const ChampionCelebrationSheet({
    super.key,
    required this.data,
    required this.onViewTournament,
  });

  static const _captureService = ShareCardCaptureService();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.lg,
            AppDimensions.md,
            AppDimensions.lg,
            AppDimensions.lg,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppDimensions.radiusXl),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: AlignmentDirectional.center,
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.md),
                Text(
                  'البطل اتوّج',
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: AppColors.secondaryLight,
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.xs),
                Text(
                  'شارك لحظة التتويج قبل العودة لإدارة البطولة.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondaryTinted,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.md),
                SizedBox(
                  height: 280,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: ChampionShareCard(data: data, exportMode: true),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.lg),
                FilledButton.icon(
                  onPressed: () => _share(context),
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('شارك كارت البطل'),
                ),
                const SizedBox(height: AppDimensions.sm),
                OutlinedButton.icon(
                  onPressed: onViewTournament,
                  icon: const Icon(Icons.emoji_events_rounded),
                  label: const Text('عرض البطولة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    final selection = await showPrideShareComposer(
      context: context,
      cardType: ShareCardType.champion,
      previewBuilder: (format) =>
          ChampionShareCard(data: data, exportMode: true, format: format),
    );
    if (selection == null || !context.mounted) return;
    try {
      final outcome = await _captureService.exportAndShareWidget(
        context: context,
        shareRequest: PrideWidgetShareRequest(
          widget: ChampionShareCard(
            data: data,
            exportMode: true,
            format: selection.format,
          ),
          exportRequest: PrideExportRequest(
            cardType: ShareCardType.champion,
            format: selection.format,
            mediaType: selection.mediaType,
            fileName: 'el7reef_champion_${data.sharePayload.tournamentId}',
            includeAudio: selection.includeAudio,
          ),
          text: 'بطل ${data.tournamentName} على الحريف 🏆',
          payload: data.sharePayload,
        ),
      );
      if (context.mounted) showPrideShareFallbackNotice(context, outcome);
    } catch (error, stackTrace) {
      AppLogger.error('ChampionCelebrationSheet.share', error, stackTrace);
      Get.snackbar('تعذر المشاركة', 'تعذر تجهيز كارت البطل.');
    }
  }
}
