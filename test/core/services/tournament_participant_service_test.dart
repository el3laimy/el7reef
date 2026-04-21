import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/constants/firebase_paths.dart';
import 'package:el7reef/core/enums/guest_claim_status.dart';
import 'package:el7reef/core/enums/tournament_enums.dart';
import 'package:el7reef/core/enums/tournament_ops_enums.dart';
import 'package:el7reef/core/services/tournament_lifecycle_service.dart';
import 'package:el7reef/core/services/tournament_participant_service.dart';
import 'package:el7reef/core/services/tournament_registration_service.dart';
import 'package:el7reef/data/models/tournament_registration_model.dart';
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

        expect(
          replacement.replacementParticipant.status,
          TournamentParticipantStatus.finalized,
        );
        expect(
          replacement.replacementParticipant.replacementForParticipantId,
          participantId,
        );
        expect(replaced.status, TournamentParticipantStatus.replaced);
        expect(
          replaced.replacedByParticipantId,
          replacement.replacementParticipant.id,
        );
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

    test(
      'reactivateParticipant restores withdrawn finalized participant',
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

        await participantService.withdrawParticipant(
          participantId: participantId,
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 11)),
        );
        final reactivated = await participantService.reactivateParticipant(
          participantId: participantId,
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 12)),
        );

        final tournament = await tournamentRepository.getTournament(
          'tournament-1',
        );
        expect(
          reactivated.reactivatedParticipant.status,
          TournamentParticipantStatus.finalized,
        );
        expect(reactivated.reactivatedParticipant.withdrawnAt, isNull);
        expect(tournament?.activeParticipantCount, 2);
      },
    );

    test(
      'reactivateParticipant restores replaced participant and withdraws replacement',
      () async {
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

        final reactivated = await participantService.reactivateParticipant(
          participantId: participantId,
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 12)),
        );

        final participants = await participantService.getTournamentParticipants(
          'tournament-1',
        );
        final withdrawnReplacement = participants.firstWhere(
          (item) => item.id == replacement.replacementParticipant.id,
        );

        expect(
          reactivated.reactivatedParticipant.status,
          TournamentParticipantStatus.approved,
        );
        expect(
          reactivated.reactivatedParticipant.replacedByParticipantId,
          isNull,
        );
        expect(
          reactivated.withdrawnReplacement?.id,
          replacement.replacementParticipant.id,
        );
        expect(
          withdrawnReplacement.status,
          TournamentParticipantStatus.withdrawn,
        );
      },
    );

    test(
      'updateParticipantSeed updates active participant before groups start',
      () async {
        final participantId = participantService.participantIdFor(
          tournamentId: 'tournament-1',
          sourceType: TournamentParticipantSourceType.registeredTeam,
          sourceEntityId: 'team-1',
        );

        final updated = await participantService.updateParticipantSeed(
          participantId: participantId,
          actorId: 'organizer-1',
          seed: 7,
          now: now.add(const Duration(minutes: 6)),
        );

        expect(updated.seed, 7);
      },
    );

    test(
      'withdrawParticipant is a no-op when participant is already withdrawn',
      () async {
        final participantId = participantService.participantIdFor(
          tournamentId: 'tournament-1',
          sourceType: TournamentParticipantSourceType.registeredTeam,
          sourceEntityId: 'team-1',
        );

        await participantService.withdrawParticipant(
          participantId: participantId,
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 6)),
        );
        final participantDocBefore = await firestore
            .collection(FirebasePaths.tournamentParticipants)
            .doc(participantId)
            .get();
        final auditBefore = await firestore
            .collection(FirebasePaths.auditEvents)
            .where('action', isEqualTo: 'participantWithdrawn')
            .where('entityId', isEqualTo: participantId)
            .get();

        final unchanged = await participantService.withdrawParticipant(
          participantId: participantId,
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 7)),
        );
        final participantDocAfter = await firestore
            .collection(FirebasePaths.tournamentParticipants)
            .doc(participantId)
            .get();
        final auditAfter = await firestore
            .collection(FirebasePaths.auditEvents)
            .where('action', isEqualTo: 'participantWithdrawn')
            .where('entityId', isEqualTo: participantId)
            .get();

        expect(unchanged.status, TournamentParticipantStatus.withdrawn);
        expect(
          participantDocAfter.data()?['updatedAt'],
          participantDocBefore.data()?['updatedAt'],
        );
        expect(auditAfter.docs, hasLength(auditBefore.docs.length));
      },
    );

    test('updateParticipantSeed is a no-op when seed is unchanged', () async {
      final participantId = participantService.participantIdFor(
        tournamentId: 'tournament-1',
        sourceType: TournamentParticipantSourceType.registeredTeam,
        sourceEntityId: 'team-1',
      );

      await participantService.updateParticipantSeed(
        participantId: participantId,
        actorId: 'organizer-1',
        seed: 3,
        now: now.add(const Duration(minutes: 6)),
      );
      final participantDocBefore = await firestore
          .collection(FirebasePaths.tournamentParticipants)
          .doc(participantId)
          .get();
      final auditBefore = await firestore
          .collection(FirebasePaths.auditEvents)
          .where('action', isEqualTo: 'participantSeedUpdated')
          .where('entityId', isEqualTo: participantId)
          .get();

      final unchanged = await participantService.updateParticipantSeed(
        participantId: participantId,
        actorId: 'organizer-1',
        seed: 3,
        now: now.add(const Duration(minutes: 7)),
      );
      final participantDocAfter = await firestore
          .collection(FirebasePaths.tournamentParticipants)
          .doc(participantId)
          .get();
      final auditAfter = await firestore
          .collection(FirebasePaths.auditEvents)
          .where('action', isEqualTo: 'participantSeedUpdated')
          .where('entityId', isEqualTo: participantId)
          .get();

      expect(unchanged.seed, 3);
      expect(
        participantDocAfter.data()?['updatedAt'],
        participantDocBefore.data()?['updatedAt'],
      );
      expect(auditAfter.docs, hasLength(auditBefore.docs.length));
    });

    test(
      'syncApprovedRegistration is a no-op when participant state is unchanged',
      () async {
        final registrationSnapshot = await firestore
            .collection(FirebasePaths.tournamentRegistrations)
            .doc('team::tournament-1::team-1')
            .get();
        final registration = TournamentRegistrationModel.fromJson(
          registrationSnapshot.data()!,
          registrationSnapshot.id,
        ).toEntity();
        final participantId = participantService.participantIdFor(
          tournamentId: 'tournament-1',
          sourceType: TournamentParticipantSourceType.registeredTeam,
          sourceEntityId: 'team-1',
        );

        final participantDocBefore = await firestore
            .collection(FirebasePaths.tournamentParticipants)
            .doc(participantId)
            .get();
        final tournamentDocBefore = await firestore
            .collection(FirebasePaths.tournaments)
            .doc('tournament-1')
            .get();
        final auditBefore = await firestore
            .collection(FirebasePaths.auditEvents)
            .where('action', isEqualTo: 'participantAdded')
            .where('entityId', isEqualTo: participantId)
            .get();

        final unchanged = await participantService.syncApprovedRegistration(
          registration: registration,
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 8)),
        );

        final participantDocAfter = await firestore
            .collection(FirebasePaths.tournamentParticipants)
            .doc(participantId)
            .get();
        final tournamentDocAfter = await firestore
            .collection(FirebasePaths.tournaments)
            .doc('tournament-1')
            .get();
        final auditAfter = await firestore
            .collection(FirebasePaths.auditEvents)
            .where('action', isEqualTo: 'participantAdded')
            .where('entityId', isEqualTo: participantId)
            .get();

        expect(
          unchanged.updatedAt,
          DateTime.fromMillisecondsSinceEpoch(
            participantDocBefore.data()!['updatedAt'] as int,
          ),
        );
        expect(
          participantDocAfter.data()?['updatedAt'],
          participantDocBefore.data()?['updatedAt'],
        );
        expect(
          tournamentDocAfter.data()?['activeParticipantCount'],
          tournamentDocBefore.data()?['activeParticipantCount'],
        );
        expect(auditAfter.docs, hasLength(auditBefore.docs.length));
      },
    );
  });
}
