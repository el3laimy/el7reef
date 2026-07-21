import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/enums/match_status.dart';
import 'package:el7reef/core/enums/match_attendance_status.dart';
import 'package:el7reef/core/enums/match_check_in_status.dart';
import 'package:el7reef/core/enums/team_member_availability.dart';
import 'package:el7reef/core/enums/team_membership_role.dart';
import 'package:el7reef/core/enums/tournament_enums.dart';
import 'package:el7reef/core/enums/tournament_ops_enums.dart';
import 'package:el7reef/core/services/tournament_fixture_service.dart';
import 'package:el7reef/core/services/match_settlement_service.dart';
import 'package:el7reef/core/services/tournament_lifecycle_service.dart';
import 'package:el7reef/core/services/tournament_registration_service.dart';
import 'package:el7reef/core/constants/firebase_paths.dart';
import 'package:el7reef/data/models/guest_player_model.dart';
import 'package:el7reef/data/models/match_check_in_model.dart';
import 'package:el7reef/data/models/match_lineup_snapshot_model.dart';
import 'package:el7reef/data/models/match_side_player_model.dart';
import 'package:el7reef/data/repositories/group_standing_snapshot_repository_impl.dart';
import 'package:el7reef/data/repositories/knockout_tie_repository_impl.dart';
import 'package:el7reef/data/repositories/match_repository_impl.dart';
import 'package:el7reef/data/repositories/player_repository_impl.dart';
import 'package:el7reef/data/repositories/team_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_repository_impl.dart';
import 'package:el7reef/domain/entities/guest_player.dart';
import 'package:el7reef/domain/entities/match.dart';
import 'package:el7reef/domain/entities/match_check_in.dart';
import 'package:el7reef/domain/entities/match_lineup_entry.dart';
import 'package:el7reef/domain/entities/match_lineup_snapshot.dart';
import 'package:el7reef/domain/entities/penalty_shootout_result.dart';
import 'package:el7reef/domain/entities/match_side_player.dart';
import 'package:el7reef/domain/entities/participant_ref.dart';
import 'package:el7reef/domain/entities/player.dart';
import 'package:el7reef/domain/entities/team.dart';
import 'package:el7reef/domain/entities/tournament.dart';

