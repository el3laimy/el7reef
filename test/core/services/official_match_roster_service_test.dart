import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/constants/firebase_paths.dart';
import 'package:el7reef/core/enums/match_attendance_status.dart';
import 'package:el7reef/core/enums/team_member_availability.dart';
import 'package:el7reef/core/enums/team_membership_role.dart';
import 'package:el7reef/core/enums/team_membership_status.dart';
import 'package:el7reef/core/services/official_match_roster_service.dart';
import 'package:el7reef/data/models/guest_player_model.dart';
import 'package:el7reef/data/models/match_lineup_snapshot_model.dart';
import 'package:el7reef/data/models/match_model.dart';
import 'package:el7reef/data/models/match_side_player_model.dart';
import 'package:el7reef/data/models/player_model.dart';
import 'package:el7reef/data/models/team_membership_model.dart';
import 'package:el7reef/domain/entities/guest_player.dart';
import 'package:el7reef/domain/entities/match.dart';
import 'package:el7reef/domain/entities/match_lineup_entry.dart';
import 'package:el7reef/domain/entities/match_lineup_snapshot.dart';
import 'package:el7reef/domain/entities/match_side_player.dart';
import 'package:el7reef/domain/entities/participant_ref.dart';
import 'package:el7reef/domain/entities/player.dart';
import 'package:el7reef/domain/entities/team_membership.dart';

