import '../../core/enums/fantasy_league_phase.dart';

/// Source of truth for the current fantasy round state of a league.
class FantasyLeagueLifecycle {
  final String leagueId;
  final int currentGameweek;
  final FantasyLeaguePhase phase;
  final DateTime? deadlineAt;
  final bool isLocked;
  final bool isGlobal;
  final DateTime? openedAt;
  final DateTime? settledAt;
  final DateTime updatedAt;

  const FantasyLeagueLifecycle({
    required this.leagueId,
    this.currentGameweek = 1,
    this.phase = FantasyLeaguePhase.draft,
    this.deadlineAt,
    this.isLocked = false,
    this.isGlobal = false,
    this.openedAt,
    this.settledAt,
    required this.updatedAt,
  });

  bool get isSettled => settledAt != null || phase == FantasyLeaguePhase.settled;

  bool get allowsTransfers =>
      !isLocked &&
      (phase == FantasyLeaguePhase.draft ||
          phase == FantasyLeaguePhase.transferWindow);

  bool get allowsDraftEdits =>
      !isLocked &&
      (phase == FantasyLeaguePhase.upcoming ||
          phase == FantasyLeaguePhase.draft ||
          phase == FantasyLeaguePhase.transferWindow);

  FantasyLeagueLifecycle copyWith({
    String? leagueId,
    int? currentGameweek,
    FantasyLeaguePhase? phase,
    DateTime? deadlineAt,
    bool clearDeadline = false,
    bool? isLocked,
    bool? isGlobal,
    DateTime? openedAt,
    bool clearOpenedAt = false,
    DateTime? settledAt,
    bool clearSettledAt = false,
    DateTime? updatedAt,
  }) {
    return FantasyLeagueLifecycle(
      leagueId: leagueId ?? this.leagueId,
      currentGameweek: currentGameweek ?? this.currentGameweek,
      phase: phase ?? this.phase,
      deadlineAt: clearDeadline ? null : deadlineAt ?? this.deadlineAt,
      isLocked: isLocked ?? this.isLocked,
      isGlobal: isGlobal ?? this.isGlobal,
      openedAt: clearOpenedAt ? null : openedAt ?? this.openedAt,
      settledAt: clearSettledAt ? null : settledAt ?? this.settledAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
