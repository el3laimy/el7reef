import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_text_styles.dart';
import 'el7reef_glass_surface.dart';

class SectionStateCard extends StatelessWidget {
  final String? title;
  final String message;
  final IconData icon;
  final Color color;
  final El7reefGlassVariant variant;
  final String? actionLabel;
  final FutureOr<void> Function()? onAction;

  const SectionStateCard({
    super.key,
    this.title,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.color = AppColors.primary,
    this.variant = El7reefGlassVariant.base,
    this.actionLabel,
    this.onAction,
  });

  const SectionStateCard.error({
    super.key,
    this.title,
    required this.message,
    this.icon = Icons.lock_outline_rounded,
    this.color = AppColors.error,
    this.variant = El7reefGlassVariant.error,
    this.actionLabel = 'حاول تاني',
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    return El7reefGlassSurface(
      variant: variant,
      radius: AppDimensions.radiusMd,
      padding: const EdgeInsets.all(AppDimensions.md),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StateMessage(
                  icon: icon,
                  color: color,
                  title: title,
                  message: message,
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: AppDimensions.xs),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: _runAction,
                      child: Text(actionLabel!),
                    ),
                  ),
                ],
              ],
            )
          : Row(
              crossAxisAlignment: title == null
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _StateMessage(
                    icon: icon,
                    color: color,
                    title: title,
                    message: message,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(width: AppDimensions.sm),
                  TextButton(onPressed: _runAction, child: Text(actionLabel!)),
                ],
              ],
            ),
    );
  }

  void _runAction() {
    unawaited(Future<void>.sync(onAction!));
  }
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String? title;
  final String message;

  const _StateMessage({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: title == null
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: AppDimensions.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null) ...[
                Text(
                  title!,
                  style: AppTextStyles.titleSmall.copyWith(color: color),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                message,
                style: AppTextStyles.bodySmall.copyWith(color: color),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
