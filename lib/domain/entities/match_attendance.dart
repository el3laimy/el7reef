import '../../core/enums/match_attendance_status.dart';

/// Participant-level attendance truth scoped to a match and a side.
class MatchAttendance {
  final String id;
  final String matchId;
  final String? teamId;
  final String? guestTeamId;
  final String? tournamentRegistrationId;
  final String? checkInId;
  final String? teamMembershipId;
  final String? playerId;
  final String? guestPlayerId;
  final String? claimedFromGuestPlayerId;
  final MatchAttendanceStatus status;
  final bool includedInLockedLineup;
  final bool startedMatch;
  final bool played;
  final bool currentlyOnPitch;
  final int? firstEnteredMinute;
  final int? lastExitedMinute;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? markedBy;
  final DateTime? markedAt;
  final String? participationUpdatedBy;
  final DateTime? participationUpdatedAt;
  final String? notes;

  const MatchAttendance({
    required this.id,
    required this.matchId,
    this.teamId,
    this.guestTeamId,
    this.tournamentRegistrationId,
    this.checkInId,
    this.teamMembershipId,
    this.playerId,
    this.guestPlayerId,
    this.claimedFromGuestPlayerId,
    this.status = MatchAttendanceStatus.pending,
    this.includedInLockedLineup = false,
    this.startedMatch = false,
    this.played = false,
    this.currentlyOnPitch = false,
    this.firstEnteredMinute,
    this.lastExitedMinute,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.markedBy,
    this.markedAt,
    this.participationUpdatedBy,
    this.participationUpdatedAt,
    this.notes,
  }) : assert(
          (teamId != null) != (guestTeamId != null),
          'Exactly one of teamId or guestTeamId must be set.',
        ),
        assert(
          (playerId != null) != (guestPlayerId != null),
          'Exactly one of playerId or guestPlayerId must be set.',
        );

  bool get isGuestTeam => guestTeamId != null;
  bool get isRegisteredTeam => teamId != null;
  bool get isGuestParticipant => guestPlayerId != null;
  bool get isRegisteredParticipant => playerId != null;
  bool get wasSubstitutedIn => played && !startedMatch && firstEnteredMinute != null;
  bool get isPresent =>
      status == MatchAttendanceStatus.present ||
      status == MatchAttendanceStatus.late;
  String get teamParticipantId => teamId ?? guestTeamId!;
  String get participantId => playerId ?? guestPlayerId!;

  MatchAttendance copyWith({
    String? id,
    String? matchId,
    Object? teamId = _unset,
    Object? guestTeamId = _unset,
    Object? tournamentRegistrationId = _unset,
    Object? checkInId = _unset,
    Object? teamMembershipId = _unset,
    Object? playerId = _unset,
    Object? guestPlayerId = _unset,
    Object? claimedFromGuestPlayerId = _unset,
    MatchAttendanceStatus? status,
    bool? includedInLockedLineup,
    bool? startedMatch,
    bool? played,
    bool? currentlyOnPitch,
    Object? firstEnteredMinute = _unset,
    Object? lastExitedMinute = _unset,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? markedBy = _unset,
    Object? markedAt = _unset,
    Object? participationUpdatedBy = _unset,
    Object? participationUpdatedAt = _unset,
    Object? notes = _unset,
  }) {
    return MatchAttendance(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      teamId: identical(teamId, _unset) ? this.teamId : teamId as String?,
      guestTeamId: identical(guestTeamId, _unset)
          ? this.guestTeamId
          : guestTeamId as String?,
      tournamentRegistrationId: identical(tournamentRegistrationId, _unset)
          ? this.tournamentRegistrationId
          : tournamentRegistrationId as String?,
      checkInId: identical(checkInId, _unset) ? this.checkInId : checkInId as String?,
      teamMembershipId: identical(teamMembershipId, _unset)
          ? this.teamMembershipId
          : teamMembershipId as String?,
      playerId: identical(playerId, _unset) ? this.playerId : playerId as String?,
      guestPlayerId: identical(guestPlayerId, _unset)
          ? this.guestPlayerId
          : guestPlayerId as String?,
      claimedFromGuestPlayerId: identical(claimedFromGuestPlayerId, _unset)
          ? this.claimedFromGuestPlayerId
          : claimedFromGuestPlayerId as String?,
      status: status ?? this.status,
      includedInLockedLineup:
          includedInLockedLineup ?? this.includedInLockedLineup,
      startedMatch: startedMatch ?? this.startedMatch,
      played: played ?? this.played,
      currentlyOnPitch: currentlyOnPitch ?? this.currentlyOnPitch,
      firstEnteredMinute: identical(firstEnteredMinute, _unset)
          ? this.firstEnteredMinute
          : firstEnteredMinute as int?,
      lastExitedMinute: identical(lastExitedMinute, _unset)
          ? this.lastExitedMinute
          : lastExitedMinute as int?,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      markedBy: identical(markedBy, _unset) ? this.markedBy : markedBy as String?,
      markedAt: identical(markedAt, _unset) ? this.markedAt : markedAt as DateTime?,
      participationUpdatedBy: identical(participationUpdatedBy, _unset)
          ? this.participationUpdatedBy
          : participationUpdatedBy as String?,
      participationUpdatedAt: identical(participationUpdatedAt, _unset)
          ? this.participationUpdatedAt
          : participationUpdatedAt as DateTime?,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
    );
  }
}

const Object _unset = Object();
