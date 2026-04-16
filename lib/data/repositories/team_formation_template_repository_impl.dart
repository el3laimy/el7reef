import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_paths.dart';
import '../../domain/entities/team_formation_template.dart';
import '../../domain/repositories/team_formation_template_repository.dart';
import '../models/team_formation_template_model.dart';

class TeamFormationTemplateRepositoryImpl
    implements TeamFormationTemplateRepository {
  final FirebaseFirestore _firestore;

  TeamFormationTemplateRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _templatesRef =>
      _firestore.collection(FirebasePaths.teamFormationTemplates);

  @override
  Future<TeamFormationTemplate?> getTemplate(String templateId) async {
    final doc = await _templatesRef.doc(templateId).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return TeamFormationTemplateModel.fromJson(doc.data()!, doc.id).toEntity();
  }

  @override
  Future<List<TeamFormationTemplate>> getTeamTemplates(String teamId) async {
    final snapshot = await _templatesRef
        .where('teamId', isEqualTo: teamId)
        .orderBy('updatedAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => TeamFormationTemplateModel.fromJson(doc.data(), doc.id).toEntity())
        .toList(growable: false);
  }

  @override
  Future<void> createTemplate(TeamFormationTemplate template) async {
    final model = TeamFormationTemplateModel.fromEntity(template);
    await _templatesRef.doc(template.id).set(model.toJson());
  }

  @override
  Future<void> updateTemplate(TeamFormationTemplate template) async {
    final model = TeamFormationTemplateModel.fromEntity(template);
    await _templatesRef.doc(template.id).update(model.toJson());
  }

  @override
  Future<void> deleteTemplate(String templateId) async {
    await _templatesRef.doc(templateId).delete();
  }
}
