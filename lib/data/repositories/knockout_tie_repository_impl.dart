import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_paths.dart';
import '../../data/models/knockout_tie_model.dart';
import '../../domain/entities/knockout_tie.dart';
import '../../domain/repositories/knockout_tie_repository.dart';

class KnockoutTieRepositoryImpl implements KnockoutTieRepository {
  final FirebaseFirestore _firestore;

  KnockoutTieRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _tiesRef =>
      _firestore.collection(FirebasePaths.knockoutTies);

  @override
  Future<KnockoutTie?> getTie(String tieId) async {
    final doc = await _tiesRef.doc(tieId).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return KnockoutTieModel.fromJson(doc.data()!, doc.id).toEntity();
  }

  @override
  Future<void> createTie(KnockoutTie tie) async {
    await _tiesRef.doc(tie.id).set(KnockoutTieModel.fromEntity(tie).toJson());
  }

  @override
  Future<void> updateTie(KnockoutTie tie) async {
    await _tiesRef
        .doc(tie.id)
        .update(KnockoutTieModel.fromEntity(tie).toJson());
  }

  @override
  Future<List<KnockoutTie>> getBracketTies(String bracketId) async {
    final snapshot = await _tiesRef
        .where('bracketId', isEqualTo: bracketId)
        .get();
    final ties = snapshot.docs
        .map((doc) => KnockoutTieModel.fromJson(doc.data(), doc.id).toEntity())
        .toList(growable: true);
    ties.sort((left, right) {
      if (left.roundIndex != right.roundIndex) {
        return left.roundIndex.compareTo(right.roundIndex);
      }
      return left.slotNumber.compareTo(right.slotNumber);
    });
    return ties;
  }
}
