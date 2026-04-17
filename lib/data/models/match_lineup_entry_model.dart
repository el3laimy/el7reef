import '../../core/enums/match_attendance_status.dart';
import '../../core/enums/team_member_availability.dart';
import '../../core/enums/team_membership_role.dart';
import '../../domain/entities/match_lineup_entry.dart';

class MatchLineupEntryModel {
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

  const MatchLineupEntryModel({
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
  });

  factory MatchLineupEntryModel.fromJson(Map<String, dynamic> json) {
    return MatchLineupEntryModel(
      attendanceId: json['attendanceId'] as String? ?? '',
      teamMembershipId: json['teamMembershipId'] as String?,
      playerId: json['playerId'] as String?,
      guestPlayerId: json['guestPlayerId'] as String?,
      claimedFromGuestPlayerId: json['claimedFromGuestPlayerId'] as String?,
      role: TeamMembershipRole.values.firstWhere(
        (value) => value.name ==
            (json['role'] as String? ?? TeamMembershipRole.player.name),
        orElse: () => TeamMembershipRole.player,
      ),
      availability: TeamMemberAvailability.values.firstWhere(
        (value) => value.name ==
            (json['availability'] as String? ??
                TeamMemberAvailability.available.name),
        orElse: () => TeamMemberAvailability.available,
      ),
      attendanceStatus: MatchAttendanceStatus.values.firstWhere(
        (value) => value.name ==
            (json['attendanceStatus'] as String? ??
                MatchAttendanceStatus.pending.name),
        orElse: () => MatchAttendanceStatus.pending,
      ),
      displayName: json['displayName'] as String? ?? '',
      position: json['position'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'attendanceId': attendanceId,
      'teamMembershipId': teamMembershipId,
      'playerId': playerId,
      'guestPlayerId': guestPlayerId,
      'claimedFromGuestPlayerId': claimedFromGuestPlayerId,
      'role': role.name,
      'availability': availability.name,
      'attendanceStatus': attendanceStatus.name,
      'displayName': displayName,
      'position': position,
    };
  }

  MatchLineupEntry toEntity() {
    return MatchLineupEntry(
      attendanceId: attendanceId,
      teamMembershipId: teamMembershipId,
      playerId: playerId,
      guestPlayerId: guestPlayerId,
      claimedFromGuestPlayerId: claimedFromGuestPlayerId,
      role: role,
      availability: availability,
      attendanceStatus: attendanceStatus,
      displayName: displayName,
      position: position,
    );
  }

  factory MatchLineupEntryModel.fromEntity(MatchLineupEntry entry) {
    return MatchLineupEntryModel(
      attendanceId: entry.attendanceId,
      teamMembershipId: entry.teamMembershipId,
      playerId: entry.playerId,
      guestPlayerId: entry.guestPlayerId,
      claimedFromGuestPlayerId: entry.claimedFromGuestPlayerId,
      role: entry.role,
      availability: entry.availability,
      attendanceStatus: entry.attendanceStatus,
      displayName: entry.displayName,
      position: entry.position,
    );
  }
}
