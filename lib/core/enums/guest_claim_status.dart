/// Claim status for guest-backed entities that can later be linked to
/// registered players or teams.
enum GuestClaimStatus {
  /// Guest exists only as a manually entered placeholder.
  guest,

  /// A claim or invite was generated but not completed yet.
  invited,

  /// Guest entity was successfully linked to a registered identity.
  claimed,

  /// Guest entity is no longer active in operational flows.
  archived,
}
