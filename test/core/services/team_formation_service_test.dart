import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/enums/team_membership_status.dart';
import 'package:el7reef/core/services/team_formation_service.dart';
import 'package:el7reef/core/services/team_roster_service.dart';
import 'package:el7reef/data/repositories/guest_player_repository_impl.dart';
import 'package:el7reef/data/repositories/player_repository_impl.dart';
import 'package:el7reef/data/repositories/team_formation_template_repository_impl.dart';
import 'package:el7reef/data/repositories/team_membership_repository_impl.dart';
import 'package:el7reef/data/repositories/team_repository_impl.dart';
import 'package:el7reef/data/repositories/team_roster_snapshot_repository_impl.dart';
import 'package:el7reef/domain/entities/guest_player.dart';
import 'package:el7reef/domain/entities/player.dart';
import 'package:el7reef/domain/entities/team.dart';

void main() {
  group('TeamFormationService', () {
    late FakeFirebaseFirestore firestore;
    late TeamRepositoryImpl teamRepository;
    late TeamMembershipRepositoryImpl membershipRepository;
    late PlayerRepositoryImpl playerRepository;
    late GuestPlayerRepositoryImpl guestPlayerRepository;
    late TeamFormationTemplateRepositoryImpl templateRepository;
    late TeamRosterSnapshotRepositoryImpl snapshotRepository;
    late TeamRosterService rosterService;
    late TeamFormationService formationService;
    late DateTime now;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      teamRepository = TeamRepositoryImpl(firestore: firestore);
      membershipRepository = TeamMembershipRepositoryImpl(firestore: firestore);
      playerRepository = PlayerRepositoryImpl(firestore: firestore);
      guestPlayerRepository = GuestPlayerRepositoryImpl(firestore: firestore);
      templateRepository =
          TeamFormationTemplateRepositoryImpl(firestore: firestore);
      snapshotRepository =
          TeamRosterSnapshotRepositoryImpl(firestore: firestore);
      rosterService = TeamRosterService(
        teamRepository: teamRepository,
        membershipRepository: membershipRepository,
        guestPlayerRepository: guestPlayerRepository,
      );
      formationService = TeamFormationService(
        teamRepository: teamRepository,
        membershipRepository: membershipRepository,
        playerRepository: playerRepository,
        guestPlayerRepository: guestPlayerRepository,
        templateRepository: templateRepository,
        snapshotRepository: snapshotRepository,
      );
      now = DateTime(2026, 4, 16, 12);

      await teamRepository.createTeam(
        Team(
          id: 'team-1',
          name: 'Street Kings',
          ownerId: 'owner-1',
          playerIds: const ['owner-1'],
          createdAt: now,
        ),
      );
      await playerRepository.createPlayer(
        Player(
          id: 'owner-1',
          name: 'Owner One',
          createdAt: now,
          lastActiveAt: now,
        ),
      );
      await playerRepository.createPlayer(
        Player(
          id: 'player-2',
          name: 'Ahmed Salem',
          position: 'MID',
          createdAt: now,
          lastActiveAt: now,
        ),
      );
      await playerRepository.createPlayer(
        Player(
          id: 'player-3',
          name: 'Khaled Nasser',
          position: 'DEF',
          createdAt: now,
          lastActiveAt: now,
        ),
      );
      await playerRepository.createPlayer(
        Player(
          id: 'player-4',
          name: 'Omar Adel',
          position: 'FWD',
          createdAt: now,
          lastActiveAt: now,
        ),
      );
      await guestPlayerRepository.createGuestPlayer(
        GuestPlayer(
          id: 'guest-1',
          displayName: 'Mahmoud Ali',
          normalizedName: 'mahmoud ali',
          preferredPosition: 'GK',
          createdBy: 'owner-1',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await rosterService.addRegisteredPlayer(
        teamId: 'team-1',
        actorId: 'owner-1',
        playerId: 'player-2',
        status: TeamMembershipStatus.starter,
        now: now,
      );
      await rosterService.addRegisteredPlayer(
        teamId: 'team-1',
        actorId: 'owner-1',
        playerId: 'player-3',
        status: TeamMembershipStatus.bench,
        now: now.add(const Duration(minutes: 1)),
      );
      await rosterService.addGuestPlayer(
        teamId: 'team-1',
        actorId: 'owner-1',
        guestPlayerId: 'guest-1',
        status: TeamMembershipStatus.starter,
        now: now.add(const Duration(minutes: 2)),
      );
    });

    test('saves named formation templates from current roster state', () async {
      final template = await formationService.saveCurrentAsTemplate(
        teamId: 'team-1',
        actorId: 'owner-1',
        name: 'خطة الدوري',
        formationLabel: 'أساسي 2 • احتياط 1',
        now: now.add(const Duration(minutes: 5)),
      );

      final templates = await formationService.getTeamTemplates('team-1');

      expect(template.name, 'خطة الدوري');
      expect(templates, hasLength(1));
      expect(templates.single.entries, hasLength(4));
      expect(
        templates.single.entries.where((entry) => entry.isGuest).single.displayName,
        'Mahmoud Ali',
      );
    });

    test('creates ready roster snapshots with preserved summary metadata',
        () async {
      final snapshot = await formationService.createRosterSnapshot(
        teamId: 'team-1',
        actorId: 'owner-1',
        label: 'قبل مباراة نصف النهائي',
        formationLabel: 'أساسي 2 • احتياط 1',
        now: now.add(const Duration(minutes: 10)),
      );

      final snapshots = await formationService.getRecentSnapshots('team-1');

      expect(snapshot.label, 'قبل مباراة نصف النهائي');
      expect(snapshots, hasLength(1));
      expect(snapshots.single.entries, hasLength(4));
      expect(snapshots.single.summaryLabel, 'أساسي 2 • احتياط 1');
    });

    test('applies saved template and benches unmatched starters', () async {
      final template = await formationService.saveCurrentAsTemplate(
        teamId: 'team-1',
        actorId: 'owner-1',
        name: 'التشكيلة الأساسية',
        now: now.add(const Duration(minutes: 5)),
      );

      await rosterService.addRegisteredPlayer(
        teamId: 'team-1',
        actorId: 'owner-1',
        playerId: 'player-4',
        status: TeamMembershipStatus.starter,
        now: now.add(const Duration(minutes: 6)),
      );

      final playerTwoMembership = (await rosterService.getTeamRoster(
        'team-1',
        includeInactive: true,
      ))
          .firstWhere((membership) => membership.playerId == 'player-2');
      await rosterService.updateMembershipStatus(
        teamId: 'team-1',
        actorId: 'owner-1',
        membershipId: playerTwoMembership.id,
        status: TeamMembershipStatus.bench,
        now: now.add(const Duration(minutes: 7)),
      );

      final result = await formationService.applyTemplate(
        teamId: 'team-1',
        actorId: 'owner-1',
        templateId: template.id,
        now: now.add(const Duration(minutes: 8)),
      );

      final roster = await rosterService.getTeamRoster(
        'team-1',
        includeInactive: true,
      );

      expect(result.matchedMembers, 4);
      expect(result.movedToBenchMembers, 1);
      expect(
        roster.firstWhere((membership) => membership.playerId == 'player-2').status,
        TeamMembershipStatus.starter,
      );
      expect(
        roster.firstWhere((membership) => membership.playerId == 'player-4').status,
        TeamMembershipStatus.bench,
      );
    });
  });
}
