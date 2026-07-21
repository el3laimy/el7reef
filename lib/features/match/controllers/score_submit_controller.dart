import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/enums/match_status.dart';
import '../../../core/enums/tournament_ops_enums.dart';
import '../../../core/services/match_settlement_service.dart';
import '../../../core/services/claimed_participant_identity_resolver.dart';
import '../../../core/services/official_match_roster_service.dart';
import '../../../core/services/pending_pride_events_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/repositories/match_repository_impl.dart';
import '../../../data/repositories/match_side_player_repository_impl.dart';
import '../../../data/repositories/match_side_repository_impl.dart';
import '../../../data/repositories/team_repository_impl.dart';
import '../../../data/repositories/tournament_assistant_permission_repository_impl.dart';
import '../../../data/repositories/tournament_participant_repository_impl.dart';
import '../../../data/repositories/tournament_repository_impl.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/penalty_shootout_result.dart';
import '../../../domain/entities/match_participant_roster.dart';
import '../../../domain/entities/match_side.dart';
import '../../../domain/entities/match_side_player.dart';
import '../../../domain/entities/participant_ref.dart';
import '../../../domain/entities/player.dart';
import '../../../domain/entities/team.dart';
import '../../../domain/entities/tournament_assistant_permission.dart';
import '../../../core/auth/auth_service.dart';
import '../models/friendly_match_side_view.dart';
import '../models/score_submit_draft.dart';
import '../models/score_submit_models.dart';
import '../services/score_submit_preparation.dart';
import '../services/score_submit_draft_store.dart';
import 'match_controller.dart';

export '../models/score_submit_models.dart';

part 'score_submit_pride_events.dart';
part 'score_submit_helpers.dart';
part 'score_submit_draft_ops.dart';

class ScoreSubmitController extends GetxController {
  static const String attributionOverScoreMessage =
      ScoreSubmitPreparation.attributionOverScoreMessage;
  static const String prideEventWriteFailureMessage =
      'تم حفظ النتيجة، لكن فشل تسجيل أحداث الأهداف أو أفضل لاعب. حاول مرة أخرى قبل مشاركة النتيجة.';

  final String matchId;
  final MatchRepositoryImpl _matchRepo;
  final MatchSettlementService _settlementService;
  final OfficialMatchRosterService _officialRosterService;
  final MatchSideRepositoryImpl _sideRepository;
  final MatchSidePlayerRepositoryImpl _sidePlayerRepository;
  final TeamRepositoryImpl _teamRepository;
  final TournamentParticipantRepositoryImpl _participantRepository;
  final TournamentRepositoryImpl _tournamentRepository;
  final TournamentAssistantPermissionRepositoryImpl _assistantPermissionRepo;
  final PendingPrideEventsService _pendingPrideEventsService;
  final ScoreSubmitDraftStore _draftStore;
  final String? Function() _currentUserIdProvider;

