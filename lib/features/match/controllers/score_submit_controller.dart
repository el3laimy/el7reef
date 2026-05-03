import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/enums/match_status.dart';
import '../../../core/services/match_event_service.dart';
import '../../../core/services/match_settlement_service.dart';
import '../../../core/services/official_match_roster_service.dart';
import '../../../data/repositories/match_repository_impl.dart';
import '../../../data/repositories/match_side_player_repository_impl.dart';
import '../../../data/repositories/match_side_repository_impl.dart';
import '../../../data/repositories/team_repository_impl.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/match_participant_roster.dart';
import '../../../domain/entities/match_side.dart';
import '../../../domain/entities/match_side_player.dart';
import '../../../domain/entities/participant_ref.dart';
import '../../../domain/entities/player.dart';
import '../../../domain/entities/player_match_stats.dart';
import '../../../domain/entities/team.dart';
import '../../../services/auth_service.dart';
import '../models/friendly_match_side_view.dart';
import 'match_controller.dart';

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

class ScoreSubmitController extends GetxController {
  final String matchId;
  final MatchRepositoryImpl _matchRepo;
  final MatchSettlementService _settlementService;
  final MatchEventService _matchEventService;
  final OfficialMatchRosterService _officialRosterService;
  final MatchSideRepositoryImpl _sideRepository;
  final MatchSidePlayerRepositoryImpl _sidePlayerRepository;
  final TeamRepositoryImpl _teamRepository;
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
       _currentUserIdProvider =
           currentUserIdProvider ??
           (() => Get.find<AuthService>().currentUserId);

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
  final RxString selectedMvpId = ''.obs;
  final RxBool teamACleanSheet = false.obs;
  final RxBool teamBCleanSheet = false.obs;
  final TextEditingController teamAScoreController = TextEditingController();
  final TextEditingController teamBScoreController = TextEditingController();

  bool get isFriendlyMatch => match.value?.tournamentId == null;
  List<ParticipantRef> get teamAParticipants =>
      fullParticipantRoster.value?.sideA ?? const <ParticipantRef>[];
  List<ParticipantRef> get teamBParticipants =>
      fullParticipantRoster.value?.sideB ?? const <ParticipantRef>[];
  List<ParticipantRef> get allParticipants =>
      fullParticipantRoster.value?.allParticipants ?? const <ParticipantRef>[];
  List<ScoreSubmitGoalDraft> get allGoalDrafts =>
      goalDrafts.toList(growable: false);

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

      match.value = loadedMatch;
      selectedMvpId.value = loadedMatch.mvpPlayerId ?? '';
      teamAScoreController.text = loadedMatch.scoreTeamA?.toString() ?? '';
      teamBScoreController.text = loadedMatch.scoreTeamB?.toString() ?? '';
      await _loadFriendlySideNames(loadedMatch);

      final roster = await _officialRosterService.loadRegisteredRoster(
        matchId: loadedMatch.id,
        match: loadedMatch,
      );
      teamAPlayers.value = roster.teamAPlayers;
      teamBPlayers.value = roster.teamBPlayers;
      await _loadFullParticipantRoster(loadedMatch);

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

  @override
  void onClose() {
    teamAScoreController.dispose();
    teamBScoreController.dispose();
    super.onClose();
  }

  void selectMvp(String participantId) {
    selectedMvpId.value = participantId.trim();
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
  }

  void clearParticipantGoals(ParticipantRef participant) {
    final key = participantRosterKey(participant);
    goalDrafts.removeWhere((draft) => participantRosterKey(draft.actor) == key);
  }

  void clearGoalDrafts() {
    goalDrafts.clear();
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
  }

  void decrementStat(String playerId, String key) {
    if (!playerStats.containsKey(playerId)) return;
    final current = playerStats[playerId]![key] as int;
    if (current > 0) {
      playerStats[playerId]![key] = current - 1;
    }
  }

  void toggleCard(String playerId, String cardType) {
    if (!playerStats.containsKey(playerId)) return;
    playerStats[playerId]![cardType] =
        !(playerStats[playerId]![cardType] as bool);
  }

