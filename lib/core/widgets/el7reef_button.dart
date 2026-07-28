import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_text_styles.dart';

/// زر EL7REEF الرئيسي؛ صلب وواضح ويستمد حالاته من الـTheme.
class El7reefButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final IconData? icon;
  final double? width;
  final double height;

  const El7reefButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.width,
    this.height = AppDimensions.buttonHeightMd,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final childColor = isLoading
        ? AppColors.textPrimary
        : isOutlined
        ? (enabled ? AppColors.textPrimary : AppColors.textMuted)
        : (enabled ? AppColors.textOnPrimary : AppColors.textMuted);

    if (isOutlined) {
      return SizedBox(
        width: width ?? double.infinity,
        height: height,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          child: _buildChild(childColor),
        ),
      );
    }

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        child: _buildChild(childColor),
      ),
    );
  }

  Widget _buildChild(Color color) {
    if (isLoading) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppDimensions.sm),
          Flexible(
            child: Text(
              text,
              style: AppTextStyles.buttonText.copyWith(color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return Text(text, style: AppTextStyles.buttonText.copyWith(color: color));
  }
}
