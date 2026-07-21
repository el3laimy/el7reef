import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/team_membership_status.dart';
import '../../../core/widgets/el7reef_button.dart';
import '../../../core/widgets/el7reef_glass_surface.dart';
import '../controllers/team_roster_controller.dart';
import 'team_roster_search_result_tile.dart';

Future<void> showRegisteredPlayerSheet(
  BuildContext context,
  TeamRosterController controller,
) async {
  controller.clearPlayerSearch();
  await _showTeamRosterSheet(
    context,
    builder: (_) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('إضافة لاعب مسجل', style: AppTextStyles.headlineMedium),
        const SizedBox(height: AppDimensions.md),
        TextField(
          controller: controller.registeredSearchController,
          decoration: const InputDecoration(
            labelText: 'ابحث بالاسم أو @username',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: AppDimensions.md),
        SizedBox(
          height: 320,
          child: Obx(() {
            if (controller.isSearchingPlayers.value) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            if (controller.registeredSearchController.text.trim().isEmpty) {
              return Center(
                child: Text(
                  'ابدأ بكتابة اسم اللاعب أو الـ username للبحث.',
                  style: AppTextStyles.bodyMedium,
                ),
              );
            }

            if (controller.playerSearchResults.isEmpty) {
              return Center(
                child: Text(
                  'لا يوجد لاعبون مطابقون أو أنهم موجودون بالفعل داخل القائمة.',
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              );
            }

            return ListView.separated(
              itemCount: controller.playerSearchResults.length,
              separatorBuilder: (_, separatorIndex) =>
                  const SizedBox(height: AppDimensions.sm),
              itemBuilder: (_, index) {
                final player = controller.playerSearchResults[index];
                return TeamRosterSearchResultTile(
                  player: player,
                  controller: controller,
                );
              },
            );
          }),
        ),
      ],
    ),
  );
}

