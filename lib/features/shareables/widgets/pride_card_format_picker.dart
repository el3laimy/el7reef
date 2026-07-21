import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../models/pride_card_format.dart';

Future<PrideCardFormat?> showPrideCardFormatPicker(BuildContext context) {
  return showModalBottomSheet<PrideCardFormat>(
    context: context,
    useSafeArea: true,
    builder: (sheetContext) => const _PrideCardFormatSheet(),
  );
}

class _PrideCardFormatSheet extends StatefulWidget {
  const _PrideCardFormatSheet();

  @override
  State<_PrideCardFormatSheet> createState() => _PrideCardFormatSheetState();
}

class _PrideCardFormatSheetState extends State<_PrideCardFormatSheet> {
  static const _preferenceKey = 'last_pride_card_format';
  PrideCardFormat? _lastFormat;

  @override
  void initState() {
    super.initState();
    _loadLastFormat();
  }

  Future<void> _loadLastFormat() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_preferenceKey);
    if (!mounted || stored == null) return;
    for (final format in PrideCardFormat.values) {
      if (format.name == stored) {
        setState(() => _lastFormat = format);
        return;
      }
    }
  }

  void _select(PrideCardFormat format) {
    Navigator.of(context).pop(format);
    unawaited(
      SharedPreferences.getInstance().then(
        (preferences) => preferences.setString(_preferenceKey, format.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('اختار مقاس المشاركة', style: AppTextStyles.headlineSmall),
            const SizedBox(height: AppDimensions.xs),
            Text(
              'كل مقاس يصدر بدقة جاهزة للنشر من غير قص.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondaryTinted,
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            Row(
              children: [
                Expanded(
                  child: _FormatOption(
                    icon: Icons.crop_square_rounded,
                    title: 'مربع 1:1',
                    subtitle: 'WhatsApp وInstagram',
                    format: PrideCardFormat.square1x1,
                    selected: _lastFormat == PrideCardFormat.square1x1,
                    onSelected: _select,
                  ),
                ),
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: _FormatOption(
                    icon: Icons.crop_portrait_rounded,
                    title: 'منشور 4:5',
                    subtitle: 'Instagram وFacebook Feed',
                    format: PrideCardFormat.feed4x5,
                    selected: _lastFormat == PrideCardFormat.feed4x5,
                    onSelected: _select,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.sm),
            Row(
              children: [
                Expanded(
                  child: _FormatOption(
                    icon: Icons.phone_android_rounded,
                    title: 'ستوري 9:16',
                    subtitle: 'WhatsApp وInstagram Story',
                    format: PrideCardFormat.story9x16,
                    selected: _lastFormat == PrideCardFormat.story9x16,
                    onSelected: _select,
                  ),
                ),
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: _FormatOption(
                    icon: Icons.crop_16_9_rounded,
                    title: 'أفقي 16:9',
                    subtitle: 'YouTube وFacebook وX',
                    format: PrideCardFormat.landscape16x9,
                    selected: _lastFormat == PrideCardFormat.landscape16x9,
                    onSelected: _select,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final PrideCardFormat format;
  final bool selected;
  final ValueChanged<PrideCardFormat> onSelected;

  const _FormatOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.format,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 64,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        side: BorderSide(
          color: selected
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.28),
          width: selected ? 2 : 1,
        ),
      ),
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: AppTextStyles.titleMedium),
      subtitle: Text(subtitle, style: AppTextStyles.bodySmall),
      trailing: selected
          ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
          : null,
      onTap: () => onSelected(format),
    );
  }
}
