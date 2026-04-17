import '../../domain/entities/match_lineup_snapshot.dart';
import 'match_lineup_entry_model.dart';

class MatchLineupSnapshotModel {
  final String id;
  final String matchId;
  final String? teamId;
  final String? guestTeamId;
  final String? tournamentRegistrationId;
  final String? checkInId;
  final List<MatchLineupEntryModel> starters;
  final List<MatchLineupEntryModel> bench;
  final String lockedBy;
  final DateTime lockedAt;
  final String? formationLabel;
  final String? notes;

  const MatchLineupSnapshotModel({
    required this.id,
    required this.matchId,
    this.teamId,
    this.guestTeamId,
    this.tournamentRegistrationId,
    this.checkInId,
    required this.starters,
    this.bench = const [],
    required this.lockedBy,
    required this.lockedAt,
    this.formationLabel,
    this.notes,
  });

  factory MatchLineupSnapshotModel.fromJson(
    Map<String, dynamic> json,
    String docId,
  ) {
    return MatchLineupSnapshotModel(
      id: docId,
      matchId: json['matchId'] as String? ?? '',
      teamId: json['teamId'] as String?,
      guestTeamId: json['guestTeamId'] as String?,
      tournamentRegistrationId: json['tournamentRegistrationId'] as String?,
      checkInId: json['checkInId'] as String?,
      starters: (json['starters'] as List<dynamic>? ?? const [])
          .map((item) => MatchLineupEntryModel.fromJson(
                item as Map<String, dynamic>,
              ))
          .toList(),
      bench: (json['bench'] as List<dynamic>? ?? const [])
          .map((item) => MatchLineupEntryModel.fromJson(
                item as Map<String, dynamic>,
              ))
          .toList(),
      lockedBy: json['lockedBy'] as String? ?? '',
      lockedAt: json['lockedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['lockedAt'] as num).toInt(),
            )
          : DateTime.now(),
      formationLabel: json['formationLabel'] as String?,
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
      'starters': starters.map((entry) => entry.toJson()).toList(),
      'bench': bench.map((entry) => entry.toJson()).toList(),
      'lockedBy': lockedBy,
      'lockedAt': lockedAt.millisecondsSinceEpoch,
      'formationLabel': formationLabel,
      'notes': notes,
    };
  }

  MatchLineupSnapshot toEntity() {
    return MatchLineupSnapshot(
      id: id,
      matchId: matchId,
      teamId: teamId,
      guestTeamId: guestTeamId,
      tournamentRegistrationId: tournamentRegistrationId,
      checkInId: checkInId,
      starters: starters.map((entry) => entry.toEntity()).toList(growable: false),
      bench: bench.map((entry) => entry.toEntity()).toList(growable: false),
      lockedBy: lockedBy,
      lockedAt: lockedAt,
      formationLabel: formationLabel,
      notes: notes,
    );
  }

  factory MatchLineupSnapshotModel.fromEntity(MatchLineupSnapshot snapshot) {
    return MatchLineupSnapshotModel(
      id: snapshot.id,
      matchId: snapshot.matchId,
      teamId: snapshot.teamId,
      guestTeamId: snapshot.guestTeamId,
      tournamentRegistrationId: snapshot.tournamentRegistrationId,
      checkInId: snapshot.checkInId,
      starters: snapshot.starters
          .map(MatchLineupEntryModel.fromEntity)
          .toList(growable: false),
      bench: snapshot.bench
          .map(MatchLineupEntryModel.fromEntity)
          .toList(growable: false),
      lockedBy: snapshot.lockedBy,
      lockedAt: snapshot.lockedAt,
      formationLabel: snapshot.formationLabel,
      notes: snapshot.notes,
    );
  }
}
