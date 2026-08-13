import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/enums/tournament_enums.dart';
import 'package:el7reef/core/enums/tournament_ops_enums.dart';
import 'package:el7reef/data/models/tournament_participant_model.dart';
import 'package:el7reef/data/repositories/tournament_repository_impl.dart';
import 'package:el7reef/domain/entities/tournament.dart';
import 'package:el7reef/domain/entities/tournament_participant.dart';

void main() {
  group('TournamentRepositoryImpl', () {
    late FakeFirebaseFirestore firestore;
    late TournamentRepositoryImpl repository;
    late DateTime now;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = TournamentRepositoryImpl(db: firestore);
      now = DateTime(2026, 4, 20, 22);
    });

    test(
      'getPlayerTournaments uses canonical tournament participants when available',
      () async {
        await repository.createTournament(
          Tournament(
            id: 'tournament-1',
            organizerId: 'organizer-1',
            name: 'Street Cup',
            format: TournamentFormat.groupsThenKnockout,
            teamSize: TournamentTeamSize.fiveVsFive,
            maxTeams: 8,
            status: TournamentStatus.registration,
            createdAt: now,
          ),
        );
        await firestore
            .collection('tournamentParticipants')
            .doc('participant::tournament-1::registeredTeam::team-1')
            .set(
              TournamentParticipantModel.fromEntity(
                TournamentParticipant(
                  id: 'participant::tournament-1::registeredTeam::team-1',
                  tournamentId: 'tournament-1',
                  sourceType: TournamentParticipantSourceType.registeredTeam,
                  sourceEntityId: 'team-1',
                  displayName: 'Team 1',
                  createdAt: now,
                  updatedAt: now,
                  approvedAt: now,
                ),
              ).toJson(),
            );

        final tournaments = await repository.getPlayerTournaments('team-1');

        expect(tournaments, hasLength(1));
        expect(tournaments.single.id, 'tournament-1');
      },
    );

    test(
      'createTournament omits empty legacy stage arrays from new documents',
      () async {
        await repository.createTournament(
          Tournament(
            id: 'tournament-clean',
            organizerId: 'organizer-1',
            name: 'Ops Cup',
            format: TournamentFormat.groupsThenKnockout,
            teamSize: TournamentTeamSize.fiveVsFive,
            maxTeams: 8,
            status: TournamentStatus.registration,
            createdAt: now,
          ),
        );

        final snapshot = await firestore
            .collection('tournaments')
            .doc('tournament-clean')
            .get();
        final data = snapshot.data();

        expect(data, isNotNull);
        expect(data!.containsKey('groupRoundIds'), isFalse);
        expect(data.containsKey('knockoutRoundIds'), isFalse);
      },
    );

    test(
      'createTournament writes the deterministic organizer membership',
      () async {
        final beforeCreate = DateTime.now().millisecondsSinceEpoch;
        await repository.createTournament(
          Tournament(
            id: 'membership-cup',
            organizerId: 'organizer-1',
            name: 'Membership Cup',
            format: TournamentFormat.groupsThenKnockout,
            teamSize: TournamentTeamSize.fiveVsFive,
            maxTeams: 8,
            status: TournamentStatus.registration,
            createdAt: now,
          ),
        );

        final membership = await firestore
            .collection('tournamentMemberships')
            .doc('organizer-1_membership-cup')
            .get();
        final afterCreate = DateTime.now().millisecondsSinceEpoch;
        final membershipData = membership.data();

        expect(membershipData, isNotNull);
        expect(
          membershipData!.keys,
          unorderedEquals(['tournamentId', 'userId', 'role', 'createdAt']),
        );
        expect(membershipData['tournamentId'], 'membership-cup');
        expect(membershipData['userId'], 'organizer-1');
        expect(membershipData['role'], 'organizer');
        expect(
          membershipData['createdAt'],
          inInclusiveRange(beforeCreate, afterCreate),
        );
      },
    );

    test(
      'getOrganizerTournaments only returns tournaments for the requested organizer',
      () async {
        await repository.createTournament(
          Tournament(
            id: 'account-a-cup',
            organizerId: 'account-a',
            name: 'Account A Cup',
            format: TournamentFormat.groupsOnly,
            teamSize: TournamentTeamSize.fiveVsFive,
            maxTeams: 8,
            status: TournamentStatus.registration,
            createdAt: now,
          ),
        );
        await repository.createTournament(
          Tournament(
            id: 'account-b-cup',
            organizerId: 'account-b',
            name: 'Account B Cup',
            format: TournamentFormat.groupsOnly,
            teamSize: TournamentTeamSize.fiveVsFive,
            maxTeams: 8,
            status: TournamentStatus.registration,
            createdAt: now.add(const Duration(minutes: 1)),
          ),
        );

        final accountBTournaments = await repository.getOrganizerTournaments(
          'account-b',
        );

        expect(accountBTournaments.map((tournament) => tournament.id), [
          'account-b-cup',
        ]);
      },
    );

    test(
      'getDiscoverableTournaments returns only public discoverable live tournaments',
      () async {
        await repository.createTournament(
          Tournament(
            id: 'account-a-public-cup',
            organizerId: 'account-a',
            name: 'Account A Public Cup',
            format: TournamentFormat.groupsOnly,
            teamSize: TournamentTeamSize.fiveVsFive,
            maxTeams: 8,
            status: TournamentStatus.registration,
            createdAt: now,
          ),
        );
        await repository.createTournament(
          Tournament(
            id: 'account-b-public-cup',
            organizerId: 'account-b',
            name: 'Account B Public Cup',
            format: TournamentFormat.groupsOnly,
            teamSize: TournamentTeamSize.fiveVsFive,
            maxTeams: 8,
            status: TournamentStatus.registration,
            createdAt: now.add(const Duration(minutes: 1)),
          ),
        );
        await repository.createTournament(
          Tournament(
            id: 'account-b-private-cup',
            organizerId: 'account-b',
            name: 'Account B Private Cup',
            format: TournamentFormat.groupsOnly,
            teamSize: TournamentTeamSize.fiveVsFive,
            maxTeams: 8,
            visibility: TournamentVisibility.private,
            discoverable: false,
            status: TournamentStatus.registration,
            createdAt: now.add(const Duration(minutes: 2)),
          ),
        );

        final discoverableTournaments = await repository
            .getDiscoverableTournaments();

        expect(
          discoverableTournaments.map((tournament) => tournament.id),
          containsAll(['account-a-public-cup', 'account-b-public-cup']),
        );
        expect(
          discoverableTournaments.map((tournament) => tournament.id),
          isNot(contains('account-b-private-cup')),
        );
      },
    );

    test(
      'featured completed tournament stays discoverable and sorts before active catalog',
      () async {
        await repository.createTournament(
          Tournament(
            id: 'featured-world-cup',
            organizerId: 'el7reef-official',
            name: 'كأس العالم 2026',
            format: TournamentFormat.groupsThenKnockout,
            teamSize: TournamentTeamSize.elevenVsEleven,
            maxTeams: 48,
            isFeatured: true,
            featuredPriority: 0,
            status: TournamentStatus.completed,
            createdAt: now.subtract(const Duration(days: 30)),
          ),
        );
        await repository.createTournament(
          Tournament(
            id: 'active-street-cup',
            organizerId: 'account-a',
            name: 'Active Street Cup',
            format: TournamentFormat.groupsOnly,
            teamSize: TournamentTeamSize.fiveVsFive,
            maxTeams: 8,
            status: TournamentStatus.registration,
            createdAt: now,
          ),
        );

        final tournaments = await repository.getDiscoverableTournaments();

        expect(tournaments.map((tournament) => tournament.id), [
          'featured-world-cup',
          'active-street-cup',
        ]);
      },
    );

    test(
      'getLiveTournaments keeps legacy callers on discoverable query',
      () async {
        await repository.createTournament(
          Tournament(
            id: 'public-live-cup',
            organizerId: 'organizer-1',
            name: 'Public Live Cup',
            format: TournamentFormat.groupsOnly,
            teamSize: TournamentTeamSize.fiveVsFive,
            maxTeams: 8,
            status: TournamentStatus.registration,
            createdAt: now,
          ),
        );

        final liveTournaments = await repository.getLiveTournaments();

        expect(liveTournaments.map((tournament) => tournament.id), [
          'public-live-cup',
        ]);
      },
    );

    test(
      'getDiscoverableTournaments ignores legacy documents missing explicit visibility',
      () async {
        await firestore.collection('tournaments').doc('legacy-live-cup').set({
          'organizerId': 'organizer-1',
          'name': 'Legacy Live Cup',
          'format': TournamentFormat.groupsOnly.name,
          'teamSize': TournamentTeamSize.fiveVsFive.value,
          'maxTeams': 8,
          'status': TournamentStatus.registration.name,
          'createdAt': now.millisecondsSinceEpoch,
        });

        final tournaments = await repository.getDiscoverableTournaments();

        expect(tournaments, isEmpty);
      },
    );

    test(
      'getPlayerTournaments uses only public discoverable legacy registrations',
      () async {
        await repository.createTournament(
          Tournament(
            id: 'tournament-legacy',
            organizerId: 'organizer-1',
            name: 'Legacy Cup',
            format: TournamentFormat.groupsOnly,
            teamSize: TournamentTeamSize.fiveVsFive,
            maxTeams: 8,
            status: TournamentStatus.registration,
            registeredTeamIds: const ['team-legacy'],
            createdAt: now,
          ),
        );
        await repository.createTournament(
          Tournament(
            id: 'private-legacy',
            organizerId: 'organizer-2',
            name: 'Private Legacy Cup',
            format: TournamentFormat.groupsOnly,
            teamSize: TournamentTeamSize.fiveVsFive,
            maxTeams: 8,
            visibility: TournamentVisibility.private,
            discoverable: false,
            status: TournamentStatus.registration,
            registeredTeamIds: const ['team-legacy'],
            createdAt: now.add(const Duration(minutes: 1)),
          ),
        );

        final tournaments = await repository.getPlayerTournaments(
          'team-legacy',
        );

        expect(tournaments, hasLength(1));
        expect(tournaments.single.id, 'tournament-legacy');
      },
    );

    test(
      'updateTournament preserves legacy stage arrays when historical data exists',
      () async {
        await firestore
            .collection('tournaments')
            .doc('tournament-historical')
            .set({
              'organizerId': 'organizer-1',
              'name': 'Historical Cup',
              'format': TournamentFormat.groupsThenKnockout.name,
              'teamSize': TournamentTeamSize.fiveVsFive.value,
              'maxTeams': 8,
              'status': TournamentStatus.groupStage.name,
              'groupRoundIds': const ['legacy-group-round'],
              'knockoutRoundIds': const ['legacy-knockout-round'],
              'createdAt': now.millisecondsSinceEpoch,
            });

        final tournament = await repository.getTournament(
          'tournament-historical',
        );
        expect(tournament, isNotNull);

        await repository.updateTournament(
          tournament!.copyWith(description: 'Historical update'),
        );

        final snapshot = await firestore
            .collection('tournaments')
            .doc('tournament-historical')
            .get();
        final data = snapshot.data();

        expect(data, isNotNull);
        expect(data!['groupRoundIds'], const ['legacy-group-round']);
        expect(data['knockoutRoundIds'], const ['legacy-knockout-round']);
      },
    );

    test(
      'followTournament stores self follower and fetches followed tournaments',
      () async {
        await repository.createTournament(
          Tournament(
            id: 'followed-cup',
            organizerId: 'organizer-1',
            name: 'Followed Cup',
            format: TournamentFormat.groupsOnly,
            teamSize: TournamentTeamSize.fiveVsFive,
            maxTeams: 8,
            status: TournamentStatus.registration,
            createdAt: now,
          ),
        );

        await repository.followTournament('followed-cup', 'player-1');

        expect(
          await repository.isFollowingTournament('followed-cup', 'player-1'),
          isTrue,
        );
        final followed = await repository.getFollowedTournaments('player-1');
        expect(followed.map((tournament) => tournament.id), ['followed-cup']);

        await repository.unfollowTournament('followed-cup', 'player-1');

        expect(
          await repository.isFollowingTournament('followed-cup', 'player-1'),
          isFalse,
        );
      },
    );

    test(
      'getFollowedTournaments trusts the tournament path over legacy follower payloads',
      () async {
        await repository.createTournament(
          Tournament(
            id: 'followed-legacy-cup',
            organizerId: 'organizer-1',
            name: 'Followed Legacy Cup',
            format: TournamentFormat.groupsOnly,
            teamSize: TournamentTeamSize.fiveVsFive,
            maxTeams: 8,
            status: TournamentStatus.registration,
            createdAt: now,
          ),
        );
        await firestore
            .collection('tournaments')
            .doc('followed-legacy-cup')
            .collection('followers')
            .doc('player-1')
            .set({
              'tournamentId': 404,
              'userId': 'player-1',
              'createdAt': now.millisecondsSinceEpoch,
            });
        await firestore
            .collection('players')
            .doc('someone-else')
            .collection('followers')
            .doc('player-1')
            .set({
              'tournamentId': 'followed-legacy-cup',
              'userId': 'player-1',
              'createdAt': now.millisecondsSinceEpoch,
            });

        final followed = await repository.getFollowedTournaments('player-1');

        expect(followed.map((tournament) => tournament.id), [
          'followed-legacy-cup',
        ]);
      },
    );
  });
}
