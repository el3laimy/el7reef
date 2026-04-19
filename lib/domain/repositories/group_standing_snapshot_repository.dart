import '../entities/group_standing_snapshot.dart';

abstract class GroupStandingSnapshotRepository {
  Future<GroupStandingSnapshot?> getSnapshot(String snapshotId);
  Future<void> createSnapshot(GroupStandingSnapshot snapshot);
  Future<void> updateSnapshot(GroupStandingSnapshot snapshot);
  Future<List<GroupStandingSnapshot>> getGroupStageSnapshots(
    String groupStageId,
  );
}
