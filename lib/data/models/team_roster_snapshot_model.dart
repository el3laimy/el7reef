import '../../domain/entities/team_roster_snapshot.dart';
import 'team_formation_entry_model.dart';

class TeamRosterSnapshotModel {
  final String id;
  final String teamId;
  final String label;
  final String? formationLabel;
  final String? sourceTemplateId;
  final List<TeamFormationEntryModel> entries;
  final String createdBy;
  final DateTime createdAt;

  const TeamRosterSnapshotModel({
    required this.id,
    required this.teamId,
    required this.label,
    this.formationLabel,
    this.sourceTemplateId,
    required this.entries,
    required this.createdBy,
    required this.createdAt,
  });

  factory TeamRosterSnapshotModel.fromJson(
    Map<String, dynamic> json,
    String docId,
  ) {
    return TeamRosterSnapshotModel(
      id: docId,
      teamId: json['teamId'] as String? ?? '',
      label: json['label'] as String? ?? '',
      formationLabel: json['formationLabel'] as String?,
      sourceTemplateId: json['sourceTemplateId'] as String?,
      entries: (json['entries'] as List<dynamic>? ?? [])
          .map((item) => TeamFormationEntryModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(growable: false),
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['createdAt'] as num).toInt())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'teamId': teamId,
      'label': label,
      'formationLabel': formationLabel,
      'sourceTemplateId': sourceTemplateId,
      'entries': entries.map((entry) => entry.toJson()).toList(growable: false),
      'createdBy': createdBy,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  TeamRosterSnapshot toEntity() {
    return TeamRosterSnapshot(
      id: id,
      teamId: teamId,
      label: label,
      formationLabel: formationLabel,
      sourceTemplateId: sourceTemplateId,
      entries: entries.map((entry) => entry.toEntity()).toList(growable: false),
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }

  factory TeamRosterSnapshotModel.fromEntity(TeamRosterSnapshot snapshot) {
    return TeamRosterSnapshotModel(
      id: snapshot.id,
      teamId: snapshot.teamId,
      label: snapshot.label,
      formationLabel: snapshot.formationLabel,
      sourceTemplateId: snapshot.sourceTemplateId,
      entries: snapshot.entries
          .map(TeamFormationEntryModel.fromEntity)
          .toList(growable: false),
      createdBy: snapshot.createdBy,
      createdAt: snapshot.createdAt,
    );
  }
}
