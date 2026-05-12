import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/firebase_error_handler.dart';
import '../../core/constants/firebase_paths.dart';
import '../../core/enums/team_membership_status.dart';
import '../../domain/entities/team_membership.dart';
import '../../domain/repositories/team_membership_repository.dart';
import '../models/team_membership_model.dart';

class TeamMembershipRepositoryImpl implements TeamMembershipRepository {
  final FirebaseFirestore _firestore;

  TeamMembershipRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _membershipsRef =>
      _firestore.collection(FirebasePaths.teamMemberships);

  @override
  Future<TeamMembership?> getMembership(String membershipId) async {
    return FirebaseErrorHandler.guard(() async {
      final doc = await _membershipsRef.doc(membershipId).get();
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return TeamMembershipModel.fromJson(doc.data()!, doc.id).toEntity();
    });
  }

  @override
  Future<void> createMembership(TeamMembership membership) async {
    return FirebaseErrorHandler.guard(() async {
      final model = TeamMembershipModel.fromEntity(membership);
      await _membershipsRef.doc(membership.id).set(model.toJson());
    });
  }

  @override
  Future<void> updateMembership(TeamMembership membership) async {
    return FirebaseErrorHandler.guard(() async {
      final model = TeamMembershipModel.fromEntity(membership);
      await _membershipsRef.doc(membership.id).update(model.toJson());
    });
  }

  @override
  Future<List<TeamMembership>> getTeamMemberships(
    String teamId, {
    bool includeInactive = false,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      final snapshot = await _membershipsRef
          .where('teamId', isEqualTo: teamId)
          .orderBy('joinedAt')
          .get();

      final memberships = snapshot.docs
          .map((doc) => TeamMembershipModel.fromJson(doc.data(), doc.id).toEntity())
          .toList(growable: false);

      if (includeInactive) {
        return memberships;
      }

      return memberships
          .where((membership) => membership.status != TeamMembershipStatus.inactive)
          .toList(growable: false);
    });
  }

  @override
  Future<TeamMembership?> getMembershipByPlayerId({
    required String teamId,
    required String playerId,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      final snapshot = await _membershipsRef
          .where('teamId', isEqualTo: teamId)
          .where('playerId', isEqualTo: playerId)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) {
        return null;
      }
      final doc = snapshot.docs.first;
      return TeamMembershipModel.fromJson(doc.data(), doc.id).toEntity();
    });
  }

  @override
  Future<TeamMembership?> getMembershipByGuestPlayerId({
    required String teamId,
    required String guestPlayerId,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      final snapshot = await _membershipsRef
          .where('teamId', isEqualTo: teamId)
          .where('guestPlayerId', isEqualTo: guestPlayerId)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) {
        return null;
      }
      final doc = snapshot.docs.first;
      return TeamMembershipModel.fromJson(doc.data(), doc.id).toEntity();
    });
  }
}
