import '../../../core/services/guest_player_claim_link_issuer.dart';
import '../../../core/services/pride_share_attribution.dart';
import '../../../domain/entities/share_payload.dart';

class GuestMvpClaimLinkService {
  static const claimableCardTypes = {
    ShareCardType.mvp,
    ShareCardType.goalScorer,
    ShareCardType.player,
    ShareCardType.playerMilestone,
  };

  final GuestPlayerClaimLinkIssuer _claimLinkIssuer;

  const GuestMvpClaimLinkService({
    required GuestPlayerClaimLinkIssuer claimLinkIssuer,
  }) : _claimLinkIssuer = claimLinkIssuer;

  Future<SharePayload> attachClaimUrl({
    required SharePayload payload,
    required String? actorId,
  }) async {
    final normalizedActorId = actorId?.trim();
    if (normalizedActorId == null ||
        normalizedActorId.isEmpty ||
        !claimableCardTypes.contains(payload.cardType) ||
        payload.entityType != ShareEntityType.guestPlayer) {
      return payload;
    }

    final claimUrl = await _claimLinkIssuer.createGuestPlayerClaimUrl(
      guestPlayerId: payload.entityId,
      actorId: normalizedActorId,
    );
    return payload.withClaimUrl(
      PrideShareAttribution.appendToUri(claimUrl, payload),
    );
  }
}

class GuestPrideClaimLinkService extends GuestMvpClaimLinkService {
  const GuestPrideClaimLinkService({required super.claimLinkIssuer});
}