void main() {
  group('MatchSettlementService', () {
    late FakeFirebaseFirestore firestore;
    late TournamentRepositoryImpl tournamentRepository;
    late TeamRepositoryImpl teamRepository;
    late MatchRepositoryImpl matchRepository;
    late TournamentRegistrationService registrationService;
    late TournamentLifecycleService lifecycleService;
    late TournamentFixtureService fixtureService;
    late MatchSettlementService settlementService;
    late GroupStandingSnapshotRepositoryImpl standingsRepository;
    late KnockoutTieRepositoryImpl tieRepository;
    late PlayerRepositoryImpl playerRepository;
    late DateTime now;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      tournamentRepository = TournamentRepositoryImpl(db: firestore);
      teamRepository = TeamRepositoryImpl(firestore: firestore);
      matchRepository = MatchRepositoryImpl(db: firestore);
      registrationService = TournamentRegistrationService(firestore: firestore);
      lifecycleService = TournamentLifecycleService(firestore: firestore);
      fixtureService = TournamentFixtureService(firestore: firestore);
      settlementService = MatchSettlementService(
        firestore: firestore,
        tournamentLifecycleService: lifecycleService,
        allowLocalFallback: true,
      );
      standingsRepository = GroupStandingSnapshotRepositoryImpl(
        firestore: firestore,
      );
      tieRepository = KnockoutTieRepositoryImpl(firestore: firestore);
      playerRepository = PlayerRepositoryImpl(firestore: firestore);
      now = DateTime(2026, 4, 19, 22);

      await tournamentRepository.createTournament(
        Tournament(
          id: 'tournament-1',
          organizerId: 'organizer-1',
          name: 'Street Cup',
          format: TournamentFormat.groupsThenKnockout,
          teamSize: TournamentTeamSize.fiveVsFive,
          maxTeams: 4,
          status: TournamentStatus.registration,
          createdAt: now,
        ),
      );

      for (int index = 1; index <= 4; index++) {
        await teamRepository.createTeam(
          Team(
            id: 'team-$index',
            name: 'Team $index',
            ownerId: 'organizer-1',
            playerIds: const ['organizer-1'],
            createdAt: now,
          ),
        );
        await registrationService.registerTeam(
          tournamentId: 'tournament-1',
          teamId: 'team-$index',
          actorId: 'organizer-1',
          now: now.add(Duration(minutes: index)),
        );
      }

      await lifecycleService.finalizeParticipants(
        tournamentId: 'tournament-1',
        actorId: 'organizer-1',
        now: now.add(const Duration(minutes: 10)),
      );
    });

    test('score submission rejects values outside 0 to 99', () async {
      for (final score in <(int, int)>[(-1, 0), (100, 0), (0, -1), (0, 100)]) {
        await expectLater(
          settlementService.submitScore(
            matchId: 'unused-match',
            actorId: 'organizer-1',
            scoreA: score.$1,
            scoreB: score.$2,
          ),
          throwsA(isA<StateError>()),
        );
      }
      final matches = await firestore.collection(FirebasePaths.matches).get();
      expect(matches.docs, isEmpty);
    });

    test(
      'group standings ignore unapproved scores and refresh automatically after approval',
      () async {
        final groupStage = await lifecycleService.startGroupStage(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 15)),
        );
        final fixture = groupStage.fixtures.first;
        await matchRepository.updateMatch(
          fixture.copyWith(status: MatchStatus.live),
        );

        await settlementService.submitScore(
          matchId: fixture.id,
          actorId: 'organizer-1',
          scoreA: 2,
          scoreB: 0,
        );

        final scoredMatch = await matchRepository.getMatch(fixture.id);
        final pendingStandings = await lifecycleService.refreshGroupStandings(
          tournamentId: 'tournament-1',
          now: now.add(const Duration(minutes: 16)),
        );

        expect(scoredMatch?.status, MatchStatus.completed);
        expect(
          pendingStandings.single.entries.every((entry) => entry.points == 0),
          isTrue,
        );

        await settlementService.approveScore(
          matchId: fixture.id,
          actorId: 'organizer-1',
        );

        final savedStandings = await standingsRepository.getGroupStageSnapshots(
          groupStage.groupStageId,
        );
        final winnerEntry = savedStandings.single.entries.firstWhere(
          (entry) => entry.participantId == fixture.teamAParticipantId,
        );
        final loserEntry = savedStandings.single.entries.firstWhere(
          (entry) => entry.participantId == fixture.teamBParticipantId,
        );

        expect(winnerEntry.points, 3);
        expect(winnerEntry.wins, 1);
        expect(loserEntry.losses, 1);
      },
    );

    test(
      'knockout bracket ignores unapproved scores and advances winner after approval',
      () async {
        final groupStage = await lifecycleService.startGroupStage(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 15)),
        );

        for (final fixture in groupStage.fixtures) {
          final score = _groupScoreFor(fixture.teamAId!, fixture.teamBId!);
          await matchRepository.updateMatch(
            fixture.copyWith(
              scoreTeamA: score.$1,
              scoreTeamB: score.$2,
              status: MatchStatus.settled,
            ),
          );
        }

        await lifecycleService.refreshGroupStandings(
          tournamentId: 'tournament-1',
          now: now.add(const Duration(minutes: 20)),
        );
        final knockout = await lifecycleService.startKnockout(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 25)),
        );
        final finalMatch = knockout.matches.single;
        await matchRepository.updateMatch(
          finalMatch.copyWith(status: MatchStatus.live),
        );

        await settlementService.submitScore(
          matchId: finalMatch.id,
          actorId: 'organizer-1',
          scoreA: 1,
          scoreB: 0,
        );

        final pendingProgress = await lifecycleService.refreshKnockoutProgress(
          tournamentId: 'tournament-1',
          now: now.add(const Duration(minutes: 26)),
        );
        final pendingTie = await tieRepository.getTie(knockout.ties.single.id);

        expect(pendingProgress?.bracket.championParticipantId, isNull);
        expect(pendingTie?.winnerParticipantId, isNull);

        await settlementService.approveScore(
          matchId: finalMatch.id,
          actorId: 'organizer-1',
        );

        final advancedTie = await tieRepository.getTie(knockout.ties.single.id);
        expect(advancedTie?.winnerParticipantId, finalMatch.teamAParticipantId);
      },
    );

    test(
      'tied knockout requires decisive penalties and advances without adding goals',
      () async {
        final groupStage = await lifecycleService.startGroupStage(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 15)),
        );
        for (final fixture in groupStage.fixtures) {
          final score = _groupScoreFor(fixture.teamAId!, fixture.teamBId!);
          await matchRepository.updateMatch(
            fixture.copyWith(
              scoreTeamA: score.$1,
              scoreTeamB: score.$2,
              status: MatchStatus.settled,
            ),
          );
        }
        await lifecycleService.refreshGroupStandings(
          tournamentId: 'tournament-1',
          now: now.add(const Duration(minutes: 20)),
        );
        final knockout = await lifecycleService.startKnockout(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 25)),
        );
        final finalMatch = knockout.matches.single;
        await matchRepository.updateMatch(
          finalMatch.copyWith(status: MatchStatus.live),
        );

        await expectLater(
          settlementService.submitScore(
            matchId: finalMatch.id,
            actorId: 'organizer-1',
            scoreA: 1,
            scoreB: 1,
          ),
          throwsA(isA<StateError>()),
        );
        expect(
          (await matchRepository.getMatch(finalMatch.id))?.status,
          MatchStatus.live,
        );

        await settlementService.submitScore(
          matchId: finalMatch.id,
          actorId: 'organizer-1',
          scoreA: 1,
          scoreB: 1,
          penaltyShootout: const PenaltyShootoutResult(
            scoreTeamA: 4,
            scoreTeamB: 5,
          ),
        );
        final submitted = await matchRepository.getMatch(finalMatch.id);
        expect(submitted?.scoreTeamA, 1);
        expect(submitted?.scoreTeamB, 1);
        expect(submitted?.penaltyScoreTeamA, 4);
        expect(submitted?.penaltyScoreTeamB, 5);
        expect(submitted?.knockoutDecision, KnockoutDecision.teamB);

        await settlementService.approveScore(
          matchId: finalMatch.id,
          actorId: 'organizer-1',
        );
        final tie = await tieRepository.getTie(knockout.ties.single.id);
        expect(tie?.winnerParticipantId, finalMatch.teamBParticipantId);
        expect(tie?.resolutionType, KnockoutTieResolution.penalties);
      },
    );

    test(
      'pilot smoke flow completes tournament through approval-driven progression',
      () async {
        final groupStage = await lifecycleService.startGroupStage(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 15)),
        );
        final publishedFixtures = await lifecycleService.publishFixtures(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 16)),
        );

        final scheduledGroupFixture = await fixtureService.scheduleFixture(
          matchId: publishedFixtures.first.id,
          actorId: 'organizer-1',
          scheduledAt: now.add(const Duration(days: 1)),
          venueId: 'Pitch-1',
        );

        expect(scheduledGroupFixture.scheduledAt, isNotNull);
        expect(scheduledGroupFixture.venueId, 'Pitch-1');

        for (final fixture in publishedFixtures) {
          final score = _groupScoreFor(fixture.teamAId!, fixture.teamBId!);
          await matchRepository.updateMatch(
            fixture.copyWith(status: MatchStatus.live),
          );
          await settlementService.submitScore(
            matchId: fixture.id,
            actorId: 'organizer-1',
            scoreA: score.$1,
            scoreB: score.$2,
          );
          await settlementService.approveScore(
            matchId: fixture.id,
            actorId: 'organizer-1',
          );
        }

        final savedStandings = await standingsRepository.getGroupStageSnapshots(
          groupStage.groupStageId,
        );
        expect(savedStandings, hasLength(1));
        expect(
          savedStandings.single.entries.any((entry) => entry.points > 0),
          isTrue,
        );

        final knockout = await lifecycleService.startKnockout(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 25)),
        );
        final scheduledFinal = await fixtureService.scheduleFixture(
          matchId: knockout.matches.single.id,
          actorId: 'organizer-1',
          scheduledAt: now.add(const Duration(days: 2)),
          venueId: 'Main Court',
        );

        expect(scheduledFinal.venueId, 'Main Court');
        await matchRepository.updateMatch(
          scheduledFinal.copyWith(status: MatchStatus.live),
        );

        await settlementService.submitScore(
          matchId: scheduledFinal.id,
          actorId: 'organizer-1',
          scoreA: 2,
          scoreB: 1,
        );
        await settlementService.approveScore(
          matchId: scheduledFinal.id,
          actorId: 'organizer-1',
        );

        final finalTie = await tieRepository.getTie(knockout.ties.single.id);
        final completedTournament = await lifecycleService.completeTournament(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 35)),
        );

        expect(finalTie?.winnerParticipantId, isNotNull);
        expect(completedTournament.status, TournamentStatus.completed);
        expect(completedTournament.winnerParticipantId, isNotNull);
        expect(
          completedTournament.winnerParticipantId,
          finalTie?.winnerParticipantId,
        );
      },
    );

    test(
      'submit and approve score use official roster when legacy match arrays are empty',
      () async {
        await lifecycleService.startGroupStage(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 15)),
        );
        final publishedFixtures = await lifecycleService.publishFixtures(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 16)),
        );
        final fixture = publishedFixtures.first;
        final homeTeamId = fixture.teamAId!;
        final awayTeamId = fixture.teamBId!;
        await _seedRegisteredPlayersForFixture(
          playerRepository: playerRepository,
          now: now,
          fixtureTeamIds: <String>[homeTeamId, awayTeamId],
        );

        await _seedRegisteredFixtureReadyState(
          firestore: firestore,
          fixture: fixture,
          now: now.add(const Duration(minutes: 17)),
        );
        final startedFixture = await fixtureService.startMatch(
          matchId: fixture.id,
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 18)),
        );
        await matchRepository.updateMatch(
          startedFixture.copyWith(
            teamAPlayerIds: const <String>[],
            teamBPlayerIds: const <String>[],
          ),
        );

        await settlementService.submitScore(
          matchId: fixture.id,
          actorId: 'organizer-1',
          scoreA: 2,
          scoreB: 1,
          mvpPlayerId: '$homeTeamId-player-1',
        );

        final fanVotingSession = await firestore
            .collection(FirebasePaths.fanVotingSessions)
            .doc(fixture.id)
            .get();
        expect(
          fanVotingSession.data()?['eligiblePlayerIds'],
          containsAll(<String>[
            '$homeTeamId-player-1',
            '$homeTeamId-player-2',
            '$awayTeamId-player-1',
            '$awayTeamId-player-2',
          ]),
        );

        await settlementService.approveScore(
          matchId: fixture.id,
          actorId: 'organizer-1',
        );

        final homeStarter = await playerRepository.getPlayer(
          '$homeTeamId-player-1',
        );
        final awayStarter = await playerRepository.getPlayer(
          '$awayTeamId-player-1',
        );
        expect(homeStarter?.totalMatches, 1);
        expect(awayStarter?.totalMatches, 1);
      },
    );

    test('submitScore accepts registered MVP as before', () async {
      await _seedFriendlyMatch(
        matchRepository: matchRepository,
        matchId: 'registered-mvp-match',
        now: now,
        teamAPlayerIds: const ['registered-mvp'],
        teamBPlayerIds: const ['registered-opponent'],
      );
      await playerRepository.createPlayer(
        _player(id: 'registered-mvp', name: 'Registered MVP', now: now),
      );
      await playerRepository.createPlayer(
        _player(id: 'registered-opponent', name: 'Opponent', now: now),
      );

      await settlementService.submitScore(
        matchId: 'registered-mvp-match',
        actorId: 'organizer-1',
        scoreA: 3,
        scoreB: 1,
        mvpPlayerId: 'registered-mvp',
      );

      final scoredMatch = await matchRepository.getMatch(
        'registered-mvp-match',
      );
      expect(scoredMatch?.mvpPlayerId, 'registered-mvp');
      expect(scoredMatch?.status, MatchStatus.completed);
    });

    test('submitScore accepts guest player MVP from full roster', () async {
      await _seedFriendlyMatch(
        matchRepository: matchRepository,
        matchId: 'guest-mvp-match',
        now: now,
      );
      await _saveGuestPlayer(
        firestore: firestore,
        guestPlayer: _guestPlayer(
          id: 'guest-mvp',
          displayName: 'Guest MVP',
          linkedPlayerId: 'claimed-player',
          now: now,
        ),
      );
      await _seedGuestLineupSnapshot(
        firestore: firestore,
        matchId: 'guest-mvp-match',
        guestPlayerId: 'guest-mvp',
        now: now,
      );

      await settlementService.submitScore(
        matchId: 'guest-mvp-match',
        actorId: 'organizer-1',
        scoreA: 2,
        scoreB: 2,
        mvpPlayerId: 'guest-mvp',
      );

      final scoredMatch = await matchRepository.getMatch('guest-mvp-match');
      expect(scoredMatch?.mvpPlayerId, 'guest-mvp');
      expect(scoredMatch?.status, MatchStatus.completed);
    });

    test('submitScore accepts temporary match-side player MVP', () async {
      await _seedFriendlyMatch(
        matchRepository: matchRepository,
        matchId: 'temporary-mvp-match',
        now: now,
      );
      await _saveMatchSidePlayer(
        firestore: firestore,
        player: MatchSidePlayer(
          id: 'temporary-mvp',
          matchId: 'temporary-mvp-match',
          sideKey: 'A',
          sideId: 'temporary-mvp-match_A',
          kind: 'temporary',
          displayName: 'Temporary MVP',
          ratingEligible: false,
          addedBy: 'organizer-1',
          createdAt: now,
        ),
      );

      await settlementService.submitScore(
        matchId: 'temporary-mvp-match',
        actorId: 'organizer-1',
        scoreA: 1,
        scoreB: 0,
        mvpPlayerId: 'temporary-mvp',
      );

      final scoredMatch = await matchRepository.getMatch('temporary-mvp-match');
      expect(scoredMatch?.mvpPlayerId, 'temporary-mvp');
      expect(scoredMatch?.status, MatchStatus.completed);
    });

    test(
      'submitScore validates an MVP draft even without goals or legacy MVP id',
      () async {
        await _seedFriendlyMatch(
          matchRepository: matchRepository,
          matchId: 'invalid-mvp-draft-match',
          now: now,
          teamAPlayerIds: const ['registered-player'],
        );
        await playerRepository.createPlayer(
          _player(id: 'registered-player', name: 'Registered', now: now),
        );

        await expectLater(
          settlementService.submitScore(
            matchId: 'invalid-mvp-draft-match',
            actorId: 'organizer-1',
            scoreA: 1,
            scoreB: 0,
            mvpDraft: const MatchSettlementMvpDraft(
              sideKey: 'A',
              actor: ParticipantRef(
                kind: ParticipantRefKind.guestPlayer,
                id: 'guest-outside-roster',
                displayName: 'ضيف خارج القائمة',
              ),
            ),
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('MVP'),
            ),
          ),
        );

        final unchangedMatch = await matchRepository.getMatch(
          'invalid-mvp-draft-match',
        );
        final events = await firestore
            .collection(FirebasePaths.matchEvents)
            .where('matchId', isEqualTo: 'invalid-mvp-draft-match')
            .get();
        expect(unchangedMatch?.status, MatchStatus.live);
        expect(events.docs, isEmpty);
      },
    );

    test(
      'local fallback voids the canonical MVP event when resubmitted without MVP',
      () async {
        const matchId = 'clear-mvp-match';
        await _seedFriendlyMatch(
          matchRepository: matchRepository,
          matchId: matchId,
          now: now,
        );
        final canonicalMvpRef = firestore
            .collection(FirebasePaths.matchEvents)
            .doc('mvp-$matchId');
        await canonicalMvpRef.set({
          'matchId': matchId,
          'eventType': 'mvp',
          'status': 'active',
        });

        await settlementService.submitScore(
          matchId: matchId,
          actorId: 'organizer-1',
          scoreA: 1,
          scoreB: 0,
        );

        expect((await canonicalMvpRef.get()).data()?['status'], 'voided');
      },
    );

    test(
      'submitScore rejects MVP id outside the full participant roster',
      () async {
        await _seedFriendlyMatch(
          matchRepository: matchRepository,
          matchId: 'invalid-mvp-match',
          now: now,
          teamAPlayerIds: const ['registered-player'],
        );
        await playerRepository.createPlayer(
          _player(id: 'registered-player', name: 'Registered', now: now),
        );

        await expectLater(
          settlementService.submitScore(
            matchId: 'invalid-mvp-match',
            actorId: 'organizer-1',
            scoreA: 1,
            scoreB: 1,
            mvpPlayerId: 'not-in-roster',
          ),
          throwsA(isA<StateError>()),
        );

        final unchangedMatch = await matchRepository.getMatch(
          'invalid-mvp-match',
        );
        expect(unchangedMatch?.status, MatchStatus.live);
        expect(unchangedMatch?.mvpPlayerId, isNull);
      },
    );

    test(
      'approveScore with guest MVP keeps registered-only rating behavior',
      () async {
        await _seedFriendlyMatch(
          matchRepository: matchRepository,
          matchId: 'guest-approval-match',
          now: now,
          teamAId: 'team-a',
          teamBId: 'team-b',
          teamAPlayerIds: const ['registered-a'],
          teamBPlayerIds: const ['registered-b'],
        );
        await playerRepository.createPlayer(
          _player(id: 'registered-a', name: 'Registered A', now: now),
        );
        await playerRepository.createPlayer(
          _player(id: 'registered-b', name: 'Registered B', now: now),
        );
        await _saveGuestPlayer(
          firestore: firestore,
          guestPlayer: _guestPlayer(
            id: 'guest-approval-mvp',
            displayName: 'Guest Approval MVP',
            now: now,
          ),
        );
        await _seedGuestLineupSnapshot(
          firestore: firestore,
          matchId: 'guest-approval-match',
          guestPlayerId: 'guest-approval-mvp',
          now: now,
        );

        await settlementService.submitScore(
          matchId: 'guest-approval-match',
          actorId: 'organizer-1',
          scoreA: 2,
          scoreB: 0,
          mvpPlayerId: 'guest-approval-mvp',
        );
        await settlementService.approveScore(
          matchId: 'guest-approval-match',
          actorId: 'organizer-1',
        );

        final homePlayer = await playerRepository.getPlayer('registered-a');
        final awayPlayer = await playerRepository.getPlayer('registered-b');
        expect(homePlayer?.totalMatches, 1);
        expect(awayPlayer?.totalMatches, 1);
        expect(homePlayer?.mvpCount, 0);
        expect(awayPlayer?.mvpCount, 0);
        final settledMatch = await matchRepository.getMatch(
          'guest-approval-match',
        );
        expect(settledMatch?.status, MatchStatus.settled);
        expect(settledMatch?.mvpPlayerId, 'guest-approval-mvp');
      },
    );
  });
}

