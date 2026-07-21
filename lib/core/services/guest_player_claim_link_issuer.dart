abstract interface class GuestPlayerClaimLinkIssuer {
  Future<Uri> createGuestPlayerClaimUrl({
    required String guestPlayerId,
    required String actorId,
    Duration ttl = const Duration(days: 7),
    bool requiresApproval = false,
  });
}
