import '../entities/match_lineup_snapshot.dart';

abstract class MatchLineupSnapshotRepository {
  Future<MatchLineupSnapshot?> getSnapshot(String snapshotId);
  Future<void> createSnapshot(MatchLineupSnapshot snapshot);
  Future<List<MatchLineupSnapshot>> getMatchSnapshots(String matchId);
  Future<MatchLineupSnapshot?> getSnapshotByTeamId({
    required String matchId,
    required String teamId,
  });
  Future<MatchLineupSnapshot?> getSnapshotByGuestTeamId({
    required String matchId,
    required String guestTeamId,
  });
  Future<void> deleteSnapshot(String snapshotId);
}
