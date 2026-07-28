import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_text_styles.dart';
import 'identity_preset.dart';
import 'identity_preset_catalog.dart';
import 'identity_preset_picker_screen.dart';
import 'identity_visual.dart';

/// Compact entry point for the full-screen identity picker.
class IdentityPresetField extends StatelessWidget {
  const IdentityPresetField({
    super.key,
    required this.scope,
    required this.value,
    required this.onChanged,
    this.previewTitleController,
  });

  final IdentityPresetScope scope;
  final String? value;
  final ValueChanged<String?> onChanged;
  final TextEditingController? previewTitleController;

  bool get _isTeam => scope == IdentityPresetScope.team;

  @override
  Widget build(BuildContext context) {
    final preset = IdentityPresetCatalog.findByReference(value);
    final title = _isTeam ? 'شعار أو راية الفريق' : 'رمز البطولة';
    final subtitle = preset?.nameAr ?? 'اختياري — يمكنك تغييره لاحقًا';

    return Semantics(
      button: true,
      label: '$title، $subtitle',
      child: Material(
        color: AppColors.surfaceSunken,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          side: BorderSide(
            color: preset == null
                ? AppColors.surfaceBorder
                : AppColors.actionPrimary.withValues(alpha: 0.62),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openPicker(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.sm),
              child: Row(
                children: [
                  IdentityVisual(
                    source: value,
                    size: 52,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    semanticLabel: title,
                  ),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppTextStyles.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: preset == null
                                ? AppColors.textSecondary
                                : AppColors.actionLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  const Icon(
                    Icons.edit_outlined,
                    color: AppColors.actionPrimary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final selection = await IdentityPresetPickerScreen.show(
      context,
      scope: scope,
      initialReference: value,
      previewTitle: previewTitleController?.text,
    );
    if (selection == null || !context.mounted) return;
    onChanged(selection.isCleared ? null : selection.reference);
  }
}
