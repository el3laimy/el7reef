import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/enums/tournament_ops_enums.dart';
import '../../../../domain/entities/tournament_participant.dart';
import '../controllers/tournament_operations_controller.dart';

String participantStatusLabel(TournamentParticipantStatus status) =>
    switch (status) {
      TournamentParticipantStatus.approved => 'Approved',
      TournamentParticipantStatus.finalized => 'Finalized',
      TournamentParticipantStatus.withdrawn => 'Withdrawn',
      TournamentParticipantStatus.replaced => 'Replaced',
    };

String participantSourceLabel(TournamentParticipantSourceType sourceType) =>
    switch (sourceType) {
      TournamentParticipantSourceType.registeredTeam => 'Registered Team',
      TournamentParticipantSourceType.guestTeam => 'Guest Team',
    };

Color participantStatusColor(TournamentParticipantStatus status) =>
    switch (status) {
      TournamentParticipantStatus.approved => const Color(0xFFEAF1FF),
      TournamentParticipantStatus.finalized => const Color(0xFFE7F7ED),
      TournamentParticipantStatus.withdrawn => const Color(0xFFFFF2CC),
      TournamentParticipantStatus.replaced => const Color(0xFFF0F0F0),
    };

Future<void> showManualAddParticipantDialog(
  BuildContext context,
  TournamentOperationsController controller,
) async {
  final candidate = await showParticipantPickerDialog(
    context: context,
    controller: controller,
    title: 'إضافة participant يدويًا',
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
        title: Text('تعديل Seed لـ ${participant.displayName}'),
        content: TextField(
          controller: seedController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Seed',
            hintText: 'اتركها فارغة لإزالة الـ seed',
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
                    decoration: const InputDecoration(labelText: 'نوع المصدر'),
                    items: TournamentParticipantSourceType.values
                        .map(
                          (sourceType) => DropdownMenuItem(
                            value: sourceType,
                            child: Text(
                              sourceType ==
                                      TournamentParticipantSourceType
                                          .registeredTeam
                                  ? 'Registered Team'
                                  : 'Guest Team',
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      labelText: 'ابحث بالاسم',
                      hintText: 'مثال: Blue أو Falcons',
                    ),
                    textInputAction: TextInputAction.search,
                    onChanged: (value) => scheduleSearch(setState, value),
                    onSubmitted: (_) => performSearch(setState),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: isSearching
                          ? null
                          : () => performSearch(setState),
                      icon: const Icon(Icons.search),
                      label: const Text('Search'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isSearching)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(),
                    )
                  else if (searchError.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        searchError,
                        style: const TextStyle(color: Colors.red),
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
                            title: Text(candidate.displayName),
                            subtitle: Text(
                              '${candidate.sourceType.name} • ${candidate.sourceEntityId}',
                            ),
                            onTap: () =>
                                Navigator.of(dialogContext).pop(candidate),
                          );
                        },
                      ),
                    )
                  else if (hasSearched)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'لا توجد نتائج مناسبة أو أن الفريق موجود بالفعل داخل البطولة.',
                      ),
                    )
                  else
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'ابحث ثم اختر فريقًا مسجلًا أو ضيفًا لإضافته أو استبداله.',
                      ),
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