  ScoreSubmitController({
    required this.matchId,
    MatchRepositoryImpl? matchRepository,
    MatchSettlementService? settlementService,
    OfficialMatchRosterService? officialRosterService,
    MatchSideRepositoryImpl? sideRepository,
    MatchSidePlayerRepositoryImpl? sidePlayerRepository,
    TeamRepositoryImpl? teamRepository,
    TournamentParticipantRepositoryImpl? participantRepository,
    TournamentRepositoryImpl? tournamentRepository,
    TournamentAssistantPermissionRepositoryImpl? assistantPermissionRepository,
    PendingPrideEventsService? pendingPrideEventsService,
    ScoreSubmitDraftStore? draftStore,
    String? Function()? currentUserIdProvider,
  }) : _matchRepo = matchRepository ?? MatchRepositoryImpl(),
       _settlementService = settlementService ?? MatchSettlementService(),
       _officialRosterService =
           officialRosterService ?? OfficialMatchRosterService(),
       _sideRepository = sideRepository ?? MatchSideRepositoryImpl(),
       _sidePlayerRepository =
           sidePlayerRepository ?? MatchSidePlayerRepositoryImpl(),
       _teamRepository = teamRepository ?? TeamRepositoryImpl(),
       _participantRepository =
           participantRepository ?? TournamentParticipantRepositoryImpl(),
       _tournamentRepository =
           tournamentRepository ?? TournamentRepositoryImpl(),
       _assistantPermissionRepo =
           assistantPermissionRepository ??
           TournamentAssistantPermissionRepositoryImpl(),
       _pendingPrideEventsService =
           pendingPrideEventsService ?? PendingPrideEventsService(),
       _draftStore = draftStore ?? SharedPreferencesScoreSubmitDraftStore(),
       _currentUserIdProvider =
           currentUserIdProvider ??
           (() => Get.find<AuthService>().currentUserId) {
    teamAScoreController.addListener(_handleTeamAScoreTextChanged);
    teamBScoreController.addListener(_handleTeamBScoreTextChanged);
    teamAPenaltyScoreController.addListener(
      _handleTeamAPenaltyScoreTextChanged,
    );
    teamBPenaltyScoreController.addListener(
      _handleTeamBPenaltyScoreTextChanged,
    );
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
  final TextEditingController teamAPenaltyScoreController =
      TextEditingController();
  final TextEditingController teamBPenaltyScoreController =
      TextEditingController();
  final RxString teamAScoreText = ''.obs;
  final RxString teamBScoreText = ''.obs;
  final RxString teamAPenaltyScoreText = ''.obs;
  final RxString teamBPenaltyScoreText = ''.obs;
  final RxBool pendingPrideEventRetry = false.obs;
  final RxInt currentStepIndex = 0.obs;
  final RxBool isDirty = false.obs;
  final RxBool restoredDraft = false.obs;
  final Map<String, String> _lastSyncedScoreText = {'A': '', 'B': ''};
  Timer? _draftSaveDebounce;
  String? _sourceMatchFingerprint;
  bool _draftTrackingEnabled = false;

  bool get isFriendlyMatch => match.value?.tournamentId == null;
  bool get isKnockoutMatch =>
      match.value?.stageType == TournamentStageType.knockoutStage;
  bool get requiresPenaltyShootout {
    if (!isKnockoutMatch) return false;
    final scoreA = _parsedTeamScore(teamAScoreText.value);
    final scoreB = _parsedTeamScore(teamBScoreText.value);
    return scoreA != null && scoreB != null && scoreA == scoreB;
  }

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
  ({ParticipantRef actor, String sideKey})? get selectedMvpSelection =>
      _resolveMvpParticipant(selectedMvpKey.value.trim());
  ({ParticipantRef actor, String sideKey})? get selectedMvpShareSelection {
    final selection = selectedMvpSelection;
    if (selection == null) return null;
    return (
      actor: ClaimedParticipantIdentityResolver.canonicalizeKnownLink(
        selection.actor,
      ),
      sideKey: selection.sideKey,
    );
  }

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

  String? emptyScoringParticipantsRouteForSide(String sideKey) {
    final currentMatch = match.value;
    if (currentMatch == null) return null;

    final normalizedSideKey = sideKey.trim().toUpperCase();
    final teamId = normalizedSideKey == 'A'
        ? currentMatch.teamAId
        : normalizedSideKey == 'B'
        ? currentMatch.teamBId
        : null;

    if (teamId != null && teamId.isNotEmpty) {
      return AppRoutes.teamProfileById(teamId);
    }
    if (normalizedSideKey == 'A' || normalizedSideKey == 'B') {
      return AppRoutes.matchLobbyById(currentMatch.id);
    }
    return null;
  }

  String emptyScoringParticipantsActionLabelForSide(String sideKey) {
    final currentMatch = match.value;
    final normalizedSideKey = sideKey.trim().toUpperCase();
    final teamId = normalizedSideKey == 'A'
        ? currentMatch?.teamAId
        : normalizedSideKey == 'B'
        ? currentMatch?.teamBId
        : null;
    return teamId != null && teamId.isNotEmpty
        ? 'إدارة قائمة الفريق'
        : 'إضافة لاعبين للمباراة';
  }

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
      _setPenaltyScoreControllerText(
        sideKey: 'A',
        text: loadedMatch.penaltyScoreTeamA?.toString() ?? '',
      );
      _setPenaltyScoreControllerText(
        sideKey: 'B',
        text: loadedMatch.penaltyScoreTeamB?.toString() ?? '',
      );
      await _loadSideNames(loadedMatch);

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
      await _restoreDraftForMatch(loadedMatch);
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
    _draftSaveDebounce?.cancel();
    if (isDirty.value) {
      unawaited(_persistDraft());
    }
    teamAScoreController.removeListener(_handleTeamAScoreTextChanged);
    teamBScoreController.removeListener(_handleTeamBScoreTextChanged);
    teamAPenaltyScoreController.removeListener(
      _handleTeamAPenaltyScoreTextChanged,
    );
    teamBPenaltyScoreController.removeListener(
      _handleTeamBPenaltyScoreTextChanged,
    );
    teamAScoreController.dispose();
    teamBScoreController.dispose();
    teamAPenaltyScoreController.dispose();
    teamBPenaltyScoreController.dispose();
    super.onClose();
  }

