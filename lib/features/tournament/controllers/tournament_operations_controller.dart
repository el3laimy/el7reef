import 'package:get/get.dart';

import '../../../core/enums/match_status.dart';
import '../../../core/enums/tournament_ops_enums.dart';
import '../../../core/services/tournament_fixture_service.dart';
import '../../../core/services/tournament_lifecycle_service.dart';
import '../../../core/services/tournament_ops_migration_service.dart';
import '../../../core/services/tournament_participant_service.dart';
import '../../../domain/entities/group_standing_snapshot.dart';
import '../../../domain/entities/knockout_bracket.dart';
import '../../../domain/entities/knockout_tie.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/tournament.dart';
import '../../../domain/entities/tournament_group.dart';
import '../../../domain/entities/tournament_participant.dart';
import '../../../domain/repositories/group_standing_snapshot_repository.dart';
import '../../../domain/repositories/guest_team_repository.dart';
import '../../../domain/repositories/knockout_bracket_repository.dart';
import '../../../domain/repositories/knockout_tie_repository.dart';
import '../../../domain/repositories/match_repository.dart';
import '../../../domain/repositories/team_repository.dart';
import '../../../domain/repositories/tournament_group_repository.dart';
import '../../../domain/repositories/tournament_repository.dart';

class TournamentOperationsController extends GetxController {
  final TournamentRepository _tournamentRepository;
  final TournamentGroupRepository _groupRepository;
  final GroupStandingSnapshotRepository _standingRepository;
  final MatchRepository _matchRepository;
  final TeamRepository _teamRepository;
  final GuestTeamRepository _guestTeamRepository;
  final KnockoutBracketRepository _bracketRepository;
  final KnockoutTieRepository _tieRepository;
  final TournamentParticipantService _participantService;
  final TournamentOpsMigrationService _migrationService;
  final TournamentLifecycleService _lifecycleService;
  final TournamentFixtureService _fixtureService;

  TournamentOperationsController({
    required TournamentRepository tournamentRepository,
    required TournamentGroupRepository groupRepository,
    required GroupStandingSnapshotRepository standingRepository,
    required MatchRepository matchRepository,
    required TeamRepository teamRepository,
    required GuestTeamRepository guestTeamRepository,
    required KnockoutBracketRepository bracketRepository,
    required KnockoutTieRepository tieRepository,
    required TournamentParticipantService participantService,
    required TournamentOpsMigrationService migrationService,
    required TournamentLifecycleService lifecycleService,
    required TournamentFixtureService fixtureService,
  }) : _tournamentRepository = tournamentRepository,
       _groupRepository = groupRepository,
       _standingRepository = standingRepository,
       _matchRepository = matchRepository,
       _teamRepository = teamRepository,
       _guestTeamRepository = guestTeamRepository,
       _bracketRepository = bracketRepository,
       _tieRepository = tieRepository,
       _participantService = participantService,
       _migrationService = migrationService,
       _lifecycleService = lifecycleService,
       _fixtureService = fixtureService;

  final tournament = Rxn<Tournament>();
  final participants = <TournamentParticipant>[].obs;
  final groups = <TournamentGroup>[].obs;
  final standings = <GroupStandingSnapshot>[].obs;
  final fixtures = <Match>[].obs;
  final knockoutBracket = Rxn<KnockoutBracket>();
  final knockoutTies = <KnockoutTie>[].obs;
  final migrationReport = Rxn<TournamentOpsMigrationReport>();

  final isLoading = true.obs;
  final isActing = false.obs;
  final errorMessage = ''.obs;

  String? get tournamentId =>
      Get.parameters['tournamentId'] ?? Get.parameters['id'];

  bool get isBlockedByManualMigration =>
      tournament.value?.needsManualOpsMigration ?? false;

