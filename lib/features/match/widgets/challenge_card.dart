import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/challenge_status.dart';
import '../../../core/widgets/glassmorphic_container.dart';
import '../../../domain/entities/challenge.dart';

class ChallengeCard extends StatelessWidget {
  final Challenge challenge;
  final bool isSentByMe;
  final String otherPartyName;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onCancel;

  const ChallengeCard({
    super.key,
    required this.challenge,
    required this.isSentByMe,
    required this.otherPartyName,
    this.onAccept,
    this.onDecline,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return GlassmorphicContainer(
      padding: const EdgeInsets.all(AppDimensions.md),
      borderRadius: AppDimensions.radiusMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSentByMe ? Icons.arrow_outward : Icons.call_received,
                color: isSentByMe ? AppColors.textMuted : AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Text(
                  isSentByMe ? 'إلى: $otherPartyName' : 'من: $otherPartyName',
                  style: AppTextStyles.titleMedium,
                ),
              ),
              _ChallengeStatusBadge(status: challenge.status),
            ],
          ),
          
          if (challenge.message != null && challenge.message!.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.sm),
            Text(
              '"${challenge.message}"',
              style: AppTextStyles.bodyMedium.copyWith(fontStyle: FontStyle.italic, color: AppColors.textMuted),
            ),
          ],
          
          const SizedBox(height: AppDimensions.md),
          Row(
            children: [
              if (challenge.location != null && challenge.location!.isNotEmpty) ...[
                const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(challenge.location!, style: AppTextStyles.labelSmall),
                ),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('${challenge.teamSize}v${challenge.teamSize}', style: AppTextStyles.labelSmall),
              ),
            ],
          ),
          
          if (challenge.status == ChallengeStatus.pending) ...[
            const SizedBox(height: AppDimensions.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isSentByMe)
                  TextButton(
                    onPressed: onCancel,
                    child: const Text('إلغاء', style: TextStyle(color: AppColors.error)),
                  )
                else ...[
                  TextButton(
                    onPressed: onDecline,
                    child: const Text('رفض', style: TextStyle(color: AppColors.error)),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  ElevatedButton(
                    onPressed: onAccept,
                    child: const Text('قبول التحدي ⚔️'),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ChallengeStatusBadge extends StatelessWidget {
  final ChallengeStatus status;

  const _ChallengeStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      ChallengeStatus.pending => (Colors.orange, 'قيد الانتظار'),
      ChallengeStatus.accepted => (AppColors.success, 'مقبول'),
      ChallengeStatus.declined => (AppColors.error, 'مرفوض'),
      ChallengeStatus.expired => (AppColors.textMuted, 'منتهي'),
      ChallengeStatus.cancelled => (AppColors.textMuted, 'ملغى'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: AppTextStyles.labelSmall.copyWith(color: color)),
    );
  }
}
