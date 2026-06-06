import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:el7reef/core/auth/session_reset_coordinator.dart';
import 'package:el7reef/core/enums/challenge_status.dart';
import 'package:el7reef/core/enums/match_status.dart';
import 'package:el7reef/core/enums/tournament_enums.dart';
import 'package:el7reef/core/services/activity_feed_service.dart';
import 'package:el7reef/core/services/match_cancellation_service.dart';
import 'package:el7reef/core/services/match_settlement_service.dart';
import 'package:el7reef/core/services/match_start_service.dart';
import 'package:el7reef/data/repositories/match_lineup_snapshot_repository_impl.dart';
import 'package:el7reef/data/repositories/match_repository_impl.dart';
import 'package:el7reef/data/repositories/match_side_player_repository_impl.dart';
import 'package:el7reef/data/repositories/player_repository_impl.dart';
import 'package:el7reef/data/repositories/team_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_repository_impl.dart';
import 'package:el7reef/domain/entities/challenge.dart';
import 'package:el7reef/domain/entities/match.dart';
import 'package:el7reef/domain/entities/player.dart';
import 'package:el7reef/domain/entities/team.dart';
import 'package:el7reef/domain/entities/tournament.dart';
import 'package:el7reef/domain/repositories/challenge_repository.dart';
import 'package:el7reef/features/match/controllers/challenge_controller.dart';
import 'package:el7reef/features/match/controllers/match_controller.dart';
import 'package:el7reef/features/profile/controllers/profile_controller.dart';
import 'package:el7reef/features/social/controllers/activity_feed_controller.dart';
import 'package:el7reef/features/team/controllers/team_controller.dart';
import 'package:el7reef/features/tournament/controllers/tournament_controller.dart';
import 'package:el7reef/core/auth/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAuthService authService;
  late FakeFirebaseFirestore firestore;

  setUp(() {
    Get.testMode = true;
    firestore = FakeFirebaseFirestore();
    authService = _FakeAuthService();
    Get.put<AuthService>(authService);
  });

  tearDown(Get.reset);

  test('TeamController clears myTeams and form state on session reset', () {
    final controller = TeamController(
      authService: authService,
      teamRepository: TeamRepositoryImpl(firestore: firestore),
    );
    controller.myTeams.add(_team('team-a'));
    controller.errorMessage.value = 'old error';
    controller.isLoading.value = true;
    controller.teamNameController.text = 'Old Team';

    controller.resetSessionState();

    expect(controller.myTeams, isEmpty);
    expect(controller.errorMessage.value, isEmpty);
    expect(controller.isLoading.value, isFalse);
    expect(controller.teamNameController.text, isEmpty);
    controller.onClose();
  });

  test(
    'MatchController clears myMatches and currentMatch on session reset',
    () {
      final matchRepository = MatchRepositoryImpl(db: firestore);
      final sidePlayerRepository = MatchSidePlayerRepositoryImpl(
        firestore: firestore,
      );
      final controller = MatchController(
        authService: authService,
        matchRepository: matchRepository,
        sidePlayerRepository: sidePlayerRepository,
        cancellationService: MatchCancellationService(firestore: firestore),
        settlementService: MatchSettlementService(firestore: firestore),
        matchStartService: MatchStartService(
          matchRepo: matchRepository,
          snapshotRepo: MatchLineupSnapshotRepositoryImpl(firestore: firestore),
          sidePlayerRepo: sidePlayerRepository,
        ),
      );
      final match = _match('match-a', organizerId: 'account-a');
      controller.myMatches.add(match);
      controller.currentMatch.value = match;
      controller.temporaryParticipantCountsByMatch['match-a'] =
          const MatchTemporaryParticipantCounts(teamA: 1, teamB: 2);
      controller.errorMessage.value = 'old error';
      controller.isLoading.value = true;

      controller.resetSessionState();

      expect(controller.myMatches, isEmpty);
      expect(controller.currentMatch.value, isNull);
      expect(controller.temporaryParticipantCountsByMatch, isEmpty);
      expect(controller.errorMessage.value, isEmpty);
      expect(controller.isLoading.value, isFalse);
      controller.onClose();
    },
  );

  test(
    'TournamentController clears organized tournaments and create form on reset',
    () {
      final controller = TournamentController(
        authService: authService,
        tournamentRepository: TournamentRepositoryImpl(db: firestore),
        teamRepository: TeamRepositoryImpl(firestore: firestore),
      );
      controller.myOrganizedTournaments.add(_tournament('tournament-a'));
      controller.followedTournaments.add(_tournament('followed-a'));
      controller.errorMessage.value = 'old error';
      controller.isLoading.value = true;
      controller.nameController.text = 'Old Cup';
      controller.descriptionController.text = 'Old description';
      controller.locationController.text = 'Old location';
      controller.maxTeamsController.text = '32';
      controller.selectedFormat.value = TournamentFormat.knockoutOnly;
      controller.selectedTeamSize.value = TournamentTeamSize.elevenVsEleven;
      controller.selectedVisibility.value = TournamentVisibility.private;
      controller.isFantasyEnabled.value = true;

      controller.resetSessionState();

      expect(controller.myOrganizedTournaments, isEmpty);
      expect(controller.followedTournaments, isEmpty);
      expect(controller.errorMessage.value, isEmpty);
      expect(controller.isLoading.value, isFalse);
      expect(controller.nameController.text, isEmpty);
      expect(controller.descriptionController.text, isEmpty);
      expect(controller.locationController.text, isEmpty);
      expect(controller.maxTeamsController.text, '8');
      expect(
        controller.selectedFormat.value,
        TournamentFormat.groupsThenKnockout,
      );
      expect(controller.selectedTeamSize.value, TournamentTeamSize.fiveVsFive);
      expect(controller.selectedVisibility.value, TournamentVisibility.public);
      expect(controller.isFantasyEnabled.value, isFalse);
      controller.onClose();
    },
  );

  test(
    'TournamentController keeps followed tournaments separate from my tournaments',
    () {
      final controller = TournamentController(
        authService: authService,
        tournamentRepository: TournamentRepositoryImpl(db: firestore),
        teamRepository: TeamRepositoryImpl(firestore: firestore),
      );
      final organized = _tournament(
        'organized-cup',
      ).copyWith(createdAt: DateTime(2026, 5, 8));
      final participating = _tournament(
        'participating-cup',
      ).copyWith(createdAt: DateTime(2026, 5, 9));
      final followedOnly = _tournament(
        'followed-only-cup',
      ).copyWith(createdAt: DateTime(2026, 5, 10));

      controller.myOrganizedTournaments.add(organized);
      controller.myParticipatingTournaments.add(participating);
      controller.followedTournaments.addAll([
        followedOnly,
        organized,
        participating,
      ]);

      expect(controller.myTournaments.map((tournament) => tournament.id), [
        'participating-cup',
        'organized-cup',
      ]);
      expect(
        controller.followedOnlyTournaments.map((tournament) => tournament.id),
        ['followed-only-cup'],
      );
      controller.onClose();
    },
  );

  test(
    'ChallengeController clears sent, received, and player names on reset',
    () {
      final controller = ChallengeController(
        challengeRepo: _UnusedChallengeRepository(),
        authService: authService,
        playerRepository: PlayerRepositoryImpl(firestore: firestore),
      );
      controller.sentChallenges.add(_challenge('sent-a'));
      controller.receivedChallenges.add(_challenge('received-a'));
      controller.playerNames['account-a'] = 'Old Player';
      controller.isLoading.value = true;

      controller.resetSessionState();

      expect(controller.sentChallenges, isEmpty);
      expect(controller.receivedChallenges, isEmpty);
      expect(controller.playerNames, isEmpty);
      expect(controller.isLoading.value, isFalse);
      controller.onClose();
    },
  );

  test('ActivityFeedController clears feed items on reset', () {
    final controller = ActivityFeedController(
      activityFeedService: ActivityFeedService(
        playerRepository: PlayerRepositoryImpl(firestore: firestore),
        matchRepository: MatchRepositoryImpl(db: firestore),
        tournamentRepository: TournamentRepositoryImpl(db: firestore),
        teamRepository: TeamRepositoryImpl(firestore: firestore),
      ),
      authService: authService,
    );
    controller.items.add(
      ActivityFeedEntry(
        id: 'entry-a',
        actorId: 'account-a',
        actorName: 'Old Player',
        actionText: 'played',
        highlightText: 'match',
        occurredAt: DateTime(2026, 5, 7),
        iconEmoji: '',
      ),
    );
    controller.errorMessage.value = 'old error';
    controller.isLoading.value = true;

    controller.resetSessionState();

    expect(controller.items, isEmpty);
    expect(controller.errorMessage.value, isEmpty);
    expect(controller.isLoading.value, isFalse);
    controller.onClose();
  });

  test('ProfileController clears selected session values on reset', () {
    final controller = ProfileController(
      authService: authService,
      playerRepository: PlayerRepositoryImpl(firestore: firestore),
    );
    controller.selectedPosition.value = 'MID';
    controller.isLoading.value = true;

    controller.resetSessionState();

    expect(controller.selectedPosition.value, isEmpty);
    expect(controller.isLoading.value, isFalse);
    controller.onClose();
  });

  test(
    'SessionResetCoordinator clears registered user-scoped controllers',
    () async {
      final coordinator = SessionResetCoordinator();
      var resetCount = 0;
      coordinator.register(
        key: 'test-controller',
        onReset: () {
          resetCount += 1;
        },
      );

      await coordinator.resetForSignOut();

      expect(resetCount, 1);
      expect(coordinator.activeUserId, isNull);
    },
  );

  test('SessionResetCoordinator clears stale data on uid switch', () async {
    final coordinator = SessionResetCoordinator();
    var resetCount = 0;
    coordinator.register(
      key: 'test-controller',
      onReset: () {
        resetCount += 1;
      },
    );

    await coordinator.handleAuthUidChanged('account-a');
    await coordinator.handleAuthUidChanged('account-a');
    await coordinator.handleAuthUidChanged('account-b');

    expect(resetCount, 1);
    expect(coordinator.activeUserId, 'account-b');
  });

  test('controllers reload fresh user data when auth player changes', () async {
    final controller = _ReloadTrackingTeamController(
      authService: authService,
      teamRepository: TeamRepositoryImpl(firestore: firestore),
    );
    controller.onInit();
    controller.myTeams.add(_team('account-a-team'));

    authService.setCurrentPlayer(null);

    expect(controller.myTeams, isEmpty);

    authService.setCurrentPlayer(_player('account-b'));
    await Future<void>.delayed(Duration.zero);

    expect(controller.loadCalls, 2);
    expect(controller.loadedForUserIds.last, 'account-b');
    controller.onClose();
  });

  test(
    'TournamentController reloads organized tournaments for new uid only',
    () async {
      final controller = _ReloadTrackingTournamentController(
        authService: authService,
        tournamentRepository: TournamentRepositoryImpl(db: firestore),
        teamRepository: TeamRepositoryImpl(firestore: firestore),
      );
      controller.onInit();
      controller.myOrganizedTournaments.add(_tournament('account-a-cup'));

      authService.setCurrentPlayer(null);

      expect(controller.myOrganizedTournaments, isEmpty);

      authService.setCurrentPlayer(_player('account-b'));
      await Future<void>.delayed(Duration.zero);

      expect(controller.loadCalls, 2);
      expect(controller.loadedForUserIds.last, 'account-b');
      controller.onClose();
    },
  );
}

