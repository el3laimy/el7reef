/// أنواع الإجراءات المسجلة في سجل التدقيق
enum AuditAction {
  // ── Match ──
  matchCreated,
  matchScoreSubmitted,
  matchScoreApproved,
  matchFrozen,
  matchUnfrozen,
  matchGoldenRatingActivated,
  matchSettled,

  // ── Matchday ──
  teamCheckedIn,
  lineupLocked,
  substitutionRecorded,

  // ── Tournament ──
  tournamentCreated,
  tournamentStatusChanged,
  registrationCreated,
  registrationApproved,
  registrationRejected,

  // ── Guest Claim ──
  guestPlayerCreated,
  guestPlayerClaimed,
  guestTeamCreated,
  guestTeamClaimed,
  claimCodeGenerated,
  claimCodeConsumed,

  // ── Fantasy ──
  fantasyRoundSettled,
  fantasyTransferExecuted,
  fantasyChipActivated,

  // ── Roster ──
  memberAdded,
  memberRemoved,
  memberRoleChanged,

  // ── Dispute ──
  disputeOpened,
  disputeResolved,
  disputeRejected,
  disputeFrozenMatch,
}

/// نوع الكيان المستهدف بالحدث
enum AuditEntityType {
  match,
  tournament,
  player,
  team,
  guestPlayer,
  guestTeam,
  fantasyTeam,
  fantasyLeague,
  registration,
  membership,
  claimCode,
  dispute,
}