Player _player({
  required String id,
  required String name,
  required DateTime now,
}) {
  return Player(id: id, name: name, createdAt: now, lastActiveAt: now);
}

GuestPlayer _guestPlayer({
  required String id,
  required String displayName,
  String? linkedPlayerId,
  required DateTime now,
}) {
  return GuestPlayer(
    id: id,
    displayName: displayName,
    normalizedName: displayName.toLowerCase(),
    createdBy: 'organizer-1',
    createdAt: now,
    updatedAt: now,
    linkedPlayerId: linkedPlayerId,
  );
}

Future<void> _seedFriendlyMatch({
  required MatchRepositoryImpl matchRepository,
  required String matchId,
  required DateTime now,
  String? teamAId,
  String? teamBId,
  List<String> teamAPlayerIds = const [],
  List<String> teamBPlayerIds = const [],
}) async {
  await matchRepository.createMatch(
    Match(
      id: matchId,
      organizerId: 'organizer-1',
      teamAId: teamAId,
      teamBId: teamBId,
      teamAPlayerIds: teamAPlayerIds,
      teamBPlayerIds: teamBPlayerIds,
      status: MatchStatus.live,
      createdAt: now,
    ),
  );
}

Future<void> _saveGuestPlayer({
  required FakeFirebaseFirestore firestore,
  required GuestPlayer guestPlayer,
}) async {
  await firestore
      .collection(FirebasePaths.guestPlayers)
      .doc(guestPlayer.id)
      .set(GuestPlayerModel.fromEntity(guestPlayer).toJson());
}