  bool get hasOperationalStageStarted {
    final currentTournament = tournament.value;
    if (currentTournament == null) {
      return false;
    }
    return (currentTournament.currentGroupStageId != null &&
            currentTournament.currentGroupStageId!.isNotEmpty) ||
        (currentTournament.currentKnockoutBracketId != null &&
            currentTournament.currentKnockoutBracketId!.isNotEmpty);
  }

  bool get canManualAddParticipants {
    final currentTournament = tournament.value;
    if (currentTournament == null) {
      return false;
    }
    return !isBlockedByManualMigration &&
        currentTournament.participantListFinalizedAt == null &&
        !hasOperationalStageStarted;
  }

  bool get canReplaceParticipants {
    return !isBlockedByManualMigration && !hasOperationalStageStarted;
  }

  List<Match> get groupStageFixtures => fixtures
      .where((fixture) => fixture.stageType == TournamentStageType.groupStage)
      .toList(growable: false);

  bool get hasPublishedGroupFixtures => groupStageFixtures.any(
    (fixture) => fixture.fixtureStatus == FixtureStatus.published,
  );

  bool get hasSubmittedGroupResults => groupStageFixtures.any(
    (fixture) =>
        fixture.scoreTeamA != null ||
        fixture.scoreTeamB != null ||
        fixture.status == MatchStatus.completed ||
        fixture.status == MatchStatus.pendingReview ||
        fixture.isOfficialTournamentResult,
  );

  bool get canRegenerateGroupStage {
    final currentTournament = tournament.value;
    if (currentTournament == null) {
      return false;
    }
    final hasGroupStage =
        currentTournament.currentGroupStageId != null &&
        currentTournament.currentGroupStageId!.isNotEmpty;
    final knockoutNotStarted =
        currentTournament.currentKnockoutBracketId == null ||
        currentTournament.currentKnockoutBracketId!.isEmpty;
    return hasGroupStage &&
        knockoutNotStarted &&
        !isBlockedByManualMigration &&
        !hasPublishedGroupFixtures &&
        !hasSubmittedGroupResults;
  }

  bool get canPublishFixtures =>
      fixtures.isNotEmpty &&
      fixtures.any(
        (fixture) => fixture.fixtureStatus != FixtureStatus.published,
      );

  bool canReplaceParticipant(TournamentParticipant participant) {
    return participant.isActive && canReplaceParticipants;
  }

  int get activeParticipantsCount => participants
      .where(
        (participant) =>
            participant.status == TournamentParticipantStatus.approved ||
            participant.status == TournamentParticipantStatus.finalized,
      )
      .length;

  @override
  void onInit() {
    super.onInit();
    refreshAll();
  }

