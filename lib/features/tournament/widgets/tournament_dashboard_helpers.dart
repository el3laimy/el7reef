import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/tournament_ops_enums.dart';
import '../../../domain/entities/tournament_participant.dart';
import '../controllers/tournament_operations_controller.dart';

String participantStatusLabel(TournamentParticipantStatus status) =>
    switch (status) {
      TournamentParticipantStatus.approved => 'معتمد',
      TournamentParticipantStatus.finalized => 'مؤكد',
      TournamentParticipantStatus.withdrawn => 'منسحب',
      TournamentParticipantStatus.replaced => 'مستبدل',
    };

String participantSourceLabel(TournamentParticipantSourceType sourceType) =>
    switch (sourceType) {
      TournamentParticipantSourceType.registeredTeam => 'فريق مسجل',
      TournamentParticipantSourceType.guestTeam => 'فريق ضيف',
    };

Color participantStatusColor(TournamentParticipantStatus status) =>
    switch (status) {
      TournamentParticipantStatus.approved => AppColors.info,
      TournamentParticipantStatus.finalized => AppColors.success,
      TournamentParticipantStatus.withdrawn => AppColors.warning,
      TournamentParticipantStatus.replaced => AppColors.textSecondary,
    };

Future<void> showManualAddParticipantDialog(
  BuildContext context,
  TournamentOperationsController controller,
) async {
  final candidate = await showParticipantPickerDialog(
    context: context,
    controller: controller,
    title: 'إضافة فريق يدويًا',
  );
  if (candidate == null) {
    return;
  }
  await controller.addManualParticipant(
    sourceType: candidate.sourceType,
    sourceEntityId: candidate.sourceEntityId,
  );
}

Future<void> showReplaceParticipantDialog(
  BuildContext context,
  TournamentOperationsController controller,
  TournamentParticipant participant,
) async {
  final candidate = await showParticipantPickerDialog(
    context: context,
    controller: controller,
    title: 'استبدال ${participant.displayName}',
    initialSourceType: participant.sourceType,
    replacingParticipant: participant,
  );
  if (candidate == null) {
    return;
  }
  await controller.replaceParticipant(
    participantId: participant.id,
    replacementSourceType: candidate.sourceType,
    replacementSourceEntityId: candidate.sourceEntityId,
  );
}

