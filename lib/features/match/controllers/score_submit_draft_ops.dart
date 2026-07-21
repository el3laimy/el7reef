part of 'score_submit_controller.dart';

extension ScoreSubmitDraftOps on ScoreSubmitController {
  static const _saveDelay = Duration(milliseconds: 350);

  bool get isOnFirstStep => currentStepIndex.value == 0;

  bool get isOnReviewStep => currentStepIndex.value == 3;

  String get nextStepLabel => switch (currentStepIndex.value) {
    0 => 'التالي: الهدافون',
    1 => 'التالي: MVP',
    2 => 'التالي: المراجعة',
    _ => 'اعتمد النتيجة وجهّز الفخر',
  };

  void goToPreviousStep() {
    if (currentStepIndex.value > 0) {
      currentStepIndex.value -= 1;
    }
  }

  bool goToNextStep() {
    if (currentStepIndex.value == 0 && !_validateScoreStep()) {
      return false;
    }
    if (currentStepIndex.value < 3) {
      currentStepIndex.value += 1;
    }
    return true;
  }

  Future<void> discardDraft() async {
    _draftSaveDebounce?.cancel();
    await _clearStoredDraftQuietly(matchId);
    isDirty.value = false;
    restoredDraft.value = false;
  }

  Future<void> flushDraft() async {
    _draftSaveDebounce?.cancel();
    await _persistDraft();
  }

  Future<void> _restoreDraftForMatch(Match loadedMatch) async {
    _draftTrackingEnabled = false;
    _sourceMatchFingerprint = _matchFingerprint(loadedMatch);
    ScoreSubmitDraft? draft;
    try {
      draft = await _draftStore.load(loadedMatch.id);
    } catch (error) {
      AppLogger.warning('ScoreSubmitDraftOps.restore', error);
    }
    if (draft == null) {
      _draftTrackingEnabled = true;
      return;
    }
    final restored = draft;
    if (restored.sourceFingerprint != _sourceMatchFingerprint) {
      await _clearStoredDraftQuietly(loadedMatch.id);
      _draftTrackingEnabled = true;
      return;
    }

    for (final participant in allParticipants) {
      final goals = restored.goalsByParticipantKey[participantKey(participant)];
      if (goals != null && goals > 0) {
        setParticipantGoals(participant, goals);
      }
    }
    _setScoreControllerText(sideKey: 'A', text: restored.scoreA);
    _setScoreControllerText(sideKey: 'B', text: restored.scoreB);
    _setPenaltyScoreControllerText(sideKey: 'A', text: restored.penaltyScoreA);
    _setPenaltyScoreControllerText(sideKey: 'B', text: restored.penaltyScoreB);
    if (allParticipants.any(
      (participant) => participantKey(participant) == restored.selectedMvpKey,
    )) {
      selectedMvpKey.value = restored.selectedMvpKey;
    }
    _restoreRegisteredStats(restored.registeredStats);
    restoredDraft.value = true;
    isDirty.value = true;
    _draftTrackingEnabled = true;
  }

  void _restoreRegisteredStats(
    Map<String, ScoreSubmitRegisteredStatsDraft> drafts,
  ) {
    for (final entry in drafts.entries) {
      final stats = playerStats[entry.key];
      if (stats == null) continue;
      stats['assists'] = entry.value.assists;
      stats['saves'] = entry.value.saves;
      stats['yellowCard'] = entry.value.yellowCard;
      stats['redCard'] = entry.value.redCard;
    }
  }

  void _markDraftChanged() {
    if (!_draftTrackingEnabled) return;
    isDirty.value = true;
    _draftSaveDebounce?.cancel();
    _draftSaveDebounce = Timer(_saveDelay, () => unawaited(_persistDraft()));
  }

  Future<void> _persistDraft() async {
    final fingerprint = _sourceMatchFingerprint;
    if (!isDirty.value || fingerprint == null) return;
    try {
      await _draftStore.save(_draftSnapshot(fingerprint));
    } catch (error) {
      AppLogger.warning('ScoreSubmitDraftOps.persist', error);
    }
  }

  ScoreSubmitDraft _draftSnapshot(String fingerprint) {
    return ScoreSubmitDraft(
      matchId: matchId,
      sourceFingerprint: fingerprint,
      scoreA: teamAScoreController.text.trim(),
      scoreB: teamBScoreController.text.trim(),
      penaltyScoreA: teamAPenaltyScoreController.text.trim(),
      penaltyScoreB: teamBPenaltyScoreController.text.trim(),
      goalsByParticipantKey: {
        for (final draft in goalDrafts)
          participantKey(draft.actor): draft.goals,
      },
      selectedMvpKey: selectedMvpKey.value.trim(),
      registeredStats: {
        for (final entry in playerStats.entries)
          entry.key: ScoreSubmitRegisteredStatsDraft(
            assists: entry.value['assists'] as int? ?? 0,
            saves: entry.value['saves'] as int? ?? 0,
            yellowCard: entry.value['yellowCard'] as bool? ?? false,
            redCard: entry.value['redCard'] as bool? ?? false,
          ),
      },
    );
  }

  bool _validateScoreStep() {
    final result = _validateScores();
    if (!result.isValid) return false;
    return _validatePenaltyShootout(
      scoreA: result.scoreA!,
      scoreB: result.scoreB!,
    );
  }

  Future<bool> _hasSourceMatchChanged() async {
    final fingerprint = _sourceMatchFingerprint;
    if (fingerprint == null) return true;
    final latestMatch = await _matchRepo.getMatch(matchId);
    return latestMatch == null || _matchFingerprint(latestMatch) != fingerprint;
  }

  Future<void> _clearDraftAfterSubmit(Match updatedMatch) async {
    _draftSaveDebounce?.cancel();
    await _clearStoredDraftQuietly(updatedMatch.id);
    _sourceMatchFingerprint = _matchFingerprint(updatedMatch);
    isDirty.value = false;
    restoredDraft.value = false;
  }

  String _matchFingerprint(Match value) {
    return [
      value.status.name,
      value.scoreTeamA?.toString() ?? '',
      value.scoreTeamB?.toString() ?? '',
      value.penaltyScoreTeamA?.toString() ?? '',
      value.penaltyScoreTeamB?.toString() ?? '',
      value.knockoutDecision?.name ?? '',
      value.mvpPlayerId ?? '',
      value.completedAt?.millisecondsSinceEpoch.toString() ?? '',
    ].join('|');
  }

  Future<void> _clearStoredDraftQuietly(String targetMatchId) async {
    try {
      await _draftStore.clear(targetMatchId);
    } catch (error) {
      AppLogger.warning('ScoreSubmitDraftOps.clear', error);
    }
  }
}
