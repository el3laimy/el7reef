import 'package:get/get.dart';

import '../services/feature_flag_service.dart';

/// Feature toggles for unfinished surfaces that should stay hidden or disabled
/// until they are backed by production-ready data flows.
abstract class FeatureFlags {
  static bool get fantasyUiEnabled => _read(FeatureFlagKey.fantasyUiEnabled);
  static bool get activityFeedEnabled =>
      _read(FeatureFlagKey.activityFeedEnabled);
  static bool get challengesUiEnabled =>
      _read(FeatureFlagKey.challengesUiEnabled);
  static bool get friendlyMatchTopLevelEnabled =>
      _read(FeatureFlagKey.friendlyMatchTopLevelEnabled);
  static bool get socialUiEnabled => _read(FeatureFlagKey.socialUiEnabled);
  static bool get organizerAdvancedOpsEnabled =>
      _read(FeatureFlagKey.organizerAdvancedOpsEnabled);
  static bool get goldenRatingUiEnabled =>
      _read(FeatureFlagKey.goldenRatingUiEnabled);
  static bool get profileSettingsUiEnabled =>
      _read(FeatureFlagKey.profileSettingsUiEnabled);
  static bool get profileSharingUiEnabled =>
      _read(FeatureFlagKey.profileSharingUiEnabled);
  static bool get guestIdentityEnabled =>
      _read(FeatureFlagKey.guestIdentityEnabled);
  static bool get hybridTournamentRegistrationEnabled =>
      _read(FeatureFlagKey.hybridTournamentRegistrationEnabled);
  static bool get matchdayUiEnabled => _read(FeatureFlagKey.matchdayUiEnabled);

  static bool _read(FeatureFlagKey key) {
    if (Get.isRegistered<FeatureFlagService>()) {
      return Get.find<FeatureFlagService>().isEnabled(key);
    }
    return FeatureFlagService.defaultValueFor(key);
  }
}
