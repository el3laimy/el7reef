import 'package:el7reef/core/constants/firebase_paths.dart';
import 'package:el7reef/core/enums/match_attendance_status.dart';
import 'package:el7reef/core/enums/match_status.dart';
import 'package:el7reef/core/enums/team_member_availability.dart';
import 'package:el7reef/core/enums/team_membership_role.dart';
import 'package:el7reef/data/models/match_lineup_snapshot_model.dart';
import 'package:el7reef/data/repositories/match_repository_impl.dart';
import 'package:el7reef/domain/entities/match.dart';
import 'package:el7reef/domain/entities/match_lineup_entry.dart';
import 'package:el7reef/domain/entities/match_lineup_snapshot.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MatchRepositoryImpl teamSize safety', () {
    late FakeFirebaseFirestore firestore;
    late MatchRepositoryImpl repository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = MatchRepositoryImpl(db: firestore);
    });

    test('allows teamSize update before snapshots are locked', () async {
      final match = _match(teamSize: 7);
      await repository.createMatch(match);

      await repository.updateMatch(match.copyWith(teamSize: 9));

      final saved = await repository.getMatch(match.id);
      expect(saved?.teamSize, 9);
    });

    test('rejects teamSize update after any lineup snapshot exists', () async {
      final match = _match(teamSize: 7);
      await repository.createMatch(match);
      await firestore
          .collection(FirebasePaths.matchLineupSnapshots)
          .doc('snapshot-1')
          .set(
            MatchLineupSnapshotModel.fromEntity(
              MatchLineupSnapshot(
                id: 'snapshot-1',
                matchId: match.id,
                teamId: 'team-1',
                checkInId: 'check-in-1',
                starters: const [
                  MatchLineupEntry(
                    attendanceId: 'attendance-1',
                    teamMembershipId: 'member-1',
                    playerId: 'player-1',
                    role: TeamMembershipRole.player,
                    availability: TeamMemberAvailability.available,
                    attendanceStatus: MatchAttendanceStatus.present,
                    displayName: 'Player One',
                  ),
                ],
                lockedBy: 'organizer-1',
                lockedAt: DateTime(2026, 4, 24),
                playerCount: 7,
                formationCode: '2-3-1',
              ),
            ).toJson(),
          );

      expect(
        () => repository.updateMatch(match.copyWith(teamSize: 9)),
        throwsA(isA<Exception>()),
      );

      final saved = await repository.getMatch(match.id);
      expect(saved?.teamSize, 7);
    });

    test('allows non-teamSize updates after snapshots are locked', () async {
      final match = _match(teamSize: 7);
      await repository.createMatch(match);
      await firestore
          .collection(FirebasePaths.matchLineupSnapshots)
          .doc('snapshot-1')
          .set({
            'matchId': match.id,
            'teamId': 'team-1',
            'checkInId': 'check-in-1',
            'starters': const [],
            'bench': const [],
            'lockedBy': 'organizer-1',
            'lockedAt': DateTime(2026, 4, 24).millisecondsSinceEpoch,
          });

      await repository.updateMatch(match.copyWith(status: MatchStatus.live));

      final saved = await repository.getMatch(match.id);
      expect(saved?.status, MatchStatus.live);
      expect(saved?.teamSize, 7);
    });
  });
}

Match _match({required int teamSize}) {
  return Match(
    id: 'match-1',
    organizerId: 'organizer-1',
    teamSize: teamSize,
    status: MatchStatus.open,
    createdAt: DateTime(2026, 4, 24),
  );
}
