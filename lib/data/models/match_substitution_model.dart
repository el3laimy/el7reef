import '../../domain/entities/match_substitution.dart';

class MatchSubstitutionModel {
  final String id;
  final String matchId;
  final String? teamId;
  final String? guestTeamId;
  final String? tournamentRegistrationId;
  final String? checkInId;
  final String? lineupSnapshotId;
  final String outgoingAttendanceId;
  final String incomingAttendanceId;
  final int minute;
  final String createdBy;
  final DateTime createdAt;
  final String? notes;

  const MatchSubstitutionModel({
    required this.id,
    required this.matchId,
    this.teamId,
    this.guestTeamId,
    this.tournamentRegistrationId,
    this.checkInId,
    this.lineupSnapshotId,
    required this.outgoingAttendanceId,
    required this.incomingAttendanceId,
    required this.minute,
    required this.createdBy,
    required this.createdAt,
    this.notes,
  });

  factory MatchSubstitutionModel.fromJson(
    Map<String, dynamic> json,
    String docId,
  ) {
    return MatchSubstitutionModel(
      id: docId,
      matchId: json['matchId'] as String? ?? '',
      teamId: json['teamId'] as String?,
      guestTeamId: json['guestTeamId'] as String?,
      tournamentRegistrationId: json['tournamentRegistrationId'] as String?,
      checkInId: json['checkInId'] as String?,
      lineupSnapshotId: json['lineupSnapshotId'] as String?,
      outgoingAttendanceId: json['outgoingAttendanceId'] as String? ?? '',
      incomingAttendanceId: json['incomingAttendanceId'] as String? ?? '',
      minute: (json['minute'] as num?)?.toInt() ?? 0,
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['createdAt'] as num).toInt(),
            )
          : DateTime.now(),
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
      'lineupSnapshotId': lineupSnapshotId,
      'outgoingAttendanceId': outgoingAttendanceId,
      'incomingAttendanceId': incomingAttendanceId,
      'minute': minute,
      'createdBy': createdBy,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'notes': notes,
    };
  }

  MatchSubstitution toEntity() {
    return MatchSubstitution(
      id: id,
      matchId: matchId,
      teamId: teamId,
      guestTeamId: guestTeamId,
      tournamentRegistrationId: tournamentRegistrationId,
      checkInId: checkInId,
      lineupSnapshotId: lineupSnapshotId,
      outgoingAttendanceId: outgoingAttendanceId,
      incomingAttendanceId: incomingAttendanceId,
      minute: minute,
      createdBy: createdBy,
      createdAt: createdAt,
      notes: notes,
    );
  }

  factory MatchSubstitutionModel.fromEntity(MatchSubstitution substitution) {
    return MatchSubstitutionModel(
      id: substitution.id,
      matchId: substitution.matchId,
      teamId: substitution.teamId,
      guestTeamId: substitution.guestTeamId,
      tournamentRegistrationId: substitution.tournamentRegistrationId,
      checkInId: substitution.checkInId,
      lineupSnapshotId: substitution.lineupSnapshotId,
      outgoingAttendanceId: substitution.outgoingAttendanceId,
      incomingAttendanceId: substitution.incomingAttendanceId,
      minute: substitution.minute,
      createdBy: substitution.createdBy,
      createdAt: substitution.createdAt,
      notes: substitution.notes,
    );
  }
}
