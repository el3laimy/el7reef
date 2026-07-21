import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/services/guest_player_claim_link_issuer.dart';
import 'package:el7reef/domain/entities/share_payload.dart';
import 'package:el7reef/features/shareables/services/guest_mvp_claim_link_service.dart';

void main() {
  test('attaches an attributed claim URL only for a guest MVP', () async {
    final issuer = _FakeClaimLinkIssuer();
    final service = GuestMvpClaimLinkService(claimLinkIssuer: issuer);
    final payload = _guestMvpPayload();

    final enriched = await service.attachClaimUrl(
      payload: payload,
      actorId: 'organizer-1',
    );

    expect(issuer.calls, 1);
    expect(issuer.guestPlayerId, 'guest-1');
    expect(issuer.actorId, 'organizer-1');
    expect(enriched.claimUrl?.host, 'el7reef-app.web.app');
    expect(enriched.claimUrl?.queryParameters['code'], 'SAFE-CODE');
    expect(enriched.claimUrl?.queryParameters['shareCardType'], 'mvp');
    expect(enriched.claimUrl?.queryParameters['shareEntityId'], 'guest-1');
    expect(enriched.claimUrl?.queryParameters['shareMatchId'], 'match-1');
    expect(
      enriched.claimUrl?.queryParameters.containsKey('displayName'),
      isFalse,
    );
  });

  test('does not mint a claim URL for non-guest or anonymous shares', () async {
    final issuer = _FakeClaimLinkIssuer();
    final service = GuestMvpClaimLinkService(claimLinkIssuer: issuer);
    final playerPayload = SharePayload(
      cardType: ShareCardType.mvp,
      entityType: ShareEntityType.player,
      entityId: 'player-1',
      targetUrl: Uri.parse(
        'https://el7reef-app.web.app/player/player/player-1',
      ),
      campaignSource: 'mvp_card',
    );

    final unchangedPlayer = await service.attachClaimUrl(
      payload: playerPayload,
      actorId: 'organizer-1',
    );
    final unchangedAnonymous = await service.attachClaimUrl(
      payload: _guestMvpPayload(),
      actorId: null,
    );

    expect(issuer.calls, 0);
    expect(unchangedPlayer.claimUrl, isNull);
    expect(unchangedAnonymous.claimUrl, isNull);
  });

  test('attaches the same private claim flow to a guest goal card', () async {
    final issuer = _FakeClaimLinkIssuer();
    final service = GuestPrideClaimLinkService(claimLinkIssuer: issuer);
    final payload = SharePayload(
      cardType: ShareCardType.goalScorer,
      entityType: ShareEntityType.guestPlayer,
      entityId: 'guest-1',
      matchId: 'match-1',
      targetUrl: Uri.parse(
        'https://el7reef-app.web.app/player/guestPlayer/guest-1',
      ),
      campaignSource: 'goal_scorer_card',
    );

    final enriched = await service.attachClaimUrl(
      payload: payload,
      actorId: 'organizer-1',
    );

    expect(issuer.calls, 1);
    expect(enriched.claimUrl?.queryParameters['shareCardType'], 'goalScorer');
  });

  test('attaches the same private claim flow to a guest milestone', () async {
    final issuer = _FakeClaimLinkIssuer();
    final service = GuestPrideClaimLinkService(claimLinkIssuer: issuer);
    final payload = SharePayload(
      cardType: ShareCardType.playerMilestone,
      entityType: ShareEntityType.guestPlayer,
      entityId: 'guest-1',
      tournamentId: 'tournament-1',
      targetUrl: Uri.parse(
        'https://el7reef-app.web.app/player/guestPlayer/guest-1',
      ),
      campaignSource: 'player_milestone_card',
    );

    final enriched = await service.attachClaimUrl(
      payload: payload,
      actorId: 'organizer-1',
    );

    expect(issuer.calls, 1);
    expect(
      enriched.claimUrl?.queryParameters['shareCardType'],
      'playerMilestone',
    );
    expect(enriched.claimUrl?.queryParameters['shareEntityId'], 'guest-1');
  });
}

SharePayload _guestMvpPayload() {
  return SharePayload(
    cardType: ShareCardType.mvp,
    entityType: ShareEntityType.guestPlayer,
    entityId: 'guest-1',
    tournamentId: 'tournament-1',
    matchId: 'match-1',
    targetUrl: Uri.parse(
      'https://el7reef-app.web.app/player/guestPlayer/guest-1',
    ),
    campaignSource: 'mvp_card',
  );
}

class _FakeClaimLinkIssuer implements GuestPlayerClaimLinkIssuer {
  int calls = 0;
  String? guestPlayerId;
  String? actorId;

  @override
  Future<Uri> createGuestPlayerClaimUrl({
    required String guestPlayerId,
    required String actorId,
    Duration ttl = const Duration(days: 7),
    bool requiresApproval = false,
  }) async {
    calls += 1;
    this.guestPlayerId = guestPlayerId;
    this.actorId = actorId;
    return Uri.parse(
      'https://el7reef-app.web.app/claim?code=SAFE-CODE&type=guestPlayer&targetId=guest-1',
    );
  }
}
