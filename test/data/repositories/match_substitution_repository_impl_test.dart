import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/data/repositories/match_substitution_repository_impl.dart';
import 'package:el7reef/domain/entities/match_substitution.dart';

void main() {
  group('MatchSubstitutionRepositoryImpl', () {
    late FakeFirebaseFirestore firestore;
    late MatchSubstitutionRepositoryImpl repository;
    late DateTime now;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = MatchSubstitutionRepositoryImpl(firestore: firestore);
      now = DateTime(2026, 4, 17, 14);
    });

    test('creates substitutions and queries them by match and side', () async {
      await repository.createSubstitution(
        MatchSubstitution(
          id: 'sub-1',
          matchId: 'match-1',
          teamId: 'team-1',
          checkInId: 'check-in-1',
          lineupSnapshotId: 'lineup-1',
          outgoingAttendanceId: 'attendance-1',
          incomingAttendanceId: 'attendance-6',
          minute: 12,
          createdBy: 'owner-1',
          createdAt: now,
        ),
      );
      await repository.createSubstitution(
        MatchSubstitution(
          id: 'sub-2',
          matchId: 'match-1',
          guestTeamId: 'guest-team-1',
          checkInId: 'check-in-2',
          lineupSnapshotId: 'lineup-2',
          outgoingAttendanceId: 'attendance-2',
          incomingAttendanceId: 'attendance-8',
          minute: 18,
          createdBy: 'organizer-1',
          createdAt: now.add(const Duration(minutes: 1)),
        ),
      );

      final matchSubs = await repository.getMatchSubstitutions('match-1');
      final teamSubs = await repository.getTeamSubstitutions(
        matchId: 'match-1',
        teamId: 'team-1',
      );
      final guestSubs = await repository.getTeamSubstitutions(
        matchId: 'match-1',
        guestTeamId: 'guest-team-1',
      );

      expect(matchSubs.map((entry) => entry.id), ['sub-1', 'sub-2']);
      expect(teamSubs.single.outgoingAttendanceId, 'attendance-1');
      expect(guestSubs.single.incomingAttendanceId, 'attendance-8');
    });
  });
}
