import '../entities/team_roster_snapshot.dart';

abstract class TeamRosterSnapshotRepository {
  Future<TeamRosterSnapshot?> getSnapshot(String snapshotId);
  Future<List<TeamRosterSnapshot>> getTeamSnapshots(
    String teamId, {
    int limit = 10,
  });
  Future<void> createSnapshot(TeamRosterSnapshot snapshot);
}
