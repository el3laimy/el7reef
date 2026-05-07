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
      'getLiveTournaments remains public discovery and can include other organizers',
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

        final liveTournaments = await repository.getLiveTournaments();

        expect(
          liveTournaments.map((tournament) => tournament.id),
          containsAll(['account-a-public-cup', 'account-b-public-cup']),
        );
      },
    );

    test(
      'getPlayerTournaments falls back to legacy registeredTeamIds',
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
  });
}
