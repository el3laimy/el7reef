import '../../domain/entities/team_formation_template.dart';
import 'team_formation_entry_model.dart';

class TeamFormationTemplateModel {
  final String id;
  final String teamId;
  final String name;
  final String? formationLabel;
  final List<TeamFormationEntryModel> entries;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TeamFormationTemplateModel({
    required this.id,
    required this.teamId,
    required this.name,
    this.formationLabel,
    required this.entries,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TeamFormationTemplateModel.fromJson(
    Map<String, dynamic> json,
    String docId,
  ) {
    return TeamFormationTemplateModel(
      id: docId,
      teamId: json['teamId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      formationLabel: json['formationLabel'] as String?,
      entries: (json['entries'] as List<dynamic>? ?? [])
          .map((item) => TeamFormationEntryModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(growable: false),
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['createdAt'] as num).toInt())
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['updatedAt'] as num).toInt())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'teamId': teamId,
      'name': name,
      'formationLabel': formationLabel,
      'entries': entries.map((entry) => entry.toJson()).toList(growable: false),
      'createdBy': createdBy,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  TeamFormationTemplate toEntity() {
    return TeamFormationTemplate(
      id: id,
      teamId: teamId,
      name: name,
      formationLabel: formationLabel,
      entries: entries.map((entry) => entry.toEntity()).toList(growable: false),
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory TeamFormationTemplateModel.fromEntity(TeamFormationTemplate template) {
    return TeamFormationTemplateModel(
      id: template.id,
      teamId: template.teamId,
      name: template.name,
      formationLabel: template.formationLabel,
      entries: template.entries
          .map(TeamFormationEntryModel.fromEntity)
          .toList(growable: false),
      createdBy: template.createdBy,
      createdAt: template.createdAt,
      updatedAt: template.updatedAt,
    );
  }
}
