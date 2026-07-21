import '../../core/enums/team_member_availability.dart';
import '../../core/enums/team_membership_role.dart';
import '../../core/enums/team_membership_status.dart';
import '../../domain/entities/team_formation_entry.dart';

class TeamFormationEntryModel {
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

  const TeamFormationEntryModel({
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
  });

  factory TeamFormationEntryModel.fromJson(Map<String, dynamic> json) {
    return TeamFormationEntryModel(
      playerId: json['playerId'] as String?,
      guestPlayerId: json['guestPlayerId'] as String?,
      role: TeamMembershipRole.values.firstWhere(
        (value) =>
            value.name ==
            (json['role'] as String? ?? TeamMembershipRole.player.name),
        orElse: () => TeamMembershipRole.player,
      ),
      status: TeamMembershipStatus.values.firstWhere(
        (value) =>
            value.name ==
            (json['status'] as String? ?? TeamMembershipStatus.bench.name),
        orElse: () => TeamMembershipStatus.bench,
      ),
      availability: TeamMemberAvailability.values.firstWhere(
        (value) =>
            value.name ==
            (json['availability'] as String? ??
                TeamMemberAvailability.available.name),
        orElse: () => TeamMemberAvailability.available,
      ),
      displayName: json['displayName'] as String? ?? '',
      position: json['position'] as String?,
      slotId: json['slotId'] as String?,
      slotRole: json['slotRole'] as String?,
      lineIndex: (json['lineIndex'] as num?)?.toInt(),
      slotIndex: (json['slotIndex'] as num?)?.toInt(),
      slotX: (json['slotX'] as num?)?.toDouble(),
      slotY: (json['slotY'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'playerId': playerId,
      'guestPlayerId': guestPlayerId,
      'role': role.name,
      'status': status.name,
      'availability': availability.name,
      'displayName': displayName,
      'position': position,
      'slotId': slotId,
      'slotRole': slotRole,
      'lineIndex': lineIndex,
      'slotIndex': slotIndex,
      'slotX': slotX,
      'slotY': slotY,
    };
  }

  TeamFormationEntry toEntity() {
    return TeamFormationEntry(
      playerId: playerId,
      guestPlayerId: guestPlayerId,
      role: role,
      status: status,
      availability: availability,
      displayName: displayName,
      position: position,
      slotId: slotId,
      slotRole: slotRole,
      lineIndex: lineIndex,
      slotIndex: slotIndex,
      slotX: slotX,
      slotY: slotY,
    );
  }

  factory TeamFormationEntryModel.fromEntity(TeamFormationEntry entry) {
    return TeamFormationEntryModel(
      playerId: entry.playerId,
      guestPlayerId: entry.guestPlayerId,
      role: entry.role,
      status: entry.status,
      availability: entry.availability,
      displayName: entry.displayName,
      position: entry.position,
      slotId: entry.slotId,
      slotRole: entry.slotRole,
      lineIndex: entry.lineIndex,
      slotIndex: entry.slotIndex,
      slotX: entry.slotX,
      slotY: entry.slotY,
    );
  }
}
