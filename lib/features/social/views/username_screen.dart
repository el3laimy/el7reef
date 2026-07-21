import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/username_service.dart';
import '../../../core/widgets/el7reef_glass_surface.dart';
import '../../../core/widgets/el7reef_button.dart';
import '../../profile/controllers/profile_controller.dart';

/// شاشة اختيار أو تعديل Username — Task 6.1.3
class UsernameScreen extends StatefulWidget {
  final bool isFirstTime;
  const UsernameScreen({super.key, this.isFirstTime = false});

  @override
  State<UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends State<UsernameScreen> {
  final _controller = TextEditingController();
  final _usernameService = UsernameService();
  final _profileCtrl = Get.find<ProfileController>();

  UsernameValidationResult? _localResult;
  bool? _isAvailable;
  bool _checking = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // لو عنده username مسبق، نملأه
    final existing = _profileCtrl.currentPlayer?.username;
    if (existing != null) _controller.text = existing;
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final text = _controller.text.trim().toLowerCase();
    setState(() {
      _isAvailable = null;
      _localResult = text.isEmpty
          ? null
          : _usernameService.validateLocally(text);
    });
  }

  Future<void> _checkAvailability() async {
    final text = _controller.text.trim().toLowerCase();
    if (_localResult != UsernameValidationResult.valid) return;

    setState(() => _checking = true);
    try {
      final avail = await _usernameService.isAvailable(
        text,
        currentOwnerId: _profileCtrl.currentPlayer?.id,
      );
      setState(() => _isAvailable = avail);
    } finally {
      setState(() => _checking = false);
    }
  }