Future<void> showGuestPlayerSheet(
  BuildContext context,
  TeamRosterController controller,
) async {
  final formKey = GlobalKey<FormState>();
  var selectedStatus = TeamMembershipStatus.bench;
  controller.clearGuestForm();

  await _showTeamRosterSheet(
    context,
    builder: (_) => StatefulBuilder(
      builder: (context, setModalState) => Padding(
        padding: EdgeInsets.zero,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('إضافة لاعب ضيف', style: AppTextStyles.headlineMedium),
              const SizedBox(height: AppDimensions.md),
              TextFormField(
                controller: controller.guestNameController,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'اسم اللاعب مطلوب'
                    : null,
                decoration: const InputDecoration(
                  labelText: 'اسم اللاعب',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              TextFormField(
                controller: controller.guestPositionController,
                decoration: const InputDecoration(
                  labelText: 'المركز',
                  prefixIcon: Icon(Icons.sports_soccer),
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              TextFormField(
                controller: controller.guestJerseyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'رقم التيشيرت (اختياري)',
                  prefixIcon: Icon(Icons.confirmation_number_outlined),
                ),
              ),
              const SizedBox(height: AppDimensions.md),
              Text(
                'بداية اللاعب داخل القائمة',
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: AppDimensions.sm),
              Wrap(
                spacing: AppDimensions.sm,
                children: [
                  ChoiceChip(
                    label: const Text('احتياط'),
                    selected: selectedStatus == TeamMembershipStatus.bench,
                    onSelected: (_) => setModalState(
                      () => selectedStatus = TeamMembershipStatus.bench,
                    ),
                  ),
                  ChoiceChip(
                    label: const Text('أساسي'),
                    selected: selectedStatus == TeamMembershipStatus.starter,
                    onSelected: (_) => setModalState(
                      () => selectedStatus = TeamMembershipStatus.starter,
                    ),
                  ),
                  ChoiceChip(
                    label: const Text('غير نشط'),
                    selected: selectedStatus == TeamMembershipStatus.inactive,
                    onSelected: (_) => setModalState(
                      () => selectedStatus = TeamMembershipStatus.inactive,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.lg),
              Obx(
                () => El7reefButton(
                  text: 'إضافة اللاعب',
                  icon: Icons.group_add_rounded,
                  isLoading: controller.isSubmitting.value,
                  onPressed: () {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }
                    controller.createGuestPlayerAndAdd(
                      displayName: controller.guestNameController.text,
                      status: selectedStatus,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  controller.clearGuestForm();
}

Future<void> showTemplateSheet(
  BuildContext context,
  TeamRosterController controller,
) async {
  final formKey = GlobalKey<FormState>();
  controller.clearTemplateForm();
  controller.templateFormationController.text =
      controller.currentFormationSummary;

  await _showTeamRosterSheet(
    context,
    builder: (_) => Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('حفظ قالب التشكيلة', style: AppTextStyles.headlineMedium),
          const SizedBox(height: AppDimensions.md),
          TextFormField(
            controller: controller.templateNameController,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'اسم القالب مطلوب'
                : null,
            decoration: const InputDecoration(
              labelText: 'اسم القالب',
              prefixIcon: Icon(Icons.bookmark_border_rounded),
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          TextFormField(
            controller: controller.templateFormationController,
            decoration: const InputDecoration(
              labelText: 'وصف الخطة',
              prefixIcon: Icon(Icons.grid_view_rounded),
            ),
          ),
          const SizedBox(height: AppDimensions.lg),
          Obx(
            () => El7reefButton(
              text: 'حفظ القالب',
              icon: Icons.save_alt_rounded,
              isLoading: controller.isSubmitting.value,
              onPressed: () async {
                if (!formKey.currentState!.validate()) {
                  return;
                }
                final success = await controller.saveFormationTemplate(
                  name: controller.templateNameController.text,
                  formationLabel: controller.templateFormationController.text,
                );
                if (success) {
                  Get.back();
                }
              },
            ),
          ),
        ],
      ),
    ),
  );
  controller.clearTemplateForm();
}

Future<void> showSnapshotSheet(
  BuildContext context,
  TeamRosterController controller,
) async {
  final formKey = GlobalKey<FormState>();
  controller.clearSnapshotForm();
  controller.snapshotFormationController.text =
      controller.currentFormationSummary;

  await _showTeamRosterSheet(
    context,
    builder: (_) => Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('إنشاء نسخة جاهزة', style: AppTextStyles.headlineMedium),
          const SizedBox(height: AppDimensions.md),
          TextFormField(
            controller: controller.snapshotLabelController,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'اسم النسخة مطلوب'
                : null,
            decoration: const InputDecoration(
              labelText: 'اسم النسخة',
              prefixIcon: Icon(Icons.content_copy_rounded),
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          TextFormField(
            controller: controller.snapshotFormationController,
            decoration: const InputDecoration(
              labelText: 'وصف الخطة',
              prefixIcon: Icon(Icons.grid_view_rounded),
            ),
          ),
          const SizedBox(height: AppDimensions.lg),
          Obx(
            () => El7reefButton(
              text: 'إنشاء النسخة',
              icon: Icons.done_all_rounded,
              isLoading: controller.isSubmitting.value,
              onPressed: () async {
                if (!formKey.currentState!.validate()) {
                  return;
                }
                final success = await controller.createRosterSnapshot(
                  label: controller.snapshotLabelController.text,
                  formationLabel: controller.snapshotFormationController.text,
                );
                if (success) {
                  Get.back();
                }
              },
            ),
          ),
        ],
      ),
    ),
  );
  controller.clearSnapshotForm();
}

Future<void> _showTeamRosterSheet(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => El7reefGlassSurface(
      variant: El7reefGlassVariant.sheet,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppDimensions.radiusXl),
      ),
      padding: EdgeInsets.only(
        left: AppDimensions.lg,
        right: AppDimensions.lg,
        top: AppDimensions.lg,
        bottom:
            MediaQuery.of(sheetContext).viewInsets.bottom + AppDimensions.lg,
      ),
      child: builder(sheetContext),
    ),
  );
}
