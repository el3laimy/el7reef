import 'team_formation_entry.dart';

class TeamRosterSnapshot {
  final String id;
  final String teamId;
  final String label;
  final String? formationLabel;
  final String? sourceTemplateId;
  final List<TeamFormationEntry> entries;
  final String createdBy;
  final DateTime createdAt;

  const TeamRosterSnapshot({
    required this.id,
    required this.teamId,
    required this.label,
    this.formationLabel,
    this.sourceTemplateId,
    required this.entries,
    required this.createdBy,
    required this.createdAt,
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
}
