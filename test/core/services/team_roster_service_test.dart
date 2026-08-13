import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/constants/firebase_paths.dart';
import 'package:el7reef/core/enums/team_member_availability.dart';
import 'package:el7reef/core/enums/team_membership_role.dart';
import 'package:el7reef/core/enums/team_membership_status.dart';
import 'package:el7reef/core/services/team_roster_service.dart';
import 'package:el7reef/data/repositories/guest_player_repository_impl.dart';
import 'package:el7reef/data/repositories/team_membership_repository_impl.dart';
import 'package:el7reef/data/repositories/team_repository_impl.dart';
import 'package:el7reef/domain/entities/guest_player.dart';
import 'package:el7reef/domain/entities/team.dart';

void main() {
  group('TeamRosterService', () {
    late FakeFirebaseFirestore firestore;
    late TeamRosterService service;
    late TeamRepositoryImpl teamRepository;
    late TeamMembershipRepositoryImpl membershipRepository;
    late GuestPlayerRepositoryImpl guestPlayerRepository;
    late DateTime now;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      teamRepository = TeamRepositoryImpl(firestore: firestore);
      membershipRepository = TeamMembershipRepositoryImpl(firestore: firestore);
      guestPlayerRepository = GuestPlayerRepositoryImpl(firestore: firestore);
      service = TeamRosterService(
        teamRepository: teamRepository,
        membershipRepository: membershipRepository,
        guestPlayerRepository: guestPlayerRepository,
      );
      now = DateTime(2026, 4, 16, 12);

      await teamRepository.createTeam(
        Team(
          id: 'team-1',
          name: 'Street Kings',
          ownerId: 'owner-1',
          viceCaptainIds: const ['vice-1'],
          playerIds: const ['owner-1', 'vice-1'],
          createdAt: now,
        ),
      );
    });

    test('bootstraps legacy team arrays into membership records', () async {
      final roster = await service.getTeamRoster(
        'team-1',
        includeInactive: true,
      );

      expect(roster.length, 2);
      expect(
        roster
            .where((membership) => membership.playerId == 'owner-1')
            .single
            .role,
        TeamMembershipRole.owner,
      );
      expect(
        roster
            .where((membership) => membership.playerId == 'vice-1')
            .single
            .role,
        TeamMembershipRole.viceCaptain,
      );
    });

    test('adds a registered player and updates the team arrays', () async {
      final membership = await service.addRegisteredPlayer(
        teamId: 'team-1',
        actorId: 'owner-1',
        playerId: 'player-2',
        status: TeamMembershipStatus.starter,
        now: now.add(const Duration(hours: 1)),
      );

      final teamDoc = await firestore
          .collection(FirebasePaths.teams)
          .doc('team-1')
          .get();

      expect(membership.playerId, 'player-2');
      expect(teamDoc.data()?['playerIds'], contains('player-2'));
    });

    test('adds a guest player and links the guest to the team scope', () async {
      await guestPlayerRepository.createGuestPlayer(
        GuestPlayer(
          id: 'guest-1',
          displayName: 'Mahmoud Ali',
          normalizedName: 'mahmoud ali',
          createdBy: 'owner-1',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final membership = await service.addGuestPlayer(
        teamId: 'team-1',
        actorId: 'owner-1',
        guestPlayerId: 'guest-1',
        status: TeamMembershipStatus.bench,
        now: now.add(const Duration(hours: 1)),
      );

      final guestDoc = await firestore
          .collection(FirebasePaths.guestPlayers)
          .doc('guest-1')
          .get();

      expect(membership.guestPlayerId, 'guest-1');
      expect(guestDoc.data()?['teamId'], 'team-1');
    });

    test(
      'rejects manual guest-to-player conversion outside trusted claim',
      () async {
        await guestPlayerRepository.createGuestPlayer(
          GuestPlayer(
            id: 'guest-1',
            displayName: 'Mahmoud Ali',
            normalizedName: 'mahmoud ali',
            teamId: 'team-1',
            createdBy: 'owner-1',
            createdAt: now,
            updatedAt: now,
          ),
        );
        await service.addGuestPlayer(
          teamId: 'team-1',
          actorId: 'owner-1',
          guestPlayerId: 'guest-1',
          now: now,
        );

        await expectLater(
          () => service.replaceGuestWithRegisteredPlayer(
            teamId: 'team-1',
            actorId: 'owner-1',
            guestPlayerId: 'guest-1',
            playerId: 'player-3',
            now: now.add(const Duration(hours: 2)),
          ),
          throwsA(isA<UnsupportedError>()),
        );

        final teamDoc = await firestore
            .collection(FirebasePaths.teams)
            .doc('team-1')
            .get();
        final memberships = await membershipRepository.getTeamMemberships(
          'team-1',
        );

        expect(memberships.single.guestPlayerId, 'guest-1');
        expect(memberships.single.claimedFromGuestPlayerId, isNull);
        expect(teamDoc.data()?['playerIds'], isNot(contains('player-3')));
      },
    );

    test(
      'prevents duplicate registered memberships and invalid guest roles',
      () async {
        await service.addRegisteredPlayer(
          teamId: 'team-1',
          actorId: 'owner-1',
          playerId: 'player-2',
          now: now,
        );

        await expectLater(
          () => service.addRegisteredPlayer(
            teamId: 'team-1',
            actorId: 'owner-1',
            playerId: 'player-2',
            now: now.add(const Duration(minutes: 1)),
          ),
          throwsException,
        );

        await guestPlayerRepository.createGuestPlayer(
          GuestPlayer(
            id: 'guest-1',
            displayName: 'Guest One',
            normalizedName: 'guest one',
            createdBy: 'owner-1',
            createdAt: now,
            updatedAt: now,
          ),
        );

        await expectLater(
          () => service.addRegisteredPlayer(
            teamId: 'team-1',
            actorId: 'owner-1',
            playerId: 'owner-1',
            role: TeamMembershipRole.viceCaptain,
            now: now.add(const Duration(minutes: 2)),
          ),
          throwsException,
        );
      },
    );

    test(
      'updates availability and soft-removes non-owner memberships',
      () async {
        final membership = await service.addRegisteredPlayer(
          teamId: 'team-1',
          actorId: 'owner-1',
          playerId: 'player-2',
          now: now,
        );

        final updatedAvailability = await service.updateAvailability(
          teamId: 'team-1',
          actorId: 'owner-1',
          membershipId: membership.id,
          availability: TeamMemberAvailability.injured,
          now: now.add(const Duration(minutes: 5)),
        );

        final removedMembership = await service.removeMembership(
          teamId: 'team-1',
          actorId: 'owner-1',
          membershipId: membership.id,
          now: now.add(const Duration(minutes: 10)),
        );

        final teamDoc = await firestore
            .collection(FirebasePaths.teams)
            .doc('team-1')
            .get();

        expect(
          updatedAvailability.availability,
          TeamMemberAvailability.injured,
        );
        expect(removedMembership.status, TeamMembershipStatus.inactive);
        expect(
          removedMembership.availability,
          TeamMemberAvailability.unavailable,
        );
        expect(teamDoc.data()?['playerIds'], isNot(contains('player-2')));
      },
    );

    test(
      'updates vice captain role and blocks guest role escalation',
      () async {
        final membership = await service.addRegisteredPlayer(
          teamId: 'team-1',
          actorId: 'owner-1',
          playerId: 'player-4',
          now: now,
        );

        final promoted = await service.updateMembershipRole(
          teamId: 'team-1',
          actorId: 'owner-1',
          membershipId: membership.id,
          role: TeamMembershipRole.viceCaptain,
          now: now.add(const Duration(minutes: 2)),
        );

        final teamDoc = await firestore
            .collection(FirebasePaths.teams)
            .doc('team-1')
            .get();

        expect(promoted.role, TeamMembershipRole.viceCaptain);
        expect(teamDoc.data()?['viceCaptainIds'], contains('player-4'));

        await guestPlayerRepository.createGuestPlayer(
          GuestPlayer(
            id: 'guest-9',
            displayName: 'Guest Nine',
            normalizedName: 'guest nine',
            teamId: 'team-1',
            createdBy: 'owner-1',
            createdAt: now,
            updatedAt: now,
          ),
        );
        final guestMembership = await service.addGuestPlayer(
          teamId: 'team-1',
          actorId: 'owner-1',
          guestPlayerId: 'guest-9',
          now: now,
        );

        await expectLater(
          () => service.updateMembershipRole(
            teamId: 'team-1',
            actorId: 'owner-1',
            membershipId: guestMembership.id,
            role: TeamMembershipRole.viceCaptain,
            now: now.add(const Duration(minutes: 3)),
          ),
          throwsException,
        );
      },
    );
  });
}
