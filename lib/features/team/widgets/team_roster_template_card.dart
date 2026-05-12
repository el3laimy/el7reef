import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../domain/entities/team_formation_template.dart';
import '../controllers/team_roster_controller.dart';
import 'team_roster_enums.dart';
import 'team_roster_helpers.dart';
import 'team_roster_tag.dart';

class TeamRosterTemplateCard extends StatelessWidget {
  final TeamFormationTemplate template;
  final TeamRosterController controller;
  final bool canManageRoster;

  const TeamRosterTemplateCard({
    super.key,
    required this.template,
    required this.controller,
    required this.canManageRoster,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(template.name, style: AppTextStyles.titleLarge),
                    const SizedBox(height: 2),
                    Text(template.summaryLabel, style: AppTextStyles.bodySmall),
                    const SizedBox(height: 2),
                    Text(
                      'آخر تحديث: ${formatDate(template.updatedAt)}',
                      style: AppTextStyles.labelSmall,
                    ),
                  ],
                ),
              ),
              if (canManageRoster)
                PopupMenuButton<TemplateAction>(
                  color: AppColors.surfaceLight,
                  onSelected: (action) async {
                    switch (action) {
                      case TemplateAction.apply:
                        await controller.applyTemplate(template);
                      case TemplateAction.delete:
                        final confirmed = await Get.dialog<bool>(
                          AlertDialog(
                            title: const Text('حذف القالب'),
                            content: Text(
                              'هل تريد حذف القالب ${template.name}؟',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Get.back(result: false),
                                child: const Text('إلغاء'),
                              ),
                              FilledButton(
                                onPressed: () => Get.back(result: true),
                                child: const Text('حذف'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await controller.deleteTemplate(template);
                        }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: TemplateAction.apply,
                      child: Text('تطبيق القالب'),
                    ),
                    PopupMenuItem(
                      value: TemplateAction.delete,
                      child: Text('حذف القالب'),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          Wrap(
            spacing: AppDimensions.xs,
            runSpacing: AppDimensions.xs,
            children: [
                    TeamRosterTag(label: 'أساسي ${template.starterCount}', color: AppColors.primary),
                    TeamRosterTag(label: 'احتياط ${template.benchCount}', color: AppColors.secondary),
                    TeamRosterTag(
                      label: 'غير نشط ${template.inactiveCount}',
                      color: AppColors.textMuted,
                    ),
            ],
          ),
        ],
      ),
    );
  }
}
