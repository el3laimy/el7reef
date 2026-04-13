import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_text_styles.dart';

/// بطاقة QR Code قابلة للمشاركة — Task 6.2.4
class QrCodeWidget extends StatelessWidget {
  final String data;
  final String label;
  final String? sublabel;
  final double size;
  final bool showBorder;
  final VoidCallback? onShare;

  const QrCodeWidget({
    super.key,
    required this.data,
    required this.label,
    this.sublabel,
    this.size = 200,
    this.showBorder = true,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        boxShadow: showBorder
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── QR Code ──
          QrImageView(
            data: data,
            version: QrVersions.auto,
            size: size,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Colors.black,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Colors.black,
            ),
            embeddedImage: const AssetImage('assets/images/qr_logo.png'),
            embeddedImageStyle: const QrEmbeddedImageStyle(
              size: Size(36, 36),
            ),
          ),

          const SizedBox(height: AppDimensions.md),

          // ── الاسم ──
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),

          if (sublabel != null) ...[
            const SizedBox(height: 4),
            Text(
              sublabel!,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ],

          if (onShare != null) ...[
            const SizedBox(height: AppDimensions.md),
            TextButton.icon(
              onPressed: onShare,
              icon: const Icon(Icons.share_outlined,
                  color: AppColors.primary, size: 18),
              label: Text('مشاركة الباركود',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.primary,
                  )),
            ),
          ],
        ],
      ),
    );
  }
}

/// Dialog لعرض QR Code بشكل كامل
class QrCodeDialog extends StatelessWidget {
  final String qrData;
  final String playerName;
  final String? username;

  const QrCodeDialog({
    super.key,
    required this.qrData,
    required this.playerName,
    this.username,
  });

  static Future<void> show(
    BuildContext context, {
    required String qrData,
    required String playerName,
    String? username,
  }) {
    return showDialog(
      context: context,
      builder: (_) => QrCodeDialog(
        qrData: qrData,
        playerName: playerName,
        username: username,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrCodeWidget(
            data: qrData,
            label: playerName,
            sublabel: username != null ? '@$username' : null,
            size: 220,
          ),
          const SizedBox(height: AppDimensions.md),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إغلاق',
                style: AppTextStyles.labelMedium.copyWith(
                  color: Colors.white70,
                )),
          ),
        ],
      ),
    );
  }
}