Future<void> _saveMatchSidePlayer({
  required FakeFirebaseFirestore firestore,
  required MatchSidePlayer player,
}) async {
  await firestore
      .collection(FirebasePaths.matchSidePlayers)
      .doc(player.id)
      .set(MatchSidePlayerModel.fromEntity(player).toJson());
}

Future<void> _seedGuestLineupSnapshot({
  required FakeFirebaseFirestore firestore,
  required String matchId,
  required String guestPlayerId,
  required DateTime now,
}) async {
  final snapshot = MatchLineupSnapshot(
    id: 'match::$matchId::side::A::lineup',
    matchId: matchId,
    matchSideId: '${matchId}_A',
    sideKey: 'A',
    starters: <MatchLineupEntry>[
      MatchLineupEntry(
        attendanceId: 'attendance::$matchId::$guestPlayerId',
        guestPlayerId: guestPlayerId,
        role: TeamMembershipRole.player,
        availability: TeamMemberAvailability.available,
        attendanceStatus: MatchAttendanceStatus.present,
        displayName: 'Guest MVP',
      ),
    ],
    lockedBy: 'organizer-1',
    lockedAt: now,
  );
  await firestore
      .collection(FirebasePaths.matchLineupSnapshots)
      .doc(snapshot.id)
      .set(MatchLineupSnapshotModel.fromEntity(snapshot).toJson());
}