class _ReloadTrackingTeamController extends TeamController {
  int loadCalls = 0;
  final List<String?> loadedForUserIds = [];

  _ReloadTrackingTeamController({
    required super.authService,
    required super.teamRepository,
  });

  @override
  Future<void> loadMyTeams() async {
    loadCalls += 1;
    loadedForUserIds.add(Get.find<AuthService>().currentUserId);
  }
}

class _ReloadTrackingTournamentController extends TournamentController {
  int loadCalls = 0;
  final List<String?> loadedForUserIds = [];

  _ReloadTrackingTournamentController({
    required super.authService,
    required super.tournamentRepository,
    required super.teamRepository,
  });

  @override
  Future<void> loadMyTournaments() async {
    loadCalls += 1;
    loadedForUserIds.add(Get.find<AuthService>().currentUserId);
  }

  @override
  Future<void> loadLiveTournaments() async {}
}

class _FakeAuthService extends GetxService implements AuthService {
  final Rx<Player?> _currentPlayer = Rx<Player?>(null);

  void setCurrentPlayer(Player? player) {
    _currentPlayer.value = player;
  }

  @override
  Rx<Player?> get currentPlayer => _currentPlayer;

  @override
  String? get currentUserId => _currentPlayer.value?.id;

  @override
  bool get isLoggedIn => currentUserId != null;

