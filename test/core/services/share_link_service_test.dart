import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/constants/firebase_paths.dart';
import 'package:el7reef/core/enums/claim_code_status.dart';
import 'package:el7reef/core/enums/claim_payload_scope.dart';
import 'package:el7reef/core/enums/claim_target_type.dart';
import 'package:el7reef/core/enums/guest_claim_status.dart';
import 'package:el7reef/core/services/cloud_sensitive_ops_service.dart';
import 'package:el7reef/core/services/share_link_service.dart';
import 'package:el7reef/data/repositories/claim_code_repository_impl.dart';
import 'package:el7reef/data/repositories/guest_player_repository_impl.dart';
import 'package:el7reef/data/repositories/guest_team_repository_impl.dart';
import 'package:el7reef/data/repositories/team_repository_impl.dart';
import 'package:el7reef/domain/entities/guest_player.dart';
import 'package:el7reef/domain/entities/guest_team.dart';
import 'package:el7reef/domain/entities/team.dart';

void main() {
  group('ShareLinkService trusted guest issuance', () {
    late FakeFirebaseFirestore firestore;
    late ClaimCodeRepositoryImpl claimCodeRepository;
    late GuestPlayerRepositoryImpl guestPlayerRepository;
    late GuestTeamRepositoryImpl guestTeamRepository;
    late TeamRepositoryImpl teamRepository;
    late _FakeCloudSensitiveOpsService cloudOps;
    late ShareLinkService service;
    late DateTime now;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      claimCodeRepository = ClaimCodeRepositoryImpl(firestore: firestore);
      guestPlayerRepository = GuestPlayerRepositoryImpl(firestore: firestore);
      guestTeamRepository = GuestTeamRepositoryImpl(firestore: firestore);
      teamRepository = TeamRepositoryImpl(firestore: firestore);
      cloudOps = _FakeCloudSensitiveOpsService();
      service = ShareLinkService(
        claimCodeRepository: claimCodeRepository,
        guestPlayerRepository: guestPlayerRepository,
        guestTeamRepository: guestTeamRepository,
        teamRepository: teamRepository,
        cloudOps: cloudOps,
      );
      now = DateTime(2026, 8, 2, 12);

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
      'guest player issuance uses callable and leaves no bearer token in Firestore',
      () async {
        const rawCode = 'PLAYER-RAW-BEARER';
        cloudOps.issueResponse = _issueResponse(
          code: rawCode,
          targetType: ClaimTargetType.guestPlayer,
          targetId: 'guest-player-1',
          scope: ClaimPayloadScope.team,
          teamId: 'team-1',
          requiresApproval: false,
        );

        final generated = await service.createGuestPlayerClaimLink(
          guestPlayerId: 'guest-player-1',
          actorId: 'owner-1',
        );

        final guestDocument = await firestore
            .collection(FirebasePaths.guestPlayers)
            .doc('guest-player-1')
            .get();
        final claimDocuments = await firestore
            .collection(FirebasePaths.claimCodes)
            .get();

        expect(cloudOps.issueCalls, hasLength(1));
        expect(cloudOps.issueCalls.single.targetType, 'guestPlayer');
        expect(cloudOps.issueCalls.single.targetId, 'guest-player-1');
        expect(cloudOps.issueCalls.single.requiresApproval, isFalse);
        expect(
          cloudOps.issueCalls.single.ttlMs,
          const Duration(days: 7).inMilliseconds,
        );
        expect(cloudOps.issueCalls.single.requestId, isNotEmpty);
        expect(generated.claimCode.code, rawCode);
        expect(generated.payload.scope, ClaimPayloadScope.team);
        expect(generated.webUri.queryParameters['code'], rawCode);
        expect(
          generated.webUri.queryParameters.containsKey('subjectName'),
          isFalse,
        );
        expect(claimDocuments.docs, isEmpty);
        expect(
          guestDocument.data()?['claimStatus'],
          GuestClaimStatus.guest.name,
        );
        expect(guestDocument.data()?['claimCode'], isNull);
        expect(guestDocument.data().toString(), isNot(contains(rawCode)));
      },
    );

    test(
      'guest team issuance uses callable and leaves no bearer token in Firestore',
      () async {
        const rawCode = 'TEAM-RAW-BEARER';
        cloudOps.issueResponse = _issueResponse(
          code: rawCode,
          targetType: ClaimTargetType.guestTeam,
          targetId: 'guest-team-1',
          scope: ClaimPayloadScope.tournament,
          tournamentId: 'tournament-1',
          requiresApproval: true,
        );

        final generated = await service.createGuestTeamClaimLink(
          guestTeamId: 'guest-team-1',
          actorId: 'organizer-1',
        );

        final guestDocument = await firestore
            .collection(FirebasePaths.guestTeams)
            .doc('guest-team-1')
            .get();
        final claimDocuments = await firestore
            .collection(FirebasePaths.claimCodes)
            .get();

        expect(cloudOps.issueCalls, hasLength(1));
        expect(cloudOps.issueCalls.single.targetType, 'guestTeam');
        expect(cloudOps.issueCalls.single.targetId, 'guest-team-1');
        expect(cloudOps.issueCalls.single.requiresApproval, isTrue);
        expect(generated.claimCode.code, rawCode);
        expect(generated.claimCode.requiresApproval, isTrue);
        expect(generated.payload.tournamentId, 'tournament-1');
        expect(claimDocuments.docs, isEmpty);
        expect(
          guestDocument.data()?['claimStatus'],
          GuestClaimStatus.guest.name,
        );
        expect(guestDocument.data()?['claimCode'], isNull);
        expect(guestDocument.data().toString(), isNot(contains(rawCode)));
      },
    );

    test(
      'mismatched callable issuance response is rejected without writes',
      () async {
        cloudOps.issueResponse = _issueResponse(
          code: 'MISMATCHED-BEARER',
          targetType: ClaimTargetType.guestPlayer,
          targetId: 'different-guest-player',
          scope: ClaimPayloadScope.team,
          teamId: 'team-1',
          requiresApproval: false,
        );

        await expectLater(
          () => service.createGuestPlayerClaimLink(
            guestPlayerId: 'guest-player-1',
            actorId: 'owner-1',
          ),
          throwsA(isA<FormatException>()),
        );

        final guestDocument = await firestore
            .collection(FirebasePaths.guestPlayers)
            .doc('guest-player-1')
            .get();
        final claimDocuments = await firestore
            .collection(FirebasePaths.claimCodes)
            .get();
        expect(claimDocuments.docs, isEmpty);
        expect(guestDocument.data()?['claimCode'], isNull);
      },
    );

    test('callable issuance failure is closed without local minting', () async {
      cloudOps.issueError = StateError('callable unavailable');

      await expectLater(
        () => service.createGuestPlayerClaimLink(
          guestPlayerId: 'guest-player-1',
          actorId: 'owner-1',
        ),
        throwsA(isA<StateError>()),
      );

      final guestDocument = await firestore
          .collection(FirebasePaths.guestPlayers)
          .doc('guest-player-1')
          .get();
      final claimDocuments = await firestore
          .collection(FirebasePaths.claimCodes)
          .get();
      expect(cloudOps.issueCalls, hasLength(1));
      expect(claimDocuments.docs, isEmpty);
      expect(guestDocument.data()?['claimCode'], isNull);
    });

    test('guest issuer authorization is delegated to the callable', () async {
      cloudOps.issueError = StateError('permission denied by callable');

      await expectLater(
        () => service.createGuestPlayerClaimLink(
          guestPlayerId: 'guest-player-1',
          actorId: 'outsider-1',
        ),
        throwsA(isA<StateError>()),
      );

      expect(cloudOps.issueCalls, hasLength(1));
      expect(cloudOps.issueCalls.single.targetId, 'guest-player-1');
    });

    test('team invite keeps its Firestore-backed V1 contract', () async {
      final generated = await service.createTeamInviteLink(
        teamId: 'team-1',
        actorId: 'vice-1',
        tournamentId: 'tournament-1',
      );

      final parsed = service.parsePayloadFromUri(generated.webUri);
      final persisted = await claimCodeRepository.getClaimCode(
        generated.claimCode.code,
      );

      expect(cloudOps.issueCalls, isEmpty);
      expect(generated.claimCode.targetType, ClaimTargetType.teamInvite);
      expect(parsed.code, generated.claimCode.code);
      expect(parsed.targetType, ClaimTargetType.teamInvite);
      expect(parsed.teamId, 'team-1');
      expect(parsed.tournamentId, 'tournament-1');
      expect(parsed.status, ClaimCodeStatus.active);
      expect(persisted?.code, generated.claimCode.code);
      expect(persisted?.targetType, ClaimTargetType.teamInvite);
    });
  });
}

