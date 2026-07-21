part of 'score_submit_controller.dart';

extension ScoreSubmitHelpers on ScoreSubmitController {
  ScoreSubmitValidationResult _validateScores() {
    final result = ScoreSubmitPreparation.validateScores(
      rawScoreA: teamAScoreController.text,
      rawScoreB: teamBScoreController.text,
      sideAName: teamASideName.value,
      sideBName: teamBSideName.value,
      attributedGoalsA: _attributedGoalsForSide('A'),
      attributedGoalsB: _attributedGoalsForSide('B'),
    );
    if (result.isValid) return result;

    errorMessage.value = result.errorMessage!;
    Get.snackbar(
      result.errorTitle!,
      errorMessage.value,
      snackPosition: SnackPosition.BOTTOM,
    );
    return result;
  }

  ScoreSideGoalSummary _goalSummaryForSide(String sideKey) {
    final normalizedSideKey = sideKey.trim().toUpperCase();
    final scoreText = normalizedSideKey == 'A'
        ? teamAScoreText.value
        : normalizedSideKey == 'B'
        ? teamBScoreText.value
        : '';
    final attributedGoals = _attributedGoalsForSide(normalizedSideKey);
    return ScoreSubmitPreparation.goalSummary(
      sideKey: normalizedSideKey,
      rawScore: scoreText,
      attributedGoals: attributedGoals,
    );
  }

  int _attributedGoalsForSide(String sideKey) {
    final normalizedSideKey = sideKey.trim().toUpperCase();
    final draftTotal = totalDraftGoalsForSide(normalizedSideKey);
    if (draftTotal > 0 || fullParticipantRoster.value != null) {
      return draftTotal;
    }
    return normalizedSideKey == 'A'
        ? _sumGoals(teamAPlayers)
        : normalizedSideKey == 'B'
        ? _sumGoals(teamBPlayers)
        : 0;
  }

  void _syncRegisteredGoalDraft(String playerId) {
    final roster = fullParticipantRoster.value;
    if (roster == null) return;

    final participant = roster.allParticipants.firstWhereOrNull(
      (item) => item.kind == ParticipantRefKind.player && item.id == playerId,
    );
    if (participant == null) return;

    final goals = playerStats[playerId]?['goals'] as int? ?? 0;
    if (goals <= 0) {
      clearParticipantGoals(participant);
    } else {
      setParticipantGoals(participant, goals);
    }
  }

  void _syncRegisteredGoalStat(ParticipantRef participant, int goals) {
    if (participant.kind != ParticipantRefKind.player ||
        !playerStats.containsKey(participant.id)) {
      return;
    }
    playerStats[participant.id]?['goals'] = goals;
  }

  void _syncScoreControllerForSide(String sideKey) {
    final normalizedSideKey = sideKey.trim().toUpperCase();
    if (normalizedSideKey != 'A' && normalizedSideKey != 'B') return;

    final controller = normalizedSideKey == 'A'
        ? teamAScoreController
        : teamBScoreController;
    final attributedGoals = _attributedGoalsForSide(normalizedSideKey);
    final currentText = controller.text.trim();
    final parsedCurrent = _parsedTeamScore(currentText);
    final lastSyncedText = _lastSyncedScoreText[normalizedSideKey] ?? '';
    final shouldSync =
        currentText.isEmpty ||
        currentText == lastSyncedText ||
        parsedCurrent == null ||
        parsedCurrent < attributedGoals;

    if (!shouldSync) return;
    _setScoreControllerText(
      sideKey: normalizedSideKey,
      text: attributedGoals.toString(),
    );
  }

  void _setScoreControllerText({
    required String sideKey,
    required String text,
  }) {
    final normalizedSideKey = sideKey.trim().toUpperCase();
    if (normalizedSideKey == 'A') {
      teamAScoreController.text = text;
      teamAScoreText.value = text;
      _lastSyncedScoreText['A'] = text.trim();
    } else if (normalizedSideKey == 'B') {
      teamBScoreController.text = text;
      teamBScoreText.value = text;
      _lastSyncedScoreText['B'] = text.trim();
    }
  }

  void _setPenaltyScoreControllerText({
    required String sideKey,
    required String text,
  }) {
    final normalizedSideKey = sideKey.trim().toUpperCase();
    if (normalizedSideKey == 'A') {
      teamAPenaltyScoreController.text = text;
      teamAPenaltyScoreText.value = text;
    } else if (normalizedSideKey == 'B') {
      teamBPenaltyScoreController.text = text;
      teamBPenaltyScoreText.value = text;
    }
  }

  void _handleTeamAScoreTextChanged() {
    teamAScoreText.value = teamAScoreController.text;
    _markDraftChanged();
  }

  void _handleTeamBScoreTextChanged() {
    teamBScoreText.value = teamBScoreController.text;
    _markDraftChanged();
  }

  void _handleTeamAPenaltyScoreTextChanged() {
    teamAPenaltyScoreText.value = teamAPenaltyScoreController.text;
    _markDraftChanged();
  }

  void _handleTeamBPenaltyScoreTextChanged() {
    teamBPenaltyScoreText.value = teamBPenaltyScoreController.text;
    _markDraftChanged();
  }

  bool _validatePenaltyShootout({required int scoreA, required int scoreB}) {
    if (!isKnockoutMatch || scoreA != scoreB) return true;
    final penaltyScoreA = _parsedTeamScore(teamAPenaltyScoreController.text);
    final penaltyScoreB = _parsedTeamScore(teamBPenaltyScoreController.text);
    final shootout = penaltyScoreA == null || penaltyScoreB == null
        ? null
        : PenaltyShootoutResult(
            scoreTeamA: penaltyScoreA,
            scoreTeamB: penaltyScoreB,
          );
    if (shootout?.isValid == true) return true;

    errorMessage.value = penaltyScoreA != null && penaltyScoreA == penaltyScoreB
        ? 'ركلات الترجيح لا يمكن أن تنتهي بالتعادل.'
        : 'أدخل نتيجة ركلات ترجيح صحيحة بين 0 و99 لتحديد المتأهل.';
    Get.snackbar(
      'احسم المتأهل',
      errorMessage.value,
      snackPosition: SnackPosition.BOTTOM,
    );
    return false;
  }

  PenaltyShootoutResult? _penaltyShootoutForSubmission({
    required int scoreA,
    required int scoreB,
  }) {
    if (!isKnockoutMatch || scoreA != scoreB) return null;
    return PenaltyShootoutResult(
      scoreTeamA: int.parse(teamAPenaltyScoreController.text.trim()),
      scoreTeamB: int.parse(teamBPenaltyScoreController.text.trim()),
    );
  }

  int? _parsedTeamScore(String rawValue) {
    final parsed = int.tryParse(rawValue.trim());
    if (parsed == null || parsed < 0) return null;
    return parsed;
  }

  String _readableError(Object error) {
    final raw = error.toString();
    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length);
    }
    if (raw.startsWith('Bad state: ')) {
      final message = raw.substring('Bad state: '.length);
      if (message == 'settlement failed') {
        return 'تعذر تسجيل نتيجة المباراة الآن. حاول مرة أخرى.';
      }
      return message;
    }
    return raw;
  }

  int _sumGoals(List<Player> players) {
    var total = 0;
    for (final player in players) {
      total += (playerStats[player.id]?['goals'] ?? 0) as int;
    }
    return total;
  }
}
