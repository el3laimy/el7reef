import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/enums/guest_claim_status.dart';
import 'package:el7reef/core/enums/tournament_enums.dart';
import 'package:el7reef/core/enums/tournament_ops_enums.dart';
import 'package:el7reef/core/services/tournament_lifecycle_service.dart';
import 'package:el7reef/core/services/tournament_participant_service.dart';
import 'package:el7reef/core/services/tournament_registration_service.dart';
import 'package:el7reef/data/repositories/guest_team_repository_impl.dart';
import 'package:el7reef/data/repositories/team_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_repository_impl.dart';
import 'package:el7reef/domain/entities/guest_team.dart';
import 'package:el7reef/domain/entities/team.dart';
import 'package:el7reef/domain/entities/tournament.dart';

void main() {
  group('TournamentParticipantService', () {
    late FakeFirebaseFirestore firestore;
    late TournamentRepositoryImpl tournamentRepository;
    late TeamRepositoryImpl teamRepository;
    late GuestTeamRepositoryImpl guestTeamRepository;
    late TournamentRegistrationService registrationService;
    late TournamentParticipantService participantService;
    late TournamentLifecycleService lifecycleService;
    late DateTime now;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      tournamentRepository = TournamentRepositoryImpl(db: firestore);
      teamRepository = TeamRepositoryImpl(firestore: firestore);
      guestTeamRepository = GuestTeamRepositoryImpl(firestore: firestore);
      registrationService = TournamentRegistrationService(firestore: firestore);
      participantService = TournamentParticipantService(firestore: firestore);
      lifecycleService = TournamentLifecycleService(firestore: firestore);
      now = DateTime(2026, 4, 20, 20);

      await tournamentRepository.createTournament(
        Tournament(
          id: 'tournament-1',
          organizerId: 'organizer-1',
          name: 'Street Cup',
          format: TournamentFormat.groupsThenKnockout,
          teamSize: TournamentTeamSize.fiveVsFive,
          maxTeams: 8,
          status: TournamentStatus.registration,
          createdAt: now,
        ),
      );

      for (int index = 1; index <= 3; index++) {
        await teamRepository.createTeam(
          Team(
            id: 'team-$index',
            name: 'Team $index',
            ownerId: 'organizer-1',
            playerIds: const ['organizer-1'],
            createdAt: now,
          ),
        );
      }

      await guestTeamRepository.createGuestTeam(
        GuestTeam(
          id: 'guest-team-1',
          name: 'Guest Falcons',
          normalizedName: 'guest falcons',
          creatorId: 'organizer-1',
          claimStatus: GuestClaimStatus.guest,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await registrationService.registerTeam(
        tournamentId: 'tournament-1',
        teamId: 'team-1',
        actorId: 'organizer-1',
        now: now.add(const Duration(minutes: 1)),
      );
      await registrationService.registerTeam(
        tournamentId: 'tournament-1',
        teamId: 'team-2',
        actorId: 'organizer-1',
        now: now.add(const Duration(minutes: 2)),
      );
    });

    test('manual add works before participant finalization', () async {
      final participant = await participantService.addManualParticipant(
        tournamentId: 'tournament-1',
        sourceType: TournamentParticipantSourceType.guestTeam,
        sourceEntityId: 'guest-team-1',
        actorId: 'organizer-1',
        now: now.add(const Duration(minutes: 5)),
      );

      final participants = await participantService.getTournamentParticipants(
        'tournament-1',
      );
      final tournament = await tournamentRepository.getTournament(
        'tournament-1',
      );

      expect(participant.sourceType, TournamentParticipantSourceType.guestTeam);
      expect(participant.sourceEntityId, 'guest-team-1');
      expect(participants, hasLength(3));
      expect(tournament?.activeParticipantCount, 3);
      expect(tournament?.teamCount, 3);
    });

    test('manual add is blocked after participant finalization', () async {
      await lifecycleService.finalizeParticipants(
        tournamentId: 'tournament-1',
        actorId: 'organizer-1',
        now: now.add(const Duration(minutes: 10)),
      );

      expect(
        () => participantService.addManualParticipant(
          tournamentId: 'tournament-1',
          sourceType: TournamentParticipantSourceType.registeredTeam,
          sourceEntityId: 'team-3',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 11)),
        ),
        throwsA(
          predicate(
            (error) => error.toString().contains('قفل قائمة المشاركين'),
          ),
        ),
      );
    });

    test(
      'replaceParticipant keeps finalized replacement before groups start',
      () async {
        await lifecycleService.finalizeParticipants(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 10)),
        );
        final participantId = participantService.participantIdFor(
          tournamentId: 'tournament-1',
          sourceType: TournamentParticipantSourceType.registeredTeam,
          sourceEntityId: 'team-1',
        );

        final replacement = await participantService.replaceParticipant(
          participantId: participantId,
          replacementSourceType: TournamentParticipantSourceType.registeredTeam,
          replacementSourceEntityId: 'team-3',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 11)),
        );

        final participants = await participantService.getTournamentParticipants(
          'tournament-1',
        );
        final replaced = participants.firstWhere(
          (item) => item.id == participantId,
        );
        final tournament = await tournamentRepository.getTournament(
          'tournament-1',
        );

        expect(replacement.status, TournamentParticipantStatus.finalized);
        expect(replacement.replacementForParticipantId, participantId);
        expect(replaced.status, TournamentParticipantStatus.replaced);
        expect(replaced.replacedByParticipantId, replacement.id);
        expect(tournament?.activeParticipantCount, 2);
      },
    );

    test('replaceParticipant is blocked after group stage starts', () async {
      await lifecycleService.finalizeParticipants(
        tournamentId: 'tournament-1',
        actorId: 'organizer-1',
        now: now.add(const Duration(minutes: 10)),
      );
      await lifecycleService.startGroupStage(
        tournamentId: 'tournament-1',
        actorId: 'organizer-1',
        now: now.add(const Duration(minutes: 15)),
      );
      final participantId = participantService.participantIdFor(
        tournamentId: 'tournament-1',
        sourceType: TournamentParticipantSourceType.registeredTeam,
        sourceEntityId: 'team-1',
      );

      expect(
        () => participantService.replaceParticipant(
          participantId: participantId,
          replacementSourceType: TournamentParticipantSourceType.registeredTeam,
          replacementSourceEntityId: 'team-3',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 16)),
        ),
        throwsA(
          predicate(
            (error) => error.toString().contains('بعد بدء تشغيل البطولة'),
          ),
        ),
      );
    });
  });
}
