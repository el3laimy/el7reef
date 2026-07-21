import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/enums/match_attendance_status.dart';
import 'package:el7reef/core/enums/team_member_availability.dart';
import 'package:el7reef/core/enums/team_membership_role.dart';
import 'package:el7reef/data/repositories/match_lineup_snapshot_repository_impl.dart';
import 'package:el7reef/domain/entities/match_lineup_entry.dart';
import 'package:el7reef/domain/entities/match_lineup_snapshot.dart';

void main() {
  group('MatchLineupSnapshotRepositoryImpl', () {
    late FakeFirebaseFirestore firestore;
    late MatchLineupSnapshotRepositoryImpl repository;
    late DateTime now;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = MatchLineupSnapshotRepositoryImpl(firestore: firestore);
      now = DateTime(2026, 4, 17, 15);
    });

    test(
      'creates lineup snapshots and queries them by match and side',
      () async {
        await repository.createSnapshot(
          MatchLineupSnapshot(
            id: 'snapshot-1',
            matchId: 'match-1',
            teamId: 'team-1',
            checkInId: 'check-in-1',
            starters: [
              const MatchLineupEntry(
                attendanceId: 'attendance-1',
                playerId: 'player-1',
                role: TeamMembershipRole.owner,
                availability: TeamMemberAvailability.available,
                attendanceStatus: MatchAttendanceStatus.present,
                displayName: 'Captain Blue',
              ),
            ],
            lockedBy: 'owner-1',
            lockedAt: now,
            playerCount: 7,
            formationCode: '2-3-1',
          ),
        );
        await repository.createSnapshot(
          MatchLineupSnapshot(
            id: 'snapshot-2',
            matchId: 'match-1',
            guestTeamId: 'guest-team-1',
            checkInId: 'check-in-2',
            starters: [
              const MatchLineupEntry(
                attendanceId: 'attendance-2',
                guestPlayerId: 'guest-player-2',
                role: TeamMembershipRole.player,
                availability: TeamMemberAvailability.available,
                attendanceStatus: MatchAttendanceStatus.late,
                displayName: 'Guest Forward',
                shirtNumber: 9,
              ),
            ],
            lockedBy: 'organizer-1',
            lockedAt: now.add(const Duration(minutes: 1)),
          ),
        );

        final matchSnapshots = await repository.getMatchSnapshots('match-1');
        final byTeam = await repository.getSnapshotByTeamId(
          matchId: 'match-1',
          teamId: 'team-1',
        );
        final byGuest = await repository.getSnapshotByGuestTeamId(
          matchId: 'match-1',
          guestTeamId: 'guest-team-1',
        );

        expect(matchSnapshots.map((entry) => entry.id), [
          'snapshot-1',
          'snapshot-2',
        ]);
        expect(byTeam?.starters.single.displayName, 'Captain Blue');
        expect(byTeam?.playerCount, 7);
        expect(byTeam?.formationCode, '2-3-1');
        expect(byTeam?.summaryLabel, '2-3-1');
        expect(byGuest?.starters.single.guestPlayerId, 'guest-player-2');
        expect(byGuest?.starters.single.shirtNumber, 9);
        expect(byGuest?.summaryLabel, 'أساسي 1 • احتياط 0 • ضيوف 1');
      },
    );
  });
}
