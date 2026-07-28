import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/widgets/el7reef_glass_surface.dart';
import '../../../domain/entities/share_payload.dart';
import '../models/pride_card_format.dart';
import '../models/pride_export.dart';
import '../services/pride_share_preference_store.dart';

typedef PrideCardPreviewBuilder = Widget Function(PrideCardFormat format);

void showPrideShareFallbackNotice(
  BuildContext context,
  PrideShareOutcome outcome,
) {
  final message = outcome.usedImageFallback
      ? 'الفيديو ما اتجهزش، فتحنا شاشة المشاركة بالصورة بدلًا منه.'
      : outcome.usedTextFallback
      ? 'تعذر تجهيز الوسائط، فتحنا مشاركة نصية بدلًا منها.'
      : null;
  if (message == null) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

Future<PrideShareSelection?> showPrideShareComposer({
  required BuildContext context,
  required ShareCardType cardType,
  required PrideCardPreviewBuilder previewBuilder,
  PrideSharePreferenceStore? preferenceStore,
}) async {
  final videoAvailable =
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      FeatureFlags.prideVideoExportEnabled &&
      cardType.supportsVideoExport;
  final store = preferenceStore ?? PrideSharePreferenceStore();
  final initialSelection = await store.load(videoAvailable: videoAvailable);
  if (!context.mounted) return null;

  return showModalBottomSheet<PrideShareSelection>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: AppDimensions.animSlow),
      reverseDuration: Duration(milliseconds: AppDimensions.animNormal),
    ),
    builder: (_) => _PrideShareComposerSheet(
      initialSelection: initialSelection,
      videoAvailable: videoAvailable,
      previewBuilder: previewBuilder,
      preferenceStore: store,
    ),
  );
}

class _PrideShareComposerSheet extends StatefulWidget {
  final PrideShareSelection initialSelection;
  final bool videoAvailable;
  final PrideCardPreviewBuilder previewBuilder;
  final PrideSharePreferenceStore preferenceStore;

  const _PrideShareComposerSheet({
    required this.initialSelection,
    required this.videoAvailable,
    required this.previewBuilder,
    required this.preferenceStore,
  });

  @override
  State<_PrideShareComposerSheet> createState() =>
      _PrideShareComposerSheetState();
}

class _PrideShareComposerSheetState extends State<_PrideShareComposerSheet> {
  late PrideCardFormat _format;
  late PrideMediaType _mediaType;
  late bool _includeAudio;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _format = widget.initialSelection.format;
    _mediaType = widget.initialSelection.mediaType;
    _includeAudio = widget.initialSelection.includeAudio;
  }

  PrideShareSelection get _selection => PrideShareSelection(
    format: _format,
    mediaType: _mediaType,
    includeAudio: _includeAudio,
  );

  Future<void> _confirmSelection() async {
    setState(() => _isSaving = true);
    var dismissed = false;
    try {
      await widget.preferenceStore.save(_selection);
      if (!mounted) return;
      dismissed = true;
      Navigator.of(context).pop(_selection);
    } finally {
      if (mounted && !dismissed) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return El7reefSolidSurface(
      color: AppColors.surfaceRaised,
      borderColor: AppColors.surfaceBorder,
      padding: EdgeInsets.zero,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppDimensions.radiusXl),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppDimensions.lg,
            AppDimensions.md,
            AppDimensions.lg,
            MediaQuery.viewInsetsOf(context).bottom + AppDimensions.lg,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                El7reefGlassSurface(
                  role: El7reefGlassRole.previewToolbar,
                  tone: El7reefGlassTone.social,
                  padding: const EdgeInsets.all(AppDimensions.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
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
                        'جهّز لحظة الفخر',
                        style: AppTextStyles.headlineSmall,
                      ),
                      const SizedBox(height: AppDimensions.xs),
                      Text(
                        'عاين الكارت واختار الشكل قبل فتح شاشة المشاركة.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondaryTinted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.md),
                _PreviewPanel(
                  format: _format,
                  preview: widget.previewBuilder(_format),
                ),
                const SizedBox(height: AppDimensions.md),
                El7reefGlassSurface(
                  role: El7reefGlassRole.previewToolbar,
                  tone: El7reefGlassTone.social,
                  padding: const EdgeInsets.all(AppDimensions.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.videoAvailable) ...[
                        SegmentedButton<PrideMediaType>(
                          segments: const [
                            ButtonSegment(
                              value: PrideMediaType.image,
                              icon: Icon(Icons.image_rounded),
                              label: Text('صورة'),
                            ),
                            ButtonSegment(
                              value: PrideMediaType.video,
                              icon: Icon(Icons.movie_creation_rounded),
                              label: Text('فيديو'),
                            ),
                          ],
                          selected: {_mediaType},
                          onSelectionChanged: (selection) {
                            setState(() => _mediaType = selection.single);
                          },
                        ),
                        const SizedBox(height: AppDimensions.md),
                      ],
                      Text('المقاس', style: AppTextStyles.titleMedium),
                      const SizedBox(height: AppDimensions.sm),
                      _FormatChoices(
                        selected: _format,
                        onSelected: (format) =>
                            setState(() => _format = format),
                      ),
                      if (_mediaType == PrideMediaType.video) ...[
                        const SizedBox(height: AppDimensions.sm),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _includeAudio,
                          onChanged: (enabled) {
                            setState(() => _includeAudio = enabled);
                          },
                          secondary: const Icon(
                            Icons.graphic_eq_rounded,
                            color: AppColors.socialAccent,
                          ),
                          title: const Text('بصمة صوت الحريف'),
                          subtitle: const Text(
                            'يمكنك كتمها قبل تجهيز الفيديو.',
                          ),
                        ),
                      ],
                      const SizedBox(height: AppDimensions.lg),
                      FilledButton.icon(
                        key: const ValueKey('pride-share-confirm'),
                        onPressed: _isSaving ? null : _confirmSelection,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.socialAccent,
                          foregroundColor: AppColors.textOnPrimary,
                        ),
                        icon: _isSaving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.textOnPrimary,
                                ),
                              )
                            : const Icon(Icons.ios_share_rounded),
                        label: Text(
                          _mediaType == PrideMediaType.video
                              ? 'جهّز الفيديو وافتح المشاركة'
                              : 'افتح مشاركة الصورة',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  final PrideCardFormat format;
  final Widget preview;

  const _PreviewPanel({required this.format, required this.preview});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'معاينة كارت المشاركة',
      child: Container(
        height: 228,
        padding: const EdgeInsets.all(AppDimensions.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceSunken,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(color: AppColors.surfaceBorderStrong),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: format.width,
              height: format.height,
              child: preview,
            ),
          ),
        ),
      ),
    );
  }
}

class _FormatChoices extends StatelessWidget {
  final PrideCardFormat selected;
  final ValueChanged<PrideCardFormat> onSelected;

  const _FormatChoices({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimensions.sm,
      runSpacing: AppDimensions.sm,
      children: [
        _choice(PrideCardFormat.square1x1, 'مربع 1:1'),
        _choice(PrideCardFormat.feed4x5, 'منشور 4:5'),
        _choice(PrideCardFormat.story9x16, 'ستوري 9:16'),
        _choice(PrideCardFormat.landscape16x9, 'أفقي 16:9'),
      ],
    );
  }

  Widget _choice(PrideCardFormat format, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: selected == format,
      onSelected: (_) => onSelected(format),
    );
  }
}
