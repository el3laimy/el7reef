import '../../core/enums/team_member_availability.dart';
import '../../core/enums/team_membership_role.dart';
import '../../core/enums/team_membership_status.dart';
import '../../domain/entities/team_membership.dart';

class TeamMembershipModel {
  final String id;
  final String teamId;
  final String? playerId;
  final String? guestPlayerId;
  final String? claimedFromGuestPlayerId;
  final String role;
  final String status;
  final String availability;
  final DateTime joinedAt;
  final DateTime updatedAt;
  final String? invitedBy;

  const TeamMembershipModel({
    required this.id,
    required this.teamId,
    this.playerId,
    this.guestPlayerId,
    this.claimedFromGuestPlayerId,
    this.role = 'player',
    this.status = 'inactive',
    this.availability = 'available',
    required this.joinedAt,
    required this.updatedAt,
    this.invitedBy,
  });

  factory TeamMembershipModel.fromJson(
    Map<String, dynamic> json,
    String docId,
  ) {
    return TeamMembershipModel(
      id: docId,
      teamId: json['teamId'] as String? ?? '',
      playerId: json['playerId'] as String?,
      guestPlayerId: json['guestPlayerId'] as String?,
      claimedFromGuestPlayerId: json['claimedFromGuestPlayerId'] as String?,
      role: json['role'] as String? ?? 'player',
      status: json['status'] as String? ?? 'inactive',
      availability: json['availability'] as String? ?? 'available',
      joinedAt: json['joinedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['joinedAt'] as num).toInt(),
            )
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['updatedAt'] as num).toInt(),
            )
          : DateTime.now(),
      invitedBy: json['invitedBy'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'teamId': teamId,
      'playerId': playerId,
      'guestPlayerId': guestPlayerId,
      'claimedFromGuestPlayerId': claimedFromGuestPlayerId,
      'role': role,
      'status': status,
      'availability': availability,
      'joinedAt': joinedAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'invitedBy': invitedBy,
    };
  }

  TeamMembership toEntity() {
    return TeamMembership(
      id: id,
      teamId: teamId,
      playerId: playerId,
      guestPlayerId: guestPlayerId,
      claimedFromGuestPlayerId: claimedFromGuestPlayerId,
      role: _parseRole(role),
      status: _parseStatus(status),
      availability: _parseAvailability(availability),
      joinedAt: joinedAt,
      updatedAt: updatedAt,
      invitedBy: invitedBy,
    );
  }

  factory TeamMembershipModel.fromEntity(TeamMembership membership) {
    return TeamMembershipModel(
      id: membership.id,
      teamId: membership.teamId,
      playerId: membership.playerId,
      guestPlayerId: membership.guestPlayerId,
      claimedFromGuestPlayerId: membership.claimedFromGuestPlayerId,
      role: membership.role.name,
      status: membership.status.name,
      availability: membership.availability.name,
      joinedAt: membership.joinedAt,
      updatedAt: membership.updatedAt,
      invitedBy: membership.invitedBy,
    );
  }

  static TeamMembershipRole _parseRole(String value) {
    return TeamMembershipRole.values.firstWhere(
      (entry) => entry.name == value,
      orElse: () => TeamMembershipRole.player,
    );
  }

  static TeamMembershipStatus _parseStatus(String value) {
    return TeamMembershipStatus.values.firstWhere(
      (entry) => entry.name == value,
      orElse: () => TeamMembershipStatus.inactive,
    );
  }

  static TeamMemberAvailability _parseAvailability(String value) {
    return TeamMemberAvailability.values.firstWhere(
      (entry) => entry.name == value,
      orElse: () => TeamMemberAvailability.available,
    );
  }
}