Future<void> _seedRegisteredPlayersForFixture({
  required PlayerRepositoryImpl playerRepository,
  required DateTime now,
  required List<String> fixtureTeamIds,
}) async {
  for (final teamId in fixtureTeamIds) {
    await playerRepository.createPlayer(
      Player(
        id: '$teamId-player-1',
        name: '$teamId Starter',
        position: 'MID',
        createdAt: now,
        lastActiveAt: now,
      ),
    );
    await playerRepository.createPlayer(
      Player(
        id: '$teamId-player-2',
        name: '$teamId Bench',
        position: 'DEF',
        createdAt: now,
        lastActiveAt: now,
      ),
    );
  }
}

Future<void> _seedRegisteredFixtureReadyState({
  required FakeFirebaseFirestore firestore,
  required Match fixture,
  required DateTime now,
}) async {
  await _seedSingleRegisteredCheckIn(
    firestore: firestore,
    matchId: fixture.id,
    teamId: fixture.teamAId!,
    now: now,
  );
  await _seedSingleRegisteredCheckIn(
    firestore: firestore,
    matchId: fixture.id,
    teamId: fixture.teamBId!,
    now: now,
  );
  await _seedSingleRegisteredSnapshot(
    firestore: firestore,
    matchId: fixture.id,
    teamId: fixture.teamAId!,
    now: now,
  );
  await _seedSingleRegisteredSnapshot(
    firestore: firestore,
    matchId: fixture.id,
    teamId: fixture.teamBId!,
    now: now,
  );
}

