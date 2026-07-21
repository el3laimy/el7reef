import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/tournament_ops_enums.dart';
import '../../../core/widgets/el7reef_surface.dart';
import '../../../domain/entities/tournament_participant.dart';
import '../controllers/tournament_operations_controller.dart';
import '../widgets/tournament_widgets.dart';

enum _ParticipantStatusFilter { active, withdrawn, replaced }

class TournamentParticipantsScreen extends StatefulWidget {
  const TournamentParticipantsScreen({super.key});

  @override
  State<TournamentParticipantsScreen> createState() =>
      _TournamentParticipantsScreenState();
}

class _TournamentParticipantsScreenState
    extends State<TournamentParticipantsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TournamentOperationsController controller =
      Get.find<TournamentOperationsController>();

  _ParticipantStatusFilter _statusFilter = _ParticipantStatusFilter.active;
  String? _selectedGroupId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
      final groupIds =
          activeParticipants
              .map((participant) => participant.groupId)
              .whereType<String>()
              .toSet()
              .toList(growable: false)
            ..sort(
              (left, right) => controller
                  .groupLabelFor(left)
                  .compareTo(controller.groupLabelFor(right)),
            );
      final filteredParticipants = _filterParticipants(
        active: activeParticipants,
        withdrawn: withdrawnParticipants,
        replaced: replacedParticipants,
      );

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
          decoration: const BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: SafeArea(
            child: controller.participants.isEmpty
                ? Center(
                    child: TournamentStateMessage(
                      title: 'لا يوجد فرق مشاركة بعد',
                      message: controller.canManualAddParticipants
                          ? 'اعتمد التسجيلات أو أضف فريق يدويًا.'
                          : 'اعتمد التسجيلات أولًا أو راجع حالة تشغيل البطولة الحالية.',
                    ),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppDimensions.pagePadding,
                          AppDimensions.sm,
                          AppDimensions.pagePadding,
                          0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ParticipantCounts(
                              active: activeParticipants.length,
                              withdrawn: withdrawnParticipants.length,
                              replaced: replacedParticipants.length,
                              canManage: controller.canManageTournament,
                            ),
                            const SizedBox(height: AppDimensions.md),
                            TextField(
                              key: const ValueKey('participant-search-field'),
                              controller: _searchController,
                              onChanged: (_) => setState(() {}),
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                hintText: 'ابحث باسم الفريق أو رمزه',
                                prefixIcon: const Icon(Icons.search_rounded),
                                suffixIcon: _searchController.text.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'مسح البحث',
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {});
                                        },
                                        icon: const Icon(Icons.close_rounded),
                                      ),
                              ),
                            ),
                            const SizedBox(height: AppDimensions.sm),
                            _StatusFilters(
                              selected: _statusFilter,
                              withdrawnCount: withdrawnParticipants.length,
                              replacedCount: replacedParticipants.length,
                              canManage: controller.canManageTournament,
                              onSelected: (filter) {
                                setState(() => _statusFilter = filter);
                              },
                            ),
                            if (groupIds.length > 1) ...[
                              const SizedBox(height: AppDimensions.sm),
                              _GroupFilters(
                                groupIds: groupIds,
                                selectedGroupId: _selectedGroupId,
                                groupLabel: controller.groupLabelFor,
                                onSelected: (groupId) {
                                  setState(() => _selectedGroupId = groupId);
                                },
                              ),
                            ],
                            const SizedBox(height: AppDimensions.sm),
                            Text(
                              '${filteredParticipants.length} فريق ظاهر',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondaryTinted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimensions.sm),
                      Expanded(
                        child: filteredParticipants.isEmpty
                            ? _NoParticipantResults(onClear: _clearFilters)
                            : ListView.separated(
                                key: const ValueKey('participant-results-list'),
                                padding: const EdgeInsets.fromLTRB(
                                  AppDimensions.pagePadding,
                                  0,
                                  AppDimensions.pagePadding,
                                  AppDimensions.xxl,
                                ),
                                itemCount: filteredParticipants.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: AppDimensions.sm),
                                itemBuilder: (context, index) =>
                                    TournamentParticipantCard(
                                      participant: filteredParticipants[index],
                                      controller: controller,
                                    ),
                              ),
                      ),
                    ],
                  ),
          ),
        ),
      );
    });
  }

  List<TournamentParticipant> _filterParticipants({
    required List<TournamentParticipant> active,
    required List<TournamentParticipant> withdrawn,
    required List<TournamentParticipant> replaced,
  }) {
    final statusParticipants = switch (_statusFilter) {
      _ParticipantStatusFilter.active => active,
      _ParticipantStatusFilter.withdrawn => withdrawn,
      _ParticipantStatusFilter.replaced => replaced,
    };
    final query = _searchController.text.trim().toLowerCase();
    return statusParticipants
        .where((participant) {
          final matchesGroup =
              _selectedGroupId == null ||
              participant.groupId == _selectedGroupId;
          final matchesQuery =
              query.isEmpty ||
              participant.displayName.toLowerCase().contains(query);
          return matchesGroup && matchesQuery;
        })
        .toList(growable: false);
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _selectedGroupId = null;
      _statusFilter = _ParticipantStatusFilter.active;
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

class _ParticipantCounts extends StatelessWidget {
  final int active;
  final int withdrawn;
  final int replaced;
  final bool canManage;

  const _ParticipantCounts({
    required this.active,
    required this.withdrawn,
    required this.replaced,
    required this.canManage,
  });

  @override
  Widget build(BuildContext context) {
    return El7reefSurface(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: _CountMetric(label: 'نشط', value: active),
          ),
          if (canManage) ...[
            const _MetricDivider(),
            Expanded(
              child: _CountMetric(label: 'منسحب', value: withdrawn),
            ),
            const _MetricDivider(),
            Expanded(
              child: _CountMetric(label: 'مستبدل', value: replaced),
            ),
          ],
        ],
      ),
    );
  }
}

