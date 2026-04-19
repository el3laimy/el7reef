import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/constants/firebase_paths.dart';
import 'package:el7reef/core/services/analytics_service.dart';

void main() {
  group('AnalyticsService', () {
    test('persists measurable analytics events when firestore is available',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = AnalyticsService(firestore: firestore);

      service.trackInviteSent(
        type: 'team_invite',
        targetId: 'team-1',
        actorId: 'owner-1',
      );

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final snapshot =
          await firestore.collection(FirebasePaths.analyticsEvents).get();

      expect(snapshot.docs, hasLength(1));
      expect(snapshot.docs.single.data()['eventName'], 'invite_sent');
      expect(snapshot.docs.single.data()['actorId'], 'owner-1');
      expect(
        (snapshot.docs.single.data()['parameters'] as Map<String, dynamic>)['targetId'],
        'team-1',
      );
    });
  });
}
