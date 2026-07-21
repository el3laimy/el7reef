import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/enums/match_status.dart';
import 'package:el7reef/core/services/cloud_sensitive_ops_service.dart';
import 'package:el7reef/core/services/match_settlement_service.dart';
import 'package:el7reef/domain/entities/participant_ref.dart';
import 'package:el7reef/domain/entities/player_match_stats.dart';

void main() {
  group('MatchSettlementService remote operations', () {
    test(
      'submitScore uses callable settlement result before local writes',
      () async {
        final firestore = FakeFirebaseFirestore();
        final cloudOps = _FakeCloudSensitiveOpsService(
          submitResponse: const <String, dynamic>{
            'status': 'completed',
            'ratingsApplied': false,
            'alreadySettled': false,
          },
        );
        final service = MatchSettlementService(
          firestore: firestore,
          cloudSensitiveOps: cloudOps,
        );

        final result = await service.submitScore(
          matchId: 'match-1',
          actorId: 'organizer-1',
          scoreA: 3,
          scoreB: 2,
          mvpPlayerId: 'guest-9',
          detailedStats: const <PlayerMatchStats>[
            PlayerMatchStats(
              playerId: 'player-1',
              matchId: 'match-1',
              teamId: 'team-1',
              goals: 2,
            ),
          ],
          goalDrafts: const <MatchSettlementGoalDraft>[
            MatchSettlementGoalDraft(
              sideKey: 'A',
              actor: ParticipantRef(
                kind: ParticipantRefKind.guestPlayer,
                id: 'guest-9',
                displayName: 'ضيف هداف',
              ),
              goals: 1,
            ),
          ],
          mvpDraft: const MatchSettlementMvpDraft(
            sideKey: 'A',
            actor: ParticipantRef(
              kind: ParticipantRefKind.guestPlayer,
              id: 'guest-9',
              displayName: 'ضيف هداف',
            ),
          ),
        );

        expect(result.status, MatchStatus.completed);
        expect(cloudOps.submitCalls, 1);
        expect(cloudOps.approveCalls, 0);
        expect(cloudOps.lastSubmitPayload?['matchId'], 'match-1');
        expect(cloudOps.lastSubmitPayload?['scoreA'], 3);
        expect(cloudOps.lastSubmitPayload?['scoreB'], 2);
        expect(cloudOps.lastSubmitPayload?['mvpPlayerId'], 'guest-9');
        expect(cloudOps.lastSubmitPayload?['detailedStats'], hasLength(1));
        expect(cloudOps.lastSubmitPayload?['goals'], hasLength(1));
        expect(cloudOps.lastSubmitPayload?['mvp'], isA<Map<String, dynamic>>());

        final localMatch = await firestore
            .collection('matches')
            .doc('match-1')
            .get();
        expect(localMatch.exists, isFalse);
      },
    );

    test(
      'approveScore uses callable approval result before local writes',
      () async {
        final firestore = FakeFirebaseFirestore();
        final cloudOps = _FakeCloudSensitiveOpsService(
          approveResponse: const <String, dynamic>{
            'status': 'settled',
            'ratingsApplied': true,
            'alreadySettled': false,
          },
        );
        final service = MatchSettlementService(
          firestore: firestore,
          cloudSensitiveOps: cloudOps,
        );

        final result = await service.approveScore(
          matchId: 'match-1',
          actorId: 'organizer-1',
        );

        expect(result.status, MatchStatus.settled);
        expect(result.ratingsApplied, isTrue);
        expect(cloudOps.submitCalls, 0);
        expect(cloudOps.approveCalls, 1);
        expect(cloudOps.lastApprovePayload?['matchId'], 'match-1');

        final localMatch = await firestore
            .collection('matches')
            .doc('match-1')
            .get();
        expect(localMatch.exists, isFalse);
      },
    );

    test(
      'submitScore fails clearly when callable is unavailable without fallback',
      () {
        final service = MatchSettlementService(
          firestore: FakeFirebaseFirestore(),
          cloudSensitiveOps: _FakeCloudSensitiveOpsService(),
        );

        expect(
          service.submitScore(
            matchId: 'match-1',
            actorId: 'organizer-1',
            scoreA: 1,
            scoreB: 0,
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('خادم نتائج المباراة'),
            ),
          ),
        );
      },
    );

    test(
      'submitScore rejects attributed goals above either side score before callable',
      () async {
        for (final testCase in <({String sideKey, int scoreA, int scoreB})>[
          (sideKey: 'A', scoreA: 1, scoreB: 3),
          (sideKey: 'B', scoreA: 3, scoreB: 1),
        ]) {
          final cloudOps = _FakeCloudSensitiveOpsService(
            submitResponse: const <String, dynamic>{'status': 'completed'},
          );
          final service = MatchSettlementService(
            firestore: FakeFirebaseFirestore(),
            cloudSensitiveOps: cloudOps,
          );

          await expectLater(
            service.submitScore(
              matchId: 'match-1',
              actorId: 'organizer-1',
              scoreA: testCase.scoreA,
              scoreB: testCase.scoreB,
              goalDrafts: <MatchSettlementGoalDraft>[
                MatchSettlementGoalDraft(
                  sideKey: testCase.sideKey,
                  actor: const ParticipantRef(
                    kind: ParticipantRefKind.player,
                    id: 'player-1',
                    displayName: 'Player One',
                  ),
                  goals: 2,
                ),
              ],
            ),
            throwsA(
              isA<StateError>().having(
                (error) => error.message,
                'message',
                contains('الأهداف المنسوبة'),
              ),
            ),
          );
          expect(cloudOps.submitCalls, 0);
        }
      },
    );

    for (final testCase in <({String label, Map<String, dynamic> response})>[
      (
        label: 'missing status',
        response: const <String, dynamic>{'ratingsApplied': false},
      ),
      (
        label: 'unknown status',
        response: const <String, dynamic>{'status': 'unexpected'},
      ),
    ]) {
      test(
        'submitScore rejects a non-empty callable response with ${testCase.label}',
        () async {
          final firestore = FakeFirebaseFirestore();
          final cloudOps = _FakeCloudSensitiveOpsService(
            submitResponse: testCase.response,
          );
          final service = MatchSettlementService(
            firestore: firestore,
            cloudSensitiveOps: cloudOps,
          );

          await expectLater(
            service.submitScore(
              matchId: 'match-1',
              actorId: 'organizer-1',
              scoreA: 1,
              scoreB: 0,
            ),
            throwsA(
              isA<StateError>().having(
                (error) => error.message,
                'message',
                contains('استجابة خادم نتائج المباراة'),
              ),
            ),
          );
          expect(cloudOps.submitCalls, 1);
          expect(
            (await firestore.collection('matches').doc('match-1').get()).exists,
            isFalse,
          );
        },
      );
    }
  });
}

class _FakeCloudSensitiveOpsService extends CloudSensitiveOpsService {
  _FakeCloudSensitiveOpsService({this.submitResponse, this.approveResponse});

  final Map<String, dynamic>? submitResponse;
  final Map<String, dynamic>? approveResponse;
  int submitCalls = 0;
  int approveCalls = 0;
  Map<String, dynamic>? lastSubmitPayload;
  Map<String, dynamic>? lastApprovePayload;

  @override
  Future<Map<String, dynamic>?> submitMatchSettlement(
    Map<String, dynamic> payload,
  ) async {
    submitCalls += 1;
    lastSubmitPayload = payload;
    return submitResponse;
  }

  @override
  Future<Map<String, dynamic>?> approveMatchScore(
    Map<String, dynamic> payload,
  ) async {
    approveCalls += 1;
    lastApprovePayload = payload;
    return approveResponse;
  }
}
