import '../../domain/entities/share_payload.dart';
import '../../features/shareables/models/pride_export.dart';

class AnalyticsService {
  static const String prideCardViewedEvent = 'pride_card_viewed';
  static const String shareStartedEvent = 'share_started';
  static const String shareSheetReturnedEvent = 'share_sheet_returned';
  static const String prideExportFinishedEvent = 'pride_export_finished';
  static const String shareLinkOpenedEvent = 'share_link_opened';
  static const String claimStartedFromCardEvent = 'claim_started_from_card';
  static const String claimCompletedFromCardEvent = 'claim_completed_from_card';

  const AnalyticsService();

  void trackEvent(String eventName, {Map<String, dynamic>? parameters}) {
    // Keep the existing call contract without client persistence or logging.
    // Only a separately approved trusted path under ELR-OPS-405 may replace it.
  }

  void trackInviteSent({
    required String type,
    required String targetId,
    required String actorId,
  }) {
    trackEvent('invite_sent');
  }

  void trackClaimOpen({required String type, required String targetId}) {
    trackEvent('claim_open');
  }

  void trackClaimCompletion({
    required String type,
    required String targetId,
    required String actorId,
  }) {
    trackEvent('claim_completion');
  }

  void trackJoinCompletion({
    required String type,
    required String targetId,
    required String actorId,
  }) {
    trackEvent('join_completion');
  }

  void trackPrideCardViewed(SharePayload payload) {
    trackEvent(prideCardViewedEvent);
  }

  void trackShareStarted(SharePayload payload) {
    trackEvent(shareStartedEvent);
  }

  void trackShareSheetReturned(SharePayload payload) {
    trackEvent(shareSheetReturnedEvent);
  }

  void trackPrideExportFinished(PrideExportResult result) {
    trackEvent(prideExportFinishedEvent);
  }

  void trackShareLinkOpened(SharePayload payload) {
    trackEvent(shareLinkOpenedEvent);
  }

  void trackClaimStartedFromCard(SharePayload payload) {
    trackEvent(claimStartedFromCardEvent);
  }

  void trackClaimCompletedFromCard(SharePayload payload) {
    trackEvent(claimCompletedFromCardEvent);
  }
}
