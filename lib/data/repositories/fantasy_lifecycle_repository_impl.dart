import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_paths.dart';
import '../../domain/entities/fantasy_league_lifecycle.dart';
import '../../domain/repositories/fantasy_lifecycle_repository.dart';
import '../models/fantasy_league_lifecycle_model.dart';

class FantasyLifecycleRepositoryImpl implements FantasyLifecycleRepository {
  final FirebaseFirestore _db;

  FantasyLifecycleRepositoryImpl({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference get _leaguesRef =>
      _db.collection(FirebasePaths.fantasyLeagues);

  @override
  Future<FantasyLeagueLifecycle?> getLeagueLifecycle(String leagueId) async {
    final doc = await _leaguesRef.doc(leagueId).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return FantasyLeagueLifecycleModel.fromJson(
      doc.data()! as Map<String, dynamic>,
      doc.id,
    ).toEntity();
  }

  @override
  Future<void> saveLeagueLifecycle(FantasyLeagueLifecycle lifecycle) async {
    final model = FantasyLeagueLifecycleModel.fromEntity(lifecycle);
    await _leaguesRef.doc(lifecycle.leagueId).set(model.toJson());
  }
}