Future<void> _seedSingleRegisteredCheckIn({
  required FakeFirebaseFirestore firestore,
  required String matchId,
  required String teamId,
  required DateTime now,
}) async {
  final checkIn = MatchCheckIn(
    id: 'match::$matchId::team::$teamId::checkin',
    matchId: matchId,
    teamId: teamId,
    status: MatchCheckInStatus.verified,
    createdBy: 'organizer-1',
    createdAt: now,
    updatedAt: now,
    checkedInBy: 'organizer-1',
    checkedInAt: now,
    verifiedBy: 'organizer-1',
    verifiedAt: now,
  );
  await firestore
      .collection(FirebasePaths.matchCheckIns)
      .doc(checkIn.id)
      .set(MatchCheckInModel.fromEntity(checkIn).toJson());
}

Future<void> _seedSingleRegisteredSnapshot({
  required FakeFirebaseFirestore firestore,
  required String matchId,
  required String teamId,
  required DateTime now,
}) async {
  final snapshot = MatchLineupSnapshot(
    id: 'match::$matchId::team::$teamId::lineup',
    matchId: matchId,
    teamId: teamId,
    checkInId: 'match::$matchId::team::$teamId::checkin',
    starters: <MatchLineupEntry>[
      MatchLineupEntry(
        attendanceId: 'attendance::$matchId::$teamId::starter',
        teamMembershipId: 'membership::$teamId::starter',
        playerId: '$teamId-player-1',
        role: TeamMembershipRole.player,
        availability: TeamMemberAvailability.available,
        attendanceStatus: MatchAttendanceStatus.present,
        displayName: '$teamId Starter',
      ),
    ],
    bench: <MatchLineupEntry>[
      MatchLineupEntry(
        attendanceId: 'attendance::$matchId::$teamId::bench',
        teamMembershipId: 'membership::$teamId::bench',
        playerId: '$teamId-player-2',
        role: TeamMembershipRole.player,
        availability: TeamMemberAvailability.available,
        attendanceStatus: MatchAttendanceStatus.present,
        displayName: '$teamId Bench',
      ),
    ],
    lockedBy: 'organizer-1',
    lockedAt: now,
  );
  await firestore
      .collection(FirebasePaths.matchLineupSnapshots)
      .doc(snapshot.id)
      .set(MatchLineupSnapshotModel.fromEntity(snapshot).toJson());
}

(int, int) _groupScoreFor(String teamAId, String teamBId) {
  const matrix = <String, (int, int)>{
    'team-1|team-2': (2, 0),
    'team-1|team-3': (3, 1),
    'team-1|team-4': (2, 1),
    'team-2|team-3': (1, 0),
    'team-2|team-4': (2, 1),
    'team-3|team-4': (1, 0),
  };
  return matrix['$teamAId|$teamBId'] ?? (1, 0);
}
