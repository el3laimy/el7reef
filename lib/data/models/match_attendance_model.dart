import '../../core/enums/match_attendance_status.dart';
import '../../domain/entities/match_attendance.dart';

class MatchAttendanceModel {
  final String id;
  final String matchId;
  final String? teamId;
  final String? guestTeamId;
  final String? tournamentRegistrationId;
  final String? checkInId;
  final String? teamMembershipId;
  final String? playerId;
  final String? guestPlayerId;
  final String? claimedFromGuestPlayerId;
  final String status;
  final bool includedInLockedLineup;
  final bool startedMatch;
  final bool played;
  final bool currentlyOnPitch;
  final int? firstEnteredMinute;
  final int? lastExitedMinute;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? markedBy;
  final DateTime? markedAt;
  final String? participationUpdatedBy;
  final DateTime? participationUpdatedAt;
  final String? notes;

  const MatchAttendanceModel({
    required this.id,
    required this.matchId,
    this.teamId,
    this.guestTeamId,
    this.tournamentRegistrationId,
    this.checkInId,
    this.teamMembershipId,
    this.playerId,
    this.guestPlayerId,
    this.claimedFromGuestPlayerId,
    this.status = 'pending',
    this.includedInLockedLineup = false,
    this.startedMatch = false,
    this.played = false,
    this.currentlyOnPitch = false,
    this.firstEnteredMinute,
    this.lastExitedMinute,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.markedBy,
    this.markedAt,
    this.participationUpdatedBy,
    this.participationUpdatedAt,
    this.notes,
  });

  factory MatchAttendanceModel.fromJson(Map<String, dynamic> json, String docId) {
    return MatchAttendanceModel(
      id: docId,
      matchId: json['matchId'] as String? ?? '',
      teamId: json['teamId'] as String?,
      guestTeamId: json['guestTeamId'] as String?,
      tournamentRegistrationId: json['tournamentRegistrationId'] as String?,
      checkInId: json['checkInId'] as String?,
      teamMembershipId: json['teamMembershipId'] as String?,
      playerId: json['playerId'] as String?,
      guestPlayerId: json['guestPlayerId'] as String?,
      claimedFromGuestPlayerId: json['claimedFromGuestPlayerId'] as String?,
      status: json['status'] as String? ?? 'pending',
      includedInLockedLineup:
          json['includedInLockedLineup'] as bool? ?? false,
      startedMatch: json['startedMatch'] as bool? ?? false,
      played: json['played'] as bool? ?? false,
      currentlyOnPitch: json['currentlyOnPitch'] as bool? ?? false,
      firstEnteredMinute: (json['firstEnteredMinute'] as num?)?.toInt(),
      lastExitedMinute: (json['lastExitedMinute'] as num?)?.toInt(),
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['createdAt'] as num).toInt(),
            )
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['updatedAt'] as num).toInt(),
            )
          : DateTime.now(),
      markedBy: json['markedBy'] as String?,
      markedAt: json['markedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['markedAt'] as num).toInt(),
            )
          : null,
      participationUpdatedBy: json['participationUpdatedBy'] as String?,
      participationUpdatedAt: json['participationUpdatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['participationUpdatedAt'] as num).toInt(),
            )
          : null,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'matchId': matchId,
      'teamId': teamId,
      'guestTeamId': guestTeamId,
      'tournamentRegistrationId': tournamentRegistrationId,
      'checkInId': checkInId,
      'teamMembershipId': teamMembershipId,
      'playerId': playerId,
      'guestPlayerId': guestPlayerId,
      'claimedFromGuestPlayerId': claimedFromGuestPlayerId,
      'status': status,
      'includedInLockedLineup': includedInLockedLineup,
      'startedMatch': startedMatch,
      'played': played,
      'currentlyOnPitch': currentlyOnPitch,
      'firstEnteredMinute': firstEnteredMinute,
      'lastExitedMinute': lastExitedMinute,
      'createdBy': createdBy,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'markedBy': markedBy,
      'markedAt': markedAt?.millisecondsSinceEpoch,
      'participationUpdatedBy': participationUpdatedBy,
      'participationUpdatedAt': participationUpdatedAt?.millisecondsSinceEpoch,
      'notes': notes,
    };
  }

  MatchAttendance toEntity() {
    return MatchAttendance(
      id: id,
      matchId: matchId,
      teamId: teamId,
      guestTeamId: guestTeamId,
      tournamentRegistrationId: tournamentRegistrationId,
      checkInId: checkInId,
      teamMembershipId: teamMembershipId,
      playerId: playerId,
      guestPlayerId: guestPlayerId,
      claimedFromGuestPlayerId: claimedFromGuestPlayerId,
      status: _parseStatus(status),
      includedInLockedLineup: includedInLockedLineup,
      startedMatch: startedMatch,
      played: played,
      currentlyOnPitch: currentlyOnPitch,
      firstEnteredMinute: firstEnteredMinute,
      lastExitedMinute: lastExitedMinute,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      markedBy: markedBy,
      markedAt: markedAt,
      participationUpdatedBy: participationUpdatedBy,
      participationUpdatedAt: participationUpdatedAt,
      notes: notes,
    );
  }

  factory MatchAttendanceModel.fromEntity(MatchAttendance attendance) {
    return MatchAttendanceModel(
      id: attendance.id,
      matchId: attendance.matchId,
      teamId: attendance.teamId,
      guestTeamId: attendance.guestTeamId,
      tournamentRegistrationId: attendance.tournamentRegistrationId,
      checkInId: attendance.checkInId,
      teamMembershipId: attendance.teamMembershipId,
      playerId: attendance.playerId,
      guestPlayerId: attendance.guestPlayerId,
      claimedFromGuestPlayerId: attendance.claimedFromGuestPlayerId,
      status: attendance.status.name,
      includedInLockedLineup: attendance.includedInLockedLineup,
      startedMatch: attendance.startedMatch,
      played: attendance.played,
      currentlyOnPitch: attendance.currentlyOnPitch,
      firstEnteredMinute: attendance.firstEnteredMinute,
      lastExitedMinute: attendance.lastExitedMinute,
      createdBy: attendance.createdBy,
      createdAt: attendance.createdAt,
      updatedAt: attendance.updatedAt,
      markedBy: attendance.markedBy,
      markedAt: attendance.markedAt,
      participationUpdatedBy: attendance.participationUpdatedBy,
      participationUpdatedAt: attendance.participationUpdatedAt,
      notes: attendance.notes,
    );
  }

  static MatchAttendanceStatus _parseStatus(String value) {
    return MatchAttendanceStatus.values.firstWhere(
      (entry) => entry.name == value,
      orElse: () => MatchAttendanceStatus.pending,
    );
  }
}