  int get totalTeamAGoals => isFriendlyMatch
      ? _parsedTeamScore(teamAScoreController.text) ?? 0
      : _sumGoals(teamAPlayers);

  int get totalTeamBGoals => isFriendlyMatch
      ? _parsedTeamScore(teamBScoreController.text) ?? 0
      : _sumGoals(teamBPlayers);

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
    final normalizedSelectedMvpId = selectedMvpId.value.trim();

    final scoreA = isFriendlyMatch
        ? _validatedFriendlyScore(
            teamAScoreController.text,
            teamASideName.value,
          )
        : totalTeamAGoals;
    if (scoreA == null) return null;
    final scoreB = isFriendlyMatch
        ? _validatedFriendlyScore(
            teamBScoreController.text,
            teamBSideName.value,
          )
        : totalTeamBGoals;
    if (scoreB == null) return null;

    teamACleanSheet.value = scoreB == 0;
    teamBCleanSheet.value = scoreA == 0;

    // goalDrafts are ParticipantRef-based pride data written best-effort below;
    // detailedStats stays registered-player-only for the current rating path.
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

    try {
      isLoading.value = true;
      final result = await _settlementService.submitScore(
        matchId: currentMatch.id,
        actorId: actorId,
        scoreA: scoreA,
        scoreB: scoreB,
        mvpPlayerId: normalizedSelectedMvpId.isEmpty
            ? null
            : normalizedSelectedMvpId,
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
            mvpPlayerId: normalizedSelectedMvpId.isEmpty
                ? null
                : normalizedSelectedMvpId,
            status: result.status,
          );
      match.value = updatedMatch;
      await _recordMvpMatchEventIfPossible(
        submittedMatch: updatedMatch,
        selectedMvpId: normalizedSelectedMvpId,
        actorId: actorId,
      );
      await _recordGoalMatchEventsIfPossible(
        submittedMatch: updatedMatch,
        actorId: actorId,
      );

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

  Future<void> _recordGoalMatchEventsIfPossible({
    required Match submittedMatch,
    required String actorId,
  }) async {
    final drafts = allGoalDrafts.where((draft) => draft.goals > 0).toList();
    if (drafts.isEmpty) return;

    try {
      final activeEvents = await _matchEventService.getMatchEvents(
        submittedMatch.id,
      );
      for (final event in activeEvents) {
        if (event.isGoal) {
          await _matchEventService.voidEvent(event.id);
        }
      }

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
    } catch (_) {
      // Score submission has already succeeded; goal event persistence can be
      // retried by a later integration without breaking the existing result.
    }
  }

  Future<void> _recordMvpMatchEventIfPossible({
    required Match submittedMatch,
    required String selectedMvpId,
    required String actorId,
  }) async {
    if (selectedMvpId.isEmpty) return;
    final resolved = _resolveMvpParticipant(selectedMvpId);
    if (resolved == null) return;

    try {
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
        sideKey: resolved.sideKey,
        actor: resolved.actor,
        createdBy: actorId,
      );
    } catch (_) {
      // Score submission has already succeeded; MVP event persistence can be
      // retried by a later integration without breaking the existing result.
    }
  }

  ({ParticipantRef actor, String sideKey})? _resolveMvpParticipant(
    String selectedMvpId,
  ) {
    final roster = fullParticipantRoster.value;
    if (roster == null) return null;

    final matches = <({ParticipantRef actor, String sideKey})>[
      for (final participant in roster.sideA)
        if (participant.id == selectedMvpId) (actor: participant, sideKey: 'A'),
      for (final participant in roster.sideB)
        if (participant.id == selectedMvpId) (actor: participant, sideKey: 'B'),
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

  int? _validatedFriendlyScore(String rawValue, String sideName) {
    final trimmed = rawValue.trim();
    final parsed = int.tryParse(trimmed);
    if (trimmed.isEmpty || parsed == null || parsed < 0) {
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
