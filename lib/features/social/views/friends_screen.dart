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
import '../controllers/friend_controller.dart';

class FriendsScreen extends GetView<FriendController> {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'الأصدقاء',
            style: AppTextStyles.headlineMedium,
          ).animate().fadeIn().slideY(begin: -0.2),
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: AppColors.textPrimary,
            ),
            onPressed: () => Get.back(),
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.person_add_alt_1,
                color: AppColors.primary,
              ),
              onPressed: () => Get.toNamed(AppRoutes.searchPlayers),
            ),
          ],
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            labelStyle: AppTextStyles.titleMedium,
            tabs: const [
              Tab(text: 'أصدقائي'),
              Tab(text: 'الطلبات'),
            ],
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: Obx(() {
            if (controller.isLoading.value) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            return TabBarView(
              children: [_buildFriendsList(), _buildRequestsList()],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildFriendsList() {
    final friends = controller.friends;

    if (friends.isEmpty) {
      return _buildEmptyState(
        'لا يوجد أصدقاء بعد',
        'ابحث عن أصدقائك أو استخدم الباركود لإضافتهم',
        Icons.people_outline,
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(
        top: Get.mediaQuery.padding.top + 100,
        bottom: AppDimensions.xxl,
        left: AppDimensions.pagePadding,
        right: AppDimensions.pagePadding,
      ),
      itemCount: friends.length,
      itemBuilder: (context, index) {
        final friendship = friends[index];
        final otherUserId = friendship.getOtherUserId(
          controller.currentUserId!,
        );
        final profile = controller.friendProfiles[otherUserId];

        return _buildFriendCard(profile, isRequest: false)
            .animate()
            .fadeIn(delay: Duration(milliseconds: 50 * index))
            .slideX(begin: 0.1);
      },
    );
  }

  Widget _buildRequestsList() {
    final requests = controller.pendingRequests;

    if (requests.isEmpty) {
      return _buildEmptyState(
        'لا توجد طلبات',
        'لم يرسل لك أحد طلب صداقة مؤخراً',
        Icons.notifications_none,
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(
        top: Get.mediaQuery.padding.top + 100,
        bottom: AppDimensions.xxl,
        left: AppDimensions.pagePadding,
        right: AppDimensions.pagePadding,
      ),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final friendship = requests[index];
        final otherUserId = friendship.getOtherUserId(
          controller.currentUserId!,
        );
        final profile = controller.friendProfiles[otherUserId];

        return _buildFriendCard(profile, isRequest: true)
            .animate()
            .fadeIn(delay: Duration(milliseconds: 50 * index))
            .slideX(begin: 0.1);
      },
    );
  }

  Widget _buildFriendCard(Player? player, {required bool isRequest}) {
    if (player == null) {
      return GlassmorphicContainer(
        margin: const EdgeInsets.only(bottom: AppDimensions.md),
        padding: const EdgeInsets.all(AppDimensions.md),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return GlassmorphicContainer(
      margin: const EdgeInsets.only(bottom: AppDimensions.md),
      padding: const EdgeInsets.all(AppDimensions.md),
      borderRadius: AppDimensions.radiusLg,
      child: Row(
        children: [
          // Avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: player.photoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: player.photoUrl!,
                      fit: BoxFit.cover,
                      placeholder: (ctx, url) =>
                          Container(color: AppColors.surface),
                    )
                  : Container(
                      color: AppColors.primarySurface,
                      child: Center(
                        child: Text(
                          player.name.isNotEmpty
                              ? player.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
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
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    RankTierBadge(rating: player.rating, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      '${player.rating} pt',
                      style: AppTextStyles.labelSmall,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Actions
          if (isRequest) ...[
            // Accept Button
            IconButton(
              icon: const Icon(Icons.check_circle, color: AppColors.success),
              onPressed: () => controller.acceptRequest(player.id),
            ),
            // Reject Button
            IconButton(
              icon: const Icon(Icons.cancel, color: AppColors.error),
              onPressed: () => controller.removeFriendship(player.id),
            ),
          ] else ...[
            // Remove/Options Button
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
              color: AppColors.surface,
              onSelected: (value) {
                if (value == 'remove') {
                  controller.removeFriendship(player.id);
                } else if (value == 'block') {
                  controller.blockUser(player.id);
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'remove',
                  child: ListTile(
                    leading: Icon(Icons.person_remove, color: AppColors.error),
                    title: Text(
                      'إزالة الصداقة',
                      style: TextStyle(color: AppColors.error),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'block',
                  child: ListTile(
                    leading: Icon(Icons.block, color: AppColors.error),
                    title: Text(
                      'حظر',
                      style: TextStyle(color: AppColors.error),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.xl),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 60,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: AppDimensions.lg),
          Text(title, style: AppTextStyles.headlineMedium),
          const SizedBox(height: AppDimensions.sm),
          Text(
            subtitle,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.8, 0.8)),
    );
  }
}
