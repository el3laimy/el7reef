import '../../core/enums/team_member_availability.dart';
import '../../core/enums/team_membership_role.dart';
import '../../core/enums/team_membership_status.dart';

/// Explicit membership record that links a team to either a registered player
/// or a guest player.
class TeamMembership {
  final String id;
  final String teamId;
  final String? playerId;
  final String? guestPlayerId;
  final String? claimedFromGuestPlayerId;
  final TeamMembershipRole role;
  final TeamMembershipStatus status;
  final TeamMemberAvailability availability;
  final DateTime joinedAt;
  final DateTime updatedAt;
  final String? invitedBy;

  const TeamMembership({
    required this.id,
    required this.teamId,
    this.playerId,
    this.guestPlayerId,
    this.claimedFromGuestPlayerId,
    this.role = TeamMembershipRole.player,
    this.status = TeamMembershipStatus.inactive,
    this.availability = TeamMemberAvailability.available,
    required this.joinedAt,
    required this.updatedAt,
    this.invitedBy,
  }) : assert(
          (playerId != null) != (guestPlayerId != null),
          'Exactly one of playerId or guestPlayerId must be set.',
        );

  bool get isGuest => guestPlayerId != null;
  bool get isRegistered => playerId != null;
  bool get isActive => status != TeamMembershipStatus.inactive;

  TeamMembership copyWith({
    String? id,
    String? teamId,
    Object? playerId = _unset,
    Object? guestPlayerId = _unset,
    Object? claimedFromGuestPlayerId = _unset,
    TeamMembershipRole? role,
    TeamMembershipStatus? status,
    TeamMemberAvailability? availability,
    DateTime? joinedAt,
    DateTime? updatedAt,
    Object? invitedBy = _unset,
  }) {
    return TeamMembership(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      playerId: identical(playerId, _unset) ? this.playerId : playerId as String?,
      guestPlayerId: identical(guestPlayerId, _unset)
          ? this.guestPlayerId
          : guestPlayerId as String?,
      claimedFromGuestPlayerId: identical(claimedFromGuestPlayerId, _unset)
          ? this.claimedFromGuestPlayerId
          : claimedFromGuestPlayerId as String?,
      role: role ?? this.role,
      status: status ?? this.status,
      availability: availability ?? this.availability,
      joinedAt: joinedAt ?? this.joinedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      invitedBy: identical(invitedBy, _unset) ? this.invitedBy : invitedBy as String?,
    );
  }
}

const Object _unset = Object();