void main() {
  group('OfficialMatchRosterService.loadParticipantRoster', () {
    late FakeFirebaseFirestore firestore;
    late OfficialMatchRosterService service;
    late DateTime now;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      service = OfficialMatchRosterService(firestore: firestore);
      now = DateTime(2026, 5, 3, 18);
    });

    test('maps registered team players to ParticipantRefKind.player', () async {
      await _saveMatch(firestore, _match(teamAId: 'team-a', teamBId: 'team-b'));
      await _savePlayer(firestore, _player(id: 'player-1', name: 'سليم'));
      await _saveMembership(
        firestore,
        _membership(id: 'member-1', teamId: 'team-a', playerId: 'player-1'),
      );

      final roster = await service.loadParticipantRoster(matchId: 'match-1');

      expect(roster.sideA, hasLength(1));
      expect(roster.sideA.single.kind, ParticipantRefKind.player);
      expect(roster.sideA.single.id, 'player-1');
      expect(roster.sideA.single.displayName, 'سليم');
      expect(roster.sideA.single.linkedPlayerId, isNull);
      expect(roster.sideB, isEmpty);
    });

    test(
      'maps guest team members to ParticipantRefKind.guestPlayer with claim link',
      () async {
        await _saveMatch(
          firestore,
          _match(teamAId: 'team-a', teamBId: 'team-b'),
        );
        await _saveGuestPlayer(
          firestore,
          _guestPlayer(
            id: 'guest-1',
            displayName: 'ميدو',
            teamId: 'team-a',
            linkedPlayerId: 'claimed-player-1',
            now: now,
          ),
        );
        await _saveMembership(
          firestore,
          _membership(
            id: 'member-guest-1',
            teamId: 'team-a',
            guestPlayerId: 'guest-1',
          ),
        );

        final roster = await service.loadParticipantRoster(matchId: 'match-1');

        expect(roster.sideA, hasLength(1));
        expect(roster.sideA.single.kind, ParticipantRefKind.guestPlayer);
        expect(roster.sideA.single.id, 'guest-1');
        expect(roster.sideA.single.displayName, 'ميدو');
        expect(roster.sideA.single.linkedPlayerId, 'claimed-player-1');
      },
    );

    test(
      'maps temporary match-side players to ParticipantRefKind.matchSidePlayer',
      () async {
        await _saveMatch(firestore, _match());
        await _saveMatchSidePlayer(
          firestore,
          _sidePlayer(
            id: 'side-player-1',
            sideKey: 'A',
            displayName: 'لاعب مؤقت',
            now: now,
          ),
        );

        final roster = await service.loadParticipantRoster(matchId: 'match-1');

        expect(roster.sideA, hasLength(1));
        expect(roster.sideA.single.kind, ParticipantRefKind.matchSidePlayer);
        expect(roster.sideA.single.id, 'side-player-1');
        expect(roster.sideA.single.displayName, 'لاعب مؤقت');
        expect(roster.sideA.single.linkedPlayerId, isNull);
      },
    );

    test('maps registered match-side players to player refs', () async {
      await _saveMatch(firestore, _match());
      await _savePlayer(firestore, _player(id: 'player-1', name: 'كريم'));
      await _saveMatchSidePlayer(
        firestore,
        _sidePlayer(
          id: 'side-player-1',
          sideKey: 'A',
          kind: 'registered',
          playerId: 'player-1',
          displayName: 'اسم احتياطي',
          ratingEligible: true,
          now: now,
        ),
      );

      final roster = await service.loadParticipantRoster(matchId: 'match-1');

      expect(roster.sideA, hasLength(1));
      expect(roster.sideA.single.kind, ParticipantRefKind.player);
      expect(roster.sideA.single.id, 'player-1');
      expect(roster.sideA.single.displayName, 'كريم');
    });

    test(
      'de-duplicates participants by kind and id within the same side',
      () async {
        await _saveMatch(
          firestore,
          _match(
            teamAId: 'team-a',
            teamBId: 'team-b',
            teamAPlayerIds: const ['player-1'],
          ),
        );
        await _savePlayer(firestore, _player(id: 'player-1', name: 'عمر'));
        await _saveMembership(
          firestore,
          _membership(id: 'member-1', teamId: 'team-a', playerId: 'player-1'),
        );
        await _saveMatchSidePlayer(
          firestore,
          _sidePlayer(
            id: 'side-player-1',
            sideKey: 'A',
            kind: 'registered',
            playerId: 'player-1',
            displayName: 'عمر',
            ratingEligible: true,
            now: now,
          ),
        );

        final roster = await service.loadParticipantRoster(matchId: 'match-1');

        expect(roster.sideA, hasLength(1));
        expect(roster.sideA.single.kind, ParticipantRefKind.player);
        expect(roster.sideA.single.id, 'player-1');
      },
    );

    test('returns empty side lists when no participants are found', () async {
      await _saveMatch(firestore, _match());

      final roster = await service.loadParticipantRoster(matchId: 'match-1');

      expect(roster.sideA, isEmpty);
      expect(roster.sideB, isEmpty);
      expect(roster.allParticipants, isEmpty);
    });

    test('side membership helper checks side A and side B', () async {
      await _saveMatch(
        firestore,
        _match(
          teamAId: 'team-a',
          teamBId: 'team-b',
          teamAPlayerIds: const ['player-a'],
          teamBPlayerIds: const ['player-b'],
        ),
      );
      await _savePlayer(firestore, _player(id: 'player-a', name: 'أحمد'));
      await _savePlayer(firestore, _player(id: 'player-b', name: 'حازم'));

      final roster = await service.loadParticipantRoster(matchId: 'match-1');
      final playerA = roster.sideA.single;
      final playerB = roster.sideB.single;

      expect(
        roster.isParticipantOnSide(participant: playerA, sideKey: 'A'),
        isTrue,
      );
      expect(
        roster.isParticipantOnSide(participant: playerA, sideKey: 'B'),
        isFalse,
      );
      expect(roster.sideKeyFor(playerA), 'A');
      expect(roster.sideKeyFor(playerB), 'B');
      expect(roster.participantsForSide('C'), isEmpty);
    });

    test(
      'loads mixed participant refs from a lineup snapshot for one side',
      () async {
        await _saveMatch(firestore, _match());
        await _savePlayer(
          firestore,
          _player(id: 'player-1', name: 'لاعب مسجل'),
        );
        await _savePlayer(
          firestore,
          _player(id: 'player-side-1', name: 'لاعب جانبي مسجل'),
        );
        await _saveGuestPlayer(
          firestore,
          _guestPlayer(
            id: 'guest-1',
            displayName: 'ضيف هداف',
            linkedPlayerId: 'claimed-player-1',
            now: now,
          ),
        );
        await _saveMatchSidePlayer(
          firestore,
          _sidePlayer(
            id: 'side-temp-1',
            sideKey: 'A',
            displayName: 'مؤقت سريع',
            now: now,
          ),
        );
        await _saveMatchSidePlayer(
          firestore,
          _sidePlayer(
            id: 'side-registered-1',
            sideKey: 'A',
            kind: 'registered',
            playerId: 'player-side-1',
            displayName: 'اسم جانبي احتياطي',
            ratingEligible: true,
            now: now,
          ),
        );
        await _saveLineupSnapshot(
          firestore,
          MatchLineupSnapshot(
            id: 'snapshot-a',
            matchId: 'match-1',
            matchSideId: 'match-1_A',
            sideKey: 'A',
            starters: [
              _entry(
                attendanceId: 'attendance-player-1',
                playerId: 'player-1',
                displayName: 'اسم مسجل من التشكيل',
              ),
              _entry(
                attendanceId: 'attendance-guest-1',
                guestPlayerId: 'guest-1',
                displayName: 'اسم ضيف من التشكيل',
              ),
              _entry(
                attendanceId: 'attendance-side-temp-1',
                matchSidePlayerId: 'side-temp-1',
                displayName: 'اسم مؤقت من التشكيل',
              ),
              _entry(
                attendanceId: 'attendance-side-registered-1',
                matchSidePlayerId: 'side-registered-1',
                displayName: 'اسم جانبي من التشكيل',
              ),
            ],
            lockedBy: 'organizer-1',
            lockedAt: now,
          ),
        );

        final roster = await service.loadParticipantRoster(matchId: 'match-1');
        final participantsByKey = {
          for (final participant in roster.sideA)
            _participantKey(participant): participant,
        };

        expect(roster.sideA, hasLength(4));
        expect(participantsByKey, hasLength(roster.sideA.length));
        expect(roster.sideB, isEmpty);

        final registered = participantsByKey['player:player-1'];
        expect(registered?.kind, ParticipantRefKind.player);
        expect(registered?.id, 'player-1');
        expect(registered?.displayName, 'لاعب مسجل');
        expect(registered?.linkedPlayerId, isNull);

        final guest = participantsByKey['guestPlayer:guest-1'];
        expect(guest?.kind, ParticipantRefKind.guestPlayer);
        expect(guest?.id, 'guest-1');
        expect(guest?.displayName, 'ضيف هداف');
        expect(guest?.linkedPlayerId, 'claimed-player-1');

        final temporary = participantsByKey['matchSidePlayer:side-temp-1'];
        expect(temporary?.kind, ParticipantRefKind.matchSidePlayer);
        expect(temporary?.id, 'side-temp-1');
        expect(temporary?.displayName, 'مؤقت سريع');
        expect(temporary?.linkedPlayerId, isNull);

        final sideRegistered = participantsByKey['player:player-side-1'];
        expect(sideRegistered?.kind, ParticipantRefKind.player);
        expect(sideRegistered?.id, 'player-side-1');
        expect(sideRegistered?.displayName, 'لاعب جانبي مسجل');
        expect(sideRegistered?.linkedPlayerId, isNull);

        for (final participant in roster.sideA) {
          expect(
            roster.isParticipantOnSide(participant: participant, sideKey: 'A'),
            isTrue,
          );
          expect(roster.sideKeyFor(participant), 'A');
        }
      },
    );

    test('keeps side A and side B lineup snapshots separated', () async {
      await _saveMatch(firestore, _match());
      await _savePlayer(firestore, _player(id: 'player-a', name: 'ألفا'));
      await _savePlayer(firestore, _player(id: 'player-b', name: 'بيتا'));
      await _saveLineupSnapshot(
        firestore,
        MatchLineupSnapshot(
          id: 'snapshot-a',
          matchId: 'match-1',
          matchSideId: 'match-1_A',
          sideKey: 'A',
          starters: [
            _entry(
              attendanceId: 'attendance-player-a',
              playerId: 'player-a',
              displayName: 'ألفا',
            ),
          ],
          lockedBy: 'organizer-1',
          lockedAt: now,
        ),
      );
      await _saveLineupSnapshot(
        firestore,
        MatchLineupSnapshot(
          id: 'snapshot-b',
          matchId: 'match-1',
          matchSideId: 'match-1_B',
          sideKey: 'B',
          starters: [
            _entry(
              attendanceId: 'attendance-player-b',
              playerId: 'player-b',
              displayName: 'بيتا',
            ),
          ],
          lockedBy: 'organizer-1',
          lockedAt: now,
        ),
      );

      final roster = await service.loadParticipantRoster(matchId: 'match-1');

      expect(roster.sideA.map((participant) => participant.id), ['player-a']);
      expect(roster.sideB.map((participant) => participant.id), ['player-b']);
      expect(
        roster.isParticipantOnSide(
          participant: roster.sideA.single,
          sideKey: 'B',
        ),
        isFalse,
      );
      expect(
        roster.isParticipantOnSide(
          participant: roster.sideB.single,
          sideKey: 'A',
        ),
        isFalse,
      );
    });
  });
}