Map<String, dynamic> _issueResponse({
  required String code,
  required ClaimTargetType targetType,
  required String targetId,
  required ClaimPayloadScope scope,
  String? teamId,
  String? tournamentId,
  required bool requiresApproval,
}) {
  return {
    'code': code,
    'targetType': targetType.name,
    'targetId': targetId,
    'scope': scope.name,
    'teamId': teamId,
    'tournamentId': tournamentId,
    'requiresApproval': requiresApproval,
    'status': ClaimCodeStatus.active.name,
    'expiresAt': DateTime(2026, 8, 9, 12).millisecondsSinceEpoch,
    'reused': false,
  };
}

class _IssueCall {
  final String targetType;
  final String targetId;
  final String requestId;
  final int ttlMs;
  final bool requiresApproval;

  const _IssueCall({
    required this.targetType,
    required this.targetId,
    required this.requestId,
    required this.ttlMs,
    required this.requiresApproval,
  });
}

class _FakeCloudSensitiveOpsService extends CloudSensitiveOpsService {
  Map<String, dynamic> issueResponse = const {};
  Object? issueError;
  final List<_IssueCall> issueCalls = [];

  @override
  Future<Map<String, dynamic>> issueGuestClaimCode({
    required String targetType,
    required String targetId,
    required String requestId,
    required int ttlMs,
    required bool requiresApproval,
  }) async {
    issueCalls.add(
      _IssueCall(
        targetType: targetType,
        targetId: targetId,
        requestId: requestId,
        ttlMs: ttlMs,
        requiresApproval: requiresApproval,
      ),
    );
    if (issueError case final Object error) throw error;
    return Map<String, dynamic>.from(issueResponse);
  }
}
