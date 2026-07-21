import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/constants/firebase_paths.dart';
import 'package:el7reef/core/services/analytics_service.dart';
import 'package:el7reef/domain/entities/share_payload.dart';

void main() {
  group('AnalyticsService', () {
    test(
      'persists measurable analytics events when firestore is available',
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

        final snapshot = await firestore
            .collection(FirebasePaths.analyticsEvents)
            .get();

        expect(snapshot.docs, hasLength(1));
        expect(snapshot.docs.single.data()['eventName'], 'invite_sent');
        expect(snapshot.docs.single.data()['actorId'], 'owner-1');
        expect(
          (snapshot.docs.single.data()['parameters']
              as Map<String, dynamic>)['targetId'],
          'team-1',
        );
      },
    );

    test('persists the privacy-safe pride funnel event contract', () async {
      final firestore = FakeFirebaseFirestore();
      final service = AnalyticsService(firestore: firestore);
      final payload = SharePayload(
        cardType: ShareCardType.mvp,
        entityType: ShareEntityType.guestPlayer,
        entityId: 'guest-player-1',
        tournamentId: 'tournament-1',
        matchId: 'match-1',
        targetUrl: Uri.parse('https://el7reef-app.web.app/matches/match-1'),
        claimUrl: Uri.parse('https://el7reef-app.web.app/claim?code=SAFE-CODE'),
        campaignSource: 'post_match_mvp',
      );

      service
        ..trackPrideCardViewed(payload)
        ..trackShareStarted(payload)
        ..trackShareSheetReturned(payload)
        ..trackShareLinkOpened(payload)
        ..trackClaimStartedFromCard(payload)
        ..trackClaimCompletedFromCard(payload);
      await _flushAnalyticsWrites();

      final snapshot = await firestore
          .collection(FirebasePaths.analyticsEvents)
          .get();
      final eventNames = snapshot.docs
          .map((document) => document.data()['eventName'])
          .toSet();

      expect(snapshot.docs, hasLength(6));
      expect(eventNames, <String>{
        AnalyticsService.prideCardViewedEvent,
        AnalyticsService.shareStartedEvent,
        AnalyticsService.shareSheetReturnedEvent,
        AnalyticsService.shareLinkOpenedEvent,
        AnalyticsService.claimStartedFromCardEvent,
        AnalyticsService.claimCompletedFromCardEvent,
      });
      for (final document in snapshot.docs) {
        final data = document.data();
        final parameters = data['parameters'] as Map<String, dynamic>;
        expect(data.containsKey('actorId'), isFalse);
        expect(parameters['cardType'], 'mvp');
        expect(parameters['entityType'], 'guestPlayer');
        expect(parameters['entityId'], 'guest-player-1');
        expect(parameters.containsKey('targetUrl'), isFalse);
        expect(parameters.containsKey('claimUrl'), isFalse);
      }
    });
  });
}

Future<void> _flushAnalyticsWrites() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
