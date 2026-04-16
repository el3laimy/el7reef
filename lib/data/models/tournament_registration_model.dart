import '../../core/enums/tournament_registration_mode.dart';
import '../../core/enums/tournament_registration_status.dart';
import '../../domain/entities/tournament_registration.dart';

class TournamentRegistrationModel {
  final String id;
  final String tournamentId;
  final String? teamId;
  final String? guestTeamId;
  final String? claimedFromGuestTeamId;
  final String mode;
  final String status;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? verifiedBy;
  final DateTime? verifiedAt;
  final String? notes;

  const TournamentRegistrationModel({
    required this.id,
    required this.tournamentId,
    this.teamId,
    this.guestTeamId,
    this.claimedFromGuestTeamId,
    this.mode = 'hybrid',
    this.status = 'pending',
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.verifiedBy,
    this.verifiedAt,
    this.notes,
  });

  factory TournamentRegistrationModel.fromJson(
    Map<String, dynamic> json,
    String docId,
  ) {
    return TournamentRegistrationModel(
      id: docId,
      tournamentId: json['tournamentId'] as String? ?? '',
      teamId: json['teamId'] as String?,
      guestTeamId: json['guestTeamId'] as String?,
      claimedFromGuestTeamId: json['claimedFromGuestTeamId'] as String?,
      mode: json['mode'] as String? ?? 'hybrid',
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
      'tournamentId': tournamentId,
      'teamId': teamId,
      'guestTeamId': guestTeamId,
      'claimedFromGuestTeamId': claimedFromGuestTeamId,
      'mode': mode,
      'status': status,
      'createdBy': createdBy,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'verifiedBy': verifiedBy,
      'verifiedAt': verifiedAt?.millisecondsSinceEpoch,
      'notes': notes,
    };
  }

  TournamentRegistration toEntity() {
    return TournamentRegistration(
      id: id,
      tournamentId: tournamentId,
      teamId: teamId,
      guestTeamId: guestTeamId,
      claimedFromGuestTeamId: claimedFromGuestTeamId,
      mode: _parseMode(mode),
      status: _parseStatus(status),
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      verifiedBy: verifiedBy,
      verifiedAt: verifiedAt,
      notes: notes,
    );
  }

  factory TournamentRegistrationModel.fromEntity(
    TournamentRegistration registration,
  ) {
    return TournamentRegistrationModel(
      id: registration.id,
      tournamentId: registration.tournamentId,
      teamId: registration.teamId,
      guestTeamId: registration.guestTeamId,
      claimedFromGuestTeamId: registration.claimedFromGuestTeamId,
      mode: registration.mode.name,
      status: registration.status.name,
      createdBy: registration.createdBy,
      createdAt: registration.createdAt,
      updatedAt: registration.updatedAt,
      verifiedBy: registration.verifiedBy,
      verifiedAt: registration.verifiedAt,
      notes: registration.notes,
    );
  }

  static TournamentRegistrationStatus _parseStatus(String value) {
    return TournamentRegistrationStatus.values.firstWhere(
      (entry) => entry.name == value,
      orElse: () => TournamentRegistrationStatus.pending,
    );
  }

  static TournamentRegistrationMode _parseMode(String value) {
    return TournamentRegistrationMode.values.firstWhere(
      (entry) => entry.name == value,
      orElse: () => TournamentRegistrationMode.hybrid,
    );
  }
}
