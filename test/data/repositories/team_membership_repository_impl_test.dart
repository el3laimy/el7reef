import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/enums/team_member_availability.dart';
import 'package:el7reef/core/enums/team_membership_role.dart';
import 'package:el7reef/core/enums/team_membership_status.dart';
import 'package:el7reef/data/repositories/team_membership_repository_impl.dart';
import 'package:el7reef/domain/entities/team_membership.dart';

void main() {
  group('TeamMembershipRepositoryImpl', () {
    late FakeFirebaseFirestore firestore;
    late TeamMembershipRepositoryImpl repository;
    late DateTime now;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = TeamMembershipRepositoryImpl(firestore: firestore);
      now = DateTime(2026, 4, 16, 12);
    });

    test('creates memberships and queries them by team and identity', () async {
      await repository.createMembership(
        TeamMembership(
          id: 'm-1',
          teamId: 'team-1',
          playerId: 'player-1',
          role: TeamMembershipRole.owner,
          status: TeamMembershipStatus.starter,
          availability: TeamMemberAvailability.available,
          joinedAt: now,
          updatedAt: now,
        ),
      );
      await repository.createMembership(
        TeamMembership(
          id: 'm-2',
          teamId: 'team-1',
          guestPlayerId: 'guest-1',
          role: TeamMembershipRole.player,
          status: TeamMembershipStatus.bench,
          availability: TeamMemberAvailability.available,
          joinedAt: now.add(const Duration(minutes: 1)),
          updatedAt: now.add(const Duration(minutes: 1)),
        ),
      );
      await repository.createMembership(
        TeamMembership(
          id: 'm-3',
          teamId: 'team-2',
          playerId: 'player-2',
          role: TeamMembershipRole.player,
          status: TeamMembershipStatus.starter,
          availability: TeamMemberAvailability.available,
          joinedAt: now,
          updatedAt: now,
        ),
      );

      final memberships = await repository.getTeamMemberships('team-1');
      final byPlayer = await repository.getMembershipByPlayerId(
        teamId: 'team-1',
        playerId: 'player-1',
      );
      final byGuest = await repository.getMembershipByGuestPlayerId(
        teamId: 'team-1',
        guestPlayerId: 'guest-1',
      );

      expect(memberships.map((membership) => membership.id), ['m-1', 'm-2']);
      expect(byPlayer?.role, TeamMembershipRole.owner);
      expect(byGuest?.status, TeamMembershipStatus.bench);
    });

    test('filters inactive memberships by default and includes them on demand',
        () async {
      await repository.createMembership(
        TeamMembership(
          id: 'm-1',
          teamId: 'team-1',
          playerId: 'player-1',
          status: TeamMembershipStatus.inactive,
          availability: TeamMemberAvailability.unavailable,
          joinedAt: now,
          updatedAt: now,
        ),
      );

      final activeOnly = await repository.getTeamMemberships('team-1');
      final includingInactive = await repository.getTeamMemberships(
        'team-1',
        includeInactive: true,
      );

      expect(activeOnly, isEmpty);
      expect(includingInactive.single.id, 'm-1');
    });
  });
}