  Future<void> _save() async {
    final text = _controller.text.trim().toLowerCase();
    if (_localResult != UsernameValidationResult.valid) return;

    setState(() => _saving = true);
    try {
      final player = _profileCtrl.currentPlayer;
      if (player == null) return;

      final result = await _usernameService.setUsername(
        playerId: player.id,
        newUsername: text,
        oldUsername: player.username,
      );

      switch (result) {
        case UsernameSetResult.success:
          _profileCtrl.refreshProfile();
          if (widget.isFirstTime) {
            Get.back();
          } else {
            Get.back();
            Get.snackbar(
              'تم ✅',
              '@$text تم حفظه بنجاح',
              snackPosition: SnackPosition.BOTTOM,
            );
          }
          break;
        case UsernameSetResult.taken:
          setState(() => _isAvailable = false);
          break;
        case UsernameSetResult.validationFailed:
        case UsernameSetResult.error:
          Get.snackbar(
            'خطأ',
            'فشل الحفظ، حاول مجدداً',
            snackPosition: SnackPosition.BOTTOM,
          );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.isFirstTime
          ? null
          : AppBar(title: const Text('تعديل Username')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppDimensions.xxl),

                // ── Header ──
                Text(
                  widget.isFirstTime
                      ? 'اختار اسمك في الحريف 🏷️'
                      : 'تعديل Username',
                  style: AppTextStyles.displaySmall,
                  textAlign: TextAlign.center,
                ).animate().fadeIn(),

                const SizedBox(height: AppDimensions.sm),

                Text(
                  'الـ Username هو هويتك الرقمية على المنصة\nيظهر في البروفايل والبحث وبطاقات الإنجاز',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 100.ms),

                const SizedBox(height: AppDimensions.xxl),

                // ── Input ──
                El7reefGlassSurface(
                  variant: El7reefGlassVariant.base,
                  padding: const EdgeInsets.all(AppDimensions.lg),
                  radius: AppDimensions.radiusLg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // حقل الإدخال
                      TextField(
                        controller: _controller,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.headlineMedium.copyWith(
                          letterSpacing: 1.5,
                        ),
                        decoration: InputDecoration(
                          hintText: 'harefa_7',
                          border: InputBorder.none,
                          prefixText: '@',
                          prefixStyle: AppTextStyles.headlineMedium.copyWith(
                            color: AppColors.primary,
                          ),
                          suffixIcon: _buildSuffixIcon(),
                        ),
                        onEditingComplete: _checkAvailability,
                      ),

                      const Divider(color: AppColors.surfaceBorder),
                      const SizedBox(height: AppDimensions.sm),

                      // رسالة التحقق
                      AnimatedSwitcher(
                        duration: 250.ms,
                        child: _buildValidationMessage(),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

                const SizedBox(height: AppDimensions.md),

                // ── قواعد ──
                _RulesCard().animate().fadeIn(delay: 300.ms),

                const SizedBox(height: AppDimensions.xxl),

                // ── زر الحفظ ──
                El7reefButton(
                  text: widget.isFirstTime ? 'ابدأ الرحلة 🚀' : 'حفظ',
                  icon: widget.isFirstTime
                      ? Icons.rocket_launch
                      : Icons.check_circle_outline,
                  isLoading: _saving,
                  onPressed: _canSave ? _save : null,
                ).animate().fadeIn(delay: 400.ms),

                if (widget.isFirstTime) ...[
                  const SizedBox(height: AppDimensions.md),
                  TextButton(
                    onPressed: () => Get.back(),
                    child: Text(
                      'تخطي الآن',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _canSave =>
      _localResult == UsernameValidationResult.valid &&
      (_isAvailable == true || _isAvailable == null) &&
      !_saving;

  Widget _buildSuffixIcon() {
    if (_checking) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      );
    }
    if (_isAvailable == true) {
      return const Icon(Icons.check_circle, color: AppColors.success);
    }
    if (_isAvailable == false) {
      return const Icon(Icons.cancel, color: AppColors.error);
    }
    if (_localResult == UsernameValidationResult.valid) {
      return IconButton(
        icon: const Icon(Icons.search, color: AppColors.primary),
        onPressed: _checkAvailability,
        tooltip: 'تحقق من التوفر',
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildValidationMessage() {
    if (_controller.text.trim().isEmpty) {
      return Text(
        '٣ إلى ٢٠ حرفاً — أحرف وأرقام و _ و .',
        key: const ValueKey('empty'),
        style: AppTextStyles.labelSmall,
        textAlign: TextAlign.center,
      );
    }
    if (_localResult == UsernameValidationResult.valid) {
      if (_isAvailable == true) {
        return Row(
          key: const ValueKey('available'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 16),
            const SizedBox(width: 6),
            Text(
              '@${_controller.text.trim()} متاح! ✅',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.success,
              ),
            ),
          ],
        );
      }
      if (_isAvailable == false) {
        return Row(
          key: const ValueKey('taken'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cancel, color: AppColors.error, size: 16),
            const SizedBox(width: 6),
            Text(
              'هذا الـ Username مأخوذ',
              style: AppTextStyles.labelMedium.copyWith(color: AppColors.error),
            ),
          ],
        );
      }
      return Text(
        'اضغط 🔍 للتحقق من التوفر',
        key: const ValueKey('check'),
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
        textAlign: TextAlign.center,
      );
    }
    return Row(
      key: const ValueKey('error'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.warning_rounded, color: AppColors.error, size: 16),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            _localResult?.message ?? '',
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _RulesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return El7reefGlassSurface(
      variant: El7reefGlassVariant.base,
      padding: const EdgeInsets.all(AppDimensions.md),
      radius: AppDimensions.radiusMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('القواعد:', style: AppTextStyles.labelMedium),
          const SizedBox(height: AppDimensions.xs),
          ...[
            '٣ إلى ٢٠ حرفاً فقط',
            'أحرف إنجليزية صغيرة، أرقام، _ أو .',
            'لا يبدأ أو ينتهي بـ _ أو .',
            'لا يمكن تكرار _ .. معاً',
            'يمكن التغيير مرة مجانية — ثم ٣٠ يوماً انتظار',
          ].map(
            (rule) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Text('• ', style: TextStyle(color: AppColors.primary)),
                  Expanded(child: Text(rule, style: AppTextStyles.bodySmall)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