  String participantKey(ParticipantRef participant) {
    return participantRosterKey(participant);
  }

  void selectMvp(String participantKey) {
    selectedMvpKey.value = participantKey.trim();
    _markDraftChanged();
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
    _markDraftChanged();
  }

  void clearParticipantGoals(ParticipantRef participant) {
    final key = participantRosterKey(participant);
    final sideKey = sideKeyForParticipant(participant);
    goalDrafts.removeWhere((draft) => participantRosterKey(draft.actor) == key);
    _syncRegisteredGoalStat(participant, 0);
    if (sideKey != null) {
      _syncScoreControllerForSide(sideKey);
    }
    _markDraftChanged();
  }

  void clearGoalDrafts() {
    goalDrafts.clear();
    for (final playerId in playerStats.keys) {
      playerStats[playerId]?['goals'] = 0;
    }
    _syncScoreControllerForSide('A');
    _syncScoreControllerForSide('B');
    _markDraftChanged();
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
    _markDraftChanged();
  }

  void decrementStat(String playerId, String key) {
    if (!playerStats.containsKey(playerId)) return;
    final current = playerStats[playerId]![key] as int;
    if (current > 0) {
      playerStats[playerId]![key] = current - 1;
      if (key == 'goals') {
        _syncRegisteredGoalDraft(playerId);
      }
      _markDraftChanged();
    }
  }

  void toggleCard(String playerId, String cardType) {
    if (!playerStats.containsKey(playerId)) return;
    playerStats[playerId]![cardType] =
        !(playerStats[playerId]![cardType] as bool);
    _markDraftChanged();
  }

  int get totalTeamAGoals => teamAGoalSummary.teamScore;

  int get totalTeamBGoals => teamBGoalSummary.teamScore;

