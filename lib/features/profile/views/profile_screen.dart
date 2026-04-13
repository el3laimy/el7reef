import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/photo_upload_service.dart';
import '../../../core/widgets/dynamic_frame_widget.dart';
import '../../../core/widgets/glassmorphic_container.dart';
import '../../../core/widgets/qr_code_widget.dart';
import '../../../core/widgets/rank_tier_badge.dart';
import '../../../domain/entities/player.dart';
import '../../../data/repositories/player_repository_impl.dart';
import '../controllers/profile_controller.dart';

/// شاشة البروفايل — Task 6.3.4 + 6.2.5
/// Hero Card (DynamicFrame + Photo) + Username + QR + Stats + Position
class ProfileScreen extends GetView<ProfileController> {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Obx(() {
          final player = controller.player.value;
          if (player == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          return CustomScrollView(
            slivers: [
              // ── Hero Header ──
              SliverToBoxAdapter(
                child: _buildHeroCard(player, context),
              ),

              // ── Quick Actions ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.pagePadding,
                  ),
                  child: _buildQuickActions(player, context),
                ),
              ),

              // ── Stats Grid ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.pagePadding,
                  ).copyWith(top: AppDimensions.md),
                  child: _buildStatsGrid(player),
                ),
              ),

              // ── المركز ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.pagePadding),
                  child: _buildPositionSection(),
                ),
              ),

              // ── معلومات إضافية ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.pagePadding,
                  ),
                  child: _buildInfoSection(player),
                ),
              ),

              // ── زر الخروج ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.pagePadding),
                  child: _buildSignOutButton(),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: AppDimensions.xxl),
              ),
            ],
          );
        }),
      ),
    );
  }

  /// ── Hero Card مع DynamicFrame + Photo Upload ──
  Widget _buildHeroCard(Player player, BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + AppDimensions.md,
        bottom: AppDimensions.lg,
        left: AppDimensions.pagePadding,
        right: AppDimensions.pagePadding,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primaryDark.withValues(alpha: 0.3),
            AppColors.background,
          ],
        ),
      ),
      child: Column(
        children: [
          // ── Top bar: Settings + QR ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: AppColors.textMuted, size: 20),
                onPressed: () => Get.back(),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined,
                    color: AppColors.textMuted),
                onPressed: () {},
              ),
            ],
          ),

          // ── الصورة مع DynamicFrame ──
          GestureDetector(
            onTap: () => _showPhotoOptions(context),
            child: Stack(
              alignment: Alignment.center,
              children: [
                DynamicFrameWidget(
                  rating: player.rating,
                  mvpCount: player.mvpCount,
                  size: AppDimensions.avatarHero,
                  child: player.photoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: player.photoUrl!,
                          fit: BoxFit.cover,
                          placeholder: (ctx, url) => _avatarPlaceholder(player),
                          errorWidget: (ctx, url, err) =>
                              _avatarPlaceholder(player),
                        )
                      : _avatarPlaceholder(player),
                ),
                // أيقونة الكاميرا
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.background, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt,
                        color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),

          const SizedBox(height: AppDimensions.sm),

          // ── Frame Progress ──
          FrameProgressWidget(
            rating: player.rating,
            mvpCount: player.mvpCount,
          ).animate().fadeIn(delay: 150.ms),

          const SizedBox(height: AppDimensions.md),

          // ── الاسم ──
          Text(
            player.name,
            style: AppTextStyles.headlineLarge,
          ).animate().fadeIn(delay: 200.ms),

          // ── Username ──
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => Get.toNamed(AppRoutes.username),
            child: player.hasUsername
                ? Text(
                    player.displayUsername,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(
                          AppDimensions.radiusFull),
                    ),
                    child: Text(
                      '+ اختار Username',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
          ).animate().fadeIn(delay: 250.ms),

          const SizedBox(height: AppDimensions.sm),

          // ── الرتبة ──
          RankTierBadge(rating: player.rating, size: 28)
              .animate()
              .fadeIn(delay: 300.ms),

          const SizedBox(height: AppDimensions.md),

          // ── Rating الكبير ──
          GlassmorphicContainer(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.xl,
              vertical: AppDimensions.md,
            ),
            borderRadius: AppDimensions.radiusXl,
            child: Column(
              children: [
                Text(
                  '${player.rating}',
                  style: AppTextStyles.ratingLarge,
                ),
                Text(
                  'نقاط التقييم',
                  style: AppTextStyles.labelMedium,
                ),
              ],
            ),
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
        ],
      ),
    );
  }

  /// ── Avatar Placeholder ──
  Widget _avatarPlaceholder(Player player) {
    final initial =
        player.name.isNotEmpty ? player.name[0].toUpperCase() : '?';
    return Container(
      color: AppColors.primarySurface,
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  /// ── Quick Actions (QR + Friends + Teams) — Task 6.2.5 ──
  Widget _buildQuickActions(Player player, BuildContext context) {
    return Row(
      children: [
        _actionButton(
          icon: Icons.qr_code_2,
          label: 'الباركود',
          color: AppColors.accent,
          onTap: () {
            QrCodeDialog.show(
              context,
              qrData: player.qrCode ?? '7reef://player/${player.id}',
              playerName: player.name,
              username: player.username,
            );
          },
        ),
        const SizedBox(width: AppDimensions.sm),
        _actionButton(
          icon: Icons.qr_code_scanner,
          label: 'مسح QR',
          color: AppColors.primary,
          onTap: () => Get.toNamed(AppRoutes.qrScanner),
        ),
        const SizedBox(width: AppDimensions.sm),
        _actionButton(
          icon: Icons.people_outline,
          label: 'أصدقاء',
          color: AppColors.secondary,
          badge: player.friendIds.length,
          onTap: () {
            // سيُفتح لاحقاً (Phase 6.4)
            Get.snackbar('قريباً', 'الأصدقاء — قيد التطوير 🔧',
                snackPosition: SnackPosition.BOTTOM);
          },
        ),
        const SizedBox(width: AppDimensions.sm),
        _actionButton(
          icon: Icons.share_outlined,
          label: 'مشاركة',
          color: AppColors.success,
          onTap: () {
            // Share profile link
          },
        ),
      ],
    ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.1);
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    int badge = 0,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: GlassmorphicContainer(
          padding: const EdgeInsets.symmetric(vertical: 12),
          borderRadius: AppDimensions.radiusMd,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, color: color, size: 24),
                  if (badge > 0)
                    Positioned(
                      top: -6,
                      right: -10,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$badge',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(label, style: AppTextStyles.labelSmall),
            ],
          ),
        ),
      ),
    );
  }

  /// ── Photo Upload ──
  void _showPhotoOptions(BuildContext context) async {
    final service = PhotoUploadService();
    final file = await PhotoUploadService.showPickerDialog(context, service);
    if (file == null) return;

    final player = controller.currentPlayer;
    if (player == null) return;

    Get.snackbar('جارٍ الرفع...', 'يتم رفع صورتك الشخصية',
        snackPosition: SnackPosition.BOTTOM,
        showProgressIndicator: true);

    final result = await service.uploadProfilePhoto(
      userId: player.id,
      imageFile: file,
    );

    if (result != null) {
      final repo = PlayerRepositoryImpl();
      final updated = player.copyWith(
        photoUrl: result.fullUrl,
        photoThumbUrl: result.thumbUrl,
      );
      await repo.updatePlayer(updated);
      await controller.refreshProfile();

      Get.snackbar('تم ✅', 'تم تحديث صورتك الشخصية',
          snackPosition: SnackPosition.BOTTOM);
    } else {
      Get.snackbar('خطأ', 'فشل رفع الصورة، حاول مجدداً',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  /// ── Stats Grid ──
  Widget _buildStatsGrid(Player player) {
    return GlassmorphicContainer(
      padding: const EdgeInsets.all(AppDimensions.md),
      borderRadius: AppDimensions.radiusLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الإحصائيات', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppDimensions.md),
          Row(
            children: [
              _statItem('المباريات', '${player.totalMatches}', Icons.sports_soccer, AppColors.accent),
              _statItem('الفوز', '${player.wins}', Icons.emoji_events, AppColors.success),
              _statItem('التعادل', '${player.draws}', Icons.handshake, AppColors.secondary),
              _statItem('الخسارة', '${player.losses}', Icons.trending_down, AppColors.error),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          Row(
            children: [
              _statItem('MVP', '${player.mvpCount}', Icons.star, AppColors.secondary),
              _statItem(
                'نسبة الفوز',
                '${player.winRate.toStringAsFixed(0)}%',
                Icons.percent,
                AppColors.primaryLight,
              ),
              _statItem(
                'مستوى الثقة',
                player.trustLevel.name == 'veteran'
                    ? 'مخضرم'
                    : player.trustLevel.name == 'active'
                        ? 'نشط'
                        : 'جديد',
                Icons.verified,
                player.trustLevel.name == 'veteran'
                    ? AppColors.secondary
                    : AppColors.textMuted,
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms, duration: 500.ms).slideY(begin: 0.1);
  }

  Widget _statItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.titleLarge.copyWith(color: color),
          ),
          Text(label, style: AppTextStyles.labelSmall),
        ],
      ),
    );
  }

  /// ── اختيار المركز ──
  Widget _buildPositionSection() {
    return GlassmorphicContainer(
      padding: const EdgeInsets.all(AppDimensions.md),
      borderRadius: AppDimensions.radiusLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('المركز الأساسي', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppDimensions.sm),
          Obx(() => Wrap(
                spacing: AppDimensions.sm,
                runSpacing: AppDimensions.sm,
                children: controller.positions.map((pos) {
                  final isSelected = controller.selectedPosition.value == pos;
                  return GestureDetector(
                    onTap: () => controller.updatePosition(pos),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.md,
                        vertical: AppDimensions.sm,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primarySurface
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        controller.positionLabels[pos] ?? pos,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              )),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms, duration: 500.ms).slideY(begin: 0.1);
  }

  /// ── معلومات إضافية ──
  Widget _buildInfoSection(Player player) {
    return GlassmorphicContainer(
      padding: const EdgeInsets.all(AppDimensions.md),
      borderRadius: AppDimensions.radiusLg,
      child: Column(
        children: [
          _infoRow(Icons.calendar_today, 'تاريخ الانضمام',
              _formatDate(player.createdAt)),
          const Divider(color: AppColors.surfaceBorder, height: 24),
          _infoRow(Icons.access_time, 'آخر نشاط',
              _formatDate(player.lastActiveAt)),
          const Divider(color: AppColors.surfaceBorder, height: 24),
          _infoRow(Icons.group, 'الفرق',
              '${player.teamIds.length} فريق'),
          const Divider(color: AppColors.surfaceBorder, height: 24),
          _infoRow(Icons.people, 'الأصدقاء',
              '${player.friendIds.length} صديق'),
          const Divider(color: AppColors.surfaceBorder, height: 24),
          _infoRow(Icons.military_tech, 'الإنجازات',
              '${player.achievementIds.length} إنجاز'),
        ],
      ),
    ).animate().fadeIn(delay: 700.ms, duration: 500.ms).slideY(begin: 0.1);
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textMuted, size: 20),
        const SizedBox(width: 12),
        Text(label, style: AppTextStyles.bodyMedium),
        const Spacer(),
        Text(value, style: AppTextStyles.titleMedium),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// ── زر الخروج ──
  Widget _buildSignOutButton() {
    return TextButton.icon(
      onPressed: controller.signOut,
      icon: const Icon(Icons.logout, color: AppColors.error, size: 20),
      label: Text(
        'تسجيل الخروج',
        style: AppTextStyles.labelLarge.copyWith(color: AppColors.error),
      ),
    ).animate().fadeIn(delay: 800.ms);
  }
}
