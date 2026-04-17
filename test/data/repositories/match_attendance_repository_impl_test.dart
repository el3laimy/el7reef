import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/enums/match_attendance_status.dart';
import 'package:el7reef/data/repositories/match_attendance_repository_impl.dart';
import 'package:el7reef/domain/entities/match_attendance.dart';

void main() {
  group('MatchAttendanceRepositoryImpl', () {
    late FakeFirebaseFirestore firestore;
    late MatchAttendanceRepositoryImpl repository;
    late DateTime now;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = MatchAttendanceRepositoryImpl(firestore: firestore);
      now = DateTime(2026, 4, 17, 13);
    });

    test('creates attendance records and queries them by match, team, and participant',
        () async {
      await repository.createAttendance(
        MatchAttendance(
          id: 'attendance-1',
          matchId: 'match-1',
          teamId: 'team-1',
          checkInId: 'check-in-1',
          teamMembershipId: 'membership-1',
          playerId: 'player-1',
          status: MatchAttendanceStatus.present,
          createdBy: 'organizer-1',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repository.createAttendance(
        MatchAttendance(
          id: 'attendance-2',
          matchId: 'match-1',
          teamId: 'team-1',
          checkInId: 'check-in-1',
          teamMembershipId: 'membership-2',
          guestPlayerId: 'guest-player-1',
          status: MatchAttendanceStatus.absent,
          createdBy: 'organizer-1',
          createdAt: now.add(const Duration(minutes: 1)),
          updatedAt: now.add(const Duration(minutes: 1)),
        ),
      );
      await repository.createAttendance(
        MatchAttendance(
          id: 'attendance-3',
          matchId: 'match-1',
          guestTeamId: 'guest-team-1',
          checkInId: 'check-in-2',
          teamMembershipId: 'membership-3',
          guestPlayerId: 'guest-player-2',
          status: MatchAttendanceStatus.late,
          createdBy: 'organizer-1',
          createdAt: now.add(const Duration(minutes: 2)),
          updatedAt: now.add(const Duration(minutes: 2)),
        ),
      );
      await repository.createAttendance(
        MatchAttendance(
          id: 'attendance-4',
          matchId: 'match-2',
          teamId: 'team-1',
          playerId: 'player-1',
          createdBy: 'organizer-1',
          createdAt: now.add(const Duration(minutes: 3)),
          updatedAt: now.add(const Duration(minutes: 3)),
        ),
      );

      final matchAttendances = await repository.getMatchAttendances('match-1');
      final teamAttendances = await repository.getTeamAttendances(
        matchId: 'match-1',
        teamId: 'team-1',
      );
      final guestTeamAttendances = await repository.getTeamAttendances(
        matchId: 'match-1',
        guestTeamId: 'guest-team-1',
      );
      final byPlayer = await repository.getAttendanceByPlayerId(
        matchId: 'match-1',
        playerId: 'player-1',
      );
      final byGuestPlayer = await repository.getAttendanceByGuestPlayerId(
        matchId: 'match-1',
        guestPlayerId: 'guest-player-2',
      );

      expect(
        matchAttendances.map((entry) => entry.id),
        ['attendance-1', 'attendance-2', 'attendance-3'],
      );
      expect(
        teamAttendances.map((entry) => entry.id),
        ['attendance-1', 'attendance-2'],
      );
      expect(guestTeamAttendances.single.id, 'attendance-3');
      expect(byPlayer?.status, MatchAttendanceStatus.present);
      expect(byGuestPlayer?.status, MatchAttendanceStatus.late);
    });

    test('updates attendance status, markers, and claim linkage', () async {
      await repository.createAttendance(
        MatchAttendance(
          id: 'attendance-1',
          matchId: 'match-1',
          guestTeamId: 'guest-team-1',
          guestPlayerId: 'guest-player-9',
          createdBy: 'organizer-1',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await repository.updateAttendance(
        MatchAttendance(
          id: 'attendance-1',
          matchId: 'match-1',
          guestTeamId: 'guest-team-1',
          playerId: 'player-9',
          claimedFromGuestPlayerId: 'guest-player-9',
          tournamentRegistrationId: 'tr-guest-1',
          checkInId: 'check-in-9',
          teamMembershipId: 'membership-9',
          status: MatchAttendanceStatus.present,
          includedInLockedLineup: true,
          startedMatch: false,
          played: true,
          currentlyOnPitch: true,
          firstEnteredMinute: 14,
          createdBy: 'organizer-1',
          createdAt: now,
          updatedAt: now.add(const Duration(minutes: 20)),
          markedBy: 'captain-1',
          markedAt: now.add(const Duration(minutes: 20)),
          participationUpdatedBy: 'captain-1',
          participationUpdatedAt: now.add(const Duration(minutes: 20)),
          notes: 'انضم قبل قفل التشكيل مباشرة.',
        ),
      );

      final updated = await repository.getAttendance('attendance-1');

      expect(updated?.playerId, 'player-9');
      expect(updated?.guestPlayerId, isNull);
      expect(updated?.claimedFromGuestPlayerId, 'guest-player-9');
      expect(updated?.tournamentRegistrationId, 'tr-guest-1');
      expect(updated?.status, MatchAttendanceStatus.present);
      expect(updated?.includedInLockedLineup, isTrue);
      expect(updated?.played, isTrue);
      expect(updated?.currentlyOnPitch, isTrue);
      expect(updated?.firstEnteredMinute, 14);
      expect(updated?.participationUpdatedBy, 'captain-1');
      expect(updated?.markedBy, 'captain-1');
      expect(updated?.isPresent, isTrue);
      expect(updated?.notes, 'انضم قبل قفل التشكيل مباشرة.');
    });
  });
}
