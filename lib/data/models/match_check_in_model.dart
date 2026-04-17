import '../../core/enums/match_check_in_status.dart';
import '../../domain/entities/match_check_in.dart';

class MatchCheckInModel {
  final String id;
  final String matchId;
  final String? teamId;
  final String? guestTeamId;
  final String? tournamentRegistrationId;
  final String status;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? checkedInBy;
  final DateTime? checkedInAt;
  final String? verifiedBy;
  final DateTime? verifiedAt;
  final String? notes;

  const MatchCheckInModel({
    required this.id,
    required this.matchId,
    this.teamId,
    this.guestTeamId,
    this.tournamentRegistrationId,
    this.status = 'pending',
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.checkedInBy,
    this.checkedInAt,
    this.verifiedBy,
    this.verifiedAt,
    this.notes,
  });

  factory MatchCheckInModel.fromJson(Map<String, dynamic> json, String docId) {
    return MatchCheckInModel(
      id: docId,
      matchId: json['matchId'] as String? ?? '',
      teamId: json['teamId'] as String?,
      guestTeamId: json['guestTeamId'] as String?,
      tournamentRegistrationId: json['tournamentRegistrationId'] as String?,
      status: json['status'] as String? ?? 'pending',
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
      checkedInBy: json['checkedInBy'] as String?,
      checkedInAt: json['checkedInAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['checkedInAt'] as num).toInt(),
            )
          : null,
      verifiedBy: json['verifiedBy'] as String?,
      verifiedAt: json['verifiedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['verifiedAt'] as num).toInt(),
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
      'status': status,
      'createdBy': createdBy,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'checkedInBy': checkedInBy,
      'checkedInAt': checkedInAt?.millisecondsSinceEpoch,
      'verifiedBy': verifiedBy,
      'verifiedAt': verifiedAt?.millisecondsSinceEpoch,
      'notes': notes,
    };
  }

  MatchCheckIn toEntity() {
    return MatchCheckIn(
      id: id,
      matchId: matchId,
      teamId: teamId,
      guestTeamId: guestTeamId,
      tournamentRegistrationId: tournamentRegistrationId,
      status: _parseStatus(status),
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      checkedInBy: checkedInBy,
      checkedInAt: checkedInAt,
      verifiedBy: verifiedBy,
      verifiedAt: verifiedAt,
      notes: notes,
    );
  }

  factory MatchCheckInModel.fromEntity(MatchCheckIn checkIn) {
    return MatchCheckInModel(
      id: checkIn.id,
      matchId: checkIn.matchId,
      teamId: checkIn.teamId,
      guestTeamId: checkIn.guestTeamId,
      tournamentRegistrationId: checkIn.tournamentRegistrationId,
      status: checkIn.status.name,
      createdBy: checkIn.createdBy,
      createdAt: checkIn.createdAt,
      updatedAt: checkIn.updatedAt,
      checkedInBy: checkIn.checkedInBy,
      checkedInAt: checkIn.checkedInAt,
      verifiedBy: checkIn.verifiedBy,
      verifiedAt: checkIn.verifiedAt,
      notes: checkIn.notes,
    );
  }

  static MatchCheckInStatus _parseStatus(String value) {
    return MatchCheckInStatus.values.firstWhere(
      (entry) => entry.name == value,
      orElse: () => MatchCheckInStatus.pending,
    );
  }
}
