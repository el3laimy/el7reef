import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/enums/match_check_in_status.dart';
import 'package:el7reef/data/repositories/match_check_in_repository_impl.dart';
import 'package:el7reef/domain/entities/match_check_in.dart';

void main() {
  group('MatchCheckInRepositoryImpl', () {
    late FakeFirebaseFirestore firestore;
    late MatchCheckInRepositoryImpl repository;
    late DateTime now;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = MatchCheckInRepositoryImpl(firestore: firestore);
      now = DateTime(2026, 4, 17, 12);
    });

    test('creates check-ins and queries them by match and side', () async {
      await repository.createCheckIn(
        MatchCheckIn(
          id: 'check-in-1',
          matchId: 'match-1',
          teamId: 'team-1',
          createdBy: 'organizer-1',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repository.createCheckIn(
        MatchCheckIn(
          id: 'check-in-2',
          matchId: 'match-1',
          guestTeamId: 'guest-team-1',
          status: MatchCheckInStatus.checkedIn,
          createdBy: 'organizer-1',
          createdAt: now.add(const Duration(minutes: 1)),
          updatedAt: now.add(const Duration(minutes: 1)),
          checkedInBy: 'captain-1',
          checkedInAt: now.add(const Duration(minutes: 1)),
        ),
      );
      await repository.createCheckIn(
        MatchCheckIn(
          id: 'check-in-3',
          matchId: 'match-2',
          teamId: 'team-1',
          createdBy: 'organizer-1',
          createdAt: now.add(const Duration(minutes: 2)),
          updatedAt: now.add(const Duration(minutes: 2)),
        ),
      );

      final matchCheckIns = await repository.getMatchCheckIns('match-1');
      final byTeam = await repository.getCheckInByTeamId(
        matchId: 'match-1',
        teamId: 'team-1',
      );
      final byGuestTeam = await repository.getCheckInByGuestTeamId(
        matchId: 'match-1',
        guestTeamId: 'guest-team-1',
      );

      expect(matchCheckIns.map((entry) => entry.id), ['check-in-1', 'check-in-2']);
      expect(byTeam?.status, MatchCheckInStatus.pending);
      expect(byGuestTeam?.status, MatchCheckInStatus.checkedIn);
      expect(byGuestTeam?.checkedInBy, 'captain-1');
    });

    test('updates check-in status, notes, and verification fields', () async {
      await repository.createCheckIn(
        MatchCheckIn(
          id: 'check-in-1',
          matchId: 'match-1',
          teamId: 'team-1',
          createdBy: 'organizer-1',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await repository.updateCheckIn(
        MatchCheckIn(
          id: 'check-in-1',
          matchId: 'match-1',
          teamId: 'team-1',
          tournamentRegistrationId: 'tr-1',
          status: MatchCheckInStatus.verified,
          createdBy: 'organizer-1',
          createdAt: now,
          updatedAt: now.add(const Duration(minutes: 15)),
          checkedInBy: 'captain-1',
          checkedInAt: now.add(const Duration(minutes: 10)),
          verifiedBy: 'organizer-1',
          verifiedAt: now.add(const Duration(minutes: 15)),
          notes: 'وصل الفريق كاملًا قبل الإحماء.',
        ),
      );

      final updated = await repository.getCheckIn('check-in-1');

      expect(updated?.tournamentRegistrationId, 'tr-1');
      expect(updated?.status, MatchCheckInStatus.verified);
      expect(updated?.checkedInBy, 'captain-1');
      expect(updated?.verifiedBy, 'organizer-1');
      expect(updated?.notes, 'وصل الفريق كاملًا قبل الإحماء.');
      expect(updated?.isVerified, isTrue);
    });
  });
}
