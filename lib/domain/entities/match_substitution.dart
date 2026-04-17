/// Immutable substitution event captured during live matchday operations.
class MatchSubstitution {
  final String id;
  final String matchId;
  final String? teamId;
  final String? guestTeamId;
  final String? tournamentRegistrationId;
  final String? checkInId;
  final String? lineupSnapshotId;
  final String outgoingAttendanceId;
  final String incomingAttendanceId;
  final int minute;
  final String createdBy;
  final DateTime createdAt;
  final String? notes;

  const MatchSubstitution({
    required this.id,
    required this.matchId,
    this.teamId,
    this.guestTeamId,
    this.tournamentRegistrationId,
    this.checkInId,
    this.lineupSnapshotId,
    required this.outgoingAttendanceId,
    required this.incomingAttendanceId,
    required this.minute,
    required this.createdBy,
    required this.createdAt,
    this.notes,
  }) : assert(
          (teamId != null) != (guestTeamId != null),
          'Exactly one of teamId or guestTeamId must be set.',
        ),
        assert(
          outgoingAttendanceId != incomingAttendanceId,
          'Outgoing and incoming attendance IDs must differ.',
        );

  bool get isGuestTeam => guestTeamId != null;
  bool get isRegisteredTeam => teamId != null;
  String get participantId => teamId ?? guestTeamId!;
}
