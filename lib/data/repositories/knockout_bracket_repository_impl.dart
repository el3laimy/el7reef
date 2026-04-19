import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_paths.dart';
import '../../data/models/knockout_bracket_model.dart';
import '../../domain/entities/knockout_bracket.dart';
import '../../domain/repositories/knockout_bracket_repository.dart';

class KnockoutBracketRepositoryImpl implements KnockoutBracketRepository {
  final FirebaseFirestore _firestore;

  KnockoutBracketRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _bracketsRef =>
      _firestore.collection(FirebasePaths.knockoutBrackets);

  @override
  Future<KnockoutBracket?> getBracket(String bracketId) async {
    final doc = await _bracketsRef.doc(bracketId).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return KnockoutBracketModel.fromJson(doc.data()!, doc.id).toEntity();
  }

  @override
  Future<void> createBracket(KnockoutBracket bracket) async {
    await _bracketsRef
        .doc(bracket.id)
        .set(KnockoutBracketModel.fromEntity(bracket).toJson());
  }

  @override
  Future<void> updateBracket(KnockoutBracket bracket) async {
    await _bracketsRef
        .doc(bracket.id)
        .update(KnockoutBracketModel.fromEntity(bracket).toJson());
  }
}
