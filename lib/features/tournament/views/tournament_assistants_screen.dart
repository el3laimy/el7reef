import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/el7reef_glass_surface.dart';
import '../../../domain/entities/tournament_assistant_permission.dart';
import '../controllers/tournament_assistants_controller.dart';

class TournamentAssistantsScreen
    extends GetView<TournamentAssistantsController> {
  const TournamentAssistantsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'إدارة مساعدي البطولة',
          style: AppTextStyles.headlineMedium,
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Obx(() {
          if (controller.isLoading.value &&
              controller.currentTournament.value == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final tournament = controller.currentTournament.value;
          final assistants = controller.assistants
              .where((assistant) => assistant.isActive)
              .toList(growable: false);
          if (tournament == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 64,
                    ),
                    const SizedBox(height: AppDimensions.md),
                    Text(
                      controller.errorMessage.value.isEmpty
                          ? 'عفواً، لم يتم العثور على الدورة'
                          : controller.errorMessage.value,
                      style: AppTextStyles.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              SizedBox(
                height: Get.mediaQuery.padding.top + kToolbarHeight + 20,
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.pagePadding,
                ),
                child: Text(
                  'أضف مساعدين لتسهيل إدارة "${tournament.name}". يمكنك منحهم صلاحيات مختلفة بحدود معينة حسب الثقة.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(),
              ),

              const SizedBox(height: AppDimensions.lg),

              Expanded(
                child: assistants.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.pagePadding,
                        ),
                        itemCount: assistants.length,
                        itemBuilder: (context, index) {
                          final assistant = assistants[index];
                          return _buildAssistantCard(assistant, controller)
                              .animate()
                              .fadeIn(delay: (40 * index).ms)
                              .slideY(begin: 0.1);
                        },
                      ),
              ),
            ],
          );
        }),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // يمكن فتح دايالوج بسيط هنا لإضافة مساعدين للتبسيط كـ Mockup
          _showAddAssistantBottomSheet(context, controller);
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add, color: AppColors.background),
        label: Text(
          'إضافة مساعد',
          style: AppTextStyles.buttonText.copyWith(color: AppColors.background),
        ),
      ).animate().scale(delay: 400.ms),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shield_outlined,
            size: 80,
            color: AppColors.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppDimensions.lg),
          Text('لا يوجد مساعدين بعد', style: AppTextStyles.headlineMedium),
          const SizedBox(height: AppDimensions.sm),
          Text(
            'قم بتعيين مساعدين لمساعدتك في إدخال النتائج\nوإدارة الفرق وتنظيم المسابقة.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 100), // padding for FAB
        ],
      ).animate().fadeIn(duration: 600.ms),
    );
  }

  Widget _buildAssistantCard(
    TournamentAssistantPermission assistant,
    TournamentAssistantsController controller,
  ) {
    String roleName = 'مساعد';
    Color roleColor = AppColors.primary;

    switch (assistant.preset) {
      case TournamentAssistantPermissionPreset.matchdayAssistant:
        roleName = 'إدارة يوم المباراة';
        roleColor = AppColors.primary;
        break;
      case TournamentAssistantPermissionPreset.resultsAssistant:
        roleName = 'إدخال نتائج';
        roleColor = AppColors.success;
        break;
      case TournamentAssistantPermissionPreset.scoreApprover:
        roleName = 'اعتماد النتائج';
        roleColor = AppColors.error;
        break;
      case TournamentAssistantPermissionPreset.customLimited:
        roleName = 'مشاهدة محدودة';
        roleColor = AppColors.textMuted;
        break;
    }

    return El7reefGlassSurface(
      variant: El7reefGlassVariant.base,
      margin: const EdgeInsets.only(bottom: AppDimensions.md),
      padding: const EdgeInsets.all(AppDimensions.md),
      radius: AppDimensions.radiusLg,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.security, color: roleColor),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User: ${_shortUserId(assistant.userId)}',
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      roleName,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: roleColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: () {
              controller.removeAssistant(assistant.userId);
            },
          ),
        ],
      ),
    );
  }

  void _showAddAssistantBottomSheet(
    BuildContext context,
    TournamentAssistantsController controller,
  ) {
    final TextEditingController idController = TextEditingController();
    TournamentAssistantPermissionPreset selectedPreset =
        TournamentAssistantPermissionPreset.resultsAssistant;

    Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setModalState) {
          return El7reefGlassSurface(
            variant: El7reefGlassVariant.sheet,
            padding: const EdgeInsets.all(AppDimensions.xl),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDimensions.radiusXl),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('إضافة مساعد جديد', style: AppTextStyles.headlineMedium),
                const SizedBox(height: AppDimensions.lg),
                TextField(
                  controller: idController,
                  decoration: InputDecoration(
                    labelText: 'User ID',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusMd,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.lg),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: DropdownButton<TournamentAssistantPermissionPreset>(
                    value: selectedPreset,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                        value: TournamentAssistantPermissionPreset
                            .resultsAssistant,
                        child: Text('إدخال النتائج والأهداف'),
                      ),
                      DropdownMenuItem(
                        value: TournamentAssistantPermissionPreset
                            .matchdayAssistant,
                        child: Text('إدارة يوم المباراة'),
                      ),
                      DropdownMenuItem(
                        value:
                            TournamentAssistantPermissionPreset.scoreApprover,
                        child: Text('اعتماد النتائج فقط'),
                      ),
                      DropdownMenuItem(
                        value:
                            TournamentAssistantPermissionPreset.customLimited,
                        child: Text('مشاهدة يوم المباراة فقط'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedPreset = val);
                      }
                    },
                  ),
                ),
                const SizedBox(height: AppDimensions.xl),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMd,
                        ),
                      ),
                    ),
                    onPressed: () {
                      if (idController.text.isNotEmpty) {
                        controller.addAssistant(
                          idController.text.trim(),
                          selectedPreset,
                        );
                      }
                    },
                    child: Text(
                      'منح الصلاحية',
                      style: AppTextStyles.buttonText.copyWith(
                        color: AppColors.background,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: MediaQuery.of(context).viewInsets.bottom,
                ), // Prevent keyboard overlap
              ],
            ),
          );
        },
      ),
      isScrollControlled: true,
    );
  }

  String _shortUserId(String userId) {
    if (userId.length <= 8) return userId;
    return '${userId.substring(0, 5)}...${userId.substring(userId.length - 3)}';
  }
}
