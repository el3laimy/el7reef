import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/el7reef_glass_surface.dart';
import '../../../domain/entities/share_payload.dart';
import '../models/pride_card_format.dart';
import 'pride_card_text_scale.dart';

/// The single safe-area and material boundary used by every Pride export.
///
/// Exported media is always solid. Functional glass is limited to the live
/// preview and is independently gated by [El7reefGlassSurface].
class PrideCardShell extends StatelessWidget {
  final bool exportMode;
  final PrideCardFormat format;
  final Widget child;
  final String semanticsLabel;
  final SharePayload? payload;
  final EdgeInsetsGeometry exportPadding;
  final EdgeInsetsGeometry previewPadding;
  final BoxDecoration? exportDecoration;
  final El7reefGlassVariant previewVariant;
  final double previewRadius;

  const PrideCardShell({
    super.key,
    required this.exportMode,
    required this.format,
    required this.child,
    required this.semanticsLabel,
    this.payload,
    this.exportPadding = EdgeInsets.zero,
    this.previewPadding = const EdgeInsets.all(12),
    this.exportDecoration,
    this.previewVariant = El7reefGlassVariant.pride,
    this.previewRadius = 28,
  });

  factory PrideCardShell.framed({
    Key? key,
    required bool exportMode,
    required PrideCardFormat format,
    required Widget child,
    required String semanticsLabel,
    SharePayload? payload,
    required EdgeInsetsGeometry exportPadding,
    EdgeInsetsGeometry previewPadding = const EdgeInsets.all(22),
  }) {
    return PrideCardShell(
      key: key,
      exportMode: exportMode,
      format: format,
      semanticsLabel: semanticsLabel,
      payload: payload,
      exportPadding: exportPadding,
      previewPadding: previewPadding,
      exportDecoration: BoxDecoration(
        color: AppColors.backgroundDeep,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.textPrimaryTinted.withValues(alpha: 0.12),
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final surface = Directionality(
      textDirection: TextDirection.rtl,
      child: exportMode
          ? Container(
              width: format.width,
              height: format.height,
              padding: exportPadding,
              decoration: exportDecoration,
              child: Material(color: Colors.transparent, child: child),
            )
          : El7reefGlassSurface(
              variant: previewVariant,
              padding: previewPadding,
              radius: previewRadius,
              child: child,
            ),
    );
    final content = PrideCardTextScale(
      child: Semantics(
        container: true,
        image: true,
        label: semanticsLabel,
        hint: payload == null ? null : 'تتضمن رابطًا موثقًا للمصدر',
        child: surface,
      ),
    );
    return exportMode
        ? content
        : AspectRatio(aspectRatio: format.aspectRatio, child: content);
  }
}