  Future<Match?> submit() async {
    final currentMatch = match.value;
    if (currentMatch == null) return null;

    errorMessage.value = '';
    bool sourceMatchChanged;
    try {
      isLoading.value = true;
      sourceMatchChanged = await _hasSourceMatchChanged();
    } catch (error) {
      AppLogger.warning('ScoreSubmitController.submit.sourceMatchCheck', error);
      errorMessage.value =
          'تعذر التحقق من أحدث نتيجة للمباراة. تحقق من الاتصال وحاول مرة أخرى.';
      Get.snackbar(
        'تعذر التحقق من النتيجة',
        errorMessage.value,
        snackPosition: SnackPosition.BOTTOM,
      );
      return null;
    } finally {
      isLoading.value = false;
    }

    if (sourceMatchChanged) {
      errorMessage.value =
          'تغيّرت نتيجة المباراة على جهاز آخر. ارجع وحدّث المباراة قبل الإرسال.';
      Get.snackbar('النتيجة اتغيّرت', errorMessage.value);
      return null;
    }
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

    final validatedScores = _validateScores();
    if (!validatedScores.isValid) return null;
    final scoreA = validatedScores.scoreA!;
    final scoreB = validatedScores.scoreB!;
    if (!_validatePenaltyShootout(scoreA: scoreA, scoreB: scoreB)) {
      return null;
    }
    final penaltyShootout = _penaltyShootoutForSubmission(
      scoreA: scoreA,
      scoreB: scoreB,
    );

    teamACleanSheet.value = scoreB == 0;
    teamBCleanSheet.value = scoreA == 0;

    final detailedStats = ScoreSubmitPreparation.detailedStats(
      matchId: matchId,
      teamAId: currentMatch.teamAId ?? 'A',
      teamBId: currentMatch.teamBId ?? 'B',
      teamAPlayers: teamAPlayers,
      teamBPlayers: teamBPlayers,
      playerStats: playerStats,
      teamACleanSheet: teamACleanSheet.value,
      teamBCleanSheet: teamBCleanSheet.value,
    );

    try {
      isLoading.value = true;
      final result = await _settlementService.submitScore(
        matchId: currentMatch.id,
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
        penaltyShootout: penaltyShootout,
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
            penaltyScoreTeamA: penaltyShootout?.scoreTeamA,
            penaltyScoreTeamB: penaltyShootout?.scoreTeamB,
            knockoutDecision: penaltyShootout?.decision,
            mvpPlayerId: resolvedMvp?.actor.id,
            prideEventsPending: false,
            status: result.status,
          );
      match.value = updatedMatch;
      pendingPrideEventRetry.value = updatedMatch.prideEventsPending;
      await _clearDraftAfterSubmit(updatedMatch);

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

  List<MatchSettlementGoalDraft> _settlementGoalDrafts() {
    return ScoreSubmitPreparation.settlementGoals(allGoalDrafts);
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

  Future<void> _loadSideNames(Match loadedMatch) async {
    teamASideName.value = 'فريق A';
    teamBSideName.value = 'فريق B';

    if (loadedMatch.tournamentId != null) {
      final participantAId = loadedMatch.teamAParticipantId;
      final participantBId = loadedMatch.teamBParticipantId;
      final participants = await Future.wait([
        participantAId == null || participantAId.isEmpty
            ? Future.value(null)
            : _participantRepository.getParticipant(participantAId),
        participantBId == null || participantBId.isEmpty
            ? Future.value(null)
            : _participantRepository.getParticipant(participantBId),
      ]);
      final participantAName = participants[0]?.displayName.trim() ?? '';
      final participantBName = participants[1]?.displayName.trim() ?? '';
      if (participantAName.isNotEmpty) {
        teamASideName.value = participantAName;
      }
      if (participantBName.isNotEmpty) {
        teamBSideName.value = participantBName;
      }
    }

    final teamIds = <String>[
      if (loadedMatch.teamAId != null && loadedMatch.teamAId!.isNotEmpty)
        loadedMatch.teamAId!,
      if (loadedMatch.teamBId != null && loadedMatch.teamBId!.isNotEmpty)
        loadedMatch.teamBId!,
    ];
    final teams = await _teamRepository.getTeamsByIds(teamIds);
    final teamsById = {for (final team in teams) team.id: team};
    final teamAName = teamsById[loadedMatch.teamAId]?.name.trim() ?? '';
    final teamBName = teamsById[loadedMatch.teamBId]?.name.trim() ?? '';
    if (teamASideName.value == 'فريق A' && teamAName.isNotEmpty) {
      teamASideName.value = teamAName;
    }
    if (teamBSideName.value == 'فريق B' && teamBName.isNotEmpty) {
      teamBSideName.value = teamBName;
    }
    if (loadedMatch.tournamentId != null) {
      return;
    }

    final results = await Future.wait<dynamic>([
      _sideRepository.getMatchSides(loadedMatch.id),
      _sidePlayerRepository.getMatchPlayers(loadedMatch.id),
    ]);
    final sides = results[0] as List<MatchSide>;
    final sidePlayers = results[1] as List<MatchSidePlayer>;
    final sideViews = FriendlyMatchSideView.fromMatch(
      match: loadedMatch,
      teamsById: teamsById,
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
