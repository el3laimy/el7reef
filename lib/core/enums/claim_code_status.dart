enum ClaimCodeStatus {
  active,
  claimed,
  expired,
  cancelled;

  bool get isTerminal => switch (this) {
        claimed || expired || cancelled => true,
        active => false,
      };
}
