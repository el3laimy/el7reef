import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firebase_paths.dart';
import '../../domain/entities/match_invitation.dart';
import '../../domain/repositories/match_invitation_repository.dart';
import '../models/match_invitation_model.dart';

class MatchInvitationRepositoryImpl implements MatchInvitationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _invitationsRef =>
      _firestore.collection(FirebasePaths.matchInvitations);

  @override
  Future<void> createInvitation(MatchInvitation invitation) async {
    final model = MatchInvitationModel(
      id: invitation.id,
      matchId: invitation.matchId,
      senderId: invitation.senderId,
      receiverId: invitation.receiverId,
      side: invitation.side,
      status: invitation.status,
      createdAt: invitation.createdAt,
      respondedAt: invitation.respondedAt,
    );
    await _invitationsRef.doc(invitation.id).set(model.toJson());
  }

  @override
  Future<void> updateInvitationStatus(String id, InvitationStatus status) async {
    await _invitationsRef.doc(id).update({
      'status': status.name,
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<MatchInvitation?> getInvitation(String id) async {
    final doc = await _invitationsRef.doc(id).get();
    if (doc.exists && doc.data() != null) {
      return MatchInvitationModel.fromJson(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  @override
  Future<List<MatchInvitation>> getPendingInvitationsForUser(String userId) async {
    final snapshot = await _invitationsRef
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: InvitationStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => MatchInvitationModel.fromJson(
            doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  @override
  Future<List<MatchInvitation>> getInvitationsForMatch(String matchId) async {
    final snapshot = await _invitationsRef
        .where('matchId', isEqualTo: matchId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => MatchInvitationModel.fromJson(
            doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  @override
  Future<void> cancelInvitation(String id) async {
    await updateInvitationStatus(id, InvitationStatus.cancelled);
  }
}
