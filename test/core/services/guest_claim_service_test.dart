import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/enums/claim_code_status.dart';
import 'package:el7reef/core/enums/claim_merge_conflict_type.dart';
import 'package:el7reef/core/enums/claim_payload_scope.dart';
import 'package:el7reef/core/enums/claim_target_type.dart';
import 'package:el7reef/core/services/cloud_sensitive_ops_service.dart';
import 'package:el7reef/core/services/guest_claim_service.dart';

void main() {
  group('GuestClaimService callable contract', () {
    late _FakeCloudSensitiveOpsService cloudOps;
    late GuestClaimService service;

    setUp(() {
      cloudOps = _FakeCloudSensitiveOpsService();
      service = GuestClaimService(cloudOps: cloudOps);
    });

    test('inspection uses the server target instead of a route hint', () async {
      cloudOps.inspectResponse = {
        'targetType': 'guestTeam',
        'targetId': 'server-guest-team',
        'subjectName': 'نسور الحارة',
        'scope': 'tournament',
        'teamId': 'pending-team',
        'tournamentId': 'tournament-1',
        'requiresApproval': true,
        'pendingApproval': true,
        'canApprovePendingTeamClaim': true,
        'status': 'active',
        'expiresAt': 1785628800000,
      };

      final inspection = await service.inspectGuestClaim(
        claimCode: ' bearer-code ',
      );

      expect(cloudOps.inspectedClaimCodes, ['bearer-code']);
      expect(inspection.targetType, ClaimTargetType.guestTeam);
      expect(inspection.targetId, 'server-guest-team');
      expect(inspection.subjectName, 'نسور الحارة');
      expect(inspection.scope, ClaimPayloadScope.tournament);
      expect(inspection.teamId, 'pending-team');
      expect(inspection.tournamentId, 'tournament-1');
      expect(inspection.requiresApproval, isTrue);
      expect(inspection.pendingApproval, isTrue);
      expect(inspection.canApprovePendingTeamClaim, isTrue);
      expect(inspection.status, ClaimCodeStatus.active);
      expect(inspection.expiresAt.millisecondsSinceEpoch, 1785628800000);
    });

    final playerScenarios = <_PlayerScenario>[
      const _PlayerScenario(
        name: 'claimed player response maps roster changes',
        response: {
          'outcome': 'claimed',
          'guestPlayerId': 'guest-player-1',
          'playerId': 'player-1',
          'relinkedMembershipIds': ['membership-1'],
          'linkedTeamIds': ['team-1', 'team-1'],
          'syncedLegacyTeamIds': ['legacy-team-1'],
        },
        outcome: GuestPlayerClaimOutcome.claimed,
      ),
      const _PlayerScenario(
        name: 'already claimed player response remains idempotent',
        response: {
          'outcome': 'alreadyClaimed',
          'guestPlayerId': 'guest-player-1',
          'playerId': 'player-1',
          'relinkedMembershipIds': <String>[],
          'linkedTeamIds': ['team-1'],
          'syncedLegacyTeamIds': <String>[],
        },
        outcome: GuestPlayerClaimOutcome.alreadyClaimed,
      ),
      const _PlayerScenario(
        name: 'player conflict response maps its safe conflict details',
        response: {
          'outcome': 'conflict',
          'guestPlayerId': 'guest-player-1',
          'playerId': 'player-1',
          'relinkedMembershipIds': <String>[],
          'linkedTeamIds': <String>[],
          'syncedLegacyTeamIds': <String>[],
          'conflict': {
            'type': 'rosterAlreadyContainsPlayer',
            'conflictingEntityId': 'team-1',
          },
        },
        outcome: GuestPlayerClaimOutcome.conflict,
        conflictType: ClaimMergeConflictType.rosterAlreadyContainsPlayer,
      ),
    ];

    for (final scenario in playerScenarios) {
      test(scenario.name, () async {
        cloudOps.playerResponse = scenario.response;

        final result = await service.claimGuestPlayer(
          claimCode: 'player-bearer-code',
        );

        expect(cloudOps.playerClaimCodes, ['player-bearer-code']);
        expect(result.outcome, scenario.outcome);
        expect(result.claimCode, 'player-bearer-code');
        expect(result.guestPlayerId, 'guest-player-1');
        expect(result.playerId, 'player-1');
        expect(result.conflict?.type, scenario.conflictType);
        if (scenario.outcome == GuestPlayerClaimOutcome.claimed) {
          expect(result.relinkedMembershipIds, ['membership-1']);
          expect(result.linkedTeamIds, ['team-1']);
          expect(result.syncedLegacyTeamIds, ['legacy-team-1']);
        }
        if (scenario.outcome == GuestPlayerClaimOutcome.alreadyClaimed) {
          expect(result.isIdempotent, isTrue);
        }
        if (scenario.conflictType != null) {
          expect(result.hasConflict, isTrue);
          expect(result.conflict?.conflictingEntityId, 'team-1');
        }
      });
    }

    final teamScenarios = <_TeamScenario>[
      const _TeamScenario(
        name: 'claimed team response maps merged tournaments',
        response: {
          'outcome': 'claimed',
          'guestTeamId': 'guest-team-1',
          'teamId': 'team-1',
          'mergedTournamentIds': ['tournament-1', 'tournament-2'],
          'requestedByPlayerId': 'owner-1',
        },
        outcome: GuestTeamClaimOutcome.claimed,
      ),
      const _TeamScenario(
        name: 'already claimed team response remains idempotent',
        response: {
          'outcome': 'alreadyClaimed',
          'guestTeamId': 'guest-team-1',
          'teamId': 'team-1',
          'mergedTournamentIds': ['tournament-1'],
          'requestedByPlayerId': 'owner-1',
        },
        outcome: GuestTeamClaimOutcome.alreadyClaimed,
      ),
      const _TeamScenario(
        name: 'approval response keeps the pending requester',
        response: {
          'outcome': 'approvalRequired',
          'guestTeamId': 'guest-team-1',
          'teamId': 'team-1',
          'mergedTournamentIds': ['tournament-1'],
          'requestedByPlayerId': 'owner-1',
        },
        outcome: GuestTeamClaimOutcome.approvalRequired,
      ),
      const _TeamScenario(
        name: 'team conflict response maps the server conflict',
        response: {
          'outcome': 'conflict',
          'guestTeamId': 'guest-team-1',
          'teamId': 'team-1',
          'mergedTournamentIds': <String>[],
          'requestedByPlayerId': null,
          'conflict': {
            'type': 'pendingTargetLink',
            'conflictingEntityId': 'other-team',
          },
        },
        outcome: GuestTeamClaimOutcome.conflict,
        conflictType: ClaimMergeConflictType.pendingTargetLink,
      ),
    ];

    for (final scenario in teamScenarios) {
      test(scenario.name, () async {
        cloudOps.teamResponse = scenario.response;

        final result = await service.claimGuestTeam(
          claimCode: 'team-bearer-code',
          teamId: 'team-1',
        );

        expect(cloudOps.teamClaimCodes, ['team-bearer-code']);
        expect(cloudOps.teamIds, ['team-1']);
        expect(result.outcome, scenario.outcome);
        expect(result.claimCode, 'team-bearer-code');
        expect(result.guestTeamId, 'guest-team-1');
        expect(result.teamId, 'team-1');
        expect(result.conflict?.type, scenario.conflictType);
        if (scenario.outcome == GuestTeamClaimOutcome.claimed) {
          expect(result.mergedTournamentIds, ['tournament-1', 'tournament-2']);
        }
        if (scenario.outcome == GuestTeamClaimOutcome.alreadyClaimed) {
          expect(result.isIdempotent, isTrue);
        }
        if (scenario.outcome == GuestTeamClaimOutcome.approvalRequired) {
          expect(result.isPendingApproval, isTrue);
          expect(result.requestedByPlayerId, 'owner-1');
        }
        if (scenario.conflictType != null) {
          expect(result.hasConflict, isTrue);
          expect(result.conflict?.conflictingEntityId, 'other-team');
        }
      });
    }

    test(
      'expired callable outcomes are surfaced without a local retry',
      () async {
        cloudOps.playerResponse = {
          'outcome': 'expired',
          'targetType': 'guestPlayer',
          'targetId': 'guest-player-1',
        };
        cloudOps.teamResponse = {
          'outcome': 'expired',
          'targetType': 'guestTeam',
          'targetId': 'guest-team-1',
        };

        await expectLater(
          () => service.claimGuestPlayer(claimCode: 'expired-player-code'),
          throwsA(
            isA<Exception>().having(
              (error) => error.toString(),
              'message',
              contains('انتهت صلاحية رابط الاستلام.'),
            ),
          ),
        );
        await expectLater(
          () => service.claimGuestTeam(
            claimCode: 'expired-team-code',
            teamId: 'team-1',
          ),
          throwsA(
            isA<Exception>().having(
              (error) => error.toString(),
              'message',
              contains('انتهت صلاحية رابط استلام الفريق.'),
            ),
          ),
        );

        expect(cloudOps.playerClaimCodes, ['expired-player-code']);
        expect(cloudOps.teamClaimCodes, ['expired-team-code']);
      },
    );

    test('malformed inspection response is rejected', () async {
      cloudOps.inspectResponse = {
        'targetType': 'guestPlayer',
        'targetId': 'guest-player-1',
        'scope': 'not-a-scope',
        'requiresApproval': false,
        'pendingApproval': false,
        'canApprovePendingTeamClaim': false,
        'status': 'active',
        'expiresAt': 1785628800000,
      };

      await expectLater(
        () => service.inspectGuestClaim(claimCode: 'bad-inspection-code'),
        throwsA(isA<FormatException>()),
      );
    });

    test('malformed claim response is rejected', () async {
      cloudOps.playerResponse = {
        'outcome': 'claimed',
        'guestPlayerId': 'guest-player-1',
        'relinkedMembershipIds': <String>[],
        'linkedTeamIds': <String>[],
        'syncedLegacyTeamIds': <String>[],
      };

      await expectLater(
        () => service.claimGuestPlayer(claimCode: 'bad-player-response'),
        throwsA(isA<FormatException>()),
      );
    });

    test('callable failure is closed without a client fallback', () async {
      cloudOps.playerError = StateError('function unavailable');

      await expectLater(
        () => service.claimGuestPlayer(claimCode: 'unavailable-code'),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('خدمة الاستلام غير متاحة الآن'),
          ),
        ),
      );

      expect(cloudOps.playerClaimCodes, ['unavailable-code']);
    });
  });
}

