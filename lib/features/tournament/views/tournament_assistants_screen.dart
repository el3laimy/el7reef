import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/glassmorphic_container.dart';
import '../../../core/enums/tournament_enums.dart';
import '../../../domain/entities/tournament_assistant.dart';
import '../controllers/tournament_assistants_controller.dart';

class TournamentAssistantsScreen extends StatelessWidget {
  const TournamentAssistantsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Ensuring the controller is registered with the injected tournament ID
    final controller = Get.put(TournamentAssistantsController());

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('إدارة مساعدي البطولة', style: AppTextStyles.headlineMedium),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: () => Get.back(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Obx(() {
          if (controller.isLoading.value && controller.currentTournament.value == null) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          final tournament = controller.currentTournament.value;
          if (tournament == null) {
            return Center(child: Text('عفواً، لم يتم العثور على الدورة', style: AppTextStyles.titleMedium));
          }

          return Column(
            children: [
              SizedBox(height: Get.mediaQuery.padding.top + kToolbarHeight + 20),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePadding),
                child: Text(
                  'أضف مساعدين لتسهيل إدارة "${tournament.name}". يمكنك منحهم صلاحيات مختلفة بحدود معينة حسب الثقة.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(),
              ),
              
              const SizedBox(height: AppDimensions.lg),

              Expanded(
                child: tournament.assistants.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePadding),
                        itemCount: tournament.assistants.length,
                        itemBuilder: (context, index) {
                          final assistant = tournament.assistants[index];
                          return _buildAssistantCard(assistant, controller)
                            .animate().fadeIn(delay: (40 * index).ms).slideY(begin: 0.1);
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
        label: Text('إضافة مساعد', style: AppTextStyles.buttonText.copyWith(color: AppColors.background)),
      ).animate().scale(delay: 400.ms),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, size: 80, color: AppColors.primary.withValues(alpha: 0.3)),
          const SizedBox(height: AppDimensions.lg),
          Text('لا يوجد مساعدين بعد', style: AppTextStyles.headlineMedium),
          const SizedBox(height: AppDimensions.sm),
          Text(
            'قم بتعيين مساعدين لمساعدتك في إدخال النتائج\nوإدارة الفرق وتنظيم المسابقة.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 100), // padding for FAB
        ],
      ).animate().fadeIn(duration: 600.ms),
    );
  }

  Widget _buildAssistantCard(TournamentAssistant assistant, TournamentAssistantsController controller) {
    String roleName = 'مساعد';
    Color roleColor = AppColors.primary;

    switch (assistant.role) {
      case TournamentAssistantRole.full:
        roleName = 'صلاحيات كاملة';
        roleColor = AppColors.primary;
        break;
      case TournamentAssistantRole.resultsOnly:
        roleName = 'إدخال نتائج';
        roleColor = AppColors.success;
        break;
      case TournamentAssistantRole.observer:
        roleName = 'مراقب';
        roleColor = AppColors.textMuted;
        break;
      case TournamentAssistantRole.emergency:
        roleName = 'بديل طارئ (72 ساعة)';
        roleColor = AppColors.error;
        break;
    }

    bool isEmergencyExpired = assistant.role == TournamentAssistantRole.emergency && !assistant.isValidEmergency;

    return GlassmorphicContainer(
      margin: const EdgeInsets.only(bottom: AppDimensions.md),
      padding: const EdgeInsets.all(AppDimensions.md),
      borderRadius: AppDimensions.radiusLg,
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
                Text('User: ${assistant.userId.substring(0, 5)}...', style: AppTextStyles.titleMedium),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(roleName, style: AppTextStyles.labelSmall.copyWith(color: roleColor)),
                    if (isEmergencyExpired) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(4)),
                        child: const Text('منتهي الصلاحية', style: TextStyle(fontSize: 10, color: Colors.white)),
                      )
                    ]
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

  void _showAddAssistantBottomSheet(BuildContext context, TournamentAssistantsController controller) {
    final TextEditingController idController = TextEditingController();
    TournamentAssistantRole selectedRole = TournamentAssistantRole.resultsOnly;

    Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setModalState) {
          return GlassmorphicContainer(
            padding: const EdgeInsets.all(AppDimensions.xl),
            borderRadius: AppDimensions.radiusXl,
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
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
                  child: DropdownButton<TournamentAssistantRole>(
                    value: selectedRole,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: TournamentAssistantRole.resultsOnly, child: Text('إدخال نتائج فقط')),
                      DropdownMenuItem(value: TournamentAssistantRole.full, child: Text('صلاحيات كاملة')),
                      DropdownMenuItem(value: TournamentAssistantRole.emergency, child: Text('بديل طارئ (يحل محلك طوال 72س)')),
                      DropdownMenuItem(value: TournamentAssistantRole.observer, child: Text('مراقب فقط')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedRole = val);
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
                    ),
                    onPressed: () {
                      if (idController.text.isNotEmpty) {
                        controller.addAssistant(idController.text.trim(), selectedRole);
                      }
                    },
                    child: Text('منح الصلاحية', style: AppTextStyles.buttonText.copyWith(color: AppColors.background)),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom), // Prevent keyboard overlap
              ],
            ),
          );
        }
      ),
      isScrollControlled: true,
    );
  }
}
