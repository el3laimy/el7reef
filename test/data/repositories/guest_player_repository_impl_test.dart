import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/enums/guest_claim_status.dart';
import 'package:el7reef/data/repositories/guest_player_repository_impl.dart';
import 'package:el7reef/domain/entities/guest_player.dart';

void main() {
  group('GuestPlayerRepositoryImpl', () {
    late FakeFirebaseFirestore firestore;
    late GuestPlayerRepositoryImpl repository;
    late DateTime now;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = GuestPlayerRepositoryImpl(firestore: firestore);
      now = DateTime(2026, 4, 15, 12);
    });

    test(
      'creates guest players and filters them by team and tournament',
      () async {
        await repository.createGuestPlayer(
          GuestPlayer(
            id: 'gp-1',
            displayName: 'Mahmoud Ali',
            normalizedName: 'mahmoud ali',
            teamId: 'team-1',
            tournamentId: 'tournament-1',
            createdBy: 'captain-1',
            createdAt: now,
            updatedAt: now,
          ),
        );
        await repository.createGuestPlayer(
          GuestPlayer(
            id: 'gp-2',
            displayName: 'Youssef Samy',
            normalizedName: 'youssef samy',
            teamId: 'team-1',
            tournamentId: 'tournament-1',
            createdBy: 'captain-1',
            createdAt: now.add(const Duration(minutes: 1)),
            updatedAt: now.add(const Duration(minutes: 1)),
          ),
        );
        await repository.createGuestPlayer(
          GuestPlayer(
            id: 'gp-3',
            displayName: 'Other Player',
            normalizedName: 'other player',
            teamId: 'team-2',
            tournamentId: 'tournament-2',
            createdBy: 'captain-2',
            createdAt: now,
            updatedAt: now,
          ),
        );

        final byTeam = await repository.getTeamGuestPlayers('team-1');
        final byTournament = await repository.getTournamentGuestPlayers(
          'tournament-1',
        );
        final guestPlayer = await repository.getGuestPlayer('gp-1');

        expect(byTeam.map((player) => player.id), ['gp-1', 'gp-2']);
        expect(byTournament.map((player) => player.id), ['gp-1', 'gp-2']);
        expect(guestPlayer?.displayName, 'Mahmoud Ali');
      },
    );

    test('updates and archives guest players', () async {
      await repository.createGuestPlayer(
        GuestPlayer(
          id: 'gp-1',
          displayName: 'Mahmoud Ali',
          normalizedName: 'mahmoud ali',
          teamId: 'team-1',
          tournamentId: 'tournament-1',
          createdBy: 'captain-1',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await repository.updateGuestPlayer(
        GuestPlayer(
          id: 'gp-1',
          displayName: 'Mahmoud Ali Updated',
          normalizedName: 'mahmoud ali updated',
          phoneNumber: '01000000000',
          jerseyNumber: 10,
          preferredPosition: 'MID',
          teamId: 'team-1',
          tournamentId: 'tournament-1',
          createdBy: 'captain-1',
          createdAt: now,
          updatedAt: now.add(const Duration(hours: 1)),
          claimStatus: GuestClaimStatus.invited,
          claimCode: 'code-1',
          notes: 'updated',
        ),
      );

      await repository.archiveGuestPlayer('gp-1');

      final guestPlayer = await repository.getGuestPlayer('gp-1');

      expect(guestPlayer?.displayName, 'Mahmoud Ali Updated');
      expect(guestPlayer?.phoneNumber, '01000000000');
      expect(guestPlayer?.claimCode, 'code-1');
      expect(guestPlayer?.claimStatus, GuestClaimStatus.archived);
    });

    test('loads guest players by ids in the requested order', () async {
      await repository.createGuestPlayer(
        GuestPlayer(
          id: 'gp-1',
          displayName: 'Mahmoud Ali',
          normalizedName: 'mahmoud ali',
          teamId: 'team-1',
          tournamentId: 'tournament-1',
          createdBy: 'captain-1',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repository.createGuestPlayer(
        GuestPlayer(
          id: 'gp-2',
          displayName: 'Youssef Samy',
          normalizedName: 'youssef samy',
          teamId: 'team-1',
          tournamentId: 'tournament-1',
          createdBy: 'captain-1',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final guestPlayers = await repository.getGuestPlayersByIds([
        'gp-2',
        'missing',
        'gp-1',
      ]);

      expect(guestPlayers.map((player) => player.id).toList(), [
        'gp-2',
        'gp-1',
      ]);
    });
  });
}
