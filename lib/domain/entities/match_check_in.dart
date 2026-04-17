import '../../core/enums/match_check_in_status.dart';

/// Explicit team-level matchday check-in record.
class MatchCheckIn {
  final String id;
  final String matchId;
  final String? teamId;
  final String? guestTeamId;
  final String? tournamentRegistrationId;
  final MatchCheckInStatus status;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? checkedInBy;
  final DateTime? checkedInAt;
  final String? verifiedBy;
  final DateTime? verifiedAt;
  final String? notes;

  const MatchCheckIn({
    required this.id,
    required this.matchId,
    this.teamId,
    this.guestTeamId,
    this.tournamentRegistrationId,
    this.status = MatchCheckInStatus.pending,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.checkedInBy,
    this.checkedInAt,
    this.verifiedBy,
    this.verifiedAt,
    this.notes,
  }) : assert(
          (teamId != null) != (guestTeamId != null),
          'Exactly one of teamId or guestTeamId must be set.',
        );

  bool get isGuestTeam => guestTeamId != null;
  bool get isRegisteredTeam => teamId != null;
  bool get isCheckedIn =>
      status == MatchCheckInStatus.checkedIn ||
      status == MatchCheckInStatus.verified;
  bool get isVerified => status == MatchCheckInStatus.verified;
  String get participantId => teamId ?? guestTeamId!;

  MatchCheckIn copyWith({
    String? id,
    String? matchId,
    Object? teamId = _unset,
    Object? guestTeamId = _unset,
    Object? tournamentRegistrationId = _unset,
    MatchCheckInStatus? status,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? checkedInBy = _unset,
    Object? checkedInAt = _unset,
    Object? verifiedBy = _unset,
    Object? verifiedAt = _unset,
    Object? notes = _unset,
  }) {
    return MatchCheckIn(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      teamId: identical(teamId, _unset) ? this.teamId : teamId as String?,
      guestTeamId: identical(guestTeamId, _unset)
          ? this.guestTeamId
          : guestTeamId as String?,
      tournamentRegistrationId: identical(tournamentRegistrationId, _unset)
          ? this.tournamentRegistrationId
          : tournamentRegistrationId as String?,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      checkedInBy: identical(checkedInBy, _unset)
          ? this.checkedInBy
          : checkedInBy as String?,
      checkedInAt: identical(checkedInAt, _unset)
          ? this.checkedInAt
          : checkedInAt as DateTime?,
      verifiedBy: identical(verifiedBy, _unset)
          ? this.verifiedBy
          : verifiedBy as String?,
      verifiedAt: identical(verifiedAt, _unset)
          ? this.verifiedAt
          : verifiedAt as DateTime?,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
    );
  }
}

const Object _unset = Object();
