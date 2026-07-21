import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/enums/guest_claim_status.dart';
import 'package:el7reef/core/enums/match_attendance_status.dart';
import 'package:el7reef/core/enums/match_check_in_status.dart';
import 'package:el7reef/core/enums/match_status.dart';
import 'package:el7reef/core/enums/team_member_availability.dart';
import 'package:el7reef/core/enums/team_membership_role.dart';
import 'package:el7reef/core/enums/team_membership_status.dart';
import 'package:el7reef/core/enums/tournament_enums.dart';
import 'package:el7reef/core/enums/tournament_ops_enums.dart';
import 'package:el7reef/core/enums/tournament_registration_mode.dart';
import 'package:el7reef/core/enums/tournament_registration_status.dart';
import 'package:el7reef/core/services/matchday_service.dart';
import 'package:el7reef/data/repositories/guest_player_repository_impl.dart';
import 'package:el7reef/data/repositories/guest_team_repository_impl.dart';
import 'package:el7reef/data/repositories/match_attendance_repository_impl.dart';
import 'package:el7reef/data/repositories/match_check_in_repository_impl.dart';
import 'package:el7reef/data/repositories/match_lineup_snapshot_repository_impl.dart';
import 'package:el7reef/data/repositories/match_repository_impl.dart';
import 'package:el7reef/data/repositories/match_substitution_repository_impl.dart';
import 'package:el7reef/data/repositories/player_repository_impl.dart';
import 'package:el7reef/data/repositories/team_membership_repository_impl.dart';
import 'package:el7reef/data/repositories/team_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_participant_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_registration_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_repository_impl.dart';
import 'package:el7reef/domain/entities/guest_player.dart';
import 'package:el7reef/domain/entities/guest_team.dart';
import 'package:el7reef/domain/entities/match.dart';
import 'package:el7reef/domain/entities/player.dart';
import 'package:el7reef/domain/entities/team.dart';
import 'package:el7reef/domain/entities/team_membership.dart';
import 'package:el7reef/domain/entities/tournament.dart';
import 'package:el7reef/domain/entities/tournament_participant.dart';
import 'package:el7reef/domain/entities/tournament_registration.dart';

