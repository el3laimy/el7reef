import '../entities/team_formation_template.dart';

abstract class TeamFormationTemplateRepository {
  Future<TeamFormationTemplate?> getTemplate(String templateId);
  Future<List<TeamFormationTemplate>> getTeamTemplates(String teamId);
  Future<void> createTemplate(TeamFormationTemplate template);
  Future<void> updateTemplate(TeamFormationTemplate template);
  Future<void> deleteTemplate(String templateId);
}
