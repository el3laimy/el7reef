import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/enums/match_status.dart';
import '../../../core/services/match_event_service.dart';
import '../../../core/services/match_settlement_service.dart';
import '../../../core/services/official_match_roster_service.dart';
import '../../../core/services/pending_pride_events_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/repositories/match_repository_impl.dart';
import '../../../data/repositories/match_side_player_repository_impl.dart';
import '../../../data/repositories/match_side_repository_impl.dart';
import '../../../data/repositories/team_repository_impl.dart';
import '../../../data/repositories/tournament_assistant_permission_repository_impl.dart';
import '../../../data/repositories/tournament_repository_impl.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/match_participant_roster.dart';
import '../../../domain/entities/match_side.dart';
import '../../../domain/entities/match_side_player.dart';
import '../../../domain/entities/participant_ref.dart';
import '../../../domain/entities/player.dart';
import '../../../domain/entities/player_match_stats.dart';
import '../../../domain/entities/team.dart';
import '../../../domain/entities/tournament_assistant_permission.dart';
import '../../../core/auth/auth_service.dart';
import '../models/friendly_match_side_view.dart';
import 'match_controller.dart';

part 'score_submit_pride_events.dart';
part 'score_submit_helpers.dart';

class ScoreSubmitGoalDraft {
  final ParticipantRef actor;
  final String sideKey;
  final int goals;
  final int? minute;

  const ScoreSubmitGoalDraft({
    required this.actor,
    required this.sideKey,
    required this.goals,
    this.minute,
  });
}

class ScoreSideGoalSummary {
  final String sideKey;
  final int teamScore;
  final int attributedGoals;

  const ScoreSideGoalSummary({
    required this.sideKey,
    required this.teamScore,
    required this.attributedGoals,
  });

  int get unattributedGoals =>
      teamScore > attributedGoals ? teamScore - attributedGoals : 0;

  int get overAttributedGoals =>
      attributedGoals > teamScore ? attributedGoals - teamScore : 0;

  bool get hasUnattributedGoals => unattributedGoals > 0;
  bool get isOverAttributed => overAttributedGoals > 0;
}

class ScoreSubmitController extends GetxController {
  static const String attributionOverScoreMessage =
      'عدد الأهداف المنسوبة أكبر من نتيجة الفريق.';
  static const String prideEventWriteFailureMessage =
      'تم حفظ النتيجة، لكن فشل تسجيل أحداث الأهداف أو أفضل لاعب. حاول مرة أخرى قبل مشاركة النتيجة.';

  final String matchId;
  final MatchRepositoryImpl _matchRepo;
  final MatchSettlementService _settlementService;
  final MatchEventService _matchEventService;
  final OfficialMatchRosterService _officialRosterService;
  final MatchSideRepositoryImpl _sideRepository;
  final MatchSidePlayerRepositoryImpl _sidePlayerRepository;
  final TeamRepositoryImpl _teamRepository;
  final TournamentRepositoryImpl _tournamentRepository;
  final TournamentAssistantPermissionRepositoryImpl _assistantPermissionRepo;
  final PendingPrideEventsService _pendingPrideEventsService;
  final String? Function() _currentUserIdProvider;

  ScoreSubmitController({
    required this.matchId,
    MatchRepositoryImpl? matchRepository,
    MatchSettlementService? settlementService,
    MatchEventService? matchEventService,
    OfficialMatchRosterService? officialRosterService,
    MatchSideRepositoryImpl? sideRepository,
    MatchSidePlayerRepositoryImpl? sidePlayerRepository,
    TeamRepositoryImpl? teamRepository,
    TournamentRepositoryImpl? tournamentRepository,
    TournamentAssistantPermissionRepositoryImpl? assistantPermissionRepository,
    PendingPrideEventsService? pendingPrideEventsService,
    String? Function()? currentUserIdProvider,
  }) : _matchRepo = matchRepository ?? MatchRepositoryImpl(),
       _settlementService = settlementService ?? MatchSettlementService(),
       _matchEventService = matchEventService ?? MatchEventService(),
       _officialRosterService =
           officialRosterService ?? OfficialMatchRosterService(),
       _sideRepository = sideRepository ?? MatchSideRepositoryImpl(),
       _sidePlayerRepository =
           sidePlayerRepository ?? MatchSidePlayerRepositoryImpl(),
       _teamRepository = teamRepository ?? TeamRepositoryImpl(),
       _tournamentRepository =
           tournamentRepository ?? TournamentRepositoryImpl(),
       _assistantPermissionRepo =
           assistantPermissionRepository ??
           TournamentAssistantPermissionRepositoryImpl(),
       _pendingPrideEventsService =
           pendingPrideEventsService ?? PendingPrideEventsService(),
       _currentUserIdProvider =
           currentUserIdProvider ??
           (() => Get.find<AuthService>().currentUserId) {
    teamAScoreController.addListener(_handleTeamAScoreTextChanged);
    teamBScoreController.addListener(_handleTeamBScoreTextChanged);
  }

