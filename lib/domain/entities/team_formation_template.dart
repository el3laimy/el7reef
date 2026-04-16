import 'team_formation_entry.dart';

class TeamFormationTemplate {
  final String id;
  final String teamId;
  final String name;
  final String? formationLabel;
  final List<TeamFormationEntry> entries;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TeamFormationTemplate({
    required this.id,
    required this.teamId,
    required this.name,
    this.formationLabel,
    required this.entries,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  int get starterCount =>
      entries.where((entry) => entry.status.name == 'starter').length;

  int get benchCount =>
      entries.where((entry) => entry.status.name == 'bench').length;

  int get inactiveCount =>
      entries.where((entry) => entry.status.name == 'inactive').length;

  String get summaryLabel {
    final effectiveLabel = formationLabel?.trim();
    if (effectiveLabel != null && effectiveLabel.isNotEmpty) {
      return effectiveLabel;
    }
    return 'أساسي $starterCount • احتياط $benchCount • غير نشط $inactiveCount';
  }

  TeamFormationTemplate copyWith({
    String? id,
    String? teamId,
    String? name,
    Object? formationLabel = _unset,
    List<TeamFormationEntry>? entries,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TeamFormationTemplate(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      name: name ?? this.name,
      formationLabel: identical(formationLabel, _unset)
          ? this.formationLabel
          : formationLabel as String?,
      entries: entries ?? this.entries,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

const Object _unset = Object();
