import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_paths.dart';
import '../../core/enums/claim_target_type.dart';
import '../../domain/entities/claim_code.dart';
import '../../domain/repositories/claim_code_repository.dart';
import '../models/claim_code_model.dart';

class ClaimCodeRepositoryImpl implements ClaimCodeRepository {
  final FirebaseFirestore _firestore;

  ClaimCodeRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _claimCodesRef =>
      _firestore.collection(FirebasePaths.claimCodes);

  @override
  Future<ClaimCode?> getClaimCode(String code) async {
    final doc = await _claimCodesRef.doc(code).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return ClaimCodeModel.fromJson(doc.data()!, doc.id).toEntity();
  }

  @override
  Future<void> createClaimCode(ClaimCode claimCode) async {
    final model = ClaimCodeModel.fromEntity(claimCode);
    await _claimCodesRef.doc(claimCode.code).set(model.toJson());
  }

  @override
  Future<void> updateClaimCode(ClaimCode claimCode) async {
    final model = ClaimCodeModel.fromEntity(claimCode);
    await _claimCodesRef.doc(claimCode.code).update(model.toJson());
  }

  @override
  Future<ClaimCode?> getActiveClaimCodeForTarget({
    required ClaimTargetType targetType,
    required String targetId,
    String? tournamentId,
  }) async {
    Query<Map<String, dynamic>> query = _claimCodesRef
        .where('targetType', isEqualTo: targetType.name)
        .where('targetId', isEqualTo: targetId)
        .where('status', isEqualTo: 'active');

    if (tournamentId != null && tournamentId.isNotEmpty) {
      query = query.where('tournamentId', isEqualTo: tournamentId);
    }

    final snapshot = await query.orderBy('createdAt', descending: true).limit(1).get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    final doc = snapshot.docs.first;
    return ClaimCodeModel.fromJson(doc.data(), doc.id).toEntity();
  }
}