  final Rx<Match?> match = Rx<Match?>(null);
  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;

  final RxList<Player> teamAPlayers = <Player>[].obs;
  final RxList<Player> teamBPlayers = <Player>[].obs;
  final Rx<MatchParticipantRoster?> fullParticipantRoster =
      Rx<MatchParticipantRoster?>(null);
  final RxString fullRosterErrorMessage = ''.obs;
  final RxString teamASideName = 'فريق A'.obs;
  final RxString teamBSideName = 'فريق B'.obs;
  final Map<String, RxMap<String, dynamic>> playerStats = {};
  final RxList<ScoreSubmitGoalDraft> goalDrafts = <ScoreSubmitGoalDraft>[].obs;
  final RxString selectedMvpKey = ''.obs;
  final RxBool teamACleanSheet = false.obs;
  final RxBool teamBCleanSheet = false.obs;
  final TextEditingController teamAScoreController = TextEditingController();
  final TextEditingController teamBScoreController = TextEditingController();
  final RxString teamAScoreText = ''.obs;
  final RxString teamBScoreText = ''.obs;
  final RxBool pendingPrideEventRetry = false.obs;
  final Map<String, String> _lastSyncedScoreText = {'A': '', 'B': ''};

  bool get isFriendlyMatch => match.value?.tournamentId == null;
  List<ParticipantRef> get teamAParticipants =>
      fullParticipantRoster.value?.sideA ?? const <ParticipantRef>[];
  List<ParticipantRef> get teamBParticipants =>
      fullParticipantRoster.value?.sideB ?? const <ParticipantRef>[];
  List<ParticipantRef> get allParticipants =>
      fullParticipantRoster.value?.allParticipants ?? const <ParticipantRef>[];
  List<ParticipantRef> get teamAScoringParticipants => teamAParticipants;
  List<ParticipantRef> get teamBScoringParticipants => teamBParticipants;
  List<ScoreSubmitGoalDraft> get allGoalDrafts =>
      goalDrafts.toList(growable: false);
  ScoreSideGoalSummary get teamAGoalSummary => _goalSummaryForSide('A');
  ScoreSideGoalSummary get teamBGoalSummary => _goalSummaryForSide('B');
  bool get hasAnyAttributedGoals =>
      teamAGoalSummary.attributedGoals + teamBGoalSummary.attributedGoals > 0;
  bool get hasAnyUnattributedGoals =>
      teamAGoalSummary.hasUnattributedGoals ||
      teamBGoalSummary.hasUnattributedGoals;
  bool get hasAnyOverAttributedGoals =>
      teamAGoalSummary.isOverAttributed || teamBGoalSummary.isOverAttributed;

  @Deprecated('Use selectedMvpKey, which stores kind:id participant keys.')
  RxString get selectedMvpId => selectedMvpKey;

  @override
  void onInit() {
    super.onInit();
    loadMatchAndPlayers();
  }

  Future<void> loadMatchAndPlayers() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      fullRosterErrorMessage.value = '';

      final loadedMatch = await _matchRepo.getMatch(matchId);
      if (loadedMatch == null) {
        errorMessage.value = 'تعذر العثور على المباراة';
        return;
      }
      if (loadedMatch.status == MatchStatus.cancelled) {
        errorMessage.value = 'هذه المباراة ملغاة ولا يمكن تسجيل نتيجة لها.';
        return;
      }
      if (!await _canCurrentUserSubmitScore(loadedMatch)) {
        errorMessage.value = 'لا تملك صلاحية تسجيل نتيجة هذه المباراة.';
        return;
      }

