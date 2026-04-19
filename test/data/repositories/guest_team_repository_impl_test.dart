import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/enums/guest_claim_status.dart';
import 'package:el7reef/data/repositories/guest_team_repository_impl.dart';
import 'package:el7reef/domain/entities/guest_team.dart';

void main() {
  group('GuestTeamRepositoryImpl', () {
    late FakeFirebaseFirestore firestore;
    late GuestTeamRepositoryImpl repository;
    late DateTime now;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = GuestTeamRepositoryImpl(firestore: firestore);
      now = DateTime(2026, 4, 15, 12);
    });

    test('creates guest teams and filters them by tournament', () async {
      await repository.createGuestTeam(
        GuestTeam(
          id: 'gt-1',
          name: 'Street Kings',
          normalizedName: 'street kings',
          creatorId: 'organizer-1',
          tournamentIds: const ['tournament-1'],
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repository.createGuestTeam(
        GuestTeam(
          id: 'gt-2',
          name: 'Red Lions',
          normalizedName: 'red lions',
          creatorId: 'organizer-1',
          tournamentIds: const ['tournament-1', 'tournament-2'],
          createdAt: now.add(const Duration(minutes: 1)),
          updatedAt: now.add(const Duration(minutes: 1)),
        ),
      );
      await repository.createGuestTeam(
        GuestTeam(
          id: 'gt-3',
          name: 'Blue Sharks',
          normalizedName: 'blue sharks',
          creatorId: 'organizer-2',
          tournamentIds: const ['tournament-3'],
          createdAt: now,
          updatedAt: now,
        ),
      );

      final tournamentTeams = await repository.getTournamentGuestTeams(
        'tournament-1',
      );
      final guestTeam = await repository.getGuestTeam('gt-2');

      expect(tournamentTeams.map((team) => team.id), ['gt-1', 'gt-2']);
      expect(guestTeam?.name, 'Red Lions');
    });

    test('updates and archives guest teams', () async {
      await repository.createGuestTeam(
        GuestTeam(
          id: 'gt-1',
          name: 'Street Kings',
          normalizedName: 'street kings',
          creatorId: 'organizer-1',
          tournamentIds: const ['tournament-1'],
          createdAt: now,
          updatedAt: now,
        ),
      );

      await repository.updateGuestTeam(
        GuestTeam(
          id: 'gt-1',
          name: 'Street Kings FC',
          normalizedName: 'street kings fc',
          creatorId: 'organizer-1',
          contactName: 'Captain Ahmed',
          contactPhone: '01000000000',
          tournamentIds: const ['tournament-1', 'tournament-2'],
          captainGuestPlayerId: 'gp-1',
          claimStatus: GuestClaimStatus.invited,
          createdAt: now,
          updatedAt: now.add(const Duration(hours: 1)),
        ),
      );

      await repository.archiveGuestTeam('gt-1');

      final guestTeam = await repository.getGuestTeam('gt-1');

      expect(guestTeam?.name, 'Street Kings FC');
      expect(guestTeam?.contactName, 'Captain Ahmed');
      expect(guestTeam?.captainGuestPlayerId, 'gp-1');
      expect(guestTeam?.claimStatus, GuestClaimStatus.archived);
    });

    test('loads guest teams by ids in the requested order', () async {
      await repository.createGuestTeam(
        GuestTeam(
          id: 'gt-1',
          name: 'Street Kings',
          normalizedName: 'street kings',
          creatorId: 'organizer-1',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repository.createGuestTeam(
        GuestTeam(
          id: 'gt-2',
          name: 'Red Lions',
          normalizedName: 'red lions',
          creatorId: 'organizer-1',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final guestTeams = await repository.getGuestTeamsByIds([
        'gt-2',
        'missing',
        'gt-1',
      ]);

      expect(guestTeams.map((team) => team.id).toList(), ['gt-2', 'gt-1']);
    });
  });
}
