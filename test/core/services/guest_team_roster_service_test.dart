import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/constants/firebase_paths.dart';
import 'package:el7reef/core/enums/tournament_enums.dart';
import 'package:el7reef/core/services/guest_team_roster_service.dart';
import 'package:el7reef/core/services/tournament_audit_emitter.dart';
import 'package:el7reef/core/services/tournament_permission_service.dart';
import 'package:el7reef/data/repositories/guest_player_repository_impl.dart';
import 'package:el7reef/data/repositories/guest_team_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_repository_impl.dart';
import 'package:el7reef/domain/entities/guest_team.dart';
import 'package:el7reef/domain/entities/tournament.dart';
import 'package:el7reef/domain/entities/tournament_assistant.dart';

void main() {
  group('GuestTeamRosterService', () {
    late FakeFirebaseFirestore firestore;
    late GuestPlayerRepositoryImpl guestPlayerRepository;
    late GuestTeamRepositoryImpl guestTeamRepository;
    late TournamentRepositoryImpl tournamentRepository;
    late GuestTeamRosterService service;
    late DateTime now;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      guestPlayerRepository = GuestPlayerRepositoryImpl(firestore: firestore);
      guestTeamRepository = GuestTeamRepositoryImpl(firestore: firestore);
      tournamentRepository = TournamentRepositoryImpl(db: firestore);
      service = GuestTeamRosterService(
        guestPlayerRepository: guestPlayerRepository,
        guestTeamRepository: guestTeamRepository,
        tournamentRepository: tournamentRepository,
        tournamentPermissionService: TournamentPermissionService(),
        auditEmitter: TournamentAuditEmitter(firestore: firestore),
      );
      now = DateTime(2026, 4, 20, 21);

      await tournamentRepository.createTournament(
        Tournament(
          id: 'tournament-1',
          organizerId: 'organizer-1',
          name: 'Street Cup',
          format: TournamentFormat.groupsThenKnockout,
          teamSize: TournamentTeamSize.fiveVsFive,
          maxTeams: 8,
          assistants: [
            TournamentAssistant(
              userId: 'assistant-1',
              role: TournamentAssistantRole.full,
              assignedAt: now,
            ),
            TournamentAssistant(
              userId: 'results-1',
              role: TournamentAssistantRole.resultsOnly,
              assignedAt: now,
            ),
          ],
          createdAt: now,
        ),
      );
      await guestTeamRepository.createGuestTeam(
        GuestTeam(
          id: 'guest-team-1',
          name: 'Red Guests',
          normalizedName: 'red guests',
          creatorId: 'guest-creator-1',
          tournamentIds: const ['tournament-1'],
          createdAt: now,
          updatedAt: now,
        ),
      );
      await guestTeamRepository.createGuestTeam(
        GuestTeam(
          id: 'guest-team-2',
          name: 'Black Guests',
          normalizedName: 'black guests',
          creatorId: 'guest-creator-2',
          tournamentIds: const ['tournament-1'],
          createdAt: now,
          updatedAt: now,
        ),
      );
    });

    test(
      'creates, updates, archives, and assigns captain for guest roster',
      () async {
        final created = await service.createGuestPlayer(
          tournamentId: 'tournament-1',
          guestTeamId: 'guest-team-1',
          actorId: 'organizer-1',
          displayName: 'Mahmoud Ali',
          jerseyNumber: 10,
          preferredPosition: 'MID',
          now: now,
        );
        final updatedTeam = await service.setCaptain(
          tournamentId: 'tournament-1',
          guestTeamId: 'guest-team-1',
          actorId: 'organizer-1',
          guestPlayerId: created.id,
          now: now.add(const Duration(minutes: 1)),
        );
        final updatedPlayer = await service.updateGuestPlayer(
          tournamentId: 'tournament-1',
          guestTeamId: 'guest-team-1',
          actorId: 'organizer-1',
          guestPlayerId: created.id,
          displayName: 'Mahmoud Hassan',
          phoneNumber: '01000000000',
          jerseyNumber: 11,
          preferredPosition: 'FWD',
          notes: 'captain',
          now: now.add(const Duration(minutes: 2)),
        );
        final archivedPlayer = await service.archiveGuestPlayer(
          tournamentId: 'tournament-1',
          guestTeamId: 'guest-team-1',
          actorId: 'organizer-1',
          guestPlayerId: created.id,
          now: now.add(const Duration(minutes: 3)),
        );

        final savedPlayer = await guestPlayerRepository.getGuestPlayer(
          created.id,
        );
        final savedTeam = await guestTeamRepository.getGuestTeam(
          'guest-team-1',
        );
        final auditSnapshot = await firestore
            .collection(FirebasePaths.auditEvents)
            .where('metadata.tournamentId', isEqualTo: 'tournament-1')
            .get();
        final actions = auditSnapshot.docs
            .map((doc) => doc.data()['action'] as String?)
            .whereType<String>()
            .toList(growable: false);

        expect(created.guestTeamId, 'guest-team-1');
        expect(updatedTeam.captainGuestPlayerId, created.id);
        expect(updatedPlayer.displayName, 'Mahmoud Hassan');
        expect(archivedPlayer.isArchived, isTrue);
        expect(savedPlayer?.guestTeamId, 'guest-team-1');
        expect(savedPlayer?.claimStatus.name, 'archived');
        expect(savedTeam?.captainGuestPlayerId, isNull);
        expect(actions, contains('guestPlayerCreated'));
        expect(actions, contains('guestPlayerUpdated'));
        expect(actions, contains('guestPlayerArchived'));
        expect(actions, contains('guestTeamCaptainUpdated'));
      },
    );

    test('isolates guest roster by guest team id', () async {
      await service.createGuestPlayer(
        tournamentId: 'tournament-1',
        guestTeamId: 'guest-team-1',
        actorId: 'organizer-1',
        displayName: 'Guest One',
        now: now,
      );
      await service.createGuestPlayer(
        tournamentId: 'tournament-1',
        guestTeamId: 'guest-team-2',
        actorId: 'organizer-1',
        displayName: 'Guest Two',
        now: now.add(const Duration(minutes: 1)),
      );

      final roster = await service.getGuestRoster(
        tournamentId: 'tournament-1',
        guestTeamId: 'guest-team-1',
        actorId: 'organizer-1',
      );

      expect(roster.map((player) => player.displayName), ['Guest One']);
    });

    test(
      'allows guest creator and full assistant but blocks results-only assistant',
      () async {
        final byCreator = await service.createGuestPlayer(
          tournamentId: 'tournament-1',
          guestTeamId: 'guest-team-1',
          actorId: 'guest-creator-1',
          displayName: 'Creator Guest',
          now: now,
        );
        final byAssistant = await service.createGuestPlayer(
          tournamentId: 'tournament-1',
          guestTeamId: 'guest-team-1',
          actorId: 'assistant-1',
          displayName: 'Assistant Guest',
          now: now.add(const Duration(minutes: 1)),
        );

        expect(byCreator.displayName, 'Creator Guest');
        expect(byAssistant.displayName, 'Assistant Guest');

        await expectLater(
          () => service.createGuestPlayer(
            tournamentId: 'tournament-1',
            guestTeamId: 'guest-team-1',
            actorId: 'results-1',
            displayName: 'Blocked Guest',
            now: now.add(const Duration(minutes: 2)),
          ),
          throwsA(
            predicate(
              (error) => error.toString().contains(
                'لا تملك صلاحية إدارة roster هذا الفريق الضيف',
              ),
            ),
          ),
        );
      },
    );
  });
}
