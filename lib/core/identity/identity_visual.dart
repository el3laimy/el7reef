import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_media_colors.dart';
import 'identity_preset_catalog.dart';
import 'identity_preset_mark.dart';

enum IdentityVisualAppearance { operational, onDarkMedia }

/// One visual entry point for preset references, remote images, and fallbacks.
class IdentityVisual extends StatelessWidget {
  const IdentityVisual({
    super.key,
    this.source,
    this.size = 48,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.semanticLabel,
    this.fallbackBuilder,
    this.placeholderBuilder,
    this.appearance = IdentityVisualAppearance.operational,
  });

  final String? source;
  final double size;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final String? semanticLabel;
  final WidgetBuilder? fallbackBuilder;
  final WidgetBuilder? placeholderBuilder;
  final IdentityVisualAppearance appearance;

  @override
  Widget build(BuildContext context) {
    final normalizedSource = source?.trim();
    final preset = IdentityPresetCatalog.findByReference(normalizedSource);

    Widget child;
    if (preset != null) {
      child = IdentityPresetMark(
        preset: preset,
        size: size,
        semanticLabel: semanticLabel,
      );
    } else if (_isNetworkImage(normalizedSource)) {
      child = Semantics(
        image: true,
        label: semanticLabel,
        child: CachedNetworkImage(
          imageUrl: normalizedSource!,
          width: size,
          height: size,
          fit: fit,
          fadeInDuration: const Duration(milliseconds: 150),
          placeholder: (context, _) =>
              placeholderBuilder?.call(context) ?? _defaultPlaceholder(context),
          errorWidget: (context, _, error) => _fallback(context),
        ),
      );
    } else {
      child = _fallback(context);
    }

    final clipped = borderRadius == null
        ? child
        : ClipRRect(borderRadius: borderRadius!, child: child);

    return SizedBox.square(dimension: size, child: clipped);
  }

  bool _isNetworkImage(String? value) {
    if (value == null || value.isEmpty) return false;
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  Widget _fallback(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final surfaceColor = appearance == IdentityVisualAppearance.onDarkMedia
        ? AppMediaColors.raised
        : colors.surfaceContainerHighest;
    final foregroundColor = appearance == IdentityVisualAppearance.onDarkMedia
        ? AppMediaColors.textSecondary
        : colors.onSurfaceVariant;
    return fallbackBuilder?.call(context) ??
        Semantics(
          image: true,
          label: semanticLabel ?? 'هوية افتراضية',
          child: DecoratedBox(
            key: const ValueKey<String>('identity-visual-fallback'),
            decoration: BoxDecoration(
              color: surfaceColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.shield_outlined,
                color: foregroundColor,
                size: 24,
              ),
            ),
          ),
        );
  }

  Widget _defaultPlaceholder(BuildContext context) {
    final surfaceColor = appearance == IdentityVisualAppearance.onDarkMedia
        ? AppMediaColors.raised
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    return DecoratedBox(
      decoration: BoxDecoration(color: surfaceColor, shape: BoxShape.circle),
    );
  }
}
