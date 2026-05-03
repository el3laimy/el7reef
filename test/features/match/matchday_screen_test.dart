import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:el7reef/app/routes/app_pages.dart';
import 'package:el7reef/app/routes/app_routes.dart';
import 'package:el7reef/core/auth/auth_session.dart';
import 'package:el7reef/core/enums/match_attendance_status.dart';
import 'package:el7reef/core/enums/match_status.dart';
import 'package:el7reef/core/enums/team_member_availability.dart';
import 'package:el7reef/core/enums/team_membership_role.dart';
import 'package:el7reef/core/enums/team_membership_status.dart';
import 'package:el7reef/core/enums/tournament_enums.dart';
import 'package:el7reef/core/enums/tournament_registration_mode.dart';
import 'package:el7reef/core/enums/tournament_registration_status.dart';
import 'package:el7reef/core/services/matchday_service.dart';
import 'package:el7reef/core/services/tournament_permission_service.dart';
import 'package:el7reef/data/repositories/guest_player_repository_impl.dart';
import 'package:el7reef/data/repositories/guest_team_repository_impl.dart';
import 'package:el7reef/data/repositories/match_attendance_repository_impl.dart';
import 'package:el7reef/data/repositories/match_check_in_repository_impl.dart';
import 'package:el7reef/data/repositories/match_lineup_snapshot_repository_impl.dart';
import 'package:el7reef/data/repositories/match_repository_impl.dart';
import 'package:el7reef/data/repositories/match_side_repository_impl.dart';
import 'package:el7reef/data/repositories/match_substitution_repository_impl.dart';
import 'package:el7reef/data/repositories/player_repository_impl.dart';
import 'package:el7reef/data/repositories/team_membership_repository_impl.dart';
import 'package:el7reef/data/repositories/team_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_registration_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_repository_impl.dart';
import 'package:el7reef/domain/entities/guest_player.dart';
import 'package:el7reef/domain/entities/guest_team.dart';
import 'package:el7reef/domain/entities/match.dart';
import 'package:el7reef/domain/entities/player.dart';
import 'package:el7reef/domain/entities/team.dart';
import 'package:el7reef/domain/entities/team_membership.dart';
import 'package:el7reef/domain/entities/tournament.dart';
import 'package:el7reef/domain/entities/tournament_registration.dart';
import 'package:el7reef/features/match/controllers/matchday_controller.dart';
import 'package:el7reef/features/match/views/matchday_screen.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late MatchdayService matchdayService;
  late MatchRepositoryImpl matchRepository;
  late TournamentRepositoryImpl tournamentRepository;
  late TournamentRegistrationRepositoryImpl registrationRepository;
  late TeamRepositoryImpl teamRepository;
  late TeamMembershipRepositoryImpl membershipRepository;
  late PlayerRepositoryImpl playerRepository;
  late GuestPlayerRepositoryImpl guestPlayerRepository;
  late GuestTeamRepositoryImpl guestTeamRepository;
  late MatchAttendanceRepositoryImpl attendanceRepository;
  late MatchSubstitutionRepositoryImpl substitutionRepository;
  late DateTime now;

  setUp(() async {
    Get.testMode = true;
    firestore = FakeFirebaseFirestore();
    now = DateTime(2026, 4, 17, 20);

    matchdayService = MatchdayService(firestore: firestore);
    matchRepository = MatchRepositoryImpl(db: firestore);
    tournamentRepository = TournamentRepositoryImpl(db: firestore);
    registrationRepository = TournamentRegistrationRepositoryImpl(
      firestore: firestore,
    );
    teamRepository = TeamRepositoryImpl(firestore: firestore);
    membershipRepository = TeamMembershipRepositoryImpl(firestore: firestore);
    playerRepository = PlayerRepositoryImpl(firestore: firestore);
    guestPlayerRepository = GuestPlayerRepositoryImpl(firestore: firestore);
    guestTeamRepository = GuestTeamRepositoryImpl(firestore: firestore);
    attendanceRepository = MatchAttendanceRepositoryImpl(firestore: firestore);
    substitutionRepository = MatchSubstitutionRepositoryImpl(
      firestore: firestore,
    );

    Get.put<MatchRepositoryImpl>(matchRepository, permanent: true);
    Get.put<TournamentRepositoryImpl>(tournamentRepository, permanent: true);
    Get.put<TournamentRegistrationRepositoryImpl>(
      registrationRepository,
      permanent: true,
    );
    Get.put<TeamRepositoryImpl>(teamRepository, permanent: true);
    Get.put<TeamMembershipRepositoryImpl>(
      membershipRepository,
      permanent: true,
    );
    Get.put<PlayerRepositoryImpl>(playerRepository, permanent: true);
    Get.put<GuestPlayerRepositoryImpl>(guestPlayerRepository, permanent: true);
    Get.put<GuestTeamRepositoryImpl>(guestTeamRepository, permanent: true);
    Get.put<MatchCheckInRepositoryImpl>(
      MatchCheckInRepositoryImpl(firestore: firestore),
      permanent: true,
    );
    Get.put<MatchAttendanceRepositoryImpl>(
      attendanceRepository,
      permanent: true,
    );
    Get.put<MatchLineupSnapshotRepositoryImpl>(
      MatchLineupSnapshotRepositoryImpl(firestore: firestore),
      permanent: true,
    );
    Get.put<MatchSideRepositoryImpl>(
      MatchSideRepositoryImpl(firestore: firestore),
      permanent: true,
    );
    Get.put<MatchSubstitutionRepositoryImpl>(
      substitutionRepository,
      permanent: true,
    );
    Get.put<TournamentPermissionService>(
      TournamentPermissionService(),
      permanent: true,
    );
    Get.put<MatchdayService>(matchdayService, permanent: true);

    await _seedTournament(tournamentRepository, now);
    final memberships = await _seedRegisteredTeam(
      teamRepository: teamRepository,
      playerRepository: playerRepository,
      membershipRepository: membershipRepository,
      now: now,
    );
    await _seedApprovedRegistration(
      registrationRepository: registrationRepository,
      tournamentId: 'tournament-1',
      teamId: 'team-1',
      now: now,
    );
    await matchRepository.createMatch(
      Match(
        id: 'match-1',
        organizerId: 'organizer-1',
        teamAId: 'team-1',
        status: MatchStatus.open,
        isOrganized: true,
        tournamentId: 'tournament-1',
        createdAt: now,
      ),
    );

    expect(memberships, hasLength(6));
  });

  tearDown(Get.reset);

  testWidgets('matchday route boots into the dedicated screen', (
    WidgetTester tester,
  ) async {
    _setLargeViewport(tester);
    Get.put<AuthSession>(
      _FakeAuthSession(
        currentUserId: 'owner-1',
        currentPlayer: Player(
          id: 'owner-1',
          name: 'Captain Blue',
          createdAt: now,
          lastActiveAt: now,
        ),
      ),
    );

    await tester.pumpWidget(_buildApp(AppRoutes.matchDetailsById('match-1')));
    await tester.pumpAndSettle();

    expect(find.byType(MatchdayScreen), findsOneWidget);
    expect(find.text('Blue Sharks'), findsWidgets);
  });

  testWidgets(
    'captain can complete check-in and lock lineup from matchday screen',
    (WidgetTester tester) async {
      _setLargeViewport(tester);
      final controller = _putDirectController(
        currentUserId: 'owner-1',
        currentPlayer: Player(
          id: 'owner-1',
          name: 'Captain Blue',
          createdAt: now,
          lastActiveAt: now,
        ),
      );
      await controller.loadMatchday();
      await tester.pumpWidget(_buildDirectApp());
      await tester.pumpAndSettle();

      final checkInButton = find.widgetWithText(FilledButton, 'تنفيذ check-in');
      expect(checkInButton, findsOneWidget);
      await tester.scrollUntilVisible(
        checkInButton,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(checkInButton, warnIfMissed: false);
      await tester.pumpAndSettle();
      await _closeSnackbarsIfNeeded(tester);

      expect(controller.activeCheckIn.value?.isCheckedIn, isTrue);

      final lockButton = find.widgetWithText(FilledButton, 'قفل التشكيل');
      await tester.scrollUntilVisible(
        lockButton,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(lockButton, warnIfMissed: false);
      await tester.pumpAndSettle();
      await _closeSnackbarsIfNeeded(tester);

      expect(controller.activeSnapshot.value, isNotNull);
      expect(controller.activeSnapshot.value?.starters, hasLength(5));
    },
  );

  testWidgets(
    'organizer can register a substitution from the matchday screen',
    (WidgetTester tester) async {
      _setLargeViewport(tester);
      await matchdayService.checkInRegisteredTeam(
        matchId: 'match-1',
        teamId: 'team-1',
        actorId: 'owner-1',
        membershipStatuses: const {
          'membership-1': MatchAttendanceStatus.present,
          'membership-2': MatchAttendanceStatus.present,
          'membership-3': MatchAttendanceStatus.present,
          'membership-4': MatchAttendanceStatus.present,
          'membership-5': MatchAttendanceStatus.present,
          'membership-6': MatchAttendanceStatus.present,
        },
        now: now.add(const Duration(minutes: 10)),
      );
      await matchdayService.lockRegisteredTeamLineup(
        matchId: 'match-1',
        teamId: 'team-1',
        actorId: 'owner-1',
        starterMembershipIds: const [
          'membership-1',
          'membership-2',
          'membership-3',
          'membership-4',
          'membership-5',
        ],
        benchMembershipIds: const ['membership-6'],
        now: now.add(const Duration(minutes: 15)),
      );

      final controller = _putDirectController(
        currentUserId: 'organizer-1',
        currentPlayer: Player(
          id: 'organizer-1',
          name: 'Organizer One',
          createdAt: now,
          lastActiveAt: now,
        ),
      );
      await controller.loadMatchday();
      await tester.pumpWidget(_buildDirectApp());
      await tester.pumpAndSettle();

      expect(controller.activeSnapshot.value, isNotNull);

      final dropdowns = find.byWidgetPredicate(
        (widget) => widget is DropdownButton<String>,
      );
      expect(dropdowns, findsNWidgets(2));

      await tester.ensureVisible(dropdowns.first);
      await tester.tap(dropdowns.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Captain Blue').last);
      await tester.pumpAndSettle();

      await tester.tap(dropdowns.last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blue Six').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'دقيقة التبديل'),
        '9',
      );
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'تسجيل التبديل'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'تسجيل التبديل'));
      await tester.pumpAndSettle();
      await _closeSnackbarsIfNeeded(tester);

      final substitutions = await substitutionRepository.getTeamSubstitutions(
        matchId: 'match-1',
        teamId: 'team-1',
      );
      final attendances = await attendanceRepository.getTeamAttendances(
        matchId: 'match-1',
        teamId: 'team-1',
      );

      expect(substitutions, hasLength(1));
      expect(substitutions.single.minute, 9);
      expect(find.textContaining('Captain Blue ⟶ Blue Six'), findsOneWidget);
      expect(
        attendances
            .singleWhere(
              (attendance) => attendance.teamMembershipId == 'membership-6',
            )
            .currentlyOnPitch,
        isTrue,
      );
    },
  );

  testWidgets('guest matchday only loads roster of the selected guest team', (
    WidgetTester tester,
  ) async {
    _setLargeViewport(tester);
    await guestTeamRepository.createGuestTeam(
      GuestTeam(
        id: 'guest-team-1',
        name: 'Red Guests',
        normalizedName: 'red guests',
        creatorId: 'organizer-1',
        tournamentIds: const ['tournament-1'],
        createdAt: now,
        updatedAt: now,
      ),
    );
    await guestTeamRepository.createGuestTeam(
      GuestTeam(
        id: 'guest-team-2',
        name: 'Black Guests',
        normalizedName: 'black guests',
        creatorId: 'organizer-1',
        tournamentIds: const ['tournament-1'],
        createdAt: now,
        updatedAt: now,
      ),
    );
    await guestPlayerRepository.createGuestPlayer(
      GuestPlayer(
        id: 'guest-player-1',
        displayName: 'Guest One',
        normalizedName: 'guest one',
        guestTeamId: 'guest-team-1',
        tournamentId: 'tournament-1',
        createdBy: 'organizer-1',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await guestPlayerRepository.createGuestPlayer(
      GuestPlayer(
        id: 'guest-player-2',
        displayName: 'Guest Two',
        normalizedName: 'guest two',
        guestTeamId: 'guest-team-1',
        tournamentId: 'tournament-1',
        createdBy: 'organizer-1',
        createdAt: now.add(const Duration(minutes: 1)),
        updatedAt: now.add(const Duration(minutes: 1)),
      ),
    );
    await guestPlayerRepository.createGuestPlayer(
      GuestPlayer(
        id: 'guest-player-3',
        displayName: 'Other Team Guest',
        normalizedName: 'other team guest',
        guestTeamId: 'guest-team-2',
        tournamentId: 'tournament-1',
        createdBy: 'organizer-1',
        createdAt: now.add(const Duration(minutes: 2)),
        updatedAt: now.add(const Duration(minutes: 2)),
      ),
    );
    await registrationRepository.createRegistration(
      TournamentRegistration(
        id: 'registration::tournament-1::guest-team-1',
        tournamentId: 'tournament-1',
        guestTeamId: 'guest-team-1',
        mode: TournamentRegistrationMode.quick,
        status: TournamentRegistrationStatus.approved,
        createdBy: 'organizer-1',
        createdAt: now,
        updatedAt: now,
        verifiedBy: 'organizer-1',
        verifiedAt: now,
      ),
    );
    await registrationRepository.createRegistration(
      TournamentRegistration(
        id: 'registration::tournament-1::guest-team-2',
        tournamentId: 'tournament-1',
        guestTeamId: 'guest-team-2',
        mode: TournamentRegistrationMode.quick,
        status: TournamentRegistrationStatus.approved,
        createdBy: 'organizer-1',
        createdAt: now,
        updatedAt: now,
        verifiedBy: 'organizer-1',
        verifiedAt: now,
      ),
    );
    await matchRepository.createMatch(
      Match(
        id: 'match-guest-1',
        organizerId: 'organizer-1',
        teamAId: 'team-1',
        status: MatchStatus.open,
        isOrganized: true,
        tournamentId: 'tournament-1',
        createdAt: now,
      ),
    );

    final controller = _putDirectController(
      matchId: 'match-guest-1',
      currentUserId: 'organizer-1',
      currentPlayer: Player(
        id: 'organizer-1',
        name: 'Organizer One',
        createdAt: now,
        lastActiveAt: now,
      ),
    );
    await controller.loadMatchday();
    await tester.pumpWidget(_buildDirectApp());
    await tester.pumpAndSettle();
    await controller.selectSide('guest::guest-team-1');
    await tester.pumpAndSettle();

    expect(
      controller.participants.map((participant) => participant.displayName),
      containsAll(['Guest One', 'Guest Two']),
    );
    expect(
      controller.participants.map((participant) => participant.displayName),
      isNot(contains('Other Team Guest')),
    );
  });
}

Widget _buildApp(String initialRoute) {
  return GetMaterialApp(getPages: AppPages.routes, initialRoute: initialRoute);
}

Widget _buildDirectApp() {
  return GetMaterialApp(home: const MatchdayScreen());
}

MatchdayController _putDirectController({
  String matchId = 'match-1',
  required String currentUserId,
  required Player currentPlayer,
}) {
  Get.put<AuthSession>(
    _FakeAuthSession(
      currentUserId: currentUserId,
      currentPlayer: currentPlayer,
    ),
    permanent: true,
  );
  return Get.put<MatchdayController>(
    MatchdayController(
      matchId: matchId,
      authSession: Get.find<AuthSession>(),
      matchdayService: Get.find<MatchdayService>(),
      matchRepository: Get.find<MatchRepositoryImpl>(),
      tournamentRepository: Get.find<TournamentRepositoryImpl>(),
      registrationRepository: Get.find<TournamentRegistrationRepositoryImpl>(),
      teamRepository: Get.find<TeamRepositoryImpl>(),
      guestTeamRepository: Get.find<GuestTeamRepositoryImpl>(),
      membershipRepository: Get.find<TeamMembershipRepositoryImpl>(),
      playerRepository: Get.find<PlayerRepositoryImpl>(),
      guestPlayerRepository: Get.find<GuestPlayerRepositoryImpl>(),
      checkInRepository: Get.find<MatchCheckInRepositoryImpl>(),
      attendanceRepository: Get.find<MatchAttendanceRepositoryImpl>(),
      snapshotRepository: Get.find<MatchLineupSnapshotRepositoryImpl>(),
      matchSideRepository: Get.find<MatchSideRepositoryImpl>(),
      substitutionRepository: Get.find<MatchSubstitutionRepositoryImpl>(),
      tournamentPermissionService: Get.find<TournamentPermissionService>(),
    ),
    permanent: true,
  );
}

void _setLargeViewport(WidgetTester tester) {
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  tester.view.physicalSize = const Size(1440, 3200);
  tester.view.devicePixelRatio = 1.0;
}

Future<void> _closeSnackbarsIfNeeded(WidgetTester tester) async {
  if (Get.isSnackbarOpen) {
    Get.closeAllSnackbars();
    await tester.pumpAndSettle();
  }
}

Future<void> _seedTournament(
  TournamentRepositoryImpl tournamentRepository,
  DateTime now,
) {
  return tournamentRepository.createTournament(
    Tournament(
      id: 'tournament-1',
      organizerId: 'organizer-1',
      name: 'Street League',
      format: TournamentFormat.groupsThenKnockout,
      teamSize: TournamentTeamSize.fiveVsFive,
      maxTeams: 8,
      status: TournamentStatus.groupStage,
      createdAt: now,
    ),
  );
}

Future<List<TeamMembership>> _seedRegisteredTeam({
  required TeamRepositoryImpl teamRepository,
  required PlayerRepositoryImpl playerRepository,
  required TeamMembershipRepositoryImpl membershipRepository,
  required DateTime now,
}) async {
  const playerIds = [
    'owner-1',
    'vice-1',
    'player-3',
    'player-4',
    'player-5',
    'player-6',
  ];
  const playerNames = [
    'Captain Blue',
    'Vice Blue',
    'Blue Three',
    'Blue Four',
    'Blue Five',
    'Blue Six',
  ];
  const positions = ['GK', 'DEF', 'DEF', 'MID', 'FWD', 'MID'];

  for (var index = 0; index < playerIds.length; index += 1) {
    await playerRepository.createPlayer(
      Player(
        id: playerIds[index],
        name: playerNames[index],
        position: positions[index],
        teamIds: const ['team-1'],
        createdAt: now,
        lastActiveAt: now,
      ),
    );
  }

  await teamRepository.createTeam(
    Team(
      id: 'team-1',
      name: 'Blue Sharks',
      ownerId: 'owner-1',
      viceCaptainIds: const ['vice-1'],
      playerIds: playerIds,
      tournamentIds: const ['tournament-1'],
      createdAt: now,
    ),
  );

  final memberships = <TeamMembership>[
    TeamMembership(
      id: 'membership-1',
      teamId: 'team-1',
      playerId: 'owner-1',
      role: TeamMembershipRole.owner,
      status: TeamMembershipStatus.starter,
      availability: TeamMemberAvailability.available,
      joinedAt: now,
      updatedAt: now,
    ),
    TeamMembership(
      id: 'membership-2',
      teamId: 'team-1',
      playerId: 'vice-1',
      role: TeamMembershipRole.viceCaptain,
      status: TeamMembershipStatus.starter,
      availability: TeamMemberAvailability.available,
      joinedAt: now,
      updatedAt: now,
    ),
    TeamMembership(
      id: 'membership-3',
      teamId: 'team-1',
      playerId: 'player-3',
      role: TeamMembershipRole.player,
      status: TeamMembershipStatus.starter,
      availability: TeamMemberAvailability.available,
      joinedAt: now,
      updatedAt: now,
    ),
    TeamMembership(
      id: 'membership-4',
      teamId: 'team-1',
      playerId: 'player-4',
      role: TeamMembershipRole.player,
      status: TeamMembershipStatus.starter,
      availability: TeamMemberAvailability.available,
      joinedAt: now,
      updatedAt: now,
    ),
    TeamMembership(
      id: 'membership-5',
      teamId: 'team-1',
      playerId: 'player-5',
      role: TeamMembershipRole.player,
      status: TeamMembershipStatus.starter,
      availability: TeamMemberAvailability.available,
      joinedAt: now,
      updatedAt: now,
    ),
    TeamMembership(
      id: 'membership-6',
      teamId: 'team-1',
      playerId: 'player-6',
      role: TeamMembershipRole.player,
      status: TeamMembershipStatus.bench,
      availability: TeamMemberAvailability.available,
      joinedAt: now,
      updatedAt: now,
    ),
  ];

  for (final membership in memberships) {
    await membershipRepository.createMembership(membership);
  }

  return memberships;
}

Future<void> _seedApprovedRegistration({
  required TournamentRegistrationRepositoryImpl registrationRepository,
  required String tournamentId,
  required String teamId,
  required DateTime now,
}) {
  return registrationRepository.createRegistration(
    TournamentRegistration(
      id: 'registration::$tournamentId::$teamId',
      tournamentId: tournamentId,
      teamId: teamId,
      mode: TournamentRegistrationMode.hybrid,
      status: TournamentRegistrationStatus.approved,
      createdBy: 'organizer-1',
      createdAt: now,
      updatedAt: now,
      verifiedBy: 'organizer-1',
      verifiedAt: now,
    ),
  );
}

class _FakeAuthSession implements AuthSession {
  final String? _currentUserId;
  final Player? _currentPlayer;

  const _FakeAuthSession({
    required String? currentUserId,
    required Player? currentPlayer,
  }) : _currentUserId = currentUserId,
       _currentPlayer = currentPlayer;

  @override
  Player? get currentPlayer => _currentPlayer;

  @override
  String? get currentUserId => _currentUserId;
}