  Future<void> refreshAll() async {
    final id = tournamentId;
    if (id == null || id.isEmpty) {
      errorMessage.value = 'لم يتم تحديد البطولة المطلوبة.';
      isLoading.value = false;
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';
    try {
      migrationReport.value = await _migrationService.backfillTournament(
        tournamentId: id,
      );
      final currentTournament = await _tournamentRepository.getTournament(id);
      if (currentTournament == null) {
        errorMessage.value = 'تعذر العثور على البطولة المطلوبة.';
        tournament.value = null;
        return;
      }
      tournament.value = currentTournament;
      participants.assignAll(
        await _participantService.getTournamentParticipants(id),
      );

      if (currentTournament.currentGroupStageId != null &&
          currentTournament.currentGroupStageId!.isNotEmpty) {
        await _lifecycleService.refreshGroupStandings(tournamentId: id);
        groups.assignAll(
          await _groupRepository.getTournamentGroups(
            id,
            groupStageId: currentTournament.currentGroupStageId!,
          ),
        );
        standings.assignAll(
          await _standingRepository.getGroupStageSnapshots(
            currentTournament.currentGroupStageId!,
          ),
        );
      } else {
        groups.clear();
        standings.clear();
      }

      if (currentTournament.currentKnockoutBracketId != null &&
          currentTournament.currentKnockoutBracketId!.isNotEmpty) {
        await _lifecycleService.refreshKnockoutProgress(tournamentId: id);
      }

      tournament.value = await _tournamentRepository.getTournament(id);
      fixtures.assignAll(
        await _matchRepository.getTournamentMatches(tournamentId: id),
      );

      final bracketId = tournament.value?.currentKnockoutBracketId;
      if (bracketId != null && bracketId.isNotEmpty) {
        knockoutBracket.value = await _bracketRepository.getBracket(bracketId);
        knockoutTies.assignAll(await _tieRepository.getBracketTies(bracketId));
      } else {
        knockoutBracket.value = null;
        knockoutTies.clear();
      }
    } catch (error) {
      errorMessage.value = _normalizeError(error);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> syncApprovedRegistrations() async {
    final id = tournamentId;
    if (id == null || id.isEmpty) {
      return;
    }
    await _runAction(
      message: 'تمت مزامنة التسجيلات المعتمدة مع participants.',
      action: () => _migrationService.backfillTournament(tournamentId: id),
    );
  }

  Future<void> finalizeParticipantList() async {
    final id = tournamentId;
    if (id == null || id.isEmpty) {
      return;
    }
    await _runAction(
      message: 'تم قفل قائمة المشاركين بنجاح.',
      action: () => _lifecycleService.finalizeParticipants(
        tournamentId: id,
        actorId: tournament.value?.organizerId ?? 'system',
      ),
    );
  }

  Future<void> startGroupStage() async {
    final id = tournamentId;
    if (id == null || id.isEmpty) {
      return;
    }
    await _runAction(
      message: 'تم إنشاء المجموعات وجدولها بنجاح.',
      action: () => _lifecycleService.startGroupStage(
        tournamentId: id,
        actorId: tournament.value?.organizerId ?? 'system',
      ),
    );
  }

  Future<void> publishFixtures() async {
    final id = tournamentId;
    if (id == null || id.isEmpty) {
      return;
    }
    await _runAction(
      message: 'تم نشر fixtures البطولة.',
      action: () => _lifecycleService.publishFixtures(
        tournamentId: id,
        actorId: tournament.value?.organizerId ?? 'system',
      ),
    );
  }

  Future<void> regenerateGroupStage() async {
    final id = tournamentId;
    if (id == null || id.isEmpty) {
      return;
    }
    await _runAction(
      message: 'تمت إعادة توليد المجموعات والـ fixtures بنجاح.',
      action: () => _fixtureService.regenerateGroupStage(
        tournamentId: id,
        actorId: tournament.value?.organizerId ?? 'system',
      ),
    );
  }

  Future<void> startKnockout() async {
    final id = tournamentId;
    if (id == null || id.isEmpty) {
      return;
    }
    await _runAction(
      message: 'تم إنشاء bracket الإقصاء.',
      action: () => _lifecycleService.startKnockout(
        tournamentId: id,
        actorId: tournament.value?.organizerId ?? 'system',
      ),
    );
  }

  Future<void> completeTournament() async {
    final id = tournamentId;
    if (id == null || id.isEmpty) {
      return;
    }
    await _runAction(
      message: 'تم إغلاق البطولة وتحديد البطل.',
      action: () => _lifecycleService.completeTournament(
        tournamentId: id,
        actorId: tournament.value?.organizerId ?? 'system',
      ),
    );
  }

  Future<void> withdrawParticipant(String participantId) async {
    await _runAction(
      message: 'تم سحب المشارك من البطولة.',
      action: () => _participantService.withdrawParticipant(
        participantId: participantId,
        actorId: tournament.value?.organizerId ?? 'system',
      ),
    );
  }

  Future<void> addManualParticipant({
    required TournamentParticipantSourceType sourceType,
    required String sourceEntityId,
  }) async {
    final id = tournamentId;
    if (id == null || id.isEmpty) {
      return;
    }
    await _runAction(
      message: 'تمت إضافة participant يدويًا إلى البطولة.',
      action: () => _participantService.addManualParticipant(
        tournamentId: id,
        sourceType: sourceType,
        sourceEntityId: sourceEntityId,
        actorId: tournament.value?.organizerId ?? 'system',
      ),
    );
  }

  Future<void> replaceParticipant({
    required String participantId,
    required TournamentParticipantSourceType replacementSourceType,
    required String replacementSourceEntityId,
  }) async {
    await _runAction(
      message: 'تم استبدال participant بنجاح.',
      action: () => _participantService.replaceParticipant(
        participantId: participantId,
        replacementSourceType: replacementSourceType,
        replacementSourceEntityId: replacementSourceEntityId,
        actorId: tournament.value?.organizerId ?? 'system',
      ),
    );
  }

  Future<List<TournamentParticipantCandidate>> searchParticipantCandidates({
    required String query,
    required TournamentParticipantSourceType sourceType,
    TournamentParticipant? replacingParticipant,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return const <TournamentParticipantCandidate>[];
    }

    final blockedKeys = participants
        .where((participant) => participant.id != replacingParticipant?.id)
        .map(
          (participant) =>
              '${participant.sourceType.name}::${participant.sourceEntityId}',
        )
        .toSet();

    List<TournamentParticipantCandidate> candidates;
    switch (sourceType) {
      case TournamentParticipantSourceType.registeredTeam:
        final teams = await _teamRepository.searchTeams(normalizedQuery);
        candidates = teams
            .map(
              (team) => TournamentParticipantCandidate(
                sourceType: sourceType,
                sourceEntityId: team.id,
                displayName: team.name,
              ),
            )
            .toList(growable: false);
        break;
      case TournamentParticipantSourceType.guestTeam:
        final guestTeams = await _guestTeamRepository.searchGuestTeams(
          normalizedQuery,
        );
        candidates = guestTeams
            .map(
              (guestTeam) => TournamentParticipantCandidate(
                sourceType: sourceType,
                sourceEntityId: guestTeam.id,
                displayName: guestTeam.name,
              ),
            )
            .toList(growable: false);
        break;
    }

    return candidates
        .where((candidate) {
          final key =
              '${candidate.sourceType.name}::${candidate.sourceEntityId}';
          if (blockedKeys.contains(key)) {
            return false;
          }
          if (replacingParticipant == null) {
            return true;
          }
          return !(candidate.sourceType == replacingParticipant.sourceType &&
              candidate.sourceEntityId == replacingParticipant.sourceEntityId);
        })
        .toList(growable: false);
  }

  Future<void> scheduleFixture({
    required String fixtureId,
    required DateTime scheduledAt,
    String? venueId,
  }) async {
    await _runAction(
      message: 'تم تحديث موعد الـ fixture.',
      action: () => _fixtureService.scheduleFixture(
        matchId: fixtureId,
        actorId: tournament.value?.organizerId ?? 'system',
        scheduledAt: scheduledAt,
        venueId: venueId,
      ),
    );
  }

  Future<void> _runAction({
    required String message,
    required Future<dynamic> Function() action,
  }) async {
    isActing.value = true;
    errorMessage.value = '';
    try {
      await action();
      await refreshAll();
      Get.snackbar('تم', message, snackPosition: SnackPosition.BOTTOM);
    } catch (error) {
      errorMessage.value = _normalizeError(error);
      Get.snackbar(
        'خطأ',
        errorMessage.value,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isActing.value = false;
    }
  }

  String _normalizeError(Object error) {
    return error.toString().replaceFirst('Exception: ', '').trim();
  }
}

class TournamentParticipantCandidate {
  final TournamentParticipantSourceType sourceType;
  final String sourceEntityId;
  final String displayName;

  const TournamentParticipantCandidate({
    required this.sourceType,
    required this.sourceEntityId,
    required this.displayName,
  });
}
