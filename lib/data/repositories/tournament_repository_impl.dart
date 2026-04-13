import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firebase_paths.dart';
import '../../core/enums/tournament_enums.dart';
import '../../domain/entities/tournament.dart';
import '../../domain/repositories/tournament_repository.dart';
import '../models/tournament_model.dart';

/// تنفيذ مستودع الدورة مع Firestore
class TournamentRepositoryImpl implements TournamentRepository {
  final FirebaseFirestore _db;

  TournamentRepositoryImpl({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference get _col => _db.collection(FirebasePaths.tournaments);

  @override
  Future<Tournament?> getTournament(String tournamentId) async {
    final doc = await _col.doc(tournamentId).get();
    if (!doc.exists || doc.data() == null) return null;
    return TournamentModel.fromJson(
            doc.data()! as Map<String, dynamic>, doc.id)
        .toEntity();
  }

  @override
  Future<void> createTournament(Tournament tournament) async {
    final model = TournamentModel.fromEntity(tournament);
    await _col.doc(tournament.id).set(model.toJson());
  }

  @override
  Future<void> updateTournament(Tournament tournament) async {
    final model = TournamentModel.fromEntity(tournament);
    await _col.doc(tournament.id).update(model.toJson());
  }

  @override
  Future<List<Tournament>> getLiveTournaments({int limit = 20}) async {
    final snap = await _col
        .where('status', whereIn: [
          TournamentStatus.registration.name,
          TournamentStatus.groupStage.name,
          TournamentStatus.knockoutStage.name,
        ])
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snap.docs
        .map((d) =>
            TournamentModel.fromJson(d.data()! as Map<String, dynamic>, d.id)
                .toEntity())
        .toList();
  }

  @override
  Future<List<Tournament>> getOrganizerTournaments(String organizerId) async {
    final snap = await _col
        .where('organizerId', isEqualTo: organizerId)
        .orderBy('createdAt', descending: true)
        .get();

    return snap.docs
        .map((d) =>
            TournamentModel.fromJson(d.data()! as Map<String, dynamic>, d.id)
                .toEntity())
        .toList();
  }

  @override
  Future<List<Tournament>> getPlayerTournaments(String teamId) async {
    final snap = await _col
        .where('registeredTeamIds', arrayContains: teamId)
        .orderBy('createdAt', descending: true)
        .get();

    return snap.docs
        .map((d) =>
            TournamentModel.fromJson(d.data()! as Map<String, dynamic>, d.id)
                .toEntity())
        .toList();
  }

  @override
  Future<void> registerTeam(String tournamentId, String teamId) async {
    await _col.doc(tournamentId).update({
      'registeredTeamIds': FieldValue.arrayUnion([teamId]),
    });
  }

  @override
  Future<void> unregisterTeam(String tournamentId, String teamId) async {
    await _col.doc(tournamentId).update({
      'registeredTeamIds': FieldValue.arrayRemove([teamId]),
    });
  }

  @override
  Future<void> updateStatus(String tournamentId, String status) async {
    await _col.doc(tournamentId).update({'status': status});
  }

  @override
  Future<void> addGroupRound(String tournamentId, String roundId) async {
    await _col.doc(tournamentId).update({
      'groupRoundIds': FieldValue.arrayUnion([roundId]),
    });
  }

  @override
  Future<void> addKnockoutRound(String tournamentId, String roundId) async {
    await _col.doc(tournamentId).update({
      'knockoutRoundIds': FieldValue.arrayUnion([roundId]),
    });
  }
}
