part of 'score_submit_controller.dart';

extension ScoreSubmitHelpers on ScoreSubmitController {
  int? _validatedScoreForSide({
    required String rawValue,
    required String sideName,
    required String sideKey,
  }) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return _attributedGoalsForSide(sideKey);
    }
    final parsed = int.tryParse(trimmed);
    if (parsed == null || parsed < 0) {
      final message = 'أدخل نتيجة صحيحة وغير سالبة لـ $sideName.';
      errorMessage.value = message;
      Get.snackbar(
        'نتيجة غير صحيحة',
        message,
        snackPosition: SnackPosition.BOTTOM,
      );
      return null;
    }
    return parsed;
  }

  bool _validateAttributedGoalsWithinScore({
    required int scoreA,
    required int scoreB,
  }) {
    final attributedA = _attributedGoalsForSide('A');
    final attributedB = _attributedGoalsForSide('B');
    if (attributedA <= scoreA && attributedB <= scoreB) {
      return true;
    }

    errorMessage.value = ScoreSubmitController.attributionOverScoreMessage;
    Get.snackbar(
      'نتيجة غير متسقة',
      errorMessage.value,
      snackPosition: SnackPosition.BOTTOM,
    );
    return false;
  }

  ScoreSideGoalSummary _goalSummaryForSide(String sideKey) {
    final normalizedSideKey = sideKey.trim().toUpperCase();
    final scoreText = normalizedSideKey == 'A'
        ? teamAScoreText.value
        : normalizedSideKey == 'B'
        ? teamBScoreText.value
        : '';
    final attributedGoals = _attributedGoalsForSide(normalizedSideKey);
    final parsedScore = _parsedTeamScore(scoreText);
    return ScoreSideGoalSummary(
      sideKey: normalizedSideKey,
      teamScore: parsedScore ?? attributedGoals,
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

  void _handleTeamAScoreTextChanged() {
    teamAScoreText.value = teamAScoreController.text;
  }

  void _handleTeamBScoreTextChanged() {
    teamBScoreText.value = teamBScoreController.text;
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
      return raw.substring('Bad state: '.length);
    }
    return raw;
  }

  PlayerMatchStats _buildDetailedStats({
    required Player player,
    required String teamId,
    required bool cleanSheet,
  }) {
    final stats = playerStats[player.id]!;
    return PlayerMatchStats(
      playerId: player.id,
      matchId: matchId,
      teamId: teamId,
      played: stats['played'] as bool,
      position: _mapPosition(player.position),
      goals: stats['goals'] as int,
      assists: stats['assists'] as int,
      saves: stats['saves'] as int,
      yellowCard: stats['yellowCard'] as bool,
      redCard: stats['redCard'] as bool,
      cleanSheet: cleanSheet,
    );
  }

  MatchPosition _mapPosition(String? position) {
    switch (position) {
      case 'GK':
        return MatchPosition.goalkeeper;
      case 'DEF':
        return MatchPosition.defender;
      case 'MID':
        return MatchPosition.midfielder;
      case 'FWD':
        return MatchPosition.forward;
      default:
        return MatchPosition.mixed;
    }
  }

  int _sumGoals(List<Player> players) {
    var total = 0;
    for (final player in players) {
      total += (playerStats[player.id]?['goals'] ?? 0) as int;
    }
    return total;
  }
}
