import '../../core/enums/match_attendance_status.dart';
import '../../core/enums/team_member_availability.dart';
import '../../core/enums/team_membership_role.dart';

/// Frozen participant entry captured inside a locked pre-match lineup.
class MatchLineupEntry {
  final String attendanceId;
  final String? teamMembershipId;
  final String? playerId;
  final String? guestPlayerId;
  final String? matchSidePlayerId;
  final String? claimedFromGuestPlayerId;
  final TeamMembershipRole role;
  final TeamMemberAvailability availability;
  final MatchAttendanceStatus attendanceStatus;
  final String displayName;
  final String? position;
  final int? shirtNumber;
  final bool ratingEligible;

  // ── Slot assignment (nullable for backward compatibility) ──
  final String? slotId;
  final String? slotRole;
  final int? lineIndex;
  final int? slotIndex;
  final double? slotX;
  final double? slotY;

  const MatchLineupEntry({
    required this.attendanceId,
    this.teamMembershipId,
    this.playerId,
    this.guestPlayerId,
    this.matchSidePlayerId,
    this.claimedFromGuestPlayerId,
    required this.role,
    required this.availability,
    required this.attendanceStatus,
    required this.displayName,
    this.position,
    this.shirtNumber,
    this.ratingEligible = true,
    this.slotId,
    this.slotRole,
    this.lineIndex,
    this.slotIndex,
    this.slotX,
    this.slotY,
  }) : assert(
         (playerId == null ? 0 : 1) +
                 (guestPlayerId == null ? 0 : 1) +
                 (matchSidePlayerId == null ? 0 : 1) ==
             1,
         'Exactly one of playerId, guestPlayerId, or matchSidePlayerId must be set.',
       ),
       assert(
         shirtNumber == null || (shirtNumber >= 0 && shirtNumber <= 99),
         'Shirt number must be between 0 and 99.',
       );

  bool get isGuest => guestPlayerId != null;
  bool get isTemporary => matchSidePlayerId != null;

  String get participantId => playerId ?? guestPlayerId ?? matchSidePlayerId!;

  /// Whether this entry carries exact pitch-position data.
  bool get hasSlotAssignment => slotId != null;

  MatchLineupEntry copyWith({
    String? attendanceId,
    Object? teamMembershipId = _unset,
    Object? playerId = _unset,
    Object? guestPlayerId = _unset,
    Object? matchSidePlayerId = _unset,
    Object? claimedFromGuestPlayerId = _unset,
    TeamMembershipRole? role,
    TeamMemberAvailability? availability,
    MatchAttendanceStatus? attendanceStatus,
    String? displayName,
    Object? position = _unset,
    Object? shirtNumber = _unset,
    bool? ratingEligible,
    Object? slotId = _unset,
    Object? slotRole = _unset,
    Object? lineIndex = _unset,
    Object? slotIndex = _unset,
    Object? slotX = _unset,
    Object? slotY = _unset,
  }) {
    return MatchLineupEntry(
      attendanceId: attendanceId ?? this.attendanceId,
      teamMembershipId: identical(teamMembershipId, _unset)
          ? this.teamMembershipId
          : teamMembershipId as String?,
      playerId: identical(playerId, _unset)
          ? this.playerId
          : playerId as String?,
      guestPlayerId: identical(guestPlayerId, _unset)
          ? this.guestPlayerId
          : guestPlayerId as String?,
      matchSidePlayerId: identical(matchSidePlayerId, _unset)
          ? this.matchSidePlayerId
          : matchSidePlayerId as String?,
      claimedFromGuestPlayerId: identical(claimedFromGuestPlayerId, _unset)
          ? this.claimedFromGuestPlayerId
          : claimedFromGuestPlayerId as String?,
      role: role ?? this.role,
      availability: availability ?? this.availability,
      attendanceStatus: attendanceStatus ?? this.attendanceStatus,
      displayName: displayName ?? this.displayName,
      position: identical(position, _unset)
          ? this.position
          : position as String?,
      shirtNumber: identical(shirtNumber, _unset)
          ? this.shirtNumber
          : shirtNumber as int?,
      ratingEligible: ratingEligible ?? this.ratingEligible,
      slotId: identical(slotId, _unset) ? this.slotId : slotId as String?,
      slotRole: identical(slotRole, _unset)
          ? this.slotRole
          : slotRole as String?,
      lineIndex: identical(lineIndex, _unset)
          ? this.lineIndex
          : lineIndex as int?,
      slotIndex: identical(slotIndex, _unset)
          ? this.slotIndex
          : slotIndex as int?,
      slotX: identical(slotX, _unset) ? this.slotX : slotX as double?,
      slotY: identical(slotY, _unset) ? this.slotY : slotY as double?,
    );
  }
}

const Object _unset = Object();
