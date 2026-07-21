import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/enums/claim_code_status.dart';
import 'package:el7reef/core/enums/claim_payload_scope.dart';
import 'package:el7reef/core/enums/claim_target_type.dart';
import 'package:el7reef/core/enums/guest_claim_status.dart';
import 'package:el7reef/core/services/share_link_service.dart';
import 'package:el7reef/data/repositories/claim_code_repository_impl.dart';
import 'package:el7reef/data/repositories/guest_player_repository_impl.dart';
import 'package:el7reef/data/repositories/guest_team_repository_impl.dart';
import 'package:el7reef/data/repositories/team_repository_impl.dart';
import 'package:el7reef/domain/entities/guest_player.dart';
import 'package:el7reef/domain/entities/guest_team.dart';
import 'package:el7reef/domain/entities/team.dart';

void main() {
  group('ShareLinkService', () {
    late FakeFirebaseFirestore firestore;
    late ClaimCodeRepositoryImpl claimCodeRepository;
    late GuestPlayerRepositoryImpl guestPlayerRepository;
    late GuestTeamRepositoryImpl guestTeamRepository;
    late TeamRepositoryImpl teamRepository;
    late ShareLinkService service;
    late DateTime now;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      claimCodeRepository = ClaimCodeRepositoryImpl(firestore: firestore);
      guestPlayerRepository = GuestPlayerRepositoryImpl(firestore: firestore);
      guestTeamRepository = GuestTeamRepositoryImpl(firestore: firestore);
      teamRepository = TeamRepositoryImpl(firestore: firestore);
      service = ShareLinkService(
        claimCodeRepository: claimCodeRepository,
        guestPlayerRepository: guestPlayerRepository,
        guestTeamRepository: guestTeamRepository,
        teamRepository: teamRepository,
      );
      now = DateTime(2026, 4, 15, 12);

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
      await guestPlayerRepository.createGuestPlayer(
        GuestPlayer(
          id: 'guest-player-1',
          displayName: 'Mahmoud Ali',
          normalizedName: 'mahmoud ali',
          teamId: 'team-1',
          createdBy: 'owner-1',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await guestTeamRepository.createGuestTeam(
        GuestTeam(
          id: 'guest-team-1',
          name: 'El Mal3ab Guests',
          normalizedName: 'el mal3ab guests',
          creatorId: 'organizer-1',
          tournamentIds: const ['tournament-1'],
          createdAt: now,
          updatedAt: now,
        ),
      );
    });

    test(
      'creates a guest player claim link and marks player as invited',
      () async {
        final generated = await service.createGuestPlayerClaimLink(
          guestPlayerId: 'guest-player-1',
          actorId: 'owner-1',
        );

        final updatedGuest = await guestPlayerRepository.getGuestPlayer(
          'guest-player-1',
        );
        final claimCode = await claimCodeRepository.getClaimCode(
          generated.claimCode.code,
        );

        expect(generated.claimCode.targetType, ClaimTargetType.guestPlayer);
        expect(generated.payload.scope, ClaimPayloadScope.team);
        expect(generated.appUri.scheme, ShareLinkService.appScheme);
        expect(generated.webUri.host, ShareLinkService.webHost);
        expect(generated.qrData, generated.webUri.toString());
        expect(generated.payload.subjectName, isNull);
        expect(
          generated.appUri.queryParameters.containsKey('subjectName'),
          isFalse,
        );
        expect(
          generated.webUri.queryParameters.containsKey('subjectName'),
          isFalse,
        );
        expect(updatedGuest?.claimStatus, GuestClaimStatus.invited);
        expect(updatedGuest?.claimCode, generated.claimCode.code);
        expect(claimCode?.status, ClaimCodeStatus.active);
      },
    );

    test(
      'reuses the active guest player claim link instead of minting a new code',
      () async {
        final first = await service.createGuestPlayerClaimLink(
          guestPlayerId: 'guest-player-1',
          actorId: 'owner-1',
        );
        final second = await service.createGuestPlayerClaimLink(
          guestPlayerId: 'guest-player-1',
          actorId: 'owner-1',
        );

        expect(second.claimCode.code, first.claimCode.code);
        expect(second.payload.code, first.payload.code);
      },
    );

    test(
      'scopes guest player claim link reuse to the requesting actor',
      () async {
        final ownerLink = await service.createGuestPlayerClaimLink(
          guestPlayerId: 'guest-player-1',
          actorId: 'owner-1',
        );
        final viceLink = await service.createGuestPlayerClaimLink(
          guestPlayerId: 'guest-player-1',
          actorId: 'vice-1',
        );

        expect(viceLink.claimCode.code, isNot(ownerLink.claimCode.code));
        expect(viceLink.claimCode.createdBy, 'vice-1');
        expect(viceLink.claimCode.targetId, ownerLink.claimCode.targetId);
        expect(viceLink.claimCode.status, ClaimCodeStatus.active);
      },
    );

    test(
      'rejects a guest player claim URL request from an unauthorized actor',
      () async {
        await expectLater(
          () => service.createGuestPlayerClaimUrl(
            guestPlayerId: 'guest-player-1',
            actorId: 'outsider-1',
          ),
          throwsA(
            isA<Exception>().having(
              (error) => error.toString(),
              'message',
              contains('لا تملك صلاحية'),
            ),
          ),
        );
      },
    );

    test(
      'creates a guest team claim link and persists invited state',
      () async {
        final generated = await service.createGuestTeamClaimLink(
          guestTeamId: 'guest-team-1',
          actorId: 'organizer-1',
        );

        final updatedGuestTeam = await guestTeamRepository.getGuestTeam(
          'guest-team-1',
        );

        expect(generated.claimCode.targetType, ClaimTargetType.guestTeam);
        expect(generated.claimCode.requiresApproval, isTrue);
        expect(updatedGuestTeam?.claimStatus, GuestClaimStatus.invited);
        expect(updatedGuestTeam?.claimCode, generated.claimCode.code);
      },
    );

    test('creates a team invite link with a round-trippable payload', () async {
      final generated = await service.createTeamInviteLink(
        teamId: 'team-1',
        actorId: 'vice-1',
        tournamentId: 'tournament-1',
      );

      final parsed = service.parsePayloadFromUri(generated.webUri);

      expect(generated.claimCode.targetType, ClaimTargetType.teamInvite);
      expect(parsed.code, generated.claimCode.code);
      expect(parsed.targetType, ClaimTargetType.teamInvite);
      expect(parsed.teamId, 'team-1');
      expect(parsed.tournamentId, 'tournament-1');
      expect(parsed.status, ClaimCodeStatus.active);
    });
  });
}