Future<void> showSeedEditorDialog(
  BuildContext context,
  TournamentOperationsController controller,
  TournamentParticipant participant,
) async {
  final seedController = TextEditingController(
    text: participant.seed?.toString() ?? '',
  );
  try {
    final result = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('تعديل تصنيف ${participant.displayName}'),
        content: TextField(
          controller: seedController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'التصنيف',
            hintText: 'اتركها فارغة لإزالة التصنيف',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('__clear__'),
            child: const Text('إزالة'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(seedController.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (result == null || !context.mounted) {
      return;
    }
    if (result == '__clear__') {
      await controller.updateParticipantSeed(
        participantId: participant.id,
        seed: null,
      );
      return;
    }
    final parsedSeed = int.tryParse(result);
    if (parsedSeed == null || parsedSeed <= 0) {
      return;
    }
    await controller.updateParticipantSeed(
      participantId: participant.id,
      seed: parsedSeed,
    );
  } finally {
    seedController.dispose();
  }
}

Future<TournamentParticipantCandidate?> showParticipantPickerDialog({
  required BuildContext context,
  required TournamentOperationsController controller,
  required String title,
  TournamentParticipantSourceType initialSourceType =
      TournamentParticipantSourceType.registeredTeam,
  TournamentParticipant? replacingParticipant,
}) async {
  final searchController = TextEditingController();
  TournamentParticipantSourceType selectedSourceType = initialSourceType;
  var isSearching = false;
  var hasSearched = false;
  var searchError = '';
  var results = const <TournamentParticipantCandidate>[];
  Timer? searchDebounce;
  var searchSequence = 0;

  Future<void> performSearch(
    StateSetter setState, {
    String? queryOverride,
  }) async {
    final requestId = ++searchSequence;
    final query = (queryOverride ?? searchController.text).trim();
    if (query.isEmpty) {
      setState(() {
        hasSearched = true;
        searchError = 'اكتب اسم الفريق أولاً.';
        results = const <TournamentParticipantCandidate>[];
      });
      return;
    }

    setState(() {
      isSearching = true;
      hasSearched = true;
      searchError = '';
    });
    try {
      final found = await controller.searchParticipantCandidates(
        query: query,
        sourceType: selectedSourceType,
        replacingParticipant: replacingParticipant,
      );
      if (requestId != searchSequence) {
        return;
      }
      setState(() {
        results = found;
      });
    } catch (error) {
      if (requestId != searchSequence) {
        return;
      }
      setState(() {
        searchError = error.toString().replaceFirst('Exception: ', '').trim();
        results = const <TournamentParticipantCandidate>[];
      });
    } finally {
      setState(() {
        isSearching = false;
      });
    }
  }

  void scheduleSearch(StateSetter setState, String value) {
    searchDebounce?.cancel();
    final normalized = value.trim();
    if (normalized.isEmpty) {
      setState(() {
        hasSearched = false;
        searchError = '';
        results = const <TournamentParticipantCandidate>[];
      });
      return;
    }
    searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => performSearch(setState, queryOverride: normalized),
    );
  }

  try {
    return await showDialog<TournamentParticipantCandidate>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<TournamentParticipantSourceType>(
                    initialValue: selectedSourceType,
                    decoration: const InputDecoration(labelText: 'نوع الفريق'),
                    items: TournamentParticipantSourceType.values
                        .map(
                          (sourceType) => DropdownMenuItem(
                            value: sourceType,
                            child: Text(
                              sourceType ==
                                      TournamentParticipantSourceType
                                          .registeredTeam
                                  ? 'فريق مسجل'
                                  : 'فريق ضيف',
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: isSearching
                        ? null
                        : (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              selectedSourceType = value;
                              results =
                                  const <TournamentParticipantCandidate>[];
                              searchError = '';
                              hasSearched = false;
                            });
                            if (searchController.text.trim().isNotEmpty) {
                              scheduleSearch(setState, searchController.text);
                            }
                          },
                  ),
                  const SizedBox(height: AppDimensions.md),
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      labelText: 'ابحث بالاسم',
                      hintText: 'اكتب اسم الفريق للبحث',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    textInputAction: TextInputAction.search,
                    onChanged: (value) => scheduleSearch(setState, value),
                    onSubmitted: (_) => performSearch(setState),
                  ),
                  const SizedBox(height: AppDimensions.md),
                  if (isSearching)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppDimensions.lg),
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  else if (searchError.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDimensions.sm,
                      ),
                      child: Text(
                        searchError,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    )
                  else if (results.isNotEmpty)
                    SizedBox(
                      height: 180,
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: results.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final candidate = results[index];
                          return ListTile(
                            leading: Icon(
                              candidate.sourceType ==
                                      TournamentParticipantSourceType
                                          .registeredTeam
                                  ? Icons.verified_rounded
                                  : Icons.group_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            title: Text(
                              candidate.displayName,
                              style: AppTextStyles.titleSmall.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              participantSourceLabel(candidate.sourceType),
                              style: AppTextStyles.bodySmall,
                            ),
                            onTap: () =>
                                Navigator.of(dialogContext).pop(candidate),
                          );
                        },
                      ),
                    )
                  else if (hasSearched)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDimensions.md,
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 40,
                            color: AppColors.textMuted.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: AppDimensions.sm),
                          Text(
                            'لا توجد نتائج مطابقة',
                            style: AppTextStyles.titleSmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.xs),
                          Text(
                            'تأكد من الاسم أو أنشئ فريق ضيف جديد من الزر أدناه.',
                            style: AppTextStyles.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDimensions.md,
                      ),
                      child: Text(
                        'ابحث عن فريق مسجل أو ضيف موجود لإضافته للبطولة.',
                        style: AppTextStyles.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const Divider(height: AppDimensions.lg),
                  _CreateGuestTeamButton(
                    tournamentId: controller.tournamentId,
                    onCreated: (candidate) {
                      Navigator.of(dialogContext).pop(candidate);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  } finally {
    searchDebounce?.cancel();
    searchController.dispose();
  }
}

class _CreateGuestTeamButton extends StatelessWidget {
  final String? tournamentId;
  final ValueChanged<TournamentParticipantCandidate>? onCreated;

  const _CreateGuestTeamButton({required this.tournamentId, this.onCreated});

  @override
  Widget build(BuildContext context) {
    final id = tournamentId;
    if (id == null || id.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final result = await Get.toNamed(
            AppRoutes.tournamentGuestTeamCreateForTournament(id),
          );
          if (result is Map<String, dynamic> &&
              result.containsKey('guestTeamId') &&
              result.containsKey('guestTeamName')) {
            onCreated?.call(
              TournamentParticipantCandidate(
                sourceType: TournamentParticipantSourceType.guestTeam,
                sourceEntityId: result['guestTeamId'] as String,
                displayName: result['guestTeamName'] as String,
              ),
            );
          }
        },
        icon: const Icon(Icons.add_circle_outline_rounded),
        label: const Text('إنشاء فريق ضيف جديد'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          foregroundColor: AppColors.info,
          side: BorderSide(color: AppColors.info.withValues(alpha: 0.4)),
        ),
      ),
    );
  }
}
