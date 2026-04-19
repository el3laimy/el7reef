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
  });
}
