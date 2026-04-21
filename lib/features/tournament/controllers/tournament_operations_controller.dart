import 'package:get/get.dart';

import '../../../core/enums/match_status.dart';
import '../../../core/enums/tournament_enums.dart';
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
import '../../../domain/repositories/guest_team_repository.dart';
import '../../../domain/repositories/group_standing_snapshot_repository.dart';
import '../../../domain/repositories/knockout_bracket_repository.dart';
import '../../../domain/repositories/knockout_tie_repository.dart';
import '../../../domain/repositories/match_repository.dart';
import '../../../domain/repositories/team_repository.dart';
import '../../../domain/repositories/tournament_group_repository.dart';
import '../../../domain/repositories/tournament_repository.dart';

class TournamentOperationsController extends GetxController {
  static const Duration _participantSearchCacheTtl = Duration(seconds: 30);

  final TournamentRepository _tournamentRepository;
  final TournamentGroupRepository _groupRepository;
  final MatchRepository _matchRepository;
  final TeamRepository _teamRepository;
  final GuestTeamRepository _guestTeamRepository;
  final GroupStandingSnapshotRepository _standingRepository;
  final KnockoutBracketRepository _bracketRepository;
  final KnockoutTieRepository _tieRepository;
  final TournamentParticipantService _participantService;
  final TournamentOpsMigrationService _migrationService;
  final TournamentLifecycleService _lifecycleService;
  final TournamentFixtureService _fixtureService;

  TournamentOperationsController({
    required TournamentRepository tournamentRepository,
    required TournamentGroupRepository groupRepository,
    required MatchRepository matchRepository,
    required TeamRepository teamRepository,
    required GuestTeamRepository guestTeamRepository,
    required GroupStandingSnapshotRepository standingRepository,
    required KnockoutBracketRepository bracketRepository,
    required KnockoutTieRepository tieRepository,
    required TournamentParticipantService participantService,
    required TournamentOpsMigrationService migrationService,
    required TournamentLifecycleService lifecycleService,
    required TournamentFixtureService fixtureService,
  }) : _tournamentRepository = tournamentRepository,
       _groupRepository = groupRepository,
       _matchRepository = matchRepository,
       _teamRepository = teamRepository,
       _guestTeamRepository = guestTeamRepository,
       _standingRepository = standingRepository,
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
  Map<String, TournamentParticipant> _participantById =
      const <String, TournamentParticipant>{};
  Map<String, String> _groupNameById = const <String, String>{};
  Map<String, List<TournamentParticipant>> _participantsByGroupId =
      const <String, List<TournamentParticipant>>{};
  final Map<String, _ParticipantCandidateCacheEntry> _participantSearchCache =
      <String, _ParticipantCandidateCacheEntry>{};

  String? get tournamentId =>
      Get.parameters['tournamentId'] ?? Get.parameters['id'];

  bool get isBlockedByManualMigration =>
      tournament.value?.needsManualOpsMigration ?? false;

  bool get shouldShowMaintenanceTools =>
      isBlockedByManualMigration || migrationReport.value != null;

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

  bool get hasGroupStage =>
      tournament.value?.currentGroupStageId != null &&
      tournament.value!.currentGroupStageId!.isNotEmpty;

  bool get hasKnockoutStage =>
      tournament.value?.currentKnockoutBracketId != null &&
      tournament.value!.currentKnockoutBracketId!.isNotEmpty;

  List<Match> get groupStageFixtures => fixtures
      .where((fixture) => fixture.stageType == TournamentStageType.groupStage)
      .toList(growable: false);

  List<Match> get knockoutFixtures => fixtures
      .where(
        (fixture) => fixture.stageType == TournamentStageType.knockoutStage,
      )
      .toList(growable: false);

  bool get hasPublishedGroupFixtures => groupStageFixtures.any(
    (fixture) => fixture.fixtureStatus == FixtureStatus.published,
  );

