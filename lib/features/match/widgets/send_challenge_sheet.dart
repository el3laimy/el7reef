import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../controllers/challenge_controller.dart';

class SendChallengeSheet extends StatefulWidget {
  final String challengedId;
  final String challengedName;
  final String? challengedTeamId;
  final String? challengerTeamId;

  const SendChallengeSheet({
    super.key,
    required this.challengedId,
    required this.challengedName,
    this.challengedTeamId,
    this.challengerTeamId,
  });

  @override
  State<SendChallengeSheet> createState() => _SendChallengeSheetState();
}

class _SendChallengeSheetState extends State<SendChallengeSheet> {
  final _messageCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  int _teamSize = 5;

  @override
  void dispose() {
    _messageCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: AppDimensions.lg,
        right: AppDimensions.lg,
        top: AppDimensions.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppDimensions.lg,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.lg),
          Text(
            'إرسال تحدي إلى ${widget.challengedName}',
            style: AppTextStyles.titleLarge,
          ),
          const SizedBox(height: AppDimensions.md),
          
          TextField(
            controller: _locationCtrl,
            decoration: const InputDecoration(
              labelText: 'الملعب / المكان (اختياري)',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          
          TextField(
            controller: _messageCtrl,
            decoration: const InputDecoration(
              labelText: 'رسالة التحدي (اختياري)',
              prefixIcon: Icon(Icons.message_outlined),
            ),
          ),
          const SizedBox(height: AppDimensions.lg),
          
          Text('عدد اللاعبين الأساسيين', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppDimensions.sm),
          Wrap(
            spacing: AppDimensions.sm,
            children: [5, 6, 7, 11].map((size) {
              final isSelected = _teamSize == size;
              return ChoiceChip(
                label: Text('${size}v$size'),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) setState(() => _teamSize = size);
                },
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: AppDimensions.xl),
          
          ElevatedButton(
            onPressed: () {
              final challengeCtrl = Get.find<ChallengeController>();
              challengeCtrl.sendChallenge(
                challengedId: widget.challengedId,
                challengerTeamId: widget.challengerTeamId,
                challengedTeamId: widget.challengedTeamId,
                message: _messageCtrl.text.trim().isEmpty ? null : _messageCtrl.text.trim(),
                location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
                teamSize: _teamSize,
              );
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppDimensions.md),
            ),
            child: const Text('إرسال التحدي ⚔️'),
          ),
        ],
      ),
    );
  }
}
