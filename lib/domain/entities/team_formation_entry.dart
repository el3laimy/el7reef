import '../../core/enums/team_member_availability.dart';
import '../../core/enums/team_membership_role.dart';
import '../../core/enums/team_membership_status.dart';
import 'team_membership.dart';

class TeamFormationEntry {
  final String? playerId;
  final String? guestPlayerId;
  final TeamMembershipRole role;
  final TeamMembershipStatus status;
  final TeamMemberAvailability availability;
  final String displayName;
  final String? position;
  final String? slotId;
  final String? slotRole;
  final int? lineIndex;
  final int? slotIndex;
  final double? slotX;
  final double? slotY;

  const TeamFormationEntry({
    this.playerId,
    this.guestPlayerId,
    required this.role,
    required this.status,
    required this.availability,
    required this.displayName,
    this.position,
    this.slotId,
    this.slotRole,
    this.lineIndex,
    this.slotIndex,
    this.slotX,
    this.slotY,
  }) : assert(
         (playerId != null) != (guestPlayerId != null),
         'Exactly one of playerId or guestPlayerId must be set.',
       );

  bool get isGuest => guestPlayerId != null;

  String get memberKey =>
      playerId != null ? 'player:$playerId' : 'guest:$guestPlayerId';

  bool get hasSlotAssignment => slotId?.trim().isNotEmpty == true;

  bool matchesMembership(TeamMembership membership) {
    return playerId != null
        ? membership.playerId == playerId
        : membership.guestPlayerId == guestPlayerId;
  }

  TeamFormationEntry copyWith({
    Object? playerId = _unset,
    Object? guestPlayerId = _unset,
    TeamMembershipRole? role,
    TeamMembershipStatus? status,
    TeamMemberAvailability? availability,
    String? displayName,
    Object? position = _unset,
    Object? slotId = _unset,
    Object? slotRole = _unset,
    Object? lineIndex = _unset,
    Object? slotIndex = _unset,
    Object? slotX = _unset,
    Object? slotY = _unset,
  }) {
    return TeamFormationEntry(
      playerId: identical(playerId, _unset)
          ? this.playerId
          : playerId as String?,
      guestPlayerId: identical(guestPlayerId, _unset)
          ? this.guestPlayerId
          : guestPlayerId as String?,
      role: role ?? this.role,
      status: status ?? this.status,
      availability: availability ?? this.availability,
      displayName: displayName ?? this.displayName,
      position: identical(position, _unset)
          ? this.position
          : position as String?,
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
