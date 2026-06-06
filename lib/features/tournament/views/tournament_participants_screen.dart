import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/enums/tournament_ops_enums.dart';
import '../../../core/widgets/el7reef_surface.dart';
import '../../../domain/entities/tournament_participant.dart';
import '../controllers/tournament_operations_controller.dart';
import '../widgets/tournament_widgets.dart';

class TournamentParticipantsScreen
    extends GetView<TournamentOperationsController> {
  const TournamentParticipantsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final sortedParticipants = controller.participants.toList(growable: false)
        ..sort(_compareParticipants);
      final activeParticipants = sortedParticipants
          .where((participant) => participant.isActive)
          .toList(growable: false);
      final withdrawnParticipants = sortedParticipants
          .where(
            (participant) =>
                participant.status == TournamentParticipantStatus.withdrawn,
          )
          .toList(growable: false);
      final replacedParticipants = sortedParticipants
          .where(
            (participant) =>
                participant.status == TournamentParticipantStatus.replaced,
          )
          .toList(growable: false);
      final canManage = controller.canManageTournament;

      return Scaffold(
        appBar: AppBar(title: const Text('الفرق المشاركة')),
        floatingActionButton: controller.canManualAddParticipants
            ? FloatingActionButton.extended(
                onPressed: controller.isActing.value
                    ? null
                    : () => showManualAddParticipantDialog(context, controller),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('إضافة فريق'),
              )
            : null,
        body: Container(
          decoration:
              const BoxDecoration(gradient: AppColors.backgroundGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.pagePadding),
              child: controller.participants.isEmpty
                  ? Center(
                      child: TournamentStateMessage(
                        title: 'لا يوجد فرق مشاركة بعد',
                        message: controller.canManualAddParticipants
                            ? 'اعتمد التسجيلات أو أضف فريق يدويًا.'
                            : 'اعتمد التسجيلات أولًا أو راجع حالة تشغيل البطولة الحالية.',
                      ),
                    )
                  : ListView(
                      children: [
                        El7reefSurface(
                          child: Wrap(
                            spacing: AppDimensions.sm,
                            runSpacing: AppDimensions.sm,
                            children: [
                              TournamentMetricChip(
                                label: 'نشط',
                                value: activeParticipants.length.toString(),
                              ),
                              if (canManage) ...[
                                TournamentMetricChip(
                                  label: 'منسحب',
                                  value:
                                      withdrawnParticipants.length.toString(),
                                ),
                                TournamentMetricChip(
                                  label: 'مستبدل',
                                  value:
                                      replacedParticipants.length.toString(),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: AppDimensions.md),
                        if (activeParticipants.isNotEmpty)
                          TournamentParticipantSection(
                            title: 'الفرق النشطة',
                            participants: activeParticipants,
                            controller: controller,
                          ),
                        if (canManage && withdrawnParticipants.isNotEmpty) ...[
                          const SizedBox(height: AppDimensions.md),
                          TournamentParticipantSection(
                            title: 'المنسحبون',
                            participants: withdrawnParticipants,
                            controller: controller,
                          ),
                        ],
                        if (canManage && replacedParticipants.isNotEmpty) ...[
                          const SizedBox(height: AppDimensions.md),
                          TournamentParticipantSection(
                            title: 'المستبدلون',
                            participants: replacedParticipants,
                            controller: controller,
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      );
    });
  }

  int _compareParticipants(
    TournamentParticipant left,
    TournamentParticipant right,
  ) {
    final leftSeed = left.seed ?? 9999;
    final rightSeed = right.seed ?? 9999;
    if (leftSeed != rightSeed) {
      return leftSeed.compareTo(rightSeed);
    }
    return left.displayName.compareTo(right.displayName);
  }
}
