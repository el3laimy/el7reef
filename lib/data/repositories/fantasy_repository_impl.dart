import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firebase_paths.dart';
import '../../domain/entities/fantasy_team.dart';
import '../../domain/entities/fantasy_slot.dart';
import '../../domain/entities/player_fantasy_value.dart';
import '../../domain/entities/transfer_record.dart';
import '../../domain/repositories/fantasy_repository.dart';
import '../models/fantasy_team_model.dart';
import '../models/fantasy_slot_model.dart';
import '../models/player_fantasy_value_model.dart';
import '../models/transfer_record_model.dart';

class FantasyRepositoryImpl implements FantasyRepository {
  final FirebaseFirestore _db;

  FantasyRepositoryImpl({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference get _teamsRef => _db.collection(FirebasePaths.fantasyTeams);
  CollectionReference get _slotsRef => _db.collection(FirebasePaths.fantasySlots);
  CollectionReference get _transfersRef => _db.collection(FirebasePaths.transferRecords);
  CollectionReference get _valuesRef => _db.collection(FirebasePaths.playerFantasyValues);

  @override
  Future<FantasyTeam?> getFantasyTeam(String ownerPlayerId) async {
    final doc = await _teamsRef.doc(ownerPlayerId).get();
    if (!doc.exists || doc.data() == null) return null;
    return FantasyTeamModel.fromJson(doc.data() as Map<String, dynamic>, doc.id).toEntity();
  }

  @override
  Future<List<FantasyTeam>> getLeagueLeaderboard(
    String leagueId, {
    int limit = 50,
  }) async {
    final snapshot = await _teamsRef
        .where('leagueIds', arrayContains: leagueId)
        .orderBy('totalPoints', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => FantasyTeamModel.fromJson(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ).toEntity())
        .toList();
  }

  @override
  Future<void> createFantasyTeam(FantasyTeam team, List<FantasySlot> slots) async {
    await _db.runTransaction((tx) async {
      final teamModel = FantasyTeamModel.fromEntity(team);
      tx.set(_teamsRef.doc(team.id), teamModel.toJson());

      for (var slot in slots) {
        final slotModel = FantasySlotModel.fromEntity(slot);
        final ref = _slotsRef.doc(slot.id);
        tx.set(ref, slotModel.toJson());
      }
    });
  }

  @override
  Future<void> updateFantasyTeam(FantasyTeam team) async {
    final model = FantasyTeamModel.fromEntity(team);
    await _teamsRef.doc(team.id).update(model.toJson());
  }

  @override
  Future<List<FantasySlot>> getTeamSlots(String fantasyTeamId) async {
    final snapshot = await _slotsRef.where('fantasyTeamId', isEqualTo: fantasyTeamId).get();
    return snapshot.docs
        .map((doc) => FantasySlotModel.fromJson(doc.data() as Map<String, dynamic>, doc.id).toEntity())
        .toList();
  }

  @override
  Future<void> updateFantasySlot(FantasySlot slot) async {
    final model = FantasySlotModel.fromEntity(slot);
    await _slotsRef.doc(slot.id).update(model.toJson());
  }

  @override
  Future<void> processTransfer(FantasyTeam team, TransferRecord record, List<FantasySlot> updatedSlots) async {
    await _db.runTransaction((tx) async {
      final teamModel = FantasyTeamModel.fromEntity(team);
      tx.update(_teamsRef.doc(team.id), teamModel.toJson());

      final recordModel = TransferRecordModel.fromEntity(record);
      tx.set(_transfersRef.doc(record.id), recordModel.toJson());

      for (var slot in updatedSlots) {
        final slotModel = FantasySlotModel.fromEntity(slot);
        tx.update(_slotsRef.doc(slot.id), slotModel.toJson());
      }
    });
  }

  @override
  Future<PlayerFantasyValue?> getPlayerFantasyValue(String playerId) async {
    final doc = await _valuesRef.doc(playerId).get();
    if (!doc.exists || doc.data() == null) return null;
    return PlayerFantasyValueModel.fromJson(doc.data() as Map<String, dynamic>, doc.id).toEntity();
  }

  @override
  Future<List<PlayerFantasyValue>> getMarketValues({int limit = 100}) async {
    final snapshot = await _valuesRef
        .orderBy('totalFantasyPoints', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => PlayerFantasyValueModel.fromJson(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ).toEntity())
        .toList();
  }

  @override
  Future<void> updatePlayerFantasyValue(PlayerFantasyValue value) async {
    final model = PlayerFantasyValueModel.fromEntity(value);
    await _valuesRef.doc(value.playerId).set(model.toJson(), SetOptions(merge: true));
  }

  @override
  Future<List<TransferRecord>> getTeamTransfers(String fantasyTeamId) async {
    final snapshot = await _transfersRef
        .where('fantasyTeamId', isEqualTo: fantasyTeamId)
        .orderBy('timestamp', descending: true)
        .get();
        
    return snapshot.docs
        .map((doc) => TransferRecordModel.fromJson(doc.data() as Map<String, dynamic>, doc.id).toEntity())
        .toList();
  }
}
