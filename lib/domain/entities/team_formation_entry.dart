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

  const TeamFormationEntry({
    this.playerId,
    this.guestPlayerId,
    required this.role,
    required this.status,
    required this.availability,
    required this.displayName,
    this.position,
  }) : assert(
          (playerId != null) != (guestPlayerId != null),
          'Exactly one of playerId or guestPlayerId must be set.',
        );

  bool get isGuest => guestPlayerId != null;

  String get memberKey => playerId != null ? 'player:$playerId' : 'guest:$guestPlayerId';

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
  }) {
    return TeamFormationEntry(
      playerId: identical(playerId, _unset) ? this.playerId : playerId as String?,
      guestPlayerId: identical(guestPlayerId, _unset)
          ? this.guestPlayerId
          : guestPlayerId as String?,
      role: role ?? this.role,
      status: status ?? this.status,
      availability: availability ?? this.availability,
      displayName: displayName ?? this.displayName,
      position: identical(position, _unset) ? this.position : position as String?,
    );
  }
}

const Object _unset = Object();
