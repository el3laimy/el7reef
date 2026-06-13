part of 'score_submit_controller.dart';

extension ScoreSubmitPrideEvents on ScoreSubmitController {
  Future<Match?> _retryPrideEventWrites({
    required Match submittedMatch,
    required String actorId,
  }) async {
    try {
      isLoading.value = true;
      final persistedPayload = await _pendingPrideEventsService.loadPayload(
        submittedMatch.id,
      );
      final resolvedMvp = persistedPayload == null
          ? _resolveSelectedMvpForRetry()
          : _restorePendingPridePayload(persistedPayload);
      if (resolvedMvp == null && selectedMvpKey.value.trim().isNotEmpty) {
        errorMessage.value = 'تعذر تحديد أفضل لاعب من قائمة المشاركين الحالية.';
        return null;
      }
      if (persistedPayload == null &&
          allGoalDrafts.isEmpty &&
          selectedMvpKey.value.trim().isEmpty) {
        errorMessage.value =
            'لم نجد بيانات الهدافين المحفوظة. أعد إدخال الهدافين أو أفضل لاعب ثم حاول مرة أخرى.';
        Get.snackbar(
          'أكمل بيانات الفخر',
          errorMessage.value,
          snackPosition: SnackPosition.BOTTOM,
        );
        return null;
      }

      await _recordPrideEventsOrThrow(
        submittedMatch: submittedMatch,
        resolvedMvp: resolvedMvp,
        actorId: actorId,
      );
      await _clearPrideEventRetryState(submittedMatch);
      errorMessage.value = '';
      Get.snackbar(
        'تم الحفظ',
        'تم تسجيل أحداث المباراة ويمكن مشاركة النتيجة الآن.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return submittedMatch;
    } catch (error, stackTrace) {
      AppLogger.error(
        'ScoreSubmitController._retryPrideEventWrites',
        error,
        stackTrace,
      );
      _surfacePrideEventFailure();
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  ({ParticipantRef actor, String sideKey})? _resolveSelectedMvpForRetry() {
    final normalizedSelectedMvpKey = selectedMvpKey.value.trim();
    final resolvedMvp = _resolveMvpParticipant(normalizedSelectedMvpKey);
    if (normalizedSelectedMvpKey.isNotEmpty && resolvedMvp == null) {
      return null;
    }
    return resolvedMvp;
  }

  ({ParticipantRef actor, String sideKey})? _restorePendingPridePayload(
    PendingPrideEventsPayload payload,
  ) {
    goalDrafts.assignAll(
      payload.goals.map(
        (draft) => ScoreSubmitGoalDraft(
          actor: draft.actor,
          sideKey: draft.sideKey,
          goals: draft.goals,
          minute: draft.minute,
        ),
      ),
    );
    for (final draft in goalDrafts) {
      _syncRegisteredGoalStat(draft.actor, draft.goals);
    }
    final mvp = payload.mvp;
    if (mvp == null) {
      selectedMvpKey.value = '';
      return null;
    }
    selectedMvpKey.value = participantKey(mvp.actor);
    return (actor: mvp.actor, sideKey: mvp.sideKey);
  }

  Future<void> _recordPrideEventsOrThrow({
    required Match submittedMatch,
    required ({ParticipantRef actor, String sideKey})? resolvedMvp,
    required String actorId,
  }) async {
    await _recordMvpMatchEventIfPossible(
      submittedMatch: submittedMatch,
      resolvedMvp: resolvedMvp,
      actorId: actorId,
    );
    await _recordGoalMatchEventsIfPossible(
      submittedMatch: submittedMatch,
      actorId: actorId,
    );
  }

  bool _hasSubmittedScore(Match currentMatch) {
    return currentMatch.scoreTeamA != null && currentMatch.scoreTeamB != null;
  }

  void _surfacePrideEventFailure() {
    pendingPrideEventRetry.value = true;
    errorMessage.value = ScoreSubmitController.prideEventWriteFailureMessage;
    Get.snackbar(
      'لم يكتمل التسجيل',
      errorMessage.value,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> _recordGoalMatchEventsIfPossible({
    required Match submittedMatch,
    required String actorId,
  }) async {
    final activeEvents = await _matchEventService.getMatchEvents(
      submittedMatch.id,
    );
    for (final event in activeEvents) {
      if (event.isGoal) {
        await _matchEventService.voidEvent(event.id);
      }
    }

    final drafts = allGoalDrafts.where((draft) => draft.goals > 0).toList();
    if (drafts.isEmpty) return;

    for (final draft in drafts) {
      for (var index = 1; index <= draft.goals; index += 1) {
        await _matchEventService.recordGoal(
          eventId: _goalEventId(
            matchId: submittedMatch.id,
            draft: draft,
            index: index,
          ),
          matchId: submittedMatch.id,
          tournamentId: submittedMatch.tournamentId,
          sideKey: draft.sideKey,
          actor: draft.actor,
          createdBy: actorId,
        );
      }
    }
  }

  Future<void> _recordMvpMatchEventIfPossible({
    required Match submittedMatch,
    required ({ParticipantRef actor, String sideKey})? resolvedMvp,
    required String actorId,
  }) async {
    if (resolvedMvp == null) return;

    final eventId = _mvpEventId(submittedMatch.id);
    final activeEvents = await _matchEventService.getMatchEvents(
      submittedMatch.id,
    );
    for (final event in activeEvents) {
      if (event.isMvp && event.id != eventId) {
        await _matchEventService.voidEvent(event.id);
      }
    }
    await _matchEventService.recordMvp(
      eventId: eventId,
      matchId: submittedMatch.id,
      tournamentId: submittedMatch.tournamentId,
      sideKey: resolvedMvp.sideKey,
      actor: resolvedMvp.actor,
      createdBy: actorId,
    );
  }

  ({ParticipantRef actor, String sideKey})? _resolveMvpParticipant(
    String selectedMvpKey,
  ) {
    if (selectedMvpKey.isEmpty) return null;
    final roster = fullParticipantRoster.value;
    if (roster == null) return null;
    final usesParticipantKey = selectedMvpKey.contains(':');

    final matches = <({ParticipantRef actor, String sideKey})>[
      for (final participant in roster.sideA)
        if (usesParticipantKey
            ? participantKey(participant) == selectedMvpKey
            : participant.id == selectedMvpKey)
          (actor: participant, sideKey: 'A'),
      for (final participant in roster.sideB)
        if (usesParticipantKey
            ? participantKey(participant) == selectedMvpKey
            : participant.id == selectedMvpKey)
          (actor: participant, sideKey: 'B'),
    ];
    if (matches.length != 1) return null;
    return matches.single;
  }

  String _mvpEventId(String matchId) => 'mvp-$matchId';

  String _goalEventId({
    required String matchId,
    required ScoreSubmitGoalDraft draft,
    required int index,
  }) {
    return [
      'goal',
      _safeEventIdSegment(matchId),
      draft.sideKey,
      draft.actor.kind.name,
      _safeEventIdSegment(draft.actor.id),
      index.toString(),
    ].join('-');
  }

  String _safeEventIdSegment(String value) {
    final encoded = Uri.encodeComponent(value.trim());
    return encoded.isEmpty ? 'unknown' : encoded;
  }

  ParticipantRef? _rosterParticipantFor(
    ParticipantRef participant,
    String sideKey,
  ) {
    final key = participantRosterKey(participant);
    return fullParticipantRoster.value
        ?.participantsForSide(sideKey)
        .firstWhereOrNull(
          (candidate) => participantRosterKey(candidate) == key,
        );
  }
}
