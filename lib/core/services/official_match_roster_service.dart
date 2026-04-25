import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_paths.dart';
import '../../data/models/match_lineup_snapshot_model.dart';
import '../../data/models/match_model.dart';
import '../../data/repositories/player_repository_impl.dart';
import '../../domain/entities/match.dart';
import '../../domain/entities/match_lineup_snapshot.dart';
import '../../domain/entities/player.dart';

class OfficialMatchRegisteredRoster {
  final Match match;
  final List<String> teamAPlayerIds;
  final List<String> teamBPlayerIds;
  final List<Player> teamAPlayers;
  final List<Player> teamBPlayers;

  const OfficialMatchRegisteredRoster({
    required this.match,
    required this.teamAPlayerIds,
    required this.teamBPlayerIds,
    required this.teamAPlayers,
    required this.teamBPlayers,
  });

  List<String> get allPlayerIds =>
      <String>{...teamAPlayerIds, ...teamBPlayerIds}.toList(growable: false);
}

class OfficialMatchRosterService {
  final FirebaseFirestore _firestore;
  final PlayerRepositoryImpl _playerRepository;

  OfficialMatchRosterService({
    FirebaseFirestore? firestore,
    PlayerRepositoryImpl? playerRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _playerRepository =
           playerRepository ?? PlayerRepositoryImpl(firestore: firestore);

  CollectionReference<Map<String, dynamic>> get _matchesRef =>
      _firestore.collection(FirebasePaths.matches);
  CollectionReference<Map<String, dynamic>> get _snapshotsRef =>
      _firestore.collection(FirebasePaths.matchLineupSnapshots);

  Future<OfficialMatchRegisteredRoster> loadRegisteredRoster({
    required String matchId,
    Match? match,
  }) async {
    final effectiveMatch = match ?? await _loadMatch(matchId);
    final snapshots = await _loadSnapshots(effectiveMatch.id);

    final teamAIds = _resolveSidePlayerIds(
      snapshots: snapshots,
      sideEntityId: effectiveMatch.teamAId,
      fallbackIds: effectiveMatch.teamAPlayerIds,
    );
    final teamBIds = _resolveSidePlayerIds(
      snapshots: snapshots,
      sideEntityId: effectiveMatch.teamBId,
      fallbackIds: effectiveMatch.teamBPlayerIds,
    );

    final allPlayers = await _playerRepository.getPlayersByIds(<String>[
      ...teamAIds,
      ...teamBIds,
    ]);
    final playersById = <String, Player>{
      for (final player in allPlayers) player.id: player,
    };

    return OfficialMatchRegisteredRoster(
      match: effectiveMatch,
      teamAPlayerIds: teamAIds,
      teamBPlayerIds: teamBIds,
      teamAPlayers: teamAIds
          .map((playerId) => playersById[playerId])
          .whereType<Player>()
          .toList(growable: false),
      teamBPlayers: teamBIds
          .map((playerId) => playersById[playerId])
          .whereType<Player>()
          .toList(growable: false),
    );
  }

  Future<Match> _loadMatch(String matchId) async {
    final snapshot = await _matchesRef.doc(matchId).get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('المباراة غير موجودة');
    }
    return MatchModel.fromJson(snapshot.data()!, snapshot.id).toEntity();
  }

  Future<List<MatchLineupSnapshot>> _loadSnapshots(String matchId) async {
    final snapshot = await _snapshotsRef
        .where('matchId', isEqualTo: matchId)
        .get();
    return snapshot.docs
        .map(
          (doc) =>
              MatchLineupSnapshotModel.fromJson(doc.data(), doc.id).toEntity(),
        )
        .toList(growable: false);
  }

  List<String> _resolveSidePlayerIds({
    required List<MatchLineupSnapshot> snapshots,
    required String? sideEntityId,
    required List<String> fallbackIds,
  }) {
    final snapshot = _findSnapshotForSide(
      snapshots: snapshots,
      sideEntityId: sideEntityId,
    );
    if (snapshot == null) {
      return _normalizeIds(fallbackIds);
    }

    // V1 official rating/stat/fan-voting roster is registered-player only.
    // Guest-only lineup snapshots intentionally project to an empty eligible
    // roster; guest players remain display-only until they are claimed later.
    return _projectRegisteredPlayerIds(snapshot);
  }

  MatchLineupSnapshot? _findSnapshotForSide({
    required List<MatchLineupSnapshot> snapshots,
    required String? sideEntityId,
  }) {
    if (sideEntityId == null || sideEntityId.isEmpty) {
      return null;
    }
    for (final snapshot in snapshots) {
      if (snapshot.teamId == sideEntityId ||
          snapshot.guestTeamId == sideEntityId) {
        return snapshot;
      }
    }
    return null;
  }

  List<String> _projectRegisteredPlayerIds(MatchLineupSnapshot snapshot) {
    final ids = <String>[];
    for (final entry in [...snapshot.starters, ...snapshot.bench]) {
      final playerId = entry.playerId;
      if (playerId == null ||
          playerId.trim().isEmpty ||
          ids.contains(playerId)) {
        continue;
      }
      ids.add(playerId);
    }
    return ids;
  }

  List<String> _normalizeIds(List<String> ids) {
    return ids
        .where((id) => id.trim().isNotEmpty)
        .toSet()
        .toList(growable: false);
  }
}