  @override
  RxBool get isLoading => false.obs;

  @override
  Future<AuthService> init() async => this;

  @override
  Future<void> refreshProfile() async {}

  @override
  Future<Player?> signInWithGoogle() async => _currentPlayer.value;

  @override
  Future<void> signOut() async {
    _currentPlayer.value = null;
  }
}

class _UnusedChallengeRepository implements ChallengeRepository {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Player _player(String id) {
  final now = DateTime(2026, 5, 7);
  return Player(id: id, name: id, createdAt: now, lastActiveAt: now);
}

Team _team(String id) {
  return Team(
    id: id,
    name: id,
    ownerId: 'account-a',
    createdAt: DateTime(2026, 5, 7),
  );
}

Match _match(String id, {required String organizerId}) {
  return Match(
    id: id,
    organizerId: organizerId,
    status: MatchStatus.open,
    createdAt: DateTime(2026, 5, 7),
  );
}

Tournament _tournament(String id) {
  return Tournament(
    id: id,
    organizerId: 'account-a',
    name: id,
    format: TournamentFormat.groupsThenKnockout,
    teamSize: TournamentTeamSize.fiveVsFive,
    maxTeams: 8,
    createdAt: DateTime(2026, 5, 7),
  );
}

Challenge _challenge(String id) {
  return Challenge(
    id: id,
    challengerId: 'account-a',
    challengedId: 'account-b',
    teamSize: 5,
    status: ChallengeStatus.pending,
    createdAt: DateTime(2026, 5, 7),
    expiresAt: DateTime(2026, 5, 10),
  );
}