void main() {
  group('MatchdayService', () {
    late FakeFirebaseFirestore firestore;
    late MatchdayService service;
    late MatchRepositoryImpl matchRepository;
    late TournamentRepositoryImpl tournamentRepository;
    late TournamentParticipantRepositoryImpl participantRepository;
    late TournamentRegistrationRepositoryImpl registrationRepository;
    late TeamRepositoryImpl teamRepository;
    late TeamMembershipRepositoryImpl membershipRepository;
    late PlayerRepositoryImpl playerRepository;
    late GuestTeamRepositoryImpl guestTeamRepository;
    late GuestPlayerRepositoryImpl guestPlayerRepository;
    late MatchCheckInRepositoryImpl checkInRepository;
    late MatchAttendanceRepositoryImpl attendanceRepository;
    late MatchLineupSnapshotRepositoryImpl snapshotRepository;
    late MatchSubstitutionRepositoryImpl substitutionRepository;
    late DateTime now;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = MatchdayService(firestore: firestore);
      matchRepository = MatchRepositoryImpl(db: firestore);
      tournamentRepository = TournamentRepositoryImpl(db: firestore);
      participantRepository = TournamentParticipantRepositoryImpl(
        firestore: firestore,
      );
      registrationRepository = TournamentRegistrationRepositoryImpl(
        firestore: firestore,
      );
      teamRepository = TeamRepositoryImpl(firestore: firestore);
      membershipRepository = TeamMembershipRepositoryImpl(firestore: firestore);
      playerRepository = PlayerRepositoryImpl(firestore: firestore);
      guestTeamRepository = GuestTeamRepositoryImpl(firestore: firestore);
      guestPlayerRepository = GuestPlayerRepositoryImpl(firestore: firestore);
      checkInRepository = MatchCheckInRepositoryImpl(firestore: firestore);
      attendanceRepository = MatchAttendanceRepositoryImpl(
        firestore: firestore,
      );
      snapshotRepository = MatchLineupSnapshotRepositoryImpl(
        firestore: firestore,
      );
      substitutionRepository = MatchSubstitutionRepositoryImpl(
        firestore: firestore,
      );
      now = DateTime(2026, 4, 16, 20);
    });

    test(
      'checks in a registered team and locks a valid lineup snapshot',
      () async {
        await _seedTournament(tournamentRepository, now);
        final memberships = await _seedRegisteredTeam(
          teamRepository: teamRepository,
          playerRepository: playerRepository,
          membershipRepository: membershipRepository,
          now: now,
        );
        await _seedApprovedRegisteredRegistration(
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

        final checkInResult = await service.checkInRegisteredTeam(
          matchId: 'match-1',
          teamId: 'team-1',
          actorId: 'owner-1',
          membershipStatuses: {
            for (final membership in memberships)
              membership.id: MatchAttendanceStatus.present,
          },
          now: now.add(const Duration(minutes: 10)),
        );
        final lockResult = await service.lockRegisteredTeamLineup(
          matchId: 'match-1',
          teamId: 'team-1',
          actorId: 'owner-1',
          starterMembershipIds: memberships
              .take(5)
              .map((entry) => entry.id)
              .toList(),
          benchMembershipIds: [memberships.last.id],
          formationLabel: '2-2-1',
          now: now.add(const Duration(minutes: 20)),
        );

        final checkIn = await checkInRepository.getCheckInByTeamId(
          matchId: 'match-1',
          teamId: 'team-1',
        );
        final attendances = await attendanceRepository.getTeamAttendances(
          matchId: 'match-1',
          teamId: 'team-1',
        );
        final snapshot = await snapshotRepository.getSnapshotByTeamId(
          matchId: 'match-1',
          teamId: 'team-1',
        );

        expect(checkInResult.outcome, MatchdayCheckInOutcome.checkedIn);
        expect(checkIn?.status, MatchCheckInStatus.checkedIn);
        expect(attendances, hasLength(6));
        expect(lockResult.outcome, MatchdayLineupLockOutcome.locked);
        expect(lockResult.validation.requiredStarterCount, 5);
        expect(snapshot?.starters, hasLength(5));
        expect(snapshot?.bench, hasLength(1));
        expect(snapshot?.formationLabel, '2-2-1');
        expect(snapshot?.lockedBy, 'owner-1');
        expect(
          attendances.where(
            (entry) => entry.startedMatch && entry.currentlyOnPitch,
          ),
          hasLength(5),
        );
        expect(
          attendances.where(
            (entry) => entry.played && entry.firstEnteredMinute == 0,
          ),
          hasLength(5),
        );
        expect(
          attendances
              .singleWhere((entry) => entry.teamMembershipId == 'membership-6')
              .played,
          isFalse,
        );
        expect(
          attendances
              .singleWhere((entry) => entry.teamMembershipId == 'membership-6')
              .includedInLockedLineup,
          isTrue,
        );
      },
    );

    test(
      'rejects lineup lock when starter count does not match tournament size',
      () async {
        await _seedTournament(tournamentRepository, now);
        final memberships = await _seedRegisteredTeam(
          teamRepository: teamRepository,
          playerRepository: playerRepository,
          membershipRepository: membershipRepository,
          now: now,
        );
        await _seedApprovedRegisteredRegistration(
          registrationRepository: registrationRepository,
          tournamentId: 'tournament-1',
          teamId: 'team-1',
          now: now,
        );
        await matchRepository.createMatch(
          Match(
            id: 'match-2',
            organizerId: 'organizer-1',
            teamAId: 'team-1',
            status: MatchStatus.open,
            isOrganized: true,
            tournamentId: 'tournament-1',
            createdAt: now,
          ),
        );
        await service.checkInRegisteredTeam(
          matchId: 'match-2',
          teamId: 'team-1',
          actorId: 'owner-1',
          membershipStatuses: {
            for (final membership in memberships)
              membership.id: MatchAttendanceStatus.present,
          },
          now: now.add(const Duration(minutes: 10)),
        );

        expect(
          () => service.lockRegisteredTeamLineup(
            matchId: 'match-2',
            teamId: 'team-1',
            actorId: 'owner-1',
            starterMembershipIds: memberships
                .take(4)
                .map((entry) => entry.id)
                .toList(),
            benchMembershipIds: [memberships[4].id, memberships[5].id],
            now: now.add(const Duration(minutes: 20)),
          ),
          throwsA(
            isA<Exception>().having(
              (error) => error.toString(),
              'message',
              contains('5 لاعبين أساسيين'),
            ),
          ),
        );
      },
    );

    test(
      're-running lineup lock returns the existing snapshot idempotently',
      () async {
        await _seedTournament(tournamentRepository, now);
        final memberships = await _seedRegisteredTeam(
          teamRepository: teamRepository,
          playerRepository: playerRepository,
          membershipRepository: membershipRepository,
          now: now,
        );
        await _seedApprovedRegisteredRegistration(
          registrationRepository: registrationRepository,
          tournamentId: 'tournament-1',
          teamId: 'team-1',
          now: now,
        );
        await matchRepository.createMatch(
          Match(
            id: 'match-3',
            organizerId: 'organizer-1',
            teamAId: 'team-1',
            status: MatchStatus.open,
            isOrganized: true,
            tournamentId: 'tournament-1',
            createdAt: now,
          ),
        );
        await service.checkInRegisteredTeam(
          matchId: 'match-3',
          teamId: 'team-1',
          actorId: 'owner-1',
          membershipStatuses: {
            for (final membership in memberships)
              membership.id: MatchAttendanceStatus.present,
          },
          now: now.add(const Duration(minutes: 10)),
        );

        final first = await service.lockRegisteredTeamLineup(
          matchId: 'match-3',
          teamId: 'team-1',
          actorId: 'owner-1',
          starterMembershipIds: memberships
              .take(5)
              .map((entry) => entry.id)
              .toList(),
          benchMembershipIds: [memberships.last.id],
          now: now.add(const Duration(minutes: 20)),
        );
        final second = await service.lockRegisteredTeamLineup(
          matchId: 'match-3',
          teamId: 'team-1',
          actorId: 'owner-1',
          starterMembershipIds: memberships
              .take(5)
              .map((entry) => entry.id)
              .toList(),
          benchMembershipIds: [memberships.last.id],
          now: now.add(const Duration(minutes: 25)),
        );

        expect(first.outcome, MatchdayLineupLockOutcome.locked);
        expect(second.outcome, MatchdayLineupLockOutcome.alreadyLocked);
        expect(second.snapshot.id, first.snapshot.id);
        expect(second.snapshot.lockedAt, first.snapshot.lockedAt);
      },
    );

    test(
      'records substitutions and updates played truth for registered teams',
      () async {
        await _seedTournament(tournamentRepository, now);
        final memberships = await _seedRegisteredTeam(
          teamRepository: teamRepository,
          playerRepository: playerRepository,
          membershipRepository: membershipRepository,
          now: now,
        );
        await _seedApprovedRegisteredRegistration(
          registrationRepository: registrationRepository,
          tournamentId: 'tournament-1',
          teamId: 'team-1',
          now: now,
        );
        await matchRepository.createMatch(
          Match(
            id: 'match-4',
            organizerId: 'organizer-1',
            teamAId: 'team-1',
            status: MatchStatus.open,
            isOrganized: true,
            tournamentId: 'tournament-1',
            createdAt: now,
          ),
        );

        await service.checkInRegisteredTeam(
          matchId: 'match-4',
          teamId: 'team-1',
          actorId: 'owner-1',
          membershipStatuses: {
            for (final membership in memberships)
              membership.id: MatchAttendanceStatus.present,
          },
          now: now.add(const Duration(minutes: 2)),
        );
        await service.lockRegisteredTeamLineup(
          matchId: 'match-4',
          teamId: 'team-1',
          actorId: 'owner-1',
          starterMembershipIds: memberships
              .take(5)
              .map((entry) => entry.id)
              .toList(),
          benchMembershipIds: [memberships.last.id],
          now: now.add(const Duration(minutes: 3)),
        );
        await matchRepository.updateMatch(
          Match(
            id: 'match-4',
            organizerId: 'organizer-1',
            teamAId: 'team-1',
            status: MatchStatus.live,
            isOrganized: true,
            tournamentId: 'tournament-1',
            createdAt: now,
          ),
        );

        final substitutionResult = await service
            .recordRegisteredTeamSubstitution(
              matchId: 'match-4',
              teamId: 'team-1',
              actorId: 'owner-1',
              outgoingAttendanceId:
                  'match::match-4::team::team-1::attendance::membership-5',
              incomingAttendanceId:
                  'match::match-4::team::team-1::attendance::membership-6',
              minute: 9,
              notes: 'تبديل لتنشيط الوسط.',
              now: now.add(const Duration(minutes: 9)),
            );

        final outgoing = await attendanceRepository.getAttendance(
          'match::match-4::team::team-1::attendance::membership-5',
        );
        final incoming = await attendanceRepository.getAttendance(
          'match::match-4::team::team-1::attendance::membership-6',
        );
        final substitutions = await substitutionRepository.getTeamSubstitutions(
          matchId: 'match-4',
          teamId: 'team-1',
        );

        expect(substitutionResult.substitution.minute, 9);
        expect(substitutionResult.substitution.createdBy, 'owner-1');
        expect(outgoing?.currentlyOnPitch, isFalse);
        expect(outgoing?.lastExitedMinute, 9);
        expect(incoming?.played, isTrue);
        expect(incoming?.currentlyOnPitch, isTrue);
        expect(incoming?.firstEnteredMinute, 9);
        expect(substitutions, hasLength(1));
        expect(substitutions.single.notes, 'تبديل لتنشيط الوسط.');
      },
    );

    test(
      'organizer can check in and lock a guest team lineup from attendance truth',
      () async {
        await _seedTournament(tournamentRepository, now);
        await teamRepository.createTeam(
          Team(
            id: 'team-1',
            name: 'Blue Sharks',
            ownerId: 'owner-1',
            tournamentIds: const ['tournament-1'],
            createdAt: now,
          ),
        );
        await _seedApprovedRegisteredRegistration(
          registrationRepository: registrationRepository,
          tournamentId: 'tournament-1',
          teamId: 'team-1',
          now: now,
        );
        await guestTeamRepository.createGuestTeam(
          GuestTeam(
            id: 'guest-team-1',
            name: 'Guest Falcons',
            normalizedName: 'guest falcons',
            creatorId: 'guest-owner-1',
            claimStatus: GuestClaimStatus.guest,
            tournamentIds: const ['tournament-1'],
            createdAt: now,
            updatedAt: now,
          ),
        );
        await guestTeamRepository.createGuestTeam(
          GuestTeam(
            id: 'guest-team-third',
            name: 'Unrelated Guests',
            normalizedName: 'unrelated guests',
            creatorId: 'guest-owner-third',
            claimStatus: GuestClaimStatus.guest,
            tournamentIds: const ['tournament-1'],
            createdAt: now,
            updatedAt: now,
          ),
        );
        final guestPlayers = await _seedGuestPlayers(
          guestPlayerRepository: guestPlayerRepository,
          guestTeamId: 'guest-team-1',
          idPrefix: 'guest-player',
          now: now,
        );
        await _seedApprovedGuestRegistration(
          registrationRepository: registrationRepository,
          tournamentId: 'tournament-1',
          guestTeamId: 'guest-team-1',
          now: now,
        );
        await _seedApprovedGuestRegistration(
          registrationRepository: registrationRepository,
          tournamentId: 'tournament-1',
          guestTeamId: 'guest-team-third',
          now: now,
        );
        await _seedParticipant(
          participantRepository: participantRepository,
          id: 'participant-team-1',
          sourceType: TournamentParticipantSourceType.registeredTeam,
          sourceEntityId: 'team-1',
          displayName: 'Blue Sharks',
          now: now,
        );
        await _seedParticipant(
          participantRepository: participantRepository,
          id: 'participant-guest-team-1',
          sourceType: TournamentParticipantSourceType.guestTeam,
          sourceEntityId: 'guest-team-1',
          displayName: 'Guest Falcons',
          now: now,
        );
        await matchRepository.createMatch(
          Match(
            id: 'match-guest-1',
            organizerId: 'organizer-1',
            teamAId: 'team-1',
            teamBId: 'guest-team-1',
            teamAParticipantId: 'participant-team-1',
            teamBParticipantId: 'participant-guest-team-1',
            status: MatchStatus.open,
            isOrganized: true,
            tournamentId: 'tournament-1',
            createdAt: now,
          ),
        );

        final checkInResult = await service.checkInGuestTeam(
          matchId: 'match-guest-1',
          guestTeamId: 'guest-team-1',
          actorId: 'organizer-1',
          guestPlayerStatuses: {
            for (final guestPlayer in guestPlayers)
              guestPlayer.id: MatchAttendanceStatus.present,
          },
          now: now.add(const Duration(minutes: 10)),
        );
        await expectLater(
          service.checkInGuestTeam(
            matchId: 'match-guest-1',
            guestTeamId: 'guest-team-third',
            actorId: 'organizer-1',
            guestPlayerStatuses: const {
              'third-player': MatchAttendanceStatus.present,
            },
          ),
          throwsA(
            predicate(
              (error) =>
                  error.toString().contains('ليس طرفًا صالحًا في المباراة'),
            ),
          ),
        );
        final lockResult = await service.lockGuestTeamLineup(
          matchId: 'match-guest-1',
          guestTeamId: 'guest-team-1',
          actorId: 'organizer-1',
          starterGuestPlayerIds: guestPlayers
              .take(5)
              .map((entry) => entry.id)
              .toList(),
          benchGuestPlayerIds: [guestPlayers.last.id],
          formationLabel: '3-2',
          now: now.add(const Duration(minutes: 20)),
        );

        final checkIn = await checkInRepository.getCheckInByGuestTeamId(
          matchId: 'match-guest-1',
          guestTeamId: 'guest-team-1',
        );
        final attendances = await attendanceRepository.getTeamAttendances(
          matchId: 'match-guest-1',
          guestTeamId: 'guest-team-1',
        );
        final snapshot = await snapshotRepository.getSnapshotByGuestTeamId(
          matchId: 'match-guest-1',
          guestTeamId: 'guest-team-1',
        );

        expect(checkInResult.outcome, MatchdayCheckInOutcome.verified);
        expect(checkIn?.status, MatchCheckInStatus.verified);
        expect(lockResult.outcome, MatchdayLineupLockOutcome.locked);
        expect(lockResult.validation.requiredStarterCount, 5);
        expect(snapshot?.guestTeamId, 'guest-team-1');
        expect(snapshot?.starters, hasLength(5));
        expect(snapshot?.bench, hasLength(1));
        expect(snapshot?.starters.first.isGuest, isTrue);
        expect(
          attendances.where((entry) => entry.startedMatch && entry.played),
          hasLength(5),
        );
        expect(
          attendances.where((entry) => entry.currentlyOnPitch),
          hasLength(5),
        );
      },
    );

    test(
      'allows both assigned sides in a guest-versus-guest fixture',
      () async {
        await _seedTournament(tournamentRepository, now);
        for (final guestTeam in const [
          (id: 'guest-red', name: 'Red Guests'),
          (id: 'guest-black', name: 'Black Guests'),
        ]) {
          await guestTeamRepository.createGuestTeam(
            GuestTeam(
              id: guestTeam.id,
              name: guestTeam.name,
              normalizedName: guestTeam.name.toLowerCase(),
              creatorId: 'organizer-1',
              claimStatus: GuestClaimStatus.guest,
              tournamentIds: const ['tournament-1'],
              createdAt: now,
              updatedAt: now,
            ),
          );
          await _seedApprovedGuestRegistration(
            registrationRepository: registrationRepository,
            tournamentId: 'tournament-1',
            guestTeamId: guestTeam.id,
            now: now,
          );
          await _seedParticipant(
            participantRepository: participantRepository,
            id: 'participant-${guestTeam.id}',
            sourceType: TournamentParticipantSourceType.guestTeam,
            sourceEntityId: guestTeam.id,
            displayName: guestTeam.name,
            now: now,
          );
        }
        final redPlayers = await _seedGuestPlayers(
          guestPlayerRepository: guestPlayerRepository,
          guestTeamId: 'guest-red',
          idPrefix: 'red-player',
          now: now,
        );
        final blackPlayers = await _seedGuestPlayers(
          guestPlayerRepository: guestPlayerRepository,
          guestTeamId: 'guest-black',
          idPrefix: 'black-player',
          now: now,
        );
        await matchRepository.createMatch(
          Match(
            id: 'match-guest-vs-guest',
            organizerId: 'organizer-1',
            teamAId: 'guest-red',
            teamBId: 'guest-black',
            teamAParticipantId: 'participant-guest-red',
            teamBParticipantId: 'participant-guest-black',
            status: MatchStatus.open,
            isOrganized: true,
            tournamentId: 'tournament-1',
            createdAt: now,
          ),
        );

        final redResult = await service.checkInGuestTeam(
          matchId: 'match-guest-vs-guest',
          guestTeamId: 'guest-red',
          actorId: 'organizer-1',
          guestPlayerStatuses: {
            redPlayers.first.id: MatchAttendanceStatus.present,
          },
        );
        final blackResult = await service.checkInGuestTeam(
          matchId: 'match-guest-vs-guest',
          guestTeamId: 'guest-black',
          actorId: 'organizer-1',
          guestPlayerStatuses: {
            blackPlayers.first.id: MatchAttendanceStatus.present,
          },
        );

        expect(redResult.outcome, MatchdayCheckInOutcome.verified);
        expect(blackResult.outcome, MatchdayCheckInOutcome.verified);
        expect(
          await checkInRepository.getCheckInByGuestTeamId(
            matchId: 'match-guest-vs-guest',
            guestTeamId: 'guest-red',
          ),
          isNotNull,
        );
        expect(
          await checkInRepository.getCheckInByGuestTeamId(
            matchId: 'match-guest-vs-guest',
            guestTeamId: 'guest-black',
          ),
          isNotNull,
        );
      },
    );

    test(
      'accepts a finalized guest participant without a legacy registration',
      () async {
        await _seedTournament(tournamentRepository, now);
        await guestTeamRepository.createGuestTeam(
          GuestTeam(
            id: 'guest-finalized',
            name: 'Finalized Guests',
            normalizedName: 'finalized guests',
            creatorId: 'organizer-1',
            claimStatus: GuestClaimStatus.guest,
            tournamentIds: const ['tournament-1'],
            createdAt: now,
            updatedAt: now,
          ),
        );
        final players = await _seedGuestPlayers(
          guestPlayerRepository: guestPlayerRepository,
          guestTeamId: 'guest-finalized',
          idPrefix: 'finalized-player',
          now: now,
        );
        await _seedParticipant(
          participantRepository: participantRepository,
          id: 'participant-guest-finalized',
          sourceType: TournamentParticipantSourceType.guestTeam,
          sourceEntityId: 'guest-finalized',
          displayName: 'Finalized Guests',
          now: now,
        );
        await matchRepository.createMatch(
          Match(
            id: 'match-finalized-guest',
            organizerId: 'organizer-1',
            teamAId: 'guest-finalized',
            teamAParticipantId: 'participant-guest-finalized',
            status: MatchStatus.open,
            isOrganized: true,
            tournamentId: 'tournament-1',
            createdAt: now,
          ),
        );

        final result = await service.checkInGuestTeam(
          matchId: 'match-finalized-guest',
          guestTeamId: 'guest-finalized',
          actorId: 'organizer-1',
          guestPlayerStatuses: {
            for (final player in players)
              player.id: MatchAttendanceStatus.present,
          },
        );

        expect(result.outcome, MatchdayCheckInOutcome.verified);
      },
    );
  });
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
      joinedAt: now.add(const Duration(minutes: 1)),
      updatedAt: now.add(const Duration(minutes: 1)),
    ),
    TeamMembership(
      id: 'membership-3',
      teamId: 'team-1',
      playerId: 'player-3',
      role: TeamMembershipRole.player,
      status: TeamMembershipStatus.starter,
      availability: TeamMemberAvailability.available,
      joinedAt: now.add(const Duration(minutes: 2)),
      updatedAt: now.add(const Duration(minutes: 2)),
    ),
    TeamMembership(
      id: 'membership-4',
      teamId: 'team-1',
      playerId: 'player-4',
      role: TeamMembershipRole.player,
      status: TeamMembershipStatus.starter,
      availability: TeamMemberAvailability.available,
      joinedAt: now.add(const Duration(minutes: 3)),
      updatedAt: now.add(const Duration(minutes: 3)),
    ),
    TeamMembership(
      id: 'membership-5',
      teamId: 'team-1',
      playerId: 'player-5',
      role: TeamMembershipRole.player,
      status: TeamMembershipStatus.starter,
      availability: TeamMemberAvailability.available,
      joinedAt: now.add(const Duration(minutes: 4)),
      updatedAt: now.add(const Duration(minutes: 4)),
    ),
    TeamMembership(
      id: 'membership-6',
      teamId: 'team-1',
      playerId: 'player-6',
      role: TeamMembershipRole.player,
      status: TeamMembershipStatus.bench,
      availability: TeamMemberAvailability.available,
      joinedAt: now.add(const Duration(minutes: 5)),
      updatedAt: now.add(const Duration(minutes: 5)),
    ),
  ];

  for (final membership in memberships) {
    await membershipRepository.createMembership(membership);
  }

  return memberships;
}

