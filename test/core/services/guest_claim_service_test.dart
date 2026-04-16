import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/enums/claim_merge_conflict_type.dart';
import 'package:el7reef/core/services/guest_claim_service.dart';
import 'package:el7reef/core/services/share_link_service.dart';
import 'package:el7reef/core/services/team_roster_service.dart';
import 'package:el7reef/data/repositories/claim_code_repository_impl.dart';
import 'package:el7reef/data/repositories/guest_player_repository_impl.dart';
import 'package:el7reef/data/repositories/guest_team_repository_impl.dart';
import 'package:el7reef/data/repositories/player_repository_impl.dart';
import 'package:el7reef/data/repositories/team_membership_repository_impl.dart';
import 'package:el7reef/data/repositories/team_repository_impl.dart';
import 'package:el7reef/domain/entities/guest_player.dart';
import 'package:el7reef/domain/entities/guest_team.dart';
import 'package:el7reef/domain/entities/player.dart';
import 'package:el7reef/domain/entities/team.dart';

void main() {
  group('GuestClaimService', () {
    late FakeFirebaseFirestore firestore;
    late ClaimCodeRepositoryImpl claimCodeRepository;
    late GuestPlayerRepositoryImpl guestPlayerRepository;
    late GuestTeamRepositoryImpl guestTeamRepository;
    late PlayerRepositoryImpl playerRepository;
    late TeamMembershipRepositoryImpl membershipRepository;
    late TeamRepositoryImpl teamRepository;
    late TeamRosterService teamRosterService;
    late ShareLinkService shareLinkService;
    late GuestClaimService guestClaimService;
    late DateTime now;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      claimCodeRepository = ClaimCodeRepositoryImpl(firestore: firestore);
      guestPlayerRepository = GuestPlayerRepositoryImpl(firestore: firestore);
      guestTeamRepository = GuestTeamRepositoryImpl(firestore: firestore);
      playerRepository = PlayerRepositoryImpl(firestore: firestore);
      membershipRepository = TeamMembershipRepositoryImpl(firestore: firestore);
      teamRepository = TeamRepositoryImpl(firestore: firestore);
      teamRosterService = TeamRosterService(
        teamRepository: teamRepository,
        membershipRepository: membershipRepository,
        guestPlayerRepository: guestPlayerRepository,
      );
      shareLinkService = ShareLinkService(
        claimCodeRepository: claimCodeRepository,
        guestPlayerRepository: guestPlayerRepository,
        guestTeamRepository: guestTeamRepository,
        teamRepository: teamRepository,
      );
      guestClaimService = GuestClaimService(firestore: firestore);
      now = DateTime(2026, 4, 15, 12);

      await teamRepository.createTeam(
        Team(
          id: 'team-1',
          name: 'Street Kings',
          ownerId: 'owner-1',
          playerIds: const ['owner-1'],
          viceCaptainIds: const ['vice-1'],
          createdAt: now,
        ),
      );
      await playerRepository.createPlayer(
        Player(
          id: 'owner-1',
          name: 'Owner One',
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
      await playerRepository.createPlayer(
        Player(
          id: 'player-2',
          name: 'Kareem Adel',
          createdAt: now,
          lastActiveAt: now,
        ),
      );
      await playerRepository.createPlayer(
        Player(
          id: 'owner-2',
          name: 'Captain Two',
          createdAt: now,
          lastActiveAt: now,
        ),
      );
      await playerRepository.createPlayer(
        Player(
          id: 'owner-3',
          name: 'Captain Three',
          createdAt: now,
          lastActiveAt: now,
        ),
      );
      await teamRepository.createTeam(
        Team(
          id: 'team-2',
          name: 'Blue Sharks',
          ownerId: 'owner-2',
          playerIds: const ['owner-2'],
          tournamentIds: const ['legacy-cup'],
          createdAt: now,
        ),
      );
      await teamRepository.createTeam(
        Team(
          id: 'team-3',
          name: 'Golden Boys',
          ownerId: 'owner-3',
          playerIds: const ['owner-3'],
          createdAt: now,
        ),
      );
      await guestPlayerRepository.createGuestPlayer(
        GuestPlayer(
          id: 'guest-1',
          displayName: 'Mahmoud Guest',
          normalizedName: 'mahmoud guest',
          teamId: 'team-1',
          createdBy: 'owner-1',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await guestTeamRepository.createGuestTeam(
        GuestTeam(
          id: 'guest-team-1',
          name: 'Guest Falcons',
          normalizedName: 'guest falcons',
          creatorId: 'owner-1',
          contactName: 'Organizer Omar',
          contactPhone: '01000000000',
          tournamentIds: const ['street-cup', 'ramadan-league'],
          createdAt: now,
          updatedAt: now,
        ),
      );
      await teamRosterService.addGuestPlayer(
        teamId: 'team-1',
        actorId: 'owner-1',
        guestPlayerId: 'guest-1',
        now: now,
      );
    });

    test('claims guest team directly into a registered team and preserves history',
        () async {
      final generated = await shareLinkService.createGuestTeamClaimLink(
        guestTeamId: 'guest-team-1',
        actorId: 'owner-1',
        requiresApproval: false,
      );

      final result = await guestClaimService.claimGuestTeam(
        claimCode: generated.claimCode.code,
        teamId: 'team-2',
        actorId: 'owner-2',
        now: now.add(const Duration(hours: 1)),
      );

      final updatedGuestTeam = await guestTeamRepository.getGuestTeam('guest-team-1');
      final updatedTeam = await teamRepository.getTeam('team-2');
      final updatedClaimCode =
          await claimCodeRepository.getClaimCode(generated.claimCode.code);

      expect(result.outcome, GuestTeamClaimOutcome.claimed);
      expect(result.mergedTournamentIds, containsAll(['legacy-cup', 'street-cup']));
      expect(updatedGuestTeam?.isClaimed, isTrue);
      expect(updatedGuestTeam?.linkedTeamId, 'team-2');
      expect(
        updatedTeam?.tournamentIds,
        containsAll(['legacy-cup', 'street-cup', 'ramadan-league']),
      );
      expect(updatedClaimCode?.status.name, 'claimed');
      expect(updatedClaimCode?.teamId, 'team-2');
      expect(updatedClaimCode?.claimedByPlayerId, 'owner-2');
    });

    test('returns approvalRequired when a guest team claim needs organizer approval',
        () async {
      final generated = await shareLinkService.createGuestTeamClaimLink(
        guestTeamId: 'guest-team-1',
        actorId: 'owner-1',
      );

      final result = await guestClaimService.claimGuestTeam(
        claimCode: generated.claimCode.code,
        teamId: 'team-2',
        actorId: 'owner-2',
        now: now.add(const Duration(hours: 1)),
      );

      final updatedGuestTeam = await guestTeamRepository.getGuestTeam('guest-team-1');
      final updatedTeam = await teamRepository.getTeam('team-2');
      final updatedClaimCode =
          await claimCodeRepository.getClaimCode(generated.claimCode.code);

      expect(result.outcome, GuestTeamClaimOutcome.approvalRequired);
      expect(result.isPendingApproval, isTrue);
      expect(updatedGuestTeam?.isClaimed, isFalse);
      expect(updatedGuestTeam?.linkedTeamId, isNull);
      expect(
        updatedTeam?.tournamentIds,
        containsAll(['legacy-cup', 'street-cup', 'ramadan-league']),
      );
      expect(updatedClaimCode?.status.name, 'active');
      expect(updatedClaimCode?.teamId, 'team-2');
      expect(updatedClaimCode?.claimedByPlayerId, 'owner-2');
    });

    test('guest team creator can approve a pending claim request', () async {
      final generated = await shareLinkService.createGuestTeamClaimLink(
        guestTeamId: 'guest-team-1',
        actorId: 'owner-1',
      );

      await guestClaimService.claimGuestTeam(
        claimCode: generated.claimCode.code,
        teamId: 'team-2',
        actorId: 'owner-2',
        now: now.add(const Duration(minutes: 30)),
      );

      final result = await guestClaimService.claimGuestTeam(
        claimCode: generated.claimCode.code,
        teamId: 'team-2',
        actorId: 'owner-1',
        now: now.add(const Duration(hours: 1)),
      );

      final updatedGuestTeam = await guestTeamRepository.getGuestTeam('guest-team-1');
      final updatedClaimCode =
          await claimCodeRepository.getClaimCode(generated.claimCode.code);

      expect(result.outcome, GuestTeamClaimOutcome.claimed);
      expect(updatedGuestTeam?.isClaimed, isTrue);
      expect(updatedGuestTeam?.linkedTeamId, 'team-2');
      expect(updatedClaimCode?.status.name, 'claimed');
      expect(updatedClaimCode?.claimedByPlayerId, 'owner-2');
    });

    test('re-running the same guest team claim is idempotent', () async {
      final generated = await shareLinkService.createGuestTeamClaimLink(
        guestTeamId: 'guest-team-1',
        actorId: 'owner-1',
        requiresApproval: false,
      );

      await guestClaimService.claimGuestTeam(
        claimCode: generated.claimCode.code,
        teamId: 'team-2',
        actorId: 'owner-2',
        now: now.add(const Duration(minutes: 30)),
      );

      final second = await guestClaimService.claimGuestTeam(
        claimCode: generated.claimCode.code,
        teamId: 'team-2',
        actorId: 'owner-2',
        now: now.add(const Duration(hours: 1)),
      );

      expect(second.outcome, GuestTeamClaimOutcome.alreadyClaimed);
      expect(second.isIdempotent, isTrue);
    });

    test('marks guest team claim links as expired when used after expiry', () async {
      final generated = await shareLinkService.createGuestTeamClaimLink(
        guestTeamId: 'guest-team-1',
        actorId: 'owner-1',
        requiresApproval: false,
      );
      await claimCodeRepository.updateClaimCode(
        generated.claimCode.copyWith(
          expiresAt: now.subtract(const Duration(minutes: 1)),
          updatedAt: now,
        ),
      );

      await expectLater(
        () => guestClaimService.claimGuestTeam(
          claimCode: generated.claimCode.code,
          teamId: 'team-2',
          actorId: 'owner-2',
          now: now.add(const Duration(hours: 1)),
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('انتهت صلاحية رابط استلام الفريق.'),
          ),
        ),
      );

      final updatedClaimCode =
          await claimCodeRepository.getClaimCode(generated.claimCode.code);
      expect(updatedClaimCode?.status.name, 'expired');
    });

    test('returns a target-link conflict when a different team tries to claim the same guest team',
        () async {
      final generated = await shareLinkService.createGuestTeamClaimLink(
        guestTeamId: 'guest-team-1',
        actorId: 'owner-1',
        requiresApproval: false,
      );

      await guestClaimService.claimGuestTeam(
        claimCode: generated.claimCode.code,
        teamId: 'team-2',
        actorId: 'owner-2',
        now: now.add(const Duration(minutes: 30)),
      );

      final result = await guestClaimService.claimGuestTeam(
        claimCode: generated.claimCode.code,
        teamId: 'team-3',
        actorId: 'owner-3',
        now: now.add(const Duration(hours: 1)),
      );

      expect(result.outcome, GuestTeamClaimOutcome.conflict);
      expect(result.hasConflict, isTrue);
      expect(result.conflict?.type, ClaimMergeConflictType.targetAlreadyLinked);
      expect(result.conflict?.conflictingEntityId, 'team-2');
    });

    test('returns a duplicate-name conflict when another registered team already matches the guest team',
        () async {
      await teamRepository.createTeam(
        Team(
          id: 'team-4',
          name: 'Guest Falcons',
          ownerId: 'owner-3',
          playerIds: const ['owner-3'],
          createdAt: now,
        ),
      );
      final generated = await shareLinkService.createGuestTeamClaimLink(
        guestTeamId: 'guest-team-1',
        actorId: 'owner-1',
        requiresApproval: false,
      );

      final result = await guestClaimService.claimGuestTeam(
        claimCode: generated.claimCode.code,
        teamId: 'team-2',
        actorId: 'owner-2',
        now: now.add(const Duration(hours: 1)),
      );

      expect(result.outcome, GuestTeamClaimOutcome.conflict);
      expect(result.hasConflict, isTrue);
      expect(result.conflict?.type, ClaimMergeConflictType.duplicateName);
      expect(result.conflict?.conflictingEntityId, 'team-4');
    });

    test('claims guest player into registered identity and relinks memberships',
        () async {
      final generated = await shareLinkService.createGuestPlayerClaimLink(
        guestPlayerId: 'guest-1',
        actorId: 'owner-1',
      );

      final result = await guestClaimService.claimGuestPlayer(
        claimCode: generated.claimCode.code,
        playerId: 'player-1',
        now: now.add(const Duration(hours: 1)),
      );

      final updatedGuest = await guestPlayerRepository.getGuestPlayer('guest-1');
      final updatedPlayer = await playerRepository.getPlayer('player-1');
      final updatedMembership = await membershipRepository.getMembershipByPlayerId(
        teamId: 'team-1',
        playerId: 'player-1',
      );
      final updatedClaimCode =
          await claimCodeRepository.getClaimCode(generated.claimCode.code);
      final updatedTeam = await teamRepository.getTeam('team-1');

      expect(result.outcome, GuestPlayerClaimOutcome.claimed);
      expect(result.relinkedMembershipIds, hasLength(1));
      expect(result.linkedTeamIds, contains('team-1'));
      expect(result.syncedLegacyTeamIds, isEmpty);
      expect(updatedGuest?.isClaimed, isTrue);
      expect(updatedGuest?.linkedPlayerId, 'player-1');
      expect(updatedPlayer?.teamIds, contains('team-1'));
      expect(updatedMembership?.guestPlayerId, isNull);
      expect(updatedMembership?.claimedFromGuestPlayerId, 'guest-1');
      expect(updatedClaimCode?.claimedByPlayerId, 'player-1');
      expect(updatedTeam?.playerIds, isNot(contains('player-1')));
    });

    test('re-running the same claim is idempotent', () async {
      final generated = await shareLinkService.createGuestPlayerClaimLink(
        guestPlayerId: 'guest-1',
        actorId: 'owner-1',
      );

      await guestClaimService.claimGuestPlayer(
        claimCode: generated.claimCode.code,
        playerId: 'player-1',
        now: now.add(const Duration(minutes: 30)),
      );

      final second = await guestClaimService.claimGuestPlayer(
        claimCode: generated.claimCode.code,
        playerId: 'player-1',
        now: now.add(const Duration(hours: 1)),
      );

      final roster = await teamRosterService.getTeamRoster(
        'team-1',
        includeInactive: true,
      );

      expect(second.outcome, GuestPlayerClaimOutcome.alreadyClaimed);
      expect(
        roster.where((membership) => membership.playerId == 'player-1'),
        hasLength(1),
      );
    });

    test('marks guest player claim links as expired when used after expiry',
        () async {
      final generated = await shareLinkService.createGuestPlayerClaimLink(
        guestPlayerId: 'guest-1',
        actorId: 'owner-1',
      );
      await claimCodeRepository.updateClaimCode(
        generated.claimCode.copyWith(
          expiresAt: now.subtract(const Duration(minutes: 1)),
          updatedAt: now,
        ),
      );

      await expectLater(
        () => guestClaimService.claimGuestPlayer(
          claimCode: generated.claimCode.code,
          playerId: 'player-1',
          now: now.add(const Duration(hours: 1)),
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('انتهت صلاحية رابط الاستلام.'),
          ),
        ),
      );

      final updatedClaimCode =
          await claimCodeRepository.getClaimCode(generated.claimCode.code);
      expect(updatedClaimCode?.status.name, 'expired');
    });

    test('manager-assisted claim syncs legacy team arrays for compatibility',
        () async {
      final generated = await shareLinkService.createGuestPlayerClaimLink(
        guestPlayerId: 'guest-1',
        actorId: 'owner-1',
      );

      final result = await guestClaimService.claimGuestPlayer(
        claimCode: generated.claimCode.code,
        playerId: 'player-2',
        actorId: 'owner-1',
        now: now.add(const Duration(hours: 1)),
      );

      final updatedTeam = await teamRepository.getTeam('team-1');

      expect(result.syncedLegacyTeamIds, contains('team-1'));
      expect(updatedTeam?.playerIds, contains('player-2'));
    });

    test('returns a roster conflict when the player is already active in the same team',
        () async {
      await teamRosterService.addRegisteredPlayer(
        teamId: 'team-1',
        actorId: 'owner-1',
        playerId: 'player-1',
        now: now.add(const Duration(minutes: 5)),
      );
      final generated = await shareLinkService.createGuestPlayerClaimLink(
        guestPlayerId: 'guest-1',
        actorId: 'owner-1',
      );

      final result = await guestClaimService.claimGuestPlayer(
        claimCode: generated.claimCode.code,
        playerId: 'player-1',
        now: now.add(const Duration(hours: 1)),
      );

      expect(result.outcome, GuestPlayerClaimOutcome.conflict);
      expect(result.hasConflict, isTrue);
      expect(
        result.conflict?.type,
        ClaimMergeConflictType.rosterAlreadyContainsPlayer,
      );
      expect(result.conflict?.conflictingEntityId, 'team-1');
    });

    test('returns a duplicate-phone conflict when another registered player matches the guest record',
        () async {
      await playerRepository.createPlayer(
        Player(
          id: 'player-phone-dup',
          name: 'Phone Duplicate',
          phone: '01012345678',
          createdAt: now,
          lastActiveAt: now,
        ),
      );
      await guestPlayerRepository.createGuestPlayer(
        GuestPlayer(
          id: 'guest-phone-1',
          displayName: 'Phone Guest',
          normalizedName: 'phone guest',
          phoneNumber: '01012345678',
          teamId: 'team-1',
          createdBy: 'owner-1',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await teamRosterService.addGuestPlayer(
        teamId: 'team-1',
        actorId: 'owner-1',
        guestPlayerId: 'guest-phone-1',
        now: now,
      );

      final generated = await shareLinkService.createGuestPlayerClaimLink(
        guestPlayerId: 'guest-phone-1',
        actorId: 'owner-1',
      );

      final result = await guestClaimService.claimGuestPlayer(
        claimCode: generated.claimCode.code,
        playerId: 'player-1',
        now: now.add(const Duration(hours: 1)),
      );

      expect(result.outcome, GuestPlayerClaimOutcome.conflict);
      expect(result.hasConflict, isTrue);
      expect(result.conflict?.type, ClaimMergeConflictType.duplicatePhone);
      expect(result.conflict?.conflictingEntityId, 'player-phone-dup');
    });

    test('returns a duplicate-name conflict when another registered player matches the guest record',
        () async {
      await playerRepository.createPlayer(
        Player(
          id: 'player-name-dup',
          name: 'Alias Guest',
          createdAt: now,
          lastActiveAt: now,
        ),
      );
      await guestPlayerRepository.createGuestPlayer(
        GuestPlayer(
          id: 'guest-name-1',
          displayName: 'Alias Guest',
          normalizedName: 'alias guest',
          teamId: 'team-1',
          createdBy: 'owner-1',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await teamRosterService.addGuestPlayer(
        teamId: 'team-1',
        actorId: 'owner-1',
        guestPlayerId: 'guest-name-1',
        now: now,
      );

      final generated = await shareLinkService.createGuestPlayerClaimLink(
        guestPlayerId: 'guest-name-1',
        actorId: 'owner-1',
      );

      final result = await guestClaimService.claimGuestPlayer(
        claimCode: generated.claimCode.code,
        playerId: 'player-1',
        now: now.add(const Duration(hours: 1)),
      );

      expect(result.outcome, GuestPlayerClaimOutcome.conflict);
      expect(result.hasConflict, isTrue);
      expect(result.conflict?.type, ClaimMergeConflictType.duplicateName);
      expect(result.conflict?.conflictingEntityId, 'player-name-dup');
    });
  });
}
