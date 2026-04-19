import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_paths.dart';
import '../../core/enums/guest_claim_status.dart';
import '../../domain/entities/guest_team.dart';
import '../../domain/repositories/guest_team_repository.dart';
import '../models/guest_team_model.dart';

class GuestTeamRepositoryImpl implements GuestTeamRepository {
  final FirebaseFirestore _firestore;

  GuestTeamRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _guestTeamsRef =>
      _firestore.collection(FirebasePaths.guestTeams);

  @override
  Future<GuestTeam?> getGuestTeam(String guestTeamId) async {
    final doc = await _guestTeamsRef.doc(guestTeamId).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return GuestTeamModel.fromJson(doc.data()!, doc.id).toEntity();
  }

  @override
  Future<void> createGuestTeam(GuestTeam guestTeam) async {
    final model = GuestTeamModel.fromEntity(guestTeam);
    await _guestTeamsRef.doc(guestTeam.id).set(model.toJson());
  }

  @override
  Future<void> updateGuestTeam(GuestTeam guestTeam) async {
    final model = GuestTeamModel.fromEntity(guestTeam);
    await _guestTeamsRef.doc(guestTeam.id).update(model.toJson());
  }

  @override
  Future<List<GuestTeam>> getTournamentGuestTeams(String tournamentId) async {
    final snapshot = await _guestTeamsRef
        .where('tournamentIds', arrayContains: tournamentId)
        .orderBy('createdAt')
        .get();

    return snapshot.docs
        .map((doc) => GuestTeamModel.fromJson(doc.data(), doc.id).toEntity())
        .toList(growable: false);
  }

  @override
  Future<List<GuestTeam>> searchGuestTeams(String query) async {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return const <GuestTeam>[];
    }
    final snapshot = await _guestTeamsRef
        .where('normalizedName', isGreaterThanOrEqualTo: normalizedQuery)
        .where('normalizedName', isLessThanOrEqualTo: '$normalizedQuery\uf8ff')
        .limit(20)
        .get();
    return snapshot.docs
        .map((doc) => GuestTeamModel.fromJson(doc.data(), doc.id).toEntity())
        .toList(growable: false);
  }

  @override
  Future<void> archiveGuestTeam(String guestTeamId) async {
    await _guestTeamsRef.doc(guestTeamId).update({
      'claimStatus': GuestClaimStatus.archived.name,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }
}
