import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/enums/tournament_registration_status.dart';
import 'package:el7reef/data/repositories/tournament_registration_repository_impl.dart';
import 'package:el7reef/domain/entities/tournament_registration.dart';

void main() {
  group('TournamentRegistrationRepositoryImpl', () {
    late FakeFirebaseFirestore firestore;
    late TournamentRegistrationRepositoryImpl repository;
    late DateTime now;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = TournamentRegistrationRepositoryImpl(firestore: firestore);
      now = DateTime(2026, 4, 16, 15);
    });

    test('creates registrations and queries them by tournament and participant',
        () async {
      await repository.createRegistration(
        TournamentRegistration(
          id: 'tr-1',
          tournamentId: 'tournament-1',
          teamId: 'team-1',
          createdBy: 'owner-1',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repository.createRegistration(
        TournamentRegistration(
          id: 'tr-2',
          tournamentId: 'tournament-1',
          guestTeamId: 'guest-team-1',
          createdBy: 'organizer-1',
          createdAt: now.add(const Duration(minutes: 1)),
          updatedAt: now.add(const Duration(minutes: 1)),
        ),
      );
      await repository.createRegistration(
        TournamentRegistration(
          id: 'tr-3',
          tournamentId: 'tournament-2',
          teamId: 'team-1',
          createdBy: 'owner-1',
          createdAt: now.add(const Duration(minutes: 2)),
          updatedAt: now.add(const Duration(minutes: 2)),
        ),
      );

      final tournamentRegistrations =
          await repository.getTournamentRegistrations('tournament-1');
      final byTeam = await repository.getRegistrationByTeamId(
        tournamentId: 'tournament-1',
        teamId: 'team-1',
      );
      final byGuest = await repository.getRegistrationByGuestTeamId(
        tournamentId: 'tournament-1',
        guestTeamId: 'guest-team-1',
      );
      final teamRegistrations = await repository.getRegistrationsByTeamId('team-1');
      final guestRegistrations =
          await repository.getRegistrationsByGuestTeamId('guest-team-1');

      expect(tournamentRegistrations.map((entry) => entry.id), ['tr-1', 'tr-2']);
      expect(byTeam?.teamId, 'team-1');
      expect(byGuest?.guestTeamId, 'guest-team-1');
      expect(teamRegistrations.map((entry) => entry.id), ['tr-3', 'tr-1']);
      expect(guestRegistrations.single.id, 'tr-2');
    });

    test('updates status, verification fields, and claim linkage', () async {
      await repository.createRegistration(
        TournamentRegistration(
          id: 'tr-1',
          tournamentId: 'tournament-1',
          guestTeamId: 'guest-team-1',
          createdBy: 'organizer-1',
          createdAt: now,
          updatedAt: now,
          notes: 'Manual entry',
        ),
      );

      await repository.updateRegistration(
        TournamentRegistration(
          id: 'tr-1',
          tournamentId: 'tournament-1',
          teamId: 'team-9',
          claimedFromGuestTeamId: 'guest-team-1',
          status: TournamentRegistrationStatus.approved,
          createdBy: 'organizer-1',
          createdAt: now,
          updatedAt: now.add(const Duration(hours: 1)),
          verifiedBy: 'organizer-1',
          verifiedAt: now.add(const Duration(hours: 1)),
          notes: 'Verified after claim',
        ),
      );

      final updated = await repository.getRegistration('tr-1');

      expect(updated?.teamId, 'team-9');
      expect(updated?.guestTeamId, isNull);
      expect(updated?.claimedFromGuestTeamId, 'guest-team-1');
      expect(updated?.status, TournamentRegistrationStatus.approved);
      expect(updated?.verifiedBy, 'organizer-1');
      expect(updated?.isVerified, isTrue);
      expect(updated?.notes, 'Verified after claim');
    });
  });
}
