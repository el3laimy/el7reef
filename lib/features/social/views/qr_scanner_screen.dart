import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_media_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/el7reef_glass_surface.dart';

/// شاشة QR Scanner — Task 6.2.6
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _scanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.startsWith('7reef://')) {
        _scanned = true;
        _controller.stop();
        _handleDeepLink(raw);
        return;
      }
    }
  }

  /// Deep Link Parser — Task 6.2.3
  void _handleDeepLink(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    // يستبدل // بـ Uri scheme
    final path = url.replaceFirst('7reef://', '');
    final parts = path.split('/');

    if (parts.isEmpty) return;

    switch (parts[0]) {
      case 'player':
        if (parts.length >= 2) {
          // فتح بروفايل اللاعب
          Get.back();
          Get.toNamed(AppRoutes.profile, arguments: {'playerId': parts[1]});
        }
        break;

      case 'team':
        if (parts.length >= 3 && parts[2] == 'join') {
          // طلب انضمام للفريق
          Get.back();
          Get.toNamed(AppRoutes.myTeams, arguments: {'joinTeamId': parts[1]});
        }
        break;

      case 'tournament':
        if (parts.length >= 3 && parts[2] == 'register') {
          // تسجيل في الدورة
          Get.back();
          Get.toNamed(
            AppRoutes.tournaments,
            arguments: {'tournamentId': parts[1]},
          );
        }
        break;

      default:
        Get.snackbar(
          'تعذّر الفتح',
          'باركود غير معروف',
          snackPosition: SnackPosition.BOTTOM,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppMediaColors.canvasDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppMediaColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        title: const Text('مسح الباركود'),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AppDimensions.sm),
            child: El7reefGlassSurface(
              role: El7reefGlassRole.mediaOverlay,
              padding: EdgeInsets.zero,
              radius: 20,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'تشغيل الإضاءة',
                    icon: ValueListenableBuilder(
                      valueListenable: _controller,
                      builder: (ctx1, state, child1) {
                        return Icon(
                          state.torchState == TorchState.on
                              ? Icons.flash_on
                              : Icons.flash_off,
                          color: state.torchState == TorchState.on
                              ? AppMediaColors.actionPrimary
                              : AppMediaColors.textPrimary,
                        );
                      },
                    ),
                    onPressed: _controller.toggleTorch,
                  ),
                  IconButton(
                    tooltip: 'تبديل الكاميرا',
                    icon: ValueListenableBuilder(
                      valueListenable: _controller,
                      builder: (ctx2, state, child2) {
                        return Icon(
                          state.cameraDirection == CameraFacing.front
                              ? Icons.camera_front
                              : Icons.camera_rear,
                          color: AppMediaColors.textPrimary,
                        );
                      },
                    ),
                    onPressed: _controller.switchCamera,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── كاميرا ──
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) =>
                _ScannerErrorState(onRetry: _controller.start),
          ),

          // ── إطار المسح ──
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppMediaColors.actionPrimary,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              ),
              child: Stack(
                children: [
                  _Corner(top: true, left: true),
                  _Corner(top: true, left: false),
                  _Corner(top: false, left: true),
                  _Corner(top: false, left: false),
                ],
              ),
            ),
          ),

          // ── نص توجيهي ──
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: El7reefGlassSurface(
                role: El7reefGlassRole.mediaOverlay,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.lg,
                  vertical: AppDimensions.sm,
                ),
                radius: AppDimensions.radiusLg,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'وجّه الكاميرا على الباركود',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppMediaColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.xs),
                    Text(
                      'باركود اللاعب · الفريق · الدورة',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppMediaColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerErrorState extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _ScannerErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.pagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              color: AppMediaColors.textSecondary,
              size: 48,
            ),
            const SizedBox(height: AppDimensions.md),
            Text(
              'تعذر تشغيل الكاميرا',
              style: AppTextStyles.titleLarge.copyWith(
                color: AppMediaColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.xs),
            Text(
              'اسمح للحريف باستخدام الكاميرا لمسح QR، ثم حاول مرة أخرى.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppMediaColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
              style: FilledButton.styleFrom(
                backgroundColor: AppMediaColors.actionPrimary,
                foregroundColor: AppMediaColors.inkOnAccent,
                minimumSize: const Size(160, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// زوايا إطار المسح
class _Corner extends StatelessWidget {
  final bool top;
  final bool left;
  const _Corner({required this.top, required this.left});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top ? 0 : null,
      bottom: top ? null : 0,
      left: left ? 0 : null,
      right: left ? null : 0,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          border: Border(
            top: top
                ? const BorderSide(
                    color: AppMediaColors.actionPrimary,
                    width: 3,
                  )
                : BorderSide.none,
            bottom: !top
                ? const BorderSide(
                    color: AppMediaColors.actionPrimary,
                    width: 3,
                  )
                : BorderSide.none,
            left: left
                ? const BorderSide(
                    color: AppMediaColors.actionPrimary,
                    width: 3,
                  )
                : BorderSide.none,
            right: !left
                ? const BorderSide(
                    color: AppMediaColors.actionPrimary,
                    width: 3,
                  )
                : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: top && left ? const Radius.circular(4) : Radius.zero,
            topRight: top && !left ? const Radius.circular(4) : Radius.zero,
            bottomLeft: !top && left ? const Radius.circular(4) : Radius.zero,
            bottomRight: !top && !left ? const Radius.circular(4) : Radius.zero,
          ),
        ),
      ),
    );
  }
}
