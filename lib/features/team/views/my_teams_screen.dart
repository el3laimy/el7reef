import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/el7reef_button.dart';
import '../../../core/widgets/section_state_card.dart';
import '../../../domain/entities/team.dart';
import '../../../core/auth/auth_service.dart';
import '../controllers/team_controller.dart';

/// شاشة فرقي — عرض الفرق + إنشاء فريق جديد
class MyTeamsScreen extends GetView<TeamController> {
  const MyTeamsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('فرقي')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Obx(() {
          if (controller.isLoading.value && controller.myTeams.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (controller.errorMessage.value.isNotEmpty &&
              controller.myTeams.isEmpty) {
            return _buildErrorState();
          }

          if (controller.myTeams.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppDimensions.pagePadding),
            itemCount: controller.myTeams.length,
            itemBuilder: (context, index) {
              final team = controller.myTeams[index];
              return _buildTeamCard(team, index);
            },
          );
        }),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _showCreateTeamSheet(context),
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add, color: AppColors.textOnPrimary),
          label: Text(
            'فريق جديد',
            style: AppTextStyles.buttonText.copyWith(
              color: AppColors.textOnPrimary,
            ),
          ),
        ),
      ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.5),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.pagePadding),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.groups_2_rounded,
                size: 64,
                color: AppColors.primary.withValues(alpha: 0.72),
              ),
              const SizedBox(height: AppDimensions.md),
              Text('كوّن فريقك الأول', style: AppTextStyles.headlineMedium),
              const SizedBox(height: AppDimensions.sm),
              Text(
                'ابدأ بفريق حقيقي، وبعدها دخّله بطولة أو تحدي مع فرق الحارة.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(height: 1.5),
              ),
              const SizedBox(height: AppDimensions.lg),
              El7reefButton(
                text: 'إنشاء فريق الآن',
                icon: Icons.group_add_rounded,
                onPressed: () => _showCreateTeamSheet(context),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 500.ms),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.pagePadding),
        child: SectionStateCard.error(
          title: 'تعذر تحميل الفرق',
          message: controller.errorMessage.value,
          onAction: controller.loadMyTeams,
        ),
      ),
    );
  }

  Widget _buildTeamCard(Team team, int index) {
    final uid = Get.find<AuthService>().currentUserId ?? '';

    // تحديد دور اللاعب
    String roleLabel = 'لاعب';
    Color roleColor = AppColors.textMuted;
    IconData roleIcon = Icons.person;

    if (team.ownerId == uid) {
      roleLabel = 'مالك الفريق';
      roleColor = AppColors.primary;
      roleIcon = Icons.stars;
    } else if (team.viceCaptainIds.contains(uid)) {
      roleLabel = 'نائب القائد';
      roleColor = AppColors.secondary;
      roleIcon = Icons.shield;
    }

    return GestureDetector(
          onTap: () => Get.toNamed(AppRoutes.teamProfileById(team.id)),
          child: Container(
            margin: const EdgeInsets.only(bottom: AppDimensions.md),
            padding: const EdgeInsets.all(AppDimensions.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Row(
              children: [
                // شعار الفريق
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.primaryGradient,
                  ),
                  child: Center(
                    child: Text(
                      team.name.isNotEmpty ? team.name[0] : '?',
                      style: AppTextStyles.headlineLarge.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.md),
                // معلومات الفريق
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        team.name,
                        style: AppTextStyles.headlineMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Badge for Role
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: roleColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(roleIcon, size: 12, color: roleColor),
                            const SizedBox(width: 4),
                            Text(
                              roleLabel,
                              style: AppTextStyles.labelSmall.copyWith(
                                color: roleColor,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${team.playerCount} لاعب • ${team.totalMatches} مباراة',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                // الرتبة
                Column(
                  children: [
                    Text(
                      '${team.avgRating.toInt()}',
                      style: AppTextStyles.ratingMedium.copyWith(fontSize: 20),
                    ),
                    Text('متوسط', style: AppTextStyles.labelSmall),
                    const SizedBox(height: 4),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ],
            ),
          ),
        )
        .animate(delay: (100 * index).ms)
        .fadeIn(duration: 400.ms)
        .slideX(begin: 0.1);
  }

  void _showCreateTeamSheet(BuildContext context) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(AppDimensions.lg),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusXl),
          ),
        ),
        child: Form(
          key: controller.formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // الخط العلوي
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.lg),
              Text('إنشاء فريق جديد 🏆', style: AppTextStyles.headlineMedium),
              const SizedBox(height: AppDimensions.lg),
              TextFormField(
                controller: controller.teamNameController,
                validator: controller.validateTeamName,
                decoration: const InputDecoration(
                  labelText: 'اسم الفريق',
                  hintText: 'مثال: نجوم الشارع',
                  prefixIcon: Icon(Icons.group, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: AppDimensions.lg),
              Obx(
                () => El7reefButton(
                  text: 'إنشاء الفريق',
                  icon: Icons.check_circle,
                  isLoading: controller.isLoading.value,
                  onPressed: controller.createTeam,
                ),
              ),
              SizedBox(
                height:
                    MediaQuery.of(context).padding.bottom + AppDimensions.md,
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }
}

class CreateTeamIntentScreen extends StatefulWidget {
  const CreateTeamIntentScreen({super.key});

  @override
  State<CreateTeamIntentScreen> createState() => _CreateTeamIntentScreenState();
}

class _CreateTeamIntentScreenState extends State<CreateTeamIntentScreen> {
  bool _opened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) return;
    _opened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = Get.find<TeamController>();
      Get.bottomSheet(
        _CreateTeamIntentSheet(controller: controller),
        isScrollControlled: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) => const MyTeamsScreen();
}

class _CreateTeamIntentSheet extends StatelessWidget {
  final TeamController controller;

  const _CreateTeamIntentSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      child: Form(
        key: controller.formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            Text('إنشاء فريق جديد 🏆', style: AppTextStyles.headlineMedium),
            const SizedBox(height: AppDimensions.lg),
            TextFormField(
              controller: controller.teamNameController,
              validator: controller.validateTeamName,
              decoration: const InputDecoration(
                labelText: 'اسم الفريق',
                hintText: 'مثال: نجوم الشارع',
                prefixIcon: Icon(Icons.group, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            Obx(
              () => El7reefButton(
                text: 'إنشاء الفريق',
                icon: Icons.check_circle,
                isLoading: controller.isLoading.value,
                onPressed: controller.createTeam,
              ),
            ),
            SizedBox(
              height: MediaQuery.of(context).padding.bottom + AppDimensions.md,
            ),
          ],
        ),
      ),
    );
  }
}