  bool get hasPublishedFixtures => fixtures.any(
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

  bool get canFinalizeParticipantsAction {
    final currentTournament = tournament.value;
    if (currentTournament == null) {
      return false;
    }
    return !isBlockedByManualMigration &&
        currentTournament.participantListFinalizedAt == null &&
        !hasOperationalStageStarted &&
        activeParticipantsCount >= 2;
  }

  bool get canStartGroupStageAction {
    final currentTournament = tournament.value;
    if (currentTournament == null) {
      return false;
    }
    if (currentTournament.format == TournamentFormat.knockoutOnly) {
      return false;
    }
    return !isBlockedByManualMigration &&
        currentTournament.participantListFinalizedAt != null &&
        !hasGroupStage &&
        activeParticipantsCount >= 2;
  }

  bool get canStartKnockoutAction {
    final currentTournament = tournament.value;
    if (currentTournament == null ||
        isBlockedByManualMigration ||
        hasKnockoutStage) {
      return false;
    }
    switch (currentTournament.format) {
      case TournamentFormat.knockoutOnly:
        return currentTournament.participantListFinalizedAt != null &&
            activeParticipantsCount >= 2;
      case TournamentFormat.groupsThenKnockout:
        return hasGroupStage &&
            groups.isNotEmpty &&
            standings.isNotEmpty &&
            groupStageFixtures.isNotEmpty &&
            groupStageFixtures.every(
              (fixture) => fixture.isOfficialTournamentResult,
            );
      case TournamentFormat.groupsOnly:
        return false;
    }
  }

  bool get canCompleteTournamentAction {
    final currentTournament = tournament.value;
    if (currentTournament == null ||
        currentTournament.status == TournamentStatus.completed) {
      return false;
    }
    switch (currentTournament.format) {
      case TournamentFormat.groupsOnly:
        return hasGroupStage &&
            groupStageFixtures.isNotEmpty &&
            groupStageFixtures.every(
              (fixture) => fixture.isOfficialTournamentResult,
            );
      case TournamentFormat.knockoutOnly:
      case TournamentFormat.groupsThenKnockout:
        return knockoutBracket.value?.championParticipantId != null;
    }
  }

  bool canReplaceParticipant(TournamentParticipant participant) {
    return participant.isActive && canReplaceParticipants;
  }

  bool canStartFixture(Match fixture) {
    return !isBlockedByManualMigration &&
        fixture.fixtureStatus == FixtureStatus.published &&
        fixture.status == MatchStatus.open &&
        !fixture.isFrozen;
  }

  bool canReactivateParticipant(TournamentParticipant participant) {
    return !participant.isActive &&
        !isBlockedByManualMigration &&
        !hasOperationalStageStarted;
  }

  bool canEditParticipantSeed(TournamentParticipant participant) {
    return participant.isActive &&
        !isBlockedByManualMigration &&
        !hasOperationalStageStarted;
  }

  int get activeParticipantsCount => participants
      .where(
        (participant) =>
            participant.status == TournamentParticipantStatus.approved ||
            participant.status == TournamentParticipantStatus.finalized,
      )
      .length;

  int get draftFixturesCount => fixtures
      .where((fixture) => fixture.fixtureStatus == FixtureStatus.draft)
      .length;

  int get publishedFixturesCount => fixtures
      .where((fixture) => fixture.fixtureStatus == FixtureStatus.published)
      .length;

  int get scheduledFixturesCount =>
      fixtures.where((fixture) => fixture.scheduledAt != null).length;

  int get officialResultsCount =>
      fixtures.where((fixture) => fixture.isOfficialTournamentResult).length;

  String statusLabelFor(TournamentStatus status) => switch (status) {
    TournamentStatus.upcoming => 'لم تبدأ بعد',
    TournamentStatus.registration => 'التسجيل مفتوح',
    TournamentStatus.groupStage => 'مرحلة المجموعات',
    TournamentStatus.transferWindow => 'نافذة التغييرات',
    TournamentStatus.knockoutStage => 'مرحلة الإقصاء',
    TournamentStatus.completed => 'مكتملة',
    TournamentStatus.cancelled => 'ملغاة',
  };

  List<TournamentOpsChecklistItem> get readinessChecklist {
    final currentTournament = tournament.value;
    if (currentTournament == null) {
      return const <TournamentOpsChecklistItem>[];
    }
    return <TournamentOpsChecklistItem>[
      TournamentOpsChecklistItem(
        label: 'قائمة المشاركين',
        isReady: currentTournament.participantListFinalizedAt != null,
        detail: currentTournament.participantListFinalizedAt != null
            ? 'تم قفل القائمة وجاهزة للتشغيل.'
            : activeParticipantsCount >= 2
            ? 'يمكن قفل القائمة الآن.'
            : 'تحتاج على الأقل مشاركين نشطين.',
      ),
      TournamentOpsChecklistItem(
        label: 'مرحلة المجموعات',
        isReady: hasGroupStage,
        detail: hasGroupStage
            ? 'تم إنشاء المجموعات والـ fixtures الخاصة بها.'
            : canStartGroupStageAction
            ? 'جاهزة للبدء من لوحة التشغيل.'
            : currentTournament.format == TournamentFormat.knockoutOnly
            ? 'غير مطلوبة في هذا النوع من البطولات.'
            : 'تنتظر قفل قائمة المشاركين أولًا.',
      ),
      TournamentOpsChecklistItem(
        label: 'نشر fixtures',
        isReady: hasPublishedFixtures,
        detail: hasPublishedFixtures
            ? 'تم نشر جزء من fixtures بالفعل.'
            : canPublishFixtures
            ? 'توجد fixtures draft جاهزة للنشر.'
            : fixtures.isEmpty
            ? 'لم تُولد fixtures بعد.'
            : 'كل fixtures الحالية منشورة بالفعل.',
      ),
      TournamentOpsChecklistItem(
        label: 'مرحلة الإقصاء',
        isReady: hasKnockoutStage,
        detail: hasKnockoutStage
            ? knockoutBracket.value?.championParticipantId == null
                  ? 'تم إنشاء bracket الإقصاء.'
                  : 'تم تحديد بطل الإقصاء.'
            : canStartKnockoutAction
            ? 'جاهزة للبدء الآن.'
            : currentTournament.format == TournamentFormat.groupsOnly
            ? 'غير مطلوبة في هذا النوع من البطولات.'
            : 'تنتظر اكتمال المؤهلين ونتائج المراحل السابقة.',
      ),
    ];
  }

  List<TournamentOpsPendingAction> get pendingActions {
    final currentTournament = tournament.value;
    if (currentTournament == null) {
      return const <TournamentOpsPendingAction>[];
    }

    final actions = <TournamentOpsPendingAction>[];
    if (currentTournament.participantListFinalizedAt == null) {
      actions.add(
        TournamentOpsPendingAction(
          title: 'قفل قائمة المشاركين',
          detail: activeParticipantsCount >= 2
              ? 'عدد المشاركين الحالي يسمح بالقفل والانتقال للمرحلة التالية.'
              : 'ما زال يلزم تجهيز مشاركين نشطين كفاية قبل القفل.',
        ),
      );
    }
    if (canStartGroupStageAction) {
      actions.add(
        const TournamentOpsPendingAction(
          title: 'بدء مرحلة المجموعات',
          detail: 'المشاركون جاهزون ويمكن الآن توليد المجموعات والـ fixtures.',
        ),
      );
    }
    if (canPublishFixtures) {
      actions.add(
        TournamentOpsPendingAction(
          title: 'نشر fixtures',
          detail: draftFixturesCount == 0
              ? 'كل fixtures الحالية منشورة.'
              : 'يوجد $draftFixturesCount fixture بصيغة draft تنتظر النشر.',
        ),
      );
    }
    if (canStartKnockoutAction) {
      actions.add(
        const TournamentOpsPendingAction(
          title: 'بدء الإقصاء',
          detail: 'النتائج والمؤهلون جاهزون لبناء bracket الإقصاء.',
        ),
      );
    }
    if (canCompleteTournamentAction) {
      actions.add(
        const TournamentOpsPendingAction(
          title: 'إغلاق البطولة',
          detail: 'يمكن الآن إنهاء البطولة وتثبيت البطل رسميًا.',
        ),
      );
    }
    return actions;
  }

  List<TournamentParticipant> participantsForGroup(String groupId) =>
      _participantsByGroupId[groupId] ?? const <TournamentParticipant>[];

  String groupLabelFor(String? groupId) {
    if (groupId == null || groupId.isEmpty) {
      return '-';
    }
    return _groupNameById[groupId] ?? groupId;
  }

  String participantLabelFor(String? participantId, {String fallback = 'TBD'}) {
    if (participantId == null || participantId.isEmpty) {
      return fallback;
    }
    return _participantById[participantId]?.displayName ?? fallback;
  }

  String fixtureTeamLabel(Match fixture, {required bool isHome}) {
    final participantId = isHome
        ? fixture.teamAParticipantId
        : fixture.teamBParticipantId;
    final fallbackId = isHome ? fixture.teamAId : fixture.teamBId;
    return participantLabelFor(
      participantId,
      fallback: fallbackId == null || fallbackId.isEmpty ? 'TBD' : fallbackId,
    );
  }

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
      final currentTournament = await _tournamentRepository.getTournament(id);
      if (currentTournament == null) {
        errorMessage.value = 'تعذر العثور على البطولة المطلوبة.';
        tournament.value = null;
        _clearDerivedState();
        participants.clear();
        groups.clear();
        standings.clear();
        fixtures.clear();
        knockoutBracket.value = null;
        knockoutTies.clear();
        return;
      }
      tournament.value = currentTournament;
      final groupStageId = currentTournament.currentGroupStageId;
      final bracketId = currentTournament.currentKnockoutBracketId;

      final participantsFuture = _participantService.getTournamentParticipants(
        id,
      );
      final groupsFuture = groupStageId != null && groupStageId.isNotEmpty
          ? _groupRepository.getTournamentGroups(id, groupStageId: groupStageId)
          : Future.value(const <TournamentGroup>[]);
      final standingsFuture = groupStageId != null && groupStageId.isNotEmpty
          ? _standingRepository.getGroupStageSnapshots(groupStageId)
          : Future.value(const <GroupStandingSnapshot>[]);
      final fixturesFuture = _matchRepository.getTournamentMatches(
        tournamentId: id,
      );
      final bracketFuture = bracketId != null && bracketId.isNotEmpty
          ? _bracketRepository.getBracket(bracketId)
          : Future.value(null);
      final knockoutTiesFuture = bracketId != null && bracketId.isNotEmpty
          ? _tieRepository.getBracketTies(bracketId)
          : Future.value(const <KnockoutTie>[]);

      final participantsResult = await participantsFuture;
      final groupsResult = await groupsFuture;
      final standingsResult = await standingsFuture;
      final fixturesResult = await fixturesFuture;
      final bracketResult = await bracketFuture;
      final knockoutTiesResult = await knockoutTiesFuture;

      _rebuildDerivedState(
        participantsResult: participantsResult,
        groupsResult: groupsResult,
      );

      participants.assignAll(participantsResult);
      groups.assignAll(groupsResult);
      standings.assignAll(standingsResult);
      fixtures.assignAll(fixturesResult);
      if (bracketId != null && bracketId.isNotEmpty) {
        knockoutBracket.value = bracketResult;
        knockoutTies.assignAll(knockoutTiesResult);
      } else {
        knockoutBracket.value = null;
        knockoutTies.clear();
      }
    } catch (error) {
      _clearDerivedState();
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
      onSuccess: (_) => _refreshParticipantsOnly(refreshTournament: true),
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
      onSuccess: (finalizedParticipants) async {
        _applyParticipants(finalizedParticipants);
        await _refreshTournamentOnly();
      },
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
      onSuccess: (result) async {
        _applyGroups(result.groups);
        standings.assignAll(result.standings);
        _mergeFixtures(result.fixtures);
        final currentTournament = tournament.value;
        if (currentTournament != null) {
          tournament.value = currentTournament.copyWith(
            status: TournamentStatus.groupStage,
            currentGroupStageId: result.groupStageId,
          );
        } else {
          await _refreshTournamentOnly();
        }
      },
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
      onSuccess: (publishedFixtures) async {
        fixtures.assignAll(publishedFixtures);
      },
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
      onSuccess: (result) async {
        _applyGroups(result.groups);
        standings.assignAll(result.standings);
        _replaceGroupStageFixtures(result.fixtures);
      },
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
      onSuccess: (result) async {
        knockoutBracket.value = result.bracket;
        knockoutTies.assignAll(result.ties);
        _mergeFixtures(result.matches);
        final currentTournament = tournament.value;
        if (currentTournament != null) {
          tournament.value = currentTournament.copyWith(
            status: TournamentStatus.knockoutStage,
            currentKnockoutBracketId: result.bracket.id,
          );
        } else {
          await _refreshTournamentOnly();
        }
      },
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
      onSuccess: (updatedTournament) async {
        tournament.value = updatedTournament;
      },
    );
  }

  Future<void> withdrawParticipant(String participantId) async {
    await _runAction(
      message: 'تم سحب المشارك من البطولة.',
      action: () => _participantService.withdrawParticipant(
        participantId: participantId,
        actorId: tournament.value?.organizerId ?? 'system',
      ),
      onSuccess: (updatedParticipant) async {
        _upsertParticipant(updatedParticipant);
      },
    );
  }

  Future<void> reactivateParticipant(String participantId) async {
    await _runAction(
      message: 'تمت إعادة تفعيل المشارك بنجاح.',
      action: () => _participantService.reactivateParticipant(
        participantId: participantId,
        actorId: tournament.value?.organizerId ?? 'system',
      ),
      onSuccess: (result) async {
        _upsertParticipants(<TournamentParticipant>[
          result.reactivatedParticipant,
          if (result.withdrawnReplacement != null) result.withdrawnReplacement!,
        ]);
        _syncTournamentParticipantCountLocal(
          overrideCount: result.activeParticipantCount,
        );
      },
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
      onSuccess: (participant) async {
        _upsertParticipant(participant);
      },
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
      onSuccess: (result) async {
        _upsertParticipants(<TournamentParticipant>[
          result.replacedParticipant,
          result.replacementParticipant,
        ]);
        _syncTournamentParticipantCountLocal(
          overrideCount: result.activeParticipantCount,
        );
      },
    );
  }

  Future<void> updateParticipantSeed({
    required String participantId,
    int? seed,
  }) async {
    await _runAction(
      message: seed == null
          ? 'تم حذف seed الخاصة بالمشارك.'
          : 'تم تحديث seed الخاصة بالمشارك.',
      action: () => _participantService.updateParticipantSeed(
        participantId: participantId,
        actorId: tournament.value?.organizerId ?? 'system',
        seed: seed,
      ),
      onSuccess: (updatedParticipant) async {
        _upsertParticipant(updatedParticipant);
      },
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

    final cacheKey = '${sourceType.name}::${normalizedQuery.toLowerCase()}';
    final now = DateTime.now();
    final cached = _participantSearchCache[cacheKey];
    final baseCandidates =
        cached != null &&
            now.difference(cached.cachedAt) <= _participantSearchCacheTtl
        ? cached.candidates
        : await _loadParticipantCandidates(
            normalizedQuery: normalizedQuery,
            sourceType: sourceType,
          );

    if (cached == null ||
        now.difference(cached.cachedAt) > _participantSearchCacheTtl) {
      _participantSearchCache[cacheKey] = _ParticipantCandidateCacheEntry(
        cachedAt: now,
        candidates: baseCandidates,
      );
    }

    return baseCandidates
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

  Future<List<TournamentParticipantCandidate>> _loadParticipantCandidates({
    required String normalizedQuery,
    required TournamentParticipantSourceType sourceType,
  }) async {
    switch (sourceType) {
      case TournamentParticipantSourceType.registeredTeam:
        final teams = await _teamRepository.searchTeams(normalizedQuery);
        return teams
            .map(
              (team) => TournamentParticipantCandidate(
                sourceType: sourceType,
                sourceEntityId: team.id,
                displayName: team.name,
              ),
            )
            .toList(growable: false);
      case TournamentParticipantSourceType.guestTeam:
        final guestTeams = await _guestTeamRepository.searchGuestTeams(
          normalizedQuery,
        );
        return guestTeams
            .map(
              (guestTeam) => TournamentParticipantCandidate(
                sourceType: sourceType,
                sourceEntityId: guestTeam.id,
                displayName: guestTeam.name,
              ),
            )
            .toList(growable: false);
    }
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
      onSuccess: (updatedFixture) async {
        _upsertFixture(updatedFixture);
      },
    );
  }

  Future<void> startFixture(String fixtureId) async {
    await _runAction(
      message: 'تم بدء المباراة وأصبحت جارية الآن.',
      action: () => _fixtureService.startMatch(
        matchId: fixtureId,
        actorId: tournament.value?.organizerId ?? 'system',
      ),
      onSuccess: (updatedFixture) async {
        _upsertFixture(updatedFixture);
      },
    );
  }

  Future<void> _runAction<T>({
    required String message,
    required Future<T> Function() action,
    Future<void> Function(T result)? onSuccess,
  }) async {
    isActing.value = true;
    errorMessage.value = '';
    try {
      final result = await action();
      if (onSuccess != null) {
        await onSuccess(result);
      } else {
        await refreshAll();
      }
      _showSnackbar('تم', message);
    } catch (error) {
      errorMessage.value = _normalizeError(error);
      _showSnackbar('خطأ', errorMessage.value);
    } finally {
      isActing.value = false;
    }
  }

  String _normalizeError(Object error) {
    return error.toString().replaceFirst('Exception: ', '').trim();
  }

  void _showSnackbar(String title, String message) {
    if (Get.testMode) {
      return;
    }
    Get.snackbar(title, message, snackPosition: SnackPosition.BOTTOM);
  }

  Future<void> _refreshTournamentOnly() async {
    final id = tournamentId;
    if (id == null || id.isEmpty) {
      return;
    }
    final currentTournament = await _tournamentRepository.getTournament(id);
    if (currentTournament != null) {
      tournament.value = currentTournament;
    }
  }

  Future<void> _refreshParticipantsOnly({
    bool refreshTournament = false,
  }) async {
    final id = tournamentId;
    if (id == null || id.isEmpty) {
      return;
    }
    final participantsResult = await _participantService
        .getTournamentParticipants(id);
    _applyParticipants(participantsResult);
    if (refreshTournament) {
      await _refreshTournamentOnly();
    }
  }

  void _applyParticipants(List<TournamentParticipant> nextParticipants) {
    participants.assignAll(nextParticipants);
    _rebuildDerivedState(
      participantsResult: nextParticipants,
      groupsResult: groups.toList(growable: false),
    );
    _syncTournamentParticipantCountLocal();
  }

  void _applyGroups(List<TournamentGroup> nextGroups) {
    groups.assignAll(nextGroups);
    _rebuildDerivedState(
      participantsResult: participants.toList(growable: false),
      groupsResult: nextGroups,
    );
  }

  void _upsertParticipant(TournamentParticipant participant) {
    _upsertParticipants(<TournamentParticipant>[participant]);
  }

  void _upsertParticipants(List<TournamentParticipant> updatedParticipants) {
    final nextParticipants = participants.toList(growable: true);
    for (final participant in updatedParticipants) {
      final index = nextParticipants.indexWhere(
        (item) => item.id == participant.id,
      );
      if (index == -1) {
        nextParticipants.add(participant);
      } else {
        nextParticipants[index] = participant;
      }
    }
    nextParticipants.sort((left, right) {
      final leftSeed = left.seed ?? 1 << 20;
      final rightSeed = right.seed ?? 1 << 20;
      if (leftSeed != rightSeed) {
        return leftSeed.compareTo(rightSeed);
      }
      return left.displayName.compareTo(right.displayName);
    });
    _applyParticipants(nextParticipants);
  }

  void _upsertFixture(Match fixture) {
    final nextFixtures = fixtures.toList(growable: true);
    final index = nextFixtures.indexWhere((item) => item.id == fixture.id);
    if (index == -1) {
      nextFixtures.add(fixture);
    } else {
      nextFixtures[index] = fixture;
    }
    _sortFixtures(nextFixtures);
    fixtures.assignAll(nextFixtures);
  }

  void _mergeFixtures(List<Match> incomingFixtures) {
    final nextFixtures = fixtures.toList(growable: true);
    for (final fixture in incomingFixtures) {
      final index = nextFixtures.indexWhere((item) => item.id == fixture.id);
      if (index == -1) {
        nextFixtures.add(fixture);
      } else {
        nextFixtures[index] = fixture;
      }
    }
    _sortFixtures(nextFixtures);
    fixtures.assignAll(nextFixtures);
  }

  void _replaceGroupStageFixtures(List<Match> nextGroupStageFixtures) {
    final preservedFixtures = fixtures
        .where((fixture) => fixture.stageType != TournamentStageType.groupStage)
        .toList(growable: true);
    preservedFixtures.addAll(nextGroupStageFixtures);
    _sortFixtures(preservedFixtures);
    fixtures.assignAll(preservedFixtures);
  }

  void _sortFixtures(List<Match> nextFixtures) {
    nextFixtures.sort((left, right) {
      final leftSort = left.scheduledAt ?? left.createdAt;
      final rightSort = right.scheduledAt ?? right.createdAt;
      return leftSort.compareTo(rightSort);
    });
  }

  void _rebuildDerivedState({
    required List<TournamentParticipant> participantsResult,
    required List<TournamentGroup> groupsResult,
  }) {
    final participantById = {
      for (final participant in participantsResult) participant.id: participant,
    };
    final groupNameById = {
      for (final group in groupsResult) group.id: group.name,
    };
    final participantsByGroupId = <String, List<TournamentParticipant>>{};
    for (final group in groupsResult) {
      participantsByGroupId[group.id] = group.participantIds
          .map((participantId) => participantById[participantId])
          .whereType<TournamentParticipant>()
          .toList(growable: false);
    }

    _participantById = participantById;
    _groupNameById = groupNameById;
    _participantsByGroupId = participantsByGroupId;
  }

  void _clearDerivedState() {
    _participantById = const <String, TournamentParticipant>{};
    _groupNameById = const <String, String>{};
    _participantsByGroupId = const <String, List<TournamentParticipant>>{};
  }

  void _syncTournamentParticipantCountLocal({int? overrideCount}) {
    final currentTournament = tournament.value;
    if (currentTournament == null) {
      return;
    }
    final nextCount =
        overrideCount ??
        participants.where((participant) => participant.isActive).length;
    if (currentTournament.activeParticipantCount == nextCount) {
      return;
    }
    tournament.value = currentTournament.copyWith(
      activeParticipantCount: nextCount,
    );
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

class TournamentOpsChecklistItem {
  final String label;
  final bool isReady;
  final String detail;

  const TournamentOpsChecklistItem({
    required this.label,
    required this.isReady,
    required this.detail,
  });
}

class TournamentOpsPendingAction {
  final String title;
  final String detail;

  const TournamentOpsPendingAction({required this.title, required this.detail});
}

class _ParticipantCandidateCacheEntry {
  final DateTime cachedAt;
  final List<TournamentParticipantCandidate> candidates;

  const _ParticipantCandidateCacheEntry({
    required this.cachedAt,
    required this.candidates,
  });
}
