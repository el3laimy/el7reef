import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/domain/entities/share_payload.dart';

void main() {
  group('SharePayload', () {
    test('round-trips the versioned minimum contract without PII fields', () {
      final payload = SharePayload(
        cardType: ShareCardType.mvp,
        entityType: ShareEntityType.guestPlayer,
        entityId: 'guest-player-42',
        tournamentId: 'tournament-9',
        matchId: 'match-7',
        targetUrl: Uri.parse('https://el7reef-app.web.app/matches/match-7'),
        campaignSource: 'post_match_mvp',
        claimUrl: Uri.parse('https://el7reef-app.web.app/claim?code=SAFE-CODE'),
      );

      final encoded = payload.toJson();
      final restored = SharePayload.fromJson(encoded);

      expect(
        encoded.keys,
        containsAll(<String>[
          'cardType',
          'entityType',
          'entityId',
          'tournamentId',
          'matchId',
          'targetUrl',
          'campaignSource',
          'claimUrl',
          'schemaVersion',
        ]),
      );
      expect(encoded.keys, isNot(contains('displayName')));
      expect(encoded.keys, isNot(contains('phone')));
      expect(encoded.keys, isNot(contains('photoUrl')));
      expect(payload.analyticsParameters.keys, isNot(contains('targetUrl')));
      expect(payload.analyticsParameters.keys, isNot(contains('claimUrl')));
      expect(restored.toJson(), encoded);
    });

    test(
      'omits optional identifiers and claim URL from serialized payloads',
      () {
        final encoded = SharePayload(
          cardType: ShareCardType.matchResult,
          entityType: ShareEntityType.match,
          entityId: 'match-7',
          targetUrl: Uri.parse('https://el7reef-app.web.app/matches/match-7'),
          campaignSource: 'match_result_card',
        ).toJson();

        expect(encoded.containsKey('tournamentId'), isFalse);
        expect(encoded.containsKey('matchId'), isFalse);
        expect(encoded.containsKey('claimUrl'), isFalse);
      },
    );

    test('requires absolute HTTPS URLs without PII query parameters', () {
      expect(
        () => SharePayload(
          cardType: ShareCardType.player,
          entityType: ShareEntityType.player,
          entityId: 'player-1',
          targetUrl: Uri.parse('el7reef://player/player-1'),
          campaignSource: 'player_card',
        ),
        throwsArgumentError,
      );
      expect(
        () => SharePayload(
          cardType: ShareCardType.mvp,
          entityType: ShareEntityType.guestPlayer,
          entityId: 'guest-player-1',
          targetUrl: Uri.parse(
            'https://el7reef-app.web.app/players/guest-player-1',
          ),
          claimUrl: Uri.parse(
            'https://el7reef-app.web.app/claim?subjectName=Guest',
          ),
          campaignSource: 'post_match_mvp',
        ),
        throwsArgumentError,
      );
    });

    test('rejects unexpected PII fields', () {
      final encoded = <String, dynamic>{
        'cardType': 'mvp',
        'entityType': 'guestPlayer',
        'entityId': 'guest-player-42',
        'targetUrl': 'https://el7reef-app.web.app/matches/match-7',
        'campaignSource': 'post_match_mvp',
        'schemaVersion': SharePayload.currentSchemaVersion,
        'displayName': 'لاعب زائر',
      };

      expect(() => SharePayload.fromJson(encoded), throwsFormatException);
    });

    test('rejects unsupported schema versions', () {
      final encoded = <String, dynamic>{
        'cardType': 'mvp',
        'entityType': 'guestPlayer',
        'entityId': 'guest-player-42',
        'targetUrl': 'https://el7reef-app.web.app/matches/match-7',
        'campaignSource': 'post_match_mvp',
        'schemaVersion': SharePayload.currentSchemaVersion + 1,
      };

      expect(() => SharePayload.fromJson(encoded), throwsUnsupportedError);
    });
  });
}
