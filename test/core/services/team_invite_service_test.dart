import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/services/share_link_service.dart';
import 'package:el7reef/core/services/team_invite_service.dart';
import 'package:el7reef/data/repositories/claim_code_repository_impl.dart';
import 'package:el7reef/data/repositories/guest_player_repository_impl.dart';
import 'package:el7reef/data/repositories/guest_team_repository_impl.dart';
import 'package:el7reef/data/repositories/player_repository_impl.dart';
import 'package:el7reef/data/repositories/team_membership_repository_impl.dart';
import 'package:el7reef/data/repositories/team_repository_impl.dart';
import 'package:el7reef/domain/entities/player.dart';
import 'package:el7reef/domain/entities/team.dart';

void main() {
  group('TeamInviteService', () {
    late FakeFirebaseFirestore firestore;
    late ClaimCodeRepositoryImpl claimCodeRepository;
    late TeamRepositoryImpl teamRepository;
    late TeamMembershipRepositoryImpl membershipRepository;
    late PlayerRepositoryImpl playerRepository;
    late GuestPlayerRepositoryImpl guestPlayerRepository;
    late GuestTeamRepositoryImpl guestTeamRepository;
    late ShareLinkService shareLinkService;
    late TeamInviteService teamInviteService;
    late DateTime now;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      claimCodeRepository = ClaimCodeRepositoryImpl(firestore: firestore);
      teamRepository = TeamRepositoryImpl(firestore: firestore);
      membershipRepository = TeamMembershipRepositoryImpl(firestore: firestore);
      playerRepository = PlayerRepositoryImpl(firestore: firestore);
      guestPlayerRepository = GuestPlayerRepositoryImpl(firestore: firestore);
      guestTeamRepository = GuestTeamRepositoryImpl(firestore: firestore);
      shareLinkService = ShareLinkService(
        claimCodeRepository: claimCodeRepository,
        guestPlayerRepository: guestPlayerRepository,
        guestTeamRepository: guestTeamRepository,
        teamRepository: teamRepository,
      );
      teamInviteService = TeamInviteService(
        claimCodeRepository: claimCodeRepository,
        teamRepository: teamRepository,
        membershipRepository: membershipRepository,
        playerRepository: playerRepository,
      );
      now = DateTime(2026, 4, 18, 12);

      await playerRepository.createPlayer(
        Player(
          id: 'owner-1',
          name: 'Captain Blue',
          createdAt: now,
          lastActiveAt: now,
        ),
      );
      await playerRepository.createPlayer(
        Player(
          id: 'player-1',
          name: 'Mahmoud Salem',
          createdAt: now,
          lastActiveAt: now,
        ),
      );
      await teamRepository.createTeam(
        Team(
          id: 'team-1',
          name: 'Blue Sharks',
          ownerId: 'owner-1',
          playerIds: const ['owner-1'],
          createdAt: now,
        ),
      );
    });

    test('accepts a valid invite and creates the membership linkage', () async {
      final inviteLink = await shareLinkService.createTeamInviteLink(
        teamId: 'team-1',
        actorId: 'owner-1',
      );

      final result = await teamInviteService.acceptInvite(
        code: inviteLink.claimCode.code,
        teamId: 'team-1',
        playerId: 'player-1',
        now: now.add(const Duration(minutes: 5)),
      );

      final updatedTeam = await teamRepository.getTeam('team-1');
      final updatedPlayer = await playerRepository.getPlayer('player-1');
      final membership = await membershipRepository.getMembership(
        'team-invite::team-1::player-1',
      );

      expect(result.outcome, TeamInviteAcceptanceOutcome.joined);
      expect(updatedTeam?.playerIds, contains('player-1'));
      expect(updatedPlayer?.teamIds, contains('team-1'));
      expect(membership?.playerId, 'player-1');
      expect(membership?.status.name, 'bench');
    });

    test('re-running the same invite is idempotent for the same player', () async {
      final inviteLink = await shareLinkService.createTeamInviteLink(
        teamId: 'team-1',
        actorId: 'owner-1',
      );

      await teamInviteService.acceptInvite(
        code: inviteLink.claimCode.code,
        teamId: 'team-1',
        playerId: 'player-1',
        now: now.add(const Duration(minutes: 5)),
      );
      final result = await teamInviteService.acceptInvite(
        code: inviteLink.claimCode.code,
        teamId: 'team-1',
        playerId: 'player-1',
        now: now.add(const Duration(minutes: 10)),
      );

      final memberships = await membershipRepository.getTeamMemberships(
        'team-1',
        includeInactive: true,
      );

      expect(result.outcome, TeamInviteAcceptanceOutcome.alreadyMember);
      expect(
        memberships.where((membership) => membership.playerId == 'player-1'),
        hasLength(1),
      );
    });

    test('expired invite links are rejected', () async {
      final inviteLink = await shareLinkService.createTeamInviteLink(
        teamId: 'team-1',
        actorId: 'owner-1',
        ttl: const Duration(minutes: 5),
      );

      expect(
        () => teamInviteService.acceptInvite(
          code: inviteLink.claimCode.code,
          teamId: 'team-1',
          playerId: 'player-1',
          now: inviteLink.claimCode.expiresAt.add(const Duration(seconds: 1)),
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('انتهت صلاحية رابط الدعوة'),
          ),
        ),
      );
    });
  });
}