Match _match({
  String id = 'match-1',
  String? teamAId,
  String? teamBId,
  List<String> teamAPlayerIds = const [],
  List<String> teamBPlayerIds = const [],
}) {
  return Match(
    id: id,
    organizerId: 'organizer-1',
    teamAId: teamAId,
    teamBId: teamBId,
    teamAPlayerIds: teamAPlayerIds,
    teamBPlayerIds: teamBPlayerIds,
    createdAt: DateTime(2026, 5, 3, 18),
  );
}

Player _player({required String id, required String name}) {
  final now = DateTime(2026, 5, 3, 18);
  return Player(id: id, name: name, createdAt: now, lastActiveAt: now);
}

GuestPlayer _guestPlayer({
  required String id,
  required String displayName,
  String? teamId,
  String? guestTeamId,
  String? linkedPlayerId,
  required DateTime now,
}) {
  return GuestPlayer(
    id: id,
    displayName: displayName,
    normalizedName: displayName.toLowerCase(),
    teamId: teamId,
    guestTeamId: guestTeamId,
    createdBy: 'organizer-1',
    createdAt: now,
    updatedAt: now,
    linkedPlayerId: linkedPlayerId,
  );
}

TeamMembership _membership({
  required String id,
  required String teamId,
  String? playerId,
  String? guestPlayerId,
}) {
  final now = DateTime(2026, 5, 3, 18);
  return TeamMembership(
    id: id,
    teamId: teamId,
    playerId: playerId,
    guestPlayerId: guestPlayerId,
    role: TeamMembershipRole.player,
    status: TeamMembershipStatus.bench,
    availability: TeamMemberAvailability.available,
    joinedAt: now,
    updatedAt: now,
  );
}