class _PlayerScenario {
  final String name;
  final Map<String, dynamic> response;
  final GuestPlayerClaimOutcome outcome;
  final ClaimMergeConflictType? conflictType;

  const _PlayerScenario({
    required this.name,
    required this.response,
    required this.outcome,
    this.conflictType,
  });
}

class _TeamScenario {
  final String name;
  final Map<String, dynamic> response;
  final GuestTeamClaimOutcome outcome;
  final ClaimMergeConflictType? conflictType;

  const _TeamScenario({
    required this.name,
    required this.response,
    required this.outcome,
    this.conflictType,
  });
}

class _FakeCloudSensitiveOpsService extends CloudSensitiveOpsService {
  Map<String, dynamic> inspectResponse = const {};
  Map<String, dynamic> playerResponse = const {};
  Map<String, dynamic> teamResponse = const {};
  Object? inspectError;
  Object? playerError;
  Object? teamError;

  final List<String> inspectedClaimCodes = [];
  final List<String> playerClaimCodes = [];
  final List<String> teamClaimCodes = [];
  final List<String> teamIds = [];

  @override
  Future<Map<String, dynamic>> inspectGuestClaim({
    required String claimCode,
  }) async {
    inspectedClaimCodes.add(claimCode);
    if (inspectError case final Object error) throw error;
    return Map<String, dynamic>.from(inspectResponse);
  }

  @override
  Future<Map<String, dynamic>> claimGuestPlayer({
    required String claimCode,
  }) async {
    playerClaimCodes.add(claimCode);
    if (playerError case final Object error) throw error;
    return Map<String, dynamic>.from(playerResponse);
  }

  @override
  Future<Map<String, dynamic>> claimGuestTeam({
    required String claimCode,
    required String teamId,
  }) async {
    teamClaimCodes.add(claimCode);
    teamIds.add(teamId);
    if (teamError case final Object error) throw error;
    return Map<String, dynamic>.from(teamResponse);
  }
}
