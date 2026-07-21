import 'package:el7reef/core/constants/firebase_paths.dart';
import 'package:el7reef/core/services/pending_pride_events_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'drops invalid cached participant refs without inventing a player',
    () async {
      final firestore = FakeFirebaseFirestore();
      const matchId = 'match-1';
      await firestore
          .collection(FirebasePaths.matches)
          .doc(matchId)
          .collection(PendingPrideEventsService.collectionName)
          .doc(PendingPrideEventsService.currentDocumentId)
          .set({
            'version': 1,
            'matchId': matchId,
            'scoreTeamA': 1,
            'scoreTeamB': 0,
            'goals': [
              {
                'sideKey': 'A',
                'actor': {
                  'kind': 'unknown',
                  'id': 'player-1',
                  'displayName': 'Legacy',
                },
                'goals': 1,
              },
            ],
            'mvp': {
              'sideKey': 'A',
              'actor': {
                'kind': 'unknown',
                'id': 'player-1',
                'displayName': 'Legacy',
              },
            },
            'createdBy': 'organizer-1',
            'createdAt': DateTime(2026, 7, 13).millisecondsSinceEpoch,
          });

      final payload = await PendingPrideEventsService(
        firestore: firestore,
      ).loadPayload(matchId);

      expect(payload, isNotNull);
      expect(payload?.goals, isEmpty);
      expect(payload?.mvp, isNull);
    },
  );
}