MatchSidePlayer _sidePlayer({
  required String id,
  required String sideKey,
  String kind = 'temporary',
  String? playerId,
  required String displayName,
  bool ratingEligible = false,
  required DateTime now,
}) {
  return MatchSidePlayer(
    id: id,
    matchId: 'match-1',
    sideKey: sideKey,
    sideId: 'match-1_$sideKey',
    kind: kind,
    playerId: playerId,
    displayName: displayName,
    ratingEligible: ratingEligible,
    addedBy: 'organizer-1',
    createdAt: now,
  );
}

MatchLineupEntry _entry({
  required String attendanceId,
  String? playerId,
  String? guestPlayerId,
  String? matchSidePlayerId,
  required String displayName,
}) {
  return MatchLineupEntry(
    attendanceId: attendanceId,
    playerId: playerId,
    guestPlayerId: guestPlayerId,
    matchSidePlayerId: matchSidePlayerId,
    role: TeamMembershipRole.player,
    availability: TeamMemberAvailability.available,
    attendanceStatus: MatchAttendanceStatus.present,
    displayName: displayName,
  );
}

String _participantKey(ParticipantRef participant) {
  return '${participant.kind.name}:${participant.id}';
}

Future<void> _saveMatch(FakeFirebaseFirestore firestore, Match match) async {
  await firestore
      .collection(FirebasePaths.matches)
      .doc(match.id)
      .set(MatchModel.fromEntity(match).toJson());
}

Future<void> _savePlayer(FakeFirebaseFirestore firestore, Player player) async {
  await firestore
      .collection(FirebasePaths.players)
      .doc(player.id)
      .set(PlayerModel.fromEntity(player).toJson());
}

Future<void> _saveGuestPlayer(
  FakeFirebaseFirestore firestore,
  GuestPlayer guestPlayer,
) async {
  await firestore
      .collection(FirebasePaths.guestPlayers)
      .doc(guestPlayer.id)
      .set(GuestPlayerModel.fromEntity(guestPlayer).toJson());
}

Future<void> _saveMembership(
  FakeFirebaseFirestore firestore,
  TeamMembership membership,
) async {
  await firestore
      .collection(FirebasePaths.teamMemberships)
      .doc(membership.id)
      .set(TeamMembershipModel.fromEntity(membership).toJson());
}

Future<void> _saveMatchSidePlayer(
  FakeFirebaseFirestore firestore,
  MatchSidePlayer player,
) async {
  await firestore
      .collection(FirebasePaths.matchSidePlayers)
      .doc(player.id)
      .set(MatchSidePlayerModel.fromEntity(player).toJson());
}

Future<void> _saveLineupSnapshot(
  FakeFirebaseFirestore firestore,
  MatchLineupSnapshot snapshot,
) async {
  await firestore
      .collection(FirebasePaths.matchLineupSnapshots)
      .doc(snapshot.id)
      .set(MatchLineupSnapshotModel.fromEntity(snapshot).toJson());
}
