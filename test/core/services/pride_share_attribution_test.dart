import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/services/pride_share_attribution.dart';
import 'package:el7reef/domain/entities/share_payload.dart';

void main() {
  test('prefers the Claim URL and appends safe attribution without PII', () {
    final payload =
        SharePayload(
          cardType: ShareCardType.mvp,
          entityType: ShareEntityType.guestPlayer,
          entityId: 'guest-1',
          tournamentId: 'tournament-1',
          matchId: 'match-1',
          targetUrl: Uri.parse(
            'https://el7reef-app.web.app/player/guestPlayer/guest-1',
          ),
          campaignSource: 'mvp_card',
        ).withClaimUrl(
          Uri.parse(
            'https://el7reef-app.web.app/claim?code=SAFE-CODE&type=guestPlayer&targetId=guest-1',
          ),
        );
    final claimUrl = PrideShareAttribution.attributedPublicUri(payload);

    expect(claimUrl.path, '/claim');
    expect(claimUrl.queryParameters['code'], 'SAFE-CODE');
    expect(claimUrl.queryParameters['shareCardType'], 'mvp');
    expect(claimUrl.queryParameters['shareEntityId'], 'guest-1');

    final restored = PrideShareAttribution.fromQueryParameters(
      claimUrl.queryParameters,
      targetUrl: Uri.parse('https://el7reef-app.web.app/claim'),
    );

    expect(restored?.analyticsParameters, payload.analyticsParameters);
    expect(claimUrl.queryParameters.containsKey('displayName'), isFalse);
    expect(claimUrl.queryParameters.containsKey('phone'), isFalse);
    expect(restored?.analyticsParameters.containsKey('claimUrl'), isFalse);
  });

  test('rejects partial or malformed attribution without blocking Claim', () {
    expect(
      PrideShareAttribution.fromQueryParameters(const {
        'shareCardType': 'mvp',
      }, targetUrl: Uri.parse('https://el7reef-app.web.app/claim')),
      isNull,
    );
    expect(
      PrideShareAttribution.fromQueryParameters(const {
        'shareCardType': 'mvp',
        'shareEntityType': 'guestPlayer',
        'shareEntityId': 'guest-1',
        'shareCampaignSource': 'UPPERCASE',
        'shareSchemaVersion': '1',
      }, targetUrl: Uri.parse('https://el7reef-app.web.app/claim')),
      isNull,
    );
  });
}
