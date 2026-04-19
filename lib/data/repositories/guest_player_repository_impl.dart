import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_paths.dart';
import '../../core/enums/guest_claim_status.dart';
import '../../domain/entities/guest_player.dart';
import '../../domain/repositories/guest_player_repository.dart';
import '../models/guest_player_model.dart';

class GuestPlayerRepositoryImpl implements GuestPlayerRepository {
  final FirebaseFirestore _firestore;

  GuestPlayerRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _guestPlayersRef =>
      _firestore.collection(FirebasePaths.guestPlayers);

  @override
  Future<GuestPlayer?> getGuestPlayer(String guestPlayerId) async {
    final doc = await _guestPlayersRef.doc(guestPlayerId).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return GuestPlayerModel.fromJson(doc.data()!, doc.id).toEntity();
  }

  @override
  Future<List<GuestPlayer>> getGuestPlayersByIds(
    List<String> guestPlayerIds,
  ) async {
    final orderedIds = _normalizeIds(guestPlayerIds);
    if (orderedIds.isEmpty) {
      return const <GuestPlayer>[];
    }

    final loadedPlayers = <String, GuestPlayer>{};
    for (final chunk in _chunkIds(orderedIds)) {
      final snapshot = await _guestPlayersRef
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snapshot.docs) {
        loadedPlayers[doc.id] = GuestPlayerModel.fromJson(
          doc.data(),
          doc.id,
        ).toEntity();
      }
    }

    return orderedIds
        .map((id) => loadedPlayers[id])
        .whereType<GuestPlayer>()
        .toList(growable: false);
  }

  @override
  Future<void> createGuestPlayer(GuestPlayer guestPlayer) async {
    final model = GuestPlayerModel.fromEntity(guestPlayer);
    await _guestPlayersRef.doc(guestPlayer.id).set(model.toJson());
  }

  @override
  Future<void> updateGuestPlayer(GuestPlayer guestPlayer) async {
    final model = GuestPlayerModel.fromEntity(guestPlayer);
    await _guestPlayersRef.doc(guestPlayer.id).update(model.toJson());
  }

  @override
  Future<List<GuestPlayer>> getTeamGuestPlayers(String teamId) async {
    final snapshot = await _guestPlayersRef
        .where('teamId', isEqualTo: teamId)
        .orderBy('createdAt')
        .get();

    return snapshot.docs
        .map((doc) => GuestPlayerModel.fromJson(doc.data(), doc.id).toEntity())
        .toList(growable: false);
  }

  @override
  Future<List<GuestPlayer>> getTournamentGuestPlayers(
    String tournamentId,
  ) async {
    final snapshot = await _guestPlayersRef
        .where('tournamentId', isEqualTo: tournamentId)
        .orderBy('createdAt')
        .get();

    return snapshot.docs
        .map((doc) => GuestPlayerModel.fromJson(doc.data(), doc.id).toEntity())
        .toList(growable: false);
  }

  @override
  Future<void> archiveGuestPlayer(String guestPlayerId) async {
    await _guestPlayersRef.doc(guestPlayerId).update({
      'claimStatus': GuestClaimStatus.archived.name,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  List<String> _normalizeIds(List<String> ids) {
    return ids
        .where((id) => id.trim().isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  Iterable<List<String>> _chunkIds(List<String> ids, {int size = 10}) sync* {
    for (var index = 0; index < ids.length; index += size) {
      final end = (index + size) > ids.length ? ids.length : index + size;
      yield ids.sublist(index, end);
    }
  }
}
