import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/lineup/formation_library.dart';

class FormationPickerSheet extends StatelessWidget {
  final int playerCount;
  final String selectedFormationCode;
  final ValueChanged<String> onSelected;

  const FormationPickerSheet({
    super.key,
    required this.playerCount,
    required this.selectedFormationCode,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final formations = getAvailableFormations(playerCount);
    final defaultFormation = getDefaultFormation(playerCount);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.lg),
          decoration: const BoxDecoration(
            color: Color(0xFF07111F),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('اختيار الخطة', style: AppTextStyles.headlineSmall),
              const SizedBox(height: AppDimensions.xs),
              Text(
                '$playerCount لاعبين • الأرقام لا تشمل الحارس',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: AppDimensions.md),
              ...formations.map(
                (code) => Container(
                  margin: const EdgeInsets.only(bottom: AppDimensions.sm),
                  child: ListTile(
                    onTap: () => onSelected(code),
                    tileColor: Colors.white.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusMd,
                      ),
                      side: BorderSide(
                        color: code == selectedFormationCode
                            ? AppColors.primary.withValues(alpha: 0.55)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    leading: Icon(
                      code == selectedFormationCode
                          ? Icons.check_circle_rounded
                          : Icons.sports_soccer_rounded,
                      color: code == selectedFormationCode
                          ? AppColors.primaryLight
                          : AppColors.textMuted,
                    ),
                    title: Text(code, style: AppTextStyles.titleMedium),
                    subtitle: Text(
                      [
                        formationStyleLabel(code),
                        if (code == defaultFormation) 'الافتراضية',
                      ].join(' • '),
                      style: AppTextStyles.labelSmall,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
