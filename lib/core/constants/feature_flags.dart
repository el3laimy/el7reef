/// Feature toggles for unfinished surfaces that should stay hidden or disabled
/// until they are backed by production-ready data flows.
abstract class FeatureFlags {
  static const bool fantasyUiEnabled = true;
  static const bool activityFeedEnabled = true;
  static const bool guestIdentityEnabled = true;
  static const bool hybridTournamentRegistrationEnabled = true;
  static const bool matchdayUiEnabled = true;
}
