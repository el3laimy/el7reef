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
  participantAdded,
  participantReplaced,
  participantWithdrawn,
  participantReactivated,
  participantSeedUpdated,
  participantsFinalized,
  groupStageGenerated,
  groupStageRegenerated,
  fixtureScheduled,
  fixtureStarted,
  fixturesPublished,
  knockoutGenerated,
  tournamentCompleted,

  // ── Guest Claim ──
  guestPlayerCreated,
  guestPlayerUpdated,
  guestPlayerArchived,
  guestPlayerClaimed,
  guestTeamCreated,
  guestTeamCaptainUpdated,
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

  // ── Safety ──
  profileReported,
  playerBlocked,
  playerUnblocked,
  accountDeletionRequested,
  accountDeletionProcessing,
  accountDeletionCompleted,
  accountDeletionFailed,

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
  tournamentParticipant,
  tournamentGroup,
  groupStandingSnapshot,
  knockoutBracket,
  knockoutTie,
  membership,
  claimCode,
  dispute,
  moderationReport,
  safetyRelationship,
  accountDeletion,
}
