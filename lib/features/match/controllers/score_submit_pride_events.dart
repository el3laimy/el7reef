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
      final scoreA = persistedPayload?.scoreTeamA ?? submittedMatch.scoreTeamA;
      final scoreB = persistedPayload?.scoreTeamB ?? submittedMatch.scoreTeamB;
      if (scoreA == null || scoreB == null) {
        errorMessage.value = 'لا يمكن إعادة الإرسال بدون نتيجة محفوظة.';
        return null;
      }

      final detailedStats = ScoreSubmitPreparation.detailedStats(
        matchId: submittedMatch.id,
        teamAId: submittedMatch.teamAId ?? 'A',
        teamBId: submittedMatch.teamBId ?? 'B',
        teamAPlayers: teamAPlayers,
        teamBPlayers: teamBPlayers,
        playerStats: playerStats,
        teamACleanSheet: scoreB == 0,
        teamBCleanSheet: scoreA == 0,
      );
      final result = await _settlementService.submitScore(
        matchId: submittedMatch.id,
        actorId: actorId,
        scoreA: scoreA,
        scoreB: scoreB,
        mvpPlayerId: resolvedMvp?.actor.id,
        detailedStats: detailedStats,
        goalDrafts: _settlementGoalDrafts(),
        mvpDraft: resolvedMvp == null
            ? null
            : MatchSettlementMvpDraft(
                sideKey: resolvedMvp.sideKey,
                actor: resolvedMvp.actor,
              ),
        penaltyShootout:
            submittedMatch.stageType == TournamentStageType.knockoutStage &&
                scoreA == scoreB
            ? submittedMatch.penaltyShootoutResult
            : null,
      );
      final refreshed = await _matchRepo.getMatch(submittedMatch.id);
      final completedMatch = (refreshed ?? submittedMatch).copyWith(
        prideEventsPending: false,
        status: result.status,
      );
      match.value = completedMatch;
      pendingPrideEventRetry.value = false;
      await _clearDraftAfterSubmit(completedMatch);
      errorMessage.value = '';
      Get.snackbar(
        'تم الحفظ',
        'تم تسجيل أحداث المباراة ويمكن مشاركة النتيجة الآن.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return completedMatch;
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
