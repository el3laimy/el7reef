import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/widgets/el7reef_brand_mark.dart';
import '../../../core/widgets/el7reef_button.dart';
import '../controllers/match_controller.dart';
import '../controllers/challenge_controller.dart';
import '../widgets/challenge_card.dart';
import '../widgets/create_match_sheet.dart';
import '../widgets/match_card.dart';

class MatchDiscoverScreen extends GetView<MatchController> {
  const MatchDiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final challengesEnabled = FeatureFlags.challengesUiEnabled;

    return DefaultTabController(
      length: challengesEnabled ? 3 : 2,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const El7reefBrandMark(size: 28),
              const SizedBox(width: AppDimensions.sm),
              const Text('المباريات'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
              onPressed: () {
                controller.loadLiveMatches();
                controller.loadMyMatches();
              },
            ),
          ],
          bottom: TabBar(
            tabs: [
              const Tab(text: 'مبارياتي'),
              const Tab(text: 'اكتشاف'),
              if (challengesEnabled) const Tab(text: 'التحديات'),
            ],
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: TabBarView(
            children: [
              const _MyMatchesTab(),
              const _DiscoverTab(),
              if (challengesEnabled) const _ChallengesTab(),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyMatchesTab extends GetView<MatchController> {
  const _MyMatchesTab();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value && controller.myMatches.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      }

      if (controller.myMatches.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.sports_soccer,
                size: 64,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: AppDimensions.md),
              Text('ليس لديك أي مباريات قادمة', style: AppTextStyles.bodyLarge),
              const SizedBox(height: AppDimensions.lg),
              El7reefButton(
                text: 'أنشئ مباراة جديدة',
                onPressed: showCreateMatchSheetGlobal,
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: controller.loadMyMatches,
        color: AppColors.primary,
        child: ListView.builder(
          padding: const EdgeInsets.all(AppDimensions.pagePadding),
          itemCount: controller.myMatches.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.md),
              child: MatchCard(
                match: controller.myMatches[index],
                index: index,
                controller: controller,
              ),
            );
          },
        ),
      );
    });
  }
}

class _DiscoverTab extends GetView<MatchController> {
  const _DiscoverTab();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value && controller.liveMatches.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      }

      return RefreshIndicator(
        onRefresh: controller.loadLiveMatches,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.pagePadding),
                child: El7reefButton(
                  text: 'ابدأ مباراة جديدة',
                  icon: Icons.sports_soccer,
                  onPressed: showCreateMatchSheetGlobal,
                ).animate().fadeIn(duration: 400.ms),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.pagePadding,
                ),
                child: Row(
                  children: [
                    Text('المباريات الجارية', style: AppTextStyles.titleLarge),
                    const Spacer(),
                    Text(
                      '${controller.liveMatches.length} مباراة',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppDimensions.md)),
            if (controller.liveMatches.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.pagePadding),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.sports_soccer_rounded,
                            size: 64,
                            color: AppColors.primary.withValues(alpha: 0.72),
                          ),
                          const SizedBox(height: AppDimensions.md),
                          Text(
                            'لا توجد مباريات جارية حالياً',
                            style: AppTextStyles.headlineMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppDimensions.sm),
                          Text(
                            'افتح ماتش جديد، اجمع اللاعبين، وسجّل النتيجة عشان تتحول لكارت فخر يتشارك.',
                            style: AppTextStyles.bodyMedium.copyWith(
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppDimensions.lg),
                          El7reefButton(
                            text: 'أنشئ مباراة مفتوحة',
                            icon: Icons.add_circle_outline_rounded,
                            onPressed: showCreateMatchSheetGlobal,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final match = controller.liveMatches[index];
                  return Padding(
                    padding: const EdgeInsets.only(
                      left: AppDimensions.pagePadding,
                      right: AppDimensions.pagePadding,
                      bottom: AppDimensions.md,
                    ),
                    child: MatchCard(
                      match: match,
                      index: index,
                      controller: controller,
                    ).animate().fadeIn(delay: (100 * index).ms),
                  );
                }, childCount: controller.liveMatches.length),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      );
    });
  }
}

class _ChallengesTab extends GetView<ChallengeController> {
  const _ChallengesTab();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value &&
          controller.sentChallenges.isEmpty &&
          controller.receivedChallenges.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      }

      return RefreshIndicator(
        onRefresh: controller.loadChallenges,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            if (controller.receivedChallenges.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.pagePadding),
                  child: Text('تحديات واردة', style: AppTextStyles.titleLarge),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final challenge = controller.receivedChallenges[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.pagePadding,
                      vertical: AppDimensions.xs,
                    ),
                    child: ChallengeCard(
                      challenge: challenge,
                      isSentByMe: false,
                      otherPartyName: controller.getPlayerName(
                        challenge.challengerId,
                      ),
                      onAccept: () => controller.acceptChallenge(challenge),
                      onDecline: () =>
                          controller.declineChallenge(challenge.id),
                    ),
                  );
                }, childCount: controller.receivedChallenges.length),
              ),
            ],

            if (controller.sentChallenges.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.pagePadding),
                  child: Text(
                    'تحديات أرسلتها',
                    style: AppTextStyles.titleLarge,
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final challenge = controller.sentChallenges[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.pagePadding,
                      vertical: AppDimensions.xs,
                    ),
                    child: ChallengeCard(
                      challenge: challenge,
                      isSentByMe: true,
                      otherPartyName: controller.getPlayerName(
                        challenge.challengedId,
                      ),
                      onCancel: () => controller.cancelChallenge(challenge.id),
                    ),
                  );
                }, childCount: controller.sentChallenges.length),
              ),
            ],

            if (controller.receivedChallenges.isEmpty &&
                controller.sentChallenges.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'لا توجد تحديات حالياً',
                    style: AppTextStyles.bodyLarge,
                  ),
                ),
              )
            else
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      );
    });
  }
}
