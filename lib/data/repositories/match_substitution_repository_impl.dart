import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/firebase_error_handler.dart';
import '../../core/constants/firebase_paths.dart';
import '../../domain/entities/match_substitution.dart';
import '../../domain/repositories/match_substitution_repository.dart';
import '../models/match_substitution_model.dart';

class MatchSubstitutionRepositoryImpl implements MatchSubstitutionRepository {
  final FirebaseFirestore _firestore;

  MatchSubstitutionRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _substitutionsRef =>
      _firestore.collection(FirebasePaths.matchSubstitutions);

  @override
  Future<MatchSubstitution?> getSubstitution(String substitutionId) async {
    return FirebaseErrorHandler.guard(() async {
      final doc = await _substitutionsRef.doc(substitutionId).get();
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return MatchSubstitutionModel.fromJson(doc.data()!, doc.id).toEntity();
    });
  }

  @override
  Future<void> createSubstitution(MatchSubstitution substitution) async {
    return FirebaseErrorHandler.guard(() async {
      final model = MatchSubstitutionModel.fromEntity(substitution);
      await _substitutionsRef.doc(substitution.id).set(model.toJson());
    });
  }

  @override
  Future<List<MatchSubstitution>> getMatchSubstitutions(String matchId) async {
    return FirebaseErrorHandler.guard(() async {
      final snapshot =
          await _substitutionsRef.where('matchId', isEqualTo: matchId).get();
      final substitutions = snapshot.docs
          .map((doc) => MatchSubstitutionModel.fromJson(doc.data(), doc.id).toEntity())
          .toList(growable: true);
      substitutions.sort((left, right) => left.createdAt.compareTo(right.createdAt));
      return substitutions;
    });
  }

  @override
  Future<List<MatchSubstitution>> getTeamSubstitutions({
    required String matchId,
    String? teamId,
    String? guestTeamId,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      if ((teamId != null) == (guestTeamId != null)) {
        throw ArgumentError(
          'Exactly one of teamId or guestTeamId must be provided.',
        );
      }

      Query<Map<String, dynamic>> query =
          _substitutionsRef.where('matchId', isEqualTo: matchId);
      if (teamId != null) {
        query = query.where('teamId', isEqualTo: teamId);
      } else {
        query = query.where('guestTeamId', isEqualTo: guestTeamId);
      }

      final snapshot = await query.get();
      final substitutions = snapshot.docs
          .map((doc) => MatchSubstitutionModel.fromJson(doc.data(), doc.id).toEntity())
          .toList(growable: true);
      substitutions.sort((left, right) => left.createdAt.compareTo(right.createdAt));
      return substitutions;
    });
  }
}