      match.value = loadedMatch;
      pendingPrideEventRetry.value = loadedMatch.prideEventsPending;
      selectedMvpKey.value = '';
      _setScoreControllerText(
        sideKey: 'A',
        text: loadedMatch.scoreTeamA?.toString() ?? '',
      );
      _setScoreControllerText(
        sideKey: 'B',
        text: loadedMatch.scoreTeamB?.toString() ?? '',
      );
      await _loadFriendlySideNames(loadedMatch);

      final roster = await _officialRosterService.loadRegisteredRoster(
        matchId: loadedMatch.id,
        match: loadedMatch,
      );
      teamAPlayers.value = roster.teamAPlayers;
      teamBPlayers.value = roster.teamBPlayers;
      await _loadFullParticipantRoster(loadedMatch);
      _selectExistingMvpIfPossible(loadedMatch.mvpPlayerId);

      for (final player in [...teamAPlayers, ...teamBPlayers]) {
        playerStats[player.id] = <String, dynamic>{
          'goals': 0,
          'assists': 0,
          'saves': 0,
          'yellowCard': false,
          'redCard': false,
          'played': true,
        }.obs;
      }
    } catch (error) {
      errorMessage.value = 'حدث خطأ أثناء تحميل المباراة: $error';
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> _canCurrentUserSubmitScore(Match loadedMatch) async {
    final actorId = _currentUserIdProvider();
    if (actorId == null || actorId.isEmpty) {
      return false;
    }
    if (loadedMatch.organizerId == actorId) {
      return true;
    }
    final tournamentId = loadedMatch.tournamentId;
    if (tournamentId == null || tournamentId.isEmpty) {
      return false;
    }
    final tournament = await _tournamentRepository.getTournament(tournamentId);
    if (tournament == null) {
      return false;
    }
    if (tournament.organizerId == actorId) {
      return true;
    }
    final assistantPermission = await _assistantPermissionRepo
        .getAssistantPermission(tournament.id, actorId);
    return assistantPermission != null &&
        assistantPermission.hasPermission(
          TournamentAssistantPermissionKey.canSubmitScore,
        ) &&
        assistantPermission.hasPermission(
          TournamentAssistantPermissionKey.canRecordGoalsAndMvp,
        );
  }

  @override
  void onClose() {
    teamAScoreController.removeListener(_handleTeamAScoreTextChanged);
    teamBScoreController.removeListener(_handleTeamBScoreTextChanged);
    teamAScoreController.dispose();
    teamBScoreController.dispose();
    super.onClose();
  }

  String participantKey(ParticipantRef participant) {
    return participantRosterKey(participant);
  }

  void selectMvp(String participantKey) {
    selectedMvpKey.value = participantKey.trim();
  }

  void _selectExistingMvpIfPossible(String? rawMvpId) {
    final normalized = rawMvpId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return;
    }
    final matches = allParticipants
        .where((participant) => participant.id == normalized)
        .toList(growable: false);
    if (matches.length == 1) {
      selectedMvpKey.value = participantKey(matches.single);
    }
  }

  bool isParticipantOnSide(ParticipantRef participant, String sideKey) {
    return fullParticipantRoster.value?.isParticipantOnSide(
          participant: participant,
          sideKey: sideKey,
        ) ??
        false;
  }

  String? sideKeyForParticipant(ParticipantRef participant) {
    return fullParticipantRoster.value?.sideKeyFor(participant);
  }

  void setParticipantGoals(ParticipantRef participant, int goals) {
    if (goals <= 0) {
      clearParticipantGoals(participant);
      return;
    }
    final sideKey = sideKeyForParticipant(participant);
    if (sideKey == null) return;

    final key = participantRosterKey(participant);
    final existingIndex = goalDrafts.indexWhere(
      (draft) => participantRosterKey(draft.actor) == key,
    );
    final draft = ScoreSubmitGoalDraft(
      actor: _rosterParticipantFor(participant, sideKey) ?? participant,
      sideKey: sideKey,
      goals: goals,
    );
    if (existingIndex == -1) {
      goalDrafts.add(draft);
    } else {
      goalDrafts[existingIndex] = draft;
    }
    _syncRegisteredGoalStat(participant, goals);
    _syncScoreControllerForSide(sideKey);
  }

  void clearParticipantGoals(ParticipantRef participant) {
    final key = participantRosterKey(participant);
    final sideKey = sideKeyForParticipant(participant);
    goalDrafts.removeWhere((draft) => participantRosterKey(draft.actor) == key);
    _syncRegisteredGoalStat(participant, 0);
    if (sideKey != null) {
      _syncScoreControllerForSide(sideKey);
    }
  }

  void clearGoalDrafts() {
    goalDrafts.clear();
    for (final playerId in playerStats.keys) {
      playerStats[playerId]?['goals'] = 0;
    }
    _syncScoreControllerForSide('A');
    _syncScoreControllerForSide('B');
  }

  List<ScoreSubmitGoalDraft> goalDraftsForSide(String sideKey) {
    final normalizedSideKey = sideKey.trim().toUpperCase();
    if (normalizedSideKey != 'A' && normalizedSideKey != 'B') {
      return const <ScoreSubmitGoalDraft>[];
    }
    return goalDrafts
        .where((draft) => draft.sideKey == normalizedSideKey)
        .toList(growable: false);
  }

  int totalDraftGoalsForSide(String sideKey) {
    return goalDraftsForSide(
      sideKey,
    ).fold(0, (total, draft) => total + draft.goals);
  }

  int goalsForParticipant(ParticipantRef participant) {
    final key = participantRosterKey(participant);
    final draft = goalDrafts.firstWhereOrNull(
      (item) => participantRosterKey(item.actor) == key,
    );
    if (draft != null) return draft.goals;
    if (participant.kind == ParticipantRefKind.player &&
        playerStats.containsKey(participant.id)) {
      return playerStats[participant.id]?['goals'] as int? ?? 0;
    }
    return 0;
  }

  void incrementParticipantGoals(ParticipantRef participant) {
    setParticipantGoals(participant, goalsForParticipant(participant) + 1);
  }

  void decrementParticipantGoals(ParticipantRef participant) {
    final current = goalsForParticipant(participant);
    if (current <= 0) return;
    setParticipantGoals(participant, current - 1);
  }

  bool goalDraftMismatchForSide(String sideKey) {
    final normalizedSideKey = sideKey.trim().toUpperCase();
    final score = normalizedSideKey == 'A'
        ? totalTeamAGoals
        : normalizedSideKey == 'B'
        ? totalTeamBGoals
        : null;
    if (score == null) return false;
    return totalDraftGoalsForSide(normalizedSideKey) != score;
  }

  void incrementStat(String playerId, String key) {
    if (!playerStats.containsKey(playerId)) return;
    playerStats[playerId]![key] = (playerStats[playerId]![key] as int) + 1;
    if (key == 'goals') {
      _syncRegisteredGoalDraft(playerId);
    }
  }

  void decrementStat(String playerId, String key) {
    if (!playerStats.containsKey(playerId)) return;
    final current = playerStats[playerId]![key] as int;
    if (current > 0) {
      playerStats[playerId]![key] = current - 1;
      if (key == 'goals') {
        _syncRegisteredGoalDraft(playerId);
      }
    }
  }

  void toggleCard(String playerId, String cardType) {
    if (!playerStats.containsKey(playerId)) return;
    playerStats[playerId]![cardType] =
        !(playerStats[playerId]![cardType] as bool);
  }

  int get totalTeamAGoals => teamAGoalSummary.teamScore;

  int get totalTeamBGoals => teamBGoalSummary.teamScore;

  Future<Match?> submit() async {
    final currentMatch = match.value;
    if (currentMatch == null) return null;
    final actorId = _currentUserIdProvider();
    if (actorId == null || actorId.isEmpty) {
      errorMessage.value = 'يجب تسجيل الدخول أولاً لتسجيل النتيجة.';
      Get.snackbar(
        'غير مسموح',
        errorMessage.value,
        snackPosition: SnackPosition.BOTTOM,
      );
      return null;
    }

    if (pendingPrideEventRetry.value && _hasSubmittedScore(currentMatch)) {
      return _retryPrideEventWrites(
        submittedMatch: currentMatch,
        actorId: actorId,
      );
    }

    final normalizedSelectedMvpKey = selectedMvpKey.value.trim();
    final resolvedMvp = _resolveMvpParticipant(normalizedSelectedMvpKey);
    if (normalizedSelectedMvpKey.isNotEmpty && resolvedMvp == null) {
      errorMessage.value = 'تعذر تحديد أفضل لاعب من قائمة المشاركين الحالية.';
      Get.snackbar(
        'اختيار غير صحيح',
        errorMessage.value,
        snackPosition: SnackPosition.BOTTOM,
      );
      return null;
    }

    final scoreA = _validatedScoreForSide(
      rawValue: teamAScoreController.text,
      sideName: teamASideName.value,
      sideKey: 'A',
    );
    if (scoreA == null) return null;
    final scoreB = _validatedScoreForSide(
      rawValue: teamBScoreController.text,
      sideName: teamBSideName.value,
      sideKey: 'B',
    );
    if (scoreB == null) return null;
    if (!_validateAttributedGoalsWithinScore(scoreA: scoreA, scoreB: scoreB)) {
      return null;
    }

    teamACleanSheet.value = scoreB == 0;
    teamBCleanSheet.value = scoreA == 0;

    final detailedStats = <PlayerMatchStats>[
      ...teamAPlayers.map(
        (player) => _buildDetailedStats(
          player: player,
          teamId: currentMatch.teamAId ?? 'A',
          cleanSheet: teamACleanSheet.value,
        ),
      ),
      ...teamBPlayers.map(
        (player) => _buildDetailedStats(
          player: player,
          teamId: currentMatch.teamBId ?? 'B',
          cleanSheet: teamBCleanSheet.value,
        ),
      ),
    ];

    var pendingPayloadSaved = false;
    try {
      isLoading.value = true;
      await _pendingPrideEventsService.savePayload(
        _buildPendingPridePayload(
          matchId: currentMatch.id,
          scoreA: scoreA,
          scoreB: scoreB,
          resolvedMvp: resolvedMvp,
          actorId: actorId,
        ),
      );
      pendingPayloadSaved = true;

      final result = await _settlementService.submitScore(
        matchId: currentMatch.id,
        actorId: actorId,
        scoreA: scoreA,
        scoreB: scoreB,
        mvpPlayerId: resolvedMvp?.actor.id,
        detailedStats: detailedStats,
      );

      if (Get.isRegistered<MatchController>()) {
        await Get.find<MatchController>().loadLiveMatches();
        await Get.find<MatchController>().loadMyMatches();
      }

      final updatedMatch =
          await _matchRepo.getMatch(currentMatch.id) ??
          currentMatch.copyWith(
            scoreTeamA: scoreA,
            scoreTeamB: scoreB,
            mvpPlayerId: resolvedMvp?.actor.id,
            prideEventsPending: true,
            status: result.status,
          );
      match.value = updatedMatch;
      try {
        await _recordPrideEventsOrThrow(
          submittedMatch: updatedMatch,
          resolvedMvp: resolvedMvp,
          actorId: actorId,
        );
        await _clearPrideEventRetryState(updatedMatch);
      } catch (error, stackTrace) {
        AppLogger.error(
          'ScoreSubmitController.submitScore.recordPrideEvents',
          error,
          stackTrace,
        );
        _surfacePrideEventFailure();
        return null;
      }

      if (result.status == MatchStatus.pendingReview) {
        Get.snackbar(
          'تحت المراجعة',
          'تم حفظ النتيجة، لكنها تحتاج مراجعة بسبب الشذوذ الظاهر.',
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        Get.snackbar(
          'تم الحفظ',
          'تم تسجيل النتيجة وفتح تصويت الجماهير قبل الاعتماد النهائي.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }

      return updatedMatch;
    } catch (error) {
      if (pendingPayloadSaved) {
        await _clearPendingPridePayloadQuietly(currentMatch.id);
      }
      errorMessage.value = 'فشل حفظ النتيجة: ${_readableError(error)}';
      Get.snackbar(
        'خطأ',
        errorMessage.value,
        snackPosition: SnackPosition.BOTTOM,
      );
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadFullParticipantRoster(Match loadedMatch) async {
    try {
      final roster = await _officialRosterService.loadParticipantRoster(
        matchId: loadedMatch.id,
        match: loadedMatch,
      );
      fullParticipantRoster.value = roster;
      fullRosterErrorMessage.value = '';
    } catch (error) {
      fullParticipantRoster.value = null;
      fullRosterErrorMessage.value =
          'تعذر تحميل قائمة المشاركين الكاملة: ${_readableError(error)}';
    }
  }

  Future<void> _clearPrideEventRetryState(Match submittedMatch) async {
    final clearedMatch = submittedMatch.copyWith(prideEventsPending: false);
    try {
      await _matchRepo.updatePrideEventsPending(
        matchId: submittedMatch.id,
        isPending: false,
      );
      await _clearPendingPridePayloadQuietly(submittedMatch.id);
      match.value = clearedMatch;
      pendingPrideEventRetry.value = false;
    } catch (error, stackTrace) {
      AppLogger.error(
        'ScoreSubmitController._clearPrideEventRetryState',
        error,
        stackTrace,
      );
      match.value = submittedMatch.copyWith(prideEventsPending: true);
      pendingPrideEventRetry.value = true;
    }
  }

  PendingPrideEventsPayload _buildPendingPridePayload({
    required String matchId,
    required int scoreA,
    required int scoreB,
    required ({ParticipantRef actor, String sideKey})? resolvedMvp,
    required String actorId,
  }) {
    return PendingPrideEventsPayload(
      matchId: matchId,
      scoreTeamA: scoreA,
      scoreTeamB: scoreB,
      goals: allGoalDrafts
          .where((draft) => draft.goals > 0)
          .map(
            (draft) => PendingPrideGoalDraft(
              sideKey: draft.sideKey,
              actor: draft.actor,
              goals: draft.goals,
              minute: draft.minute,
            ),
          )
          .toList(growable: false),
      mvp: resolvedMvp == null
          ? null
          : PendingPrideMvpDraft(
              sideKey: resolvedMvp.sideKey,
              actor: resolvedMvp.actor,
            ),
      createdBy: actorId,
      createdAt: DateTime.now(),
    );
  }

  Future<void> _clearPendingPridePayloadQuietly(String matchId) async {
    try {
      await _pendingPrideEventsService.clearPayload(matchId);
    } catch (error, stackTrace) {
      AppLogger.error(
        'ScoreSubmitController._clearPendingPridePayloadQuietly',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _loadFriendlySideNames(Match loadedMatch) async {
    if (loadedMatch.tournamentId != null) {
      teamASideName.value = 'فريق A';
      teamBSideName.value = 'فريق B';
      return;
    }
    final teamIds = <String>[
      if (loadedMatch.teamAId != null && loadedMatch.teamAId!.isNotEmpty)
        loadedMatch.teamAId!,
      if (loadedMatch.teamBId != null && loadedMatch.teamBId!.isNotEmpty)
        loadedMatch.teamBId!,
    ];
    final results = await Future.wait<dynamic>([
      _teamRepository.getTeamsByIds(teamIds),
      _sideRepository.getMatchSides(loadedMatch.id),
      _sidePlayerRepository.getMatchPlayers(loadedMatch.id),
    ]);
    final teams = results[0] as List<Team>;
    final sides = results[1] as List<MatchSide>;
    final sidePlayers = results[2] as List<MatchSidePlayer>;
    final sideViews = FriendlyMatchSideView.fromMatch(
      match: loadedMatch,
      teamsById: {for (final team in teams) team.id: team},
      sides: sides,
      sidePlayers: sidePlayers,
    );
    for (final side in sideViews) {
      if (side.sideKey == 'A') {
        teamASideName.value = side.displayName;
      } else if (side.sideKey == 'B') {
        teamBSideName.value = side.displayName;
      }
    }
  }
}
