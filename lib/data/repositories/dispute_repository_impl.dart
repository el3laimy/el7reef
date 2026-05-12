import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/firebase_error_handler.dart';
import '../../core/constants/firebase_paths.dart';
import '../../domain/entities/dispute.dart';
import '../../domain/repositories/dispute_repository.dart';
import '../models/dispute_model.dart';

/// تنفيذ مستودع النزاعات مع Firestore
class DisputeRepositoryImpl implements DisputeRepository {
  final FirebaseFirestore _firestore;

  DisputeRepositoryImpl({FirebaseFirestore? db, FirebaseFirestore? firestore})
    : _firestore = firestore ?? db ?? FirebaseFirestore.instance;

  CollectionReference get _disputesRef =>
      _firestore.collection(FirebasePaths.disputes);

  @override
  Future<void> createDispute(Dispute dispute) async {
    return FirebaseErrorHandler.guard(() async {
      final model = DisputeModel.fromEntity(dispute);
      await _disputesRef.doc(dispute.id).set(model.toJson());
    });
  }

  @override
  Future<Dispute?> getDispute(String disputeId) async {
    return FirebaseErrorHandler.guard(() async {
      final doc = await _disputesRef.doc(disputeId).get();
      if (!doc.exists || doc.data() == null) return null;
      return DisputeModel.fromJson(
        doc.data()! as Map<String, dynamic>,
        doc.id,
      ).toEntity();
    });
  }

  @override
  Future<void> updateDispute(Dispute dispute) async {
    return FirebaseErrorHandler.guard(() async {
      final model = DisputeModel.fromEntity(dispute);
      await _disputesRef.doc(dispute.id).update(model.toJson());
    });
  }

  @override
  Future<List<Dispute>> getMatchDisputes(String matchId) async {
    return FirebaseErrorHandler.guard(() async {
      final snapshot = await _disputesRef
          .where('matchId', isEqualTo: matchId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map(
            (doc) => DisputeModel.fromJson(
              doc.data()! as Map<String, dynamic>,
              doc.id,
            ).toEntity(),
          )
          .toList();
    });
  }

  @override
  Future<List<Dispute>> getTournamentDisputes(
    String tournamentId, {
    int limit = 50,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      final snapshot = await _disputesRef
          .where('tournamentId', isEqualTo: tournamentId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map(
            (doc) => DisputeModel.fromJson(
              doc.data()! as Map<String, dynamic>,
              doc.id,
            ).toEntity(),
          )
          .toList();
    });
  }

  @override
  Future<List<Dispute>> getPlayerDisputes(
    String playerId, {
    int limit = 20,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      final snapshot = await _disputesRef
          .where('raisedBy', isEqualTo: playerId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map(
            (doc) => DisputeModel.fromJson(
              doc.data()! as Map<String, dynamic>,
              doc.id,
            ).toEntity(),
          )
          .toList();
    });
  }
}