class _CountMetric extends StatelessWidget {
  final String label;
  final int value;

  const _CountMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: AppTextStyles.titleLarge.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w900,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(label, style: AppTextStyles.bodySmall),
      ],
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 38,
      color: AppColors.surfaceBorderStrong,
    );
  }
}

class _StatusFilters extends StatelessWidget {
  final _ParticipantStatusFilter selected;
  final int withdrawnCount;
  final int replacedCount;
  final bool canManage;
  final ValueChanged<_ParticipantStatusFilter> onSelected;

  const _StatusFilters({
    required this.selected,
    required this.withdrawnCount,
    required this.replacedCount,
    required this.canManage,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimensions.sm,
      runSpacing: AppDimensions.xs,
      children: [
        ChoiceChip(
          label: const Text('النشطة'),
          selected: selected == _ParticipantStatusFilter.active,
          onSelected: (_) => onSelected(_ParticipantStatusFilter.active),
        ),
        if (canManage && withdrawnCount > 0)
          ChoiceChip(
            label: Text('المنسحبة $withdrawnCount'),
            selected: selected == _ParticipantStatusFilter.withdrawn,
            onSelected: (_) => onSelected(_ParticipantStatusFilter.withdrawn),
          ),
        if (canManage && replacedCount > 0)
          ChoiceChip(
            label: Text('المستبدلة $replacedCount'),
            selected: selected == _ParticipantStatusFilter.replaced,
            onSelected: (_) => onSelected(_ParticipantStatusFilter.replaced),
          ),
      ],
    );
  }
}

class _GroupFilters extends StatelessWidget {
  final List<String> groupIds;
  final String? selectedGroupId;
  final String Function(String? groupId) groupLabel;
  final ValueChanged<String?> onSelected;

  const _GroupFilters({
    required this.groupIds,
    required this.selectedGroupId,
    required this.groupLabel,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppDimensions.buttonHeightMd,
      child: ListView.separated(
        key: const ValueKey('participant-group-filters'),
        scrollDirection: Axis.horizontal,
        itemCount: groupIds.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: AppDimensions.xs),
        itemBuilder: (context, index) {
          final groupId = index == 0 ? null : groupIds[index - 1];
          return ChoiceChip(
            key: ValueKey('participant-group-${groupId ?? 'all'}'),
            label: Text(groupId == null ? 'كل المجموعات' : groupLabel(groupId)),
            selected: selectedGroupId == groupId,
            onSelected: (_) => onSelected(groupId),
          );
        },
      ),
    );
  }
}

class _NoParticipantResults extends StatelessWidget {
  final VoidCallback onClear;

  const _NoParticipantResults({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 48,
              color: AppColors.textSecondaryTinted,
            ),
            const SizedBox(height: AppDimensions.sm),
            Text('لا توجد فرق مطابقة', style: AppTextStyles.titleLarge),
            const SizedBox(height: AppDimensions.xs),
            Text(
              'غيّر كلمة البحث أو اعرض كل المجموعات.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppDimensions.md),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off_rounded),
              label: const Text('مسح الفلاتر'),
            ),
          ],
        ),
      ),
    );
  }
}
