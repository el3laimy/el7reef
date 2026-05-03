/// Feature toggles for unfinished surfaces that should stay hidden or disabled
/// until they are backed by production-ready data flows.
abstract class FeatureFlags {
  static const bool fantasyUiEnabled = false;
  static const bool activityFeedEnabled = false;
  static const bool challengesUiEnabled = false;
  static const bool friendlyMatchTopLevelEnabled = false;
  static const bool socialUiEnabled = false;
  static const bool organizerAdvancedOpsEnabled = false;
  static const bool goldenRatingUiEnabled = false;
  static const bool profileSettingsUiEnabled = false;
  static const bool profileSharingUiEnabled = false;
  static const bool guestIdentityEnabled = true;
  static const bool hybridTournamentRegistrationEnabled = true;
  static const bool matchdayUiEnabled = true;
}