Future<List<GuestPlayer>> _seedGuestPlayers({
  required GuestPlayerRepositoryImpl guestPlayerRepository,
  required String guestTeamId,
  required String idPrefix,
  required DateTime now,
}) async {
  final guestPlayers = List.generate(
    6,
    (index) => GuestPlayer(
      id: '$idPrefix-${index + 1}',
      displayName: 'Guest ${index + 1}',
      normalizedName: 'guest ${index + 1}',
      preferredPosition: index == 0 ? 'GK' : 'FWD',
      guestTeamId: guestTeamId,
      tournamentId: 'tournament-1',
      createdBy: 'organizer-1',
      createdAt: now,
      updatedAt: now,
    ),
  );

  for (final guestPlayer in guestPlayers) {
    await guestPlayerRepository.createGuestPlayer(guestPlayer);
  }

  return guestPlayers;
}

Future<void> _seedParticipant({
  required TournamentParticipantRepositoryImpl participantRepository,
  required String id,
  required TournamentParticipantSourceType sourceType,
  required String sourceEntityId,
  required String displayName,
  required DateTime now,
}) {
  return participantRepository.createParticipant(
    TournamentParticipant(
      id: id,
      tournamentId: 'tournament-1',
      sourceType: sourceType,
      sourceEntityId: sourceEntityId,
      displayName: displayName,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

Future<void> _seedApprovedRegisteredRegistration({
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

Future<void> _seedApprovedGuestRegistration({
  required TournamentRegistrationRepositoryImpl registrationRepository,
  required String tournamentId,
  required String guestTeamId,
  required DateTime now,
}) {
  return registrationRepository.createRegistration(
    TournamentRegistration(
      id: 'registration::$tournamentId::$guestTeamId',
      tournamentId: tournamentId,
      guestTeamId: guestTeamId,
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
