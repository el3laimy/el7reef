import 'analytics_service.dart';

class GuestClaimCompletionReporter {
  final AnalyticsService _analytics;

  const GuestClaimCompletionReporter(this._analytics);

  void playerClaimed({required String guestPlayerId, required String actorId}) {
    _analytics.trackClaimCompletion(
      type: 'guest_player',
      targetId: guestPlayerId,
      actorId: actorId,
    );
  }

  void teamClaimed({required String guestTeamId, required String actorId}) {
    _analytics.trackClaimCompletion(
      type: 'guest_team',
      targetId: guestTeamId,
      actorId: actorId,
    );
  }
}
