/// Lifecycle phases for a fantasy league or tournament-linked fantasy season.
enum FantasyLeaguePhase {
  /// League exists but hasn't opened fantasy interactions yet.
  upcoming,

  /// Users can still build or adjust their draft.
  draft,

  /// A round is live and normal fantasy scoring context is active.
  live,

  /// Transfers are explicitly open between rounds.
  transferWindow,

  /// The round is locked and user edits should be blocked.
  locked,

  /// The round was processed and standings are final for that gameweek.
  settled,

  /// League is fully completed.
  completed,

  /// League was cancelled and should not accept actions.
  cancelled,
}
