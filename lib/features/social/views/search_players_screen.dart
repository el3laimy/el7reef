import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/glassmorphic_container.dart';
import '../../../core/widgets/rank_tier_badge.dart';
import '../../../domain/entities/player.dart';
import '../controllers/search_players_controller.dart';
import '../controllers/friend_controller.dart';
import '../../match/widgets/send_challenge_sheet.dart';
import '../../match/controllers/challenge_controller.dart';

class SearchPlayersScreen extends GetView<SearchPlayersController> {
  const SearchPlayersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: () => Get.back(),
        ),
        title: Text('البحث عن أصدقاء', style: AppTextStyles.headlineMedium),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Column(
          children: [
            SizedBox(height: Get.mediaQuery.padding.top + kToolbarHeight + 20),
            
            // Search Input Area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePadding),
              child: _buildSearchBar(),
            ),
            
            const SizedBox(height: AppDimensions.md),
            
            // Results Area
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                
                if (controller.searchController.text.isEmpty) {
                  return _buildEmptyState(
                    'ابحث بالاسم أو المعرف',
                    'يمكنك البحث بكتابة @Username أو مسح الباركود الشخصي لصديقك.',
                    Icons.search,
                  );
                }
                
                if (controller.searchResults.isEmpty) {
                  return _buildEmptyState(
                    'لا يوجد نتائج',
                    'لم نتمكن من العثور على لاعبين يطابقون بحثك.',
                    Icons.person_off_outlined,
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePadding)
                      .copyWith(bottom: AppDimensions.xxl),
                  itemCount: controller.searchResults.length,
                  itemBuilder: (context, index) {
                    final player = controller.searchResults[index];
                    return _buildPlayerCard(player)
                        .animate()
                        .fadeIn(delay: Duration(milliseconds: 40 * index))
                        .slideY(begin: 0.1);
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: TextField(
              controller: controller.searchController,
              style: AppTextStyles.bodyLarge,
              decoration: InputDecoration(
                hintText: '@username أو الاسم...',
                hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                suffixIcon: Obx(() => controller.searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.textMuted),
                        onPressed: controller.clearSearch,
                      )
                    : const SizedBox()),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.sm),
        // QR Scanner Shortcut
        Container(
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 8,
                spreadRadius: 1,
              )
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: AppColors.background),
            onPressed: () {
               Get.toNamed(AppRoutes.qrScanner);
            },
          ),
        ).animate().scale(delay: 200.ms),
      ],
    );
  }

  Widget _buildPlayerCard(Player player) {
    // نستخدم FriendController للتأكد من إمكانية الإضافة (يمكن التحقق مستقبلا من حالة الصداقة)
    return GlassmorphicContainer(
      margin: const EdgeInsets.only(bottom: AppDimensions.md),
      padding: const EdgeInsets.all(AppDimensions.md),
      borderRadius: AppDimensions.radiusLg,
      child: Row(
        children: [
          // Avatar
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 2),
            ),
            child: ClipOval(
              child: player.photoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: player.photoUrl!,
                      fit: BoxFit.cover,
                      placeholder: (ctx, url) => Container(color: AppColors.surface),
                    )
                  : Container(
                      color: AppColors.primarySurface,
                      child: Center(
                        child: Text(
                          player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 20),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: AppDimensions.md),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: AppTextStyles.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (player.hasUsername) ...[
                  const SizedBox(height: 2),
                  Text(
                    player.displayUsername,
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    RankTierBadge(rating: player.rating, size: 14),
                    const SizedBox(width: 8),
                    Text('${player.rating} pt', style: AppTextStyles.labelSmall),
                  ],
                ),
              ],
            ),
          ),
          
          // Challenge Button
          IconButton(
            icon: const Icon(Icons.flash_on, color: AppColors.secondary),
            padding: const EdgeInsets.all(12),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.secondary.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
               if (Get.isRegistered<ChallengeController>()) {
                 final challengeCtrl = Get.find<ChallengeController>();
                 if (challengeCtrl.currentUserId == player.id) {
                   Get.snackbar('تنبيه', 'لا يمكنك إرسال تحدي لنفسك!');
                   return;
                 }
               }
               Get.bottomSheet(
                 SendChallengeSheet(
                   challengedId: player.id,
                   challengedName: player.name,
                 ),
                 isScrollControlled: true,
               );
            },
          ),
          const SizedBox(width: AppDimensions.sm),
          // Add Friend Button
          IconButton(
            icon: const Icon(Icons.person_add, color: AppColors.accent),
            padding: const EdgeInsets.all(12),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.accent.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
               if (Get.isRegistered<FriendController>()) {
                 Get.find<FriendController>().sendFriendRequest(player.id);
               } else {
                 Get.snackbar('خطأ', 'خدمة الأصدقاء غير متاحة حالياً');
               }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             Icon(icon, size: 80, color: AppColors.primary.withValues(alpha: 0.3)),
            const SizedBox(height: AppDimensions.lg),
            Text(title, style: AppTextStyles.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppDimensions.sm),
            Text(
              subtitle,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.9, 0.9)),
      ),
    );
  }
}
