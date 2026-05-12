part of 'tournament_operations_controller.dart';

extension TournamentFixtureOps on TournamentOperationsController {
  Future<void> publishFixtures() async {
    final id = tournamentId;
    if (id == null || id.isEmpty) {
      return;
    }
    final actorId = _currentTournamentManagerActorId();
    if (actorId == null) return;
    await _runAction(
      message: 'تم نشر fixtures البطولة.',
      action: () => _lifecycleService.publishFixtures(
        tournamentId: id,
        actorId: actorId,
      ),
      onSuccess: (publishedFixtures) async {
        fixtures.assignAll(publishedFixtures);
      },
    );
  }

  Future<void> scheduleFixture({
    required String fixtureId,
    required DateTime scheduledAt,
    String? venueId,
  }) async {
    final actorId = _currentTournamentManagerActorId();
    if (actorId == null) return;
    await _runAction(
      message: 'تم تحديث موعد الـ fixture.',
      action: () => _fixtureService.scheduleFixture(
        matchId: fixtureId,
        actorId: actorId,
        scheduledAt: scheduledAt,
        venueId: venueId,
      ),
      onSuccess: (updatedFixture) async {
        _upsertFixture(updatedFixture);
      },
    );
  }

  Future<void> startFixture(String fixtureId) async {
    final actorId = _currentTournamentManagerActorId();
    if (actorId == null) return;
    await _runAction(
      message: 'تم بدء المباراة وأصبحت جارية الآن.',
      action: () =>
          _fixtureService.startMatch(matchId: fixtureId, actorId: actorId),
      onSuccess: (updatedFixture) async {
        _upsertFixture(updatedFixture);
      },
    );
  }

  Future<void> approveFixtureScore(String fixtureId) async {
    final actorId = _currentTournamentManagerActorId();
    if (actorId == null) return;
    await _runAction(
      message: 'تم اعتماد نتيجة المباراة وتحديث البطولة.',
      action: () => _settlementService.approveScore(
        matchId: fixtureId,
        actorId: actorId,
      ),
    );
  }
}
