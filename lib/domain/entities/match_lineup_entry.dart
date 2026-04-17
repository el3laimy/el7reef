import '../../core/enums/match_attendance_status.dart';
import '../../core/enums/team_member_availability.dart';
import '../../core/enums/team_membership_role.dart';

/// Frozen participant entry captured inside a locked pre-match lineup.
class MatchLineupEntry {
  final String attendanceId;
  final String? teamMembershipId;
  final String? playerId;
  final String? guestPlayerId;
  final String? claimedFromGuestPlayerId;
  final TeamMembershipRole role;
  final TeamMemberAvailability availability;
  final MatchAttendanceStatus attendanceStatus;
  final String displayName;
  final String? position;

  const MatchLineupEntry({
    required this.attendanceId,
    this.teamMembershipId,
    this.playerId,
    this.guestPlayerId,
    this.claimedFromGuestPlayerId,
    required this.role,
    required this.availability,
    required this.attendanceStatus,
    required this.displayName,
    this.position,
  }) : assert(
          (playerId != null) != (guestPlayerId != null),
          'Exactly one of playerId or guestPlayerId must be set.',
        );

  bool get isGuest => guestPlayerId != null;

  String get participantId => playerId ?? guestPlayerId!;

  MatchLineupEntry copyWith({
    String? attendanceId,
    Object? teamMembershipId = _unset,
    Object? playerId = _unset,
    Object? guestPlayerId = _unset,
    Object? claimedFromGuestPlayerId = _unset,
    TeamMembershipRole? role,
    TeamMemberAvailability? availability,
    MatchAttendanceStatus? attendanceStatus,
    String? displayName,
    Object? position = _unset,
  }) {
    return MatchLineupEntry(
      attendanceId: attendanceId ?? this.attendanceId,
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
      role: role ?? this.role,
      availability: availability ?? this.availability,
      attendanceStatus: attendanceStatus ?? this.attendanceStatus,
      displayName: displayName ?? this.displayName,
      position: identical(position, _unset) ? this.position : position as String?,
    );
  }
}

const Object _unset = Object();
