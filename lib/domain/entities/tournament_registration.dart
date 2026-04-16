import '../../core/enums/tournament_registration_mode.dart';
import '../../core/enums/tournament_registration_status.dart';

class TournamentRegistration {
  final String id;
  final String tournamentId;
  final String? teamId;
  final String? guestTeamId;
  final String? claimedFromGuestTeamId;
  final TournamentRegistrationMode mode;
  final TournamentRegistrationStatus status;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? verifiedBy;
  final DateTime? verifiedAt;
  final String? notes;

  const TournamentRegistration({
    required this.id,
    required this.tournamentId,
    this.teamId,
    this.guestTeamId,
    this.claimedFromGuestTeamId,
    this.mode = TournamentRegistrationMode.hybrid,
    this.status = TournamentRegistrationStatus.pending,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.verifiedBy,
    this.verifiedAt,
    this.notes,
  }) : assert(
          (teamId != null) != (guestTeamId != null),
          'Exactly one of teamId or guestTeamId must be set.',
        );

  bool get isGuestRegistration => guestTeamId != null;
  bool get isRegisteredTeamRegistration => teamId != null;
  bool get isVerified => verifiedAt != null;
  String get participantId => teamId ?? guestTeamId!;

  TournamentRegistration copyWith({
    String? id,
    String? tournamentId,
    Object? teamId = _unset,
    Object? guestTeamId = _unset,
    Object? claimedFromGuestTeamId = _unset,
    TournamentRegistrationMode? mode,
    TournamentRegistrationStatus? status,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? verifiedBy = _unset,
    Object? verifiedAt = _unset,
    Object? notes = _unset,
  }) {
    return TournamentRegistration(
      id: id ?? this.id,
      tournamentId: tournamentId ?? this.tournamentId,
      teamId: identical(teamId, _unset) ? this.teamId : teamId as String?,
      guestTeamId: identical(guestTeamId, _unset)
          ? this.guestTeamId
          : guestTeamId as String?,
      claimedFromGuestTeamId: identical(claimedFromGuestTeamId, _unset)
          ? this.claimedFromGuestTeamId
          : claimedFromGuestTeamId as String?,
      mode: mode ?? this.mode,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
