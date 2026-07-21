part of 'tournament_operations_controller.dart';

extension TournamentStageOps on TournamentOperationsController {
  Future<void> startGroupStage() async {
    final id = tournamentId;
    if (id == null || id.isEmpty) {
      return;
    }
    final actorId = _currentTournamentManagerActorId();
    if (actorId == null) return;
    await _runAction(
      message: 'تم إنشاء المجموعات وجدولها بنجاح.',
      action: () =>
          _lifecycleService.startGroupStage(tournamentId: id, actorId: actorId),
      onSuccess: (result) async {
        _applyGroups(result.groups);
        standings.assignAll(result.standings);
        _mergeFixtures(result.fixtures);
        final currentTournament = tournament.value;
        if (currentTournament != null) {
          tournament.value = currentTournament.copyWith(
            status: TournamentStatus.groupStage,
            currentGroupStageId: result.groupStageId,
          );
        } else {
          await _refreshTournamentOnly();
        }
      },
    );
  }

  Future<void> regenerateGroupStage() async {
    final id = tournamentId;
    if (id == null || id.isEmpty) {
      return;
    }
    final actorId = _currentTournamentManagerActorId();
    if (actorId == null) return;
    await _runAction(
      message: 'تمت إعادة توليد المجموعات والـ fixtures بنجاح.',
      action: () => _fixtureService.regenerateGroupStage(
        tournamentId: id,
        actorId: actorId,
      ),
      onSuccess: (result) async {
        _applyGroups(result.groups);
        standings.assignAll(result.standings);
        _replaceGroupStageFixtures(result.fixtures);
      },
    );
  }

  Future<void> startKnockout() async {
    final id = tournamentId;
    if (id == null || id.isEmpty) {
      return;
    }
    final actorId = _currentTournamentManagerActorId();
    if (actorId == null) return;
    await _runAction(
      message: 'تم إنشاء bracket الإقصاء.',
      action: () =>
          _lifecycleService.startKnockout(tournamentId: id, actorId: actorId),
      onSuccess: (result) async {
        knockoutBracket.value = result.bracket;
        knockoutTies.assignAll(result.ties);
        _mergeFixtures(result.matches);
        final currentTournament = tournament.value;
        if (currentTournament != null) {
          tournament.value = currentTournament.copyWith(
            status: TournamentStatus.knockoutStage,
            currentKnockoutBracketId: result.bracket.id,
          );
        } else {
          await _refreshTournamentOnly();
        }
      },
    );
  }

  Future<void> completeTournament() async {
    final id = tournamentId;
    if (id == null || id.isEmpty) {
      return;
    }
    final actorId = _currentTournamentManagerActorId();
    if (actorId == null) return;
    await _runAction(
      message: 'تم إغلاق البطولة وتحديد البطل.',
      action: () => _lifecycleService.completeTournament(
        tournamentId: id,
        actorId: actorId,
      ),
      onSuccess: (updatedTournament) async {
        tournament.value = updatedTournament;
        await showChampionCelebration(updatedTournament);
      },
    );
  }
}
