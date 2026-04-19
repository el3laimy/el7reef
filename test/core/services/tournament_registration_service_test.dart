import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/enums/guest_claim_status.dart';
import 'package:el7reef/core/enums/tournament_enums.dart';
import 'package:el7reef/core/enums/tournament_registration_mode.dart';
import 'package:el7reef/core/enums/tournament_registration_status.dart';
import 'package:el7reef/core/enums/tournament_ops_enums.dart';
import 'package:el7reef/core/services/tournament_participant_service.dart';
import 'package:el7reef/core/services/tournament_registration_service.dart';
import 'package:el7reef/data/repositories/guest_team_repository_impl.dart';
import 'package:el7reef/data/repositories/team_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_registration_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_repository_impl.dart';
import 'package:el7reef/domain/entities/guest_team.dart';
import 'package:el7reef/domain/entities/team.dart';
import 'package:el7reef/domain/entities/tournament.dart';

void main() {
  group('TournamentRegistrationService', () {
    late FakeFirebaseFirestore firestore;
    late TournamentRegistrationService service;
    late TournamentRepositoryImpl tournamentRepository;
    late TournamentRegistrationRepositoryImpl registrationRepository;
    late TeamRepositoryImpl teamRepository;
    late GuestTeamRepositoryImpl guestTeamRepository;
    late TournamentParticipantService participantService;
    late DateTime now;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      service = TournamentRegistrationService(firestore: firestore);
      tournamentRepository = TournamentRepositoryImpl(db: firestore);
      registrationRepository = TournamentRegistrationRepositoryImpl(
        firestore: firestore,
      );
      teamRepository = TeamRepositoryImpl(firestore: firestore);
      guestTeamRepository = GuestTeamRepositoryImpl(firestore: firestore);
      participantService = TournamentParticipantService(firestore: firestore);
      now = DateTime(2026, 4, 16, 18);

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
      await teamRepository.createTeam(
        Team(
          id: 'team-1',
          name: 'Blue Sharks',
          ownerId: 'owner-1',
          playerIds: const ['owner-1'],
          createdAt: now,
        ),
      );
      await guestTeamRepository.createGuestTeam(
        GuestTeam(
          id: 'guest-team-1',
          name: 'Guest Falcons',
          normalizedName: 'guest falcons',
          creatorId: 'guest-owner-1',
          claimStatus: GuestClaimStatus.guest,
          createdAt: now,
          updatedAt: now,
        ),
      );
    });

    test(
      'registers a registered team immediately and syncs legacy arrays',
      () async {
        final result = await service.registerTeam(
          tournamentId: 'tournament-1',
          teamId: 'team-1',
          actorId: 'owner-1',
          now: now.add(const Duration(minutes: 10)),
        );

        final registration = await registrationRepository.getRegistration(
          result.registration.id,
        );
        final tournament = await tournamentRepository.getTournament(
          'tournament-1',
        );
        final team = await teamRepository.getTeam('team-1');
        final participants = await participantService.getTournamentParticipants(
          'tournament-1',
        );

        expect(result.outcome, TournamentRegistrationOutcome.approved);
        expect(result.syncedTournamentTeamIds, isTrue);
        expect(result.syncedParticipantTournamentIds, isTrue);
        expect(registration?.status, TournamentRegistrationStatus.approved);
        expect(tournament?.registeredTeamIds, contains('team-1'));
        expect(tournament?.activeParticipantCount, 1);
        expect(tournament?.teamCount, 1);
        expect(team?.tournamentIds, contains('tournament-1'));
        expect(participants, hasLength(1));
        expect(
          participants.single.sourceType,
          TournamentParticipantSourceType.registeredTeam,
        );
        expect(
          participants.single.sourceRegistrationId,
          result.registration.id,
        );
      },
    );

    test('re-running registered team registration is idempotent', () async {
      await service.registerTeam(
        tournamentId: 'tournament-1',
        teamId: 'team-1',
        actorId: 'owner-1',
        now: now.add(const Duration(minutes: 10)),
      );

      final second = await service.registerTeam(
        tournamentId: 'tournament-1',
        teamId: 'team-1',
        actorId: 'owner-1',
        now: now.add(const Duration(minutes: 20)),
      );

      expect(second.outcome, TournamentRegistrationOutcome.alreadyApproved);
      expect(second.isIdempotent, isTrue);
    });

    test(
      'verified mode keeps registered team pending until organizer approval',
      () async {
        final pending = await service.registerTeam(
          tournamentId: 'tournament-1',
          teamId: 'team-1',
          actorId: 'owner-1',
          mode: TournamentRegistrationMode.verified,
          now: now.add(const Duration(minutes: 10)),
        );

        final pendingTournament = await tournamentRepository.getTournament(
          'tournament-1',
        );
        final pendingTeam = await teamRepository.getTeam('team-1');

        expect(pending.outcome, TournamentRegistrationOutcome.pendingApproval);
        expect(
          pending.registration.status,
          TournamentRegistrationStatus.pending,
        );
        expect(pending.registration.verifiedBy, isNull);
        expect(pending.syncedTournamentTeamIds, isFalse);
        expect(pending.syncedParticipantTournamentIds, isFalse);
        expect(pendingTournament?.registeredTeamIds, isNot(contains('team-1')));
        expect(pendingTeam?.tournamentIds, isNot(contains('tournament-1')));

        final approved = await service.approveRegistration(
          registrationId: pending.registration.id,
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 20)),
        );

        final registration = await registrationRepository.getRegistration(
          pending.registration.id,
        );
        final tournament = await tournamentRepository.getTournament(
          'tournament-1',
        );
        final team = await teamRepository.getTeam('team-1');
        final participants = await participantService.getTournamentParticipants(
          'tournament-1',
        );

        expect(approved.outcome, TournamentRegistrationOutcome.approved);
        expect(registration?.status, TournamentRegistrationStatus.approved);
        expect(registration?.verifiedBy, 'organizer-1');
        expect(tournament?.registeredTeamIds, contains('team-1'));
        expect(tournament?.activeParticipantCount, 1);
        expect(team?.tournamentIds, contains('tournament-1'));
        expect(participants.single.sourceEntityId, 'team-1');
      },
    );

    test(
      'registers guest teams as pending in hybrid mode then organizer approves',
      () async {
        final pending = await service.registerGuestTeam(
          tournamentId: 'tournament-1',
          guestTeamId: 'guest-team-1',
          actorId: 'guest-owner-1',
          mode: TournamentRegistrationMode.hybrid,
          now: now.add(const Duration(minutes: 10)),
        );

        final approved = await service.approveRegistration(
          registrationId: pending.registration.id,
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 20)),
        );

        final registration = await registrationRepository.getRegistration(
          pending.registration.id,
        );
        final guestTeam = await guestTeamRepository.getGuestTeam(
          'guest-team-1',
        );
        final participants = await participantService.getTournamentParticipants(
          'tournament-1',
        );

        expect(pending.outcome, TournamentRegistrationOutcome.pendingApproval);
        expect(approved.outcome, TournamentRegistrationOutcome.approved);
        expect(registration?.status, TournamentRegistrationStatus.approved);
        expect(registration?.verifiedBy, 'organizer-1');
        expect(guestTeam?.tournamentIds, contains('tournament-1'));
        expect(
          (await tournamentRepository.getTournament(
            'tournament-1',
          ))?.activeParticipantCount,
          1,
        );
        expect(participants, hasLength(1));
        expect(
          participants.single.sourceType,
          TournamentParticipantSourceType.guestTeam,
        );
      },
    );

    test(
      're-running guest team registration while pending is idempotent',
      () async {
        final first = await service.registerGuestTeam(
          tournamentId: 'tournament-1',
          guestTeamId: 'guest-team-1',
          actorId: 'guest-owner-1',
          mode: TournamentRegistrationMode.hybrid,
          now: now.add(const Duration(minutes: 10)),
        );

        final second = await service.registerGuestTeam(
          tournamentId: 'tournament-1',
          guestTeamId: 'guest-team-1',
          actorId: 'guest-owner-1',
          mode: TournamentRegistrationMode.hybrid,
          now: now.add(const Duration(minutes: 20)),
        );

        final registrations = await registrationRepository
            .getTournamentRegistrations('tournament-1');

        expect(first.outcome, TournamentRegistrationOutcome.pendingApproval);
        expect(second.outcome, TournamentRegistrationOutcome.alreadyPending);
        expect(second.isIdempotent, isTrue);
        expect(registrations, hasLength(1));
        expect(registrations.single.id, first.registration.id);
      },
    );

    test(
      'organizer can reject pending registrations and rerun rejection safely',
      () async {
        final pending = await service.registerGuestTeam(
          tournamentId: 'tournament-1',
          guestTeamId: 'guest-team-1',
          actorId: 'guest-owner-1',
          mode: TournamentRegistrationMode.hybrid,
          now: now.add(const Duration(minutes: 10)),
        );

        final rejected = await service.rejectRegistration(
          registrationId: pending.registration.id,
          actorId: 'organizer-1',
          notes: 'Capacity held for another slot',
          now: now.add(const Duration(minutes: 20)),
        );
        final rerun = await service.rejectRegistration(
          registrationId: pending.registration.id,
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 30)),
        );

        final registration = await registrationRepository.getRegistration(
          pending.registration.id,
        );

        expect(rejected.outcome, TournamentRegistrationOutcome.rejected);
        expect(rerun.outcome, TournamentRegistrationOutcome.alreadyRejected);
        expect(registration?.status, TournamentRegistrationStatus.rejected);
        expect(registration?.notes, 'Capacity held for another slot');
      },
    );

    test(
      'quick mode rejects guest registration attempts from non-organizers',
      () async {
        expect(
          () => service.registerGuestTeam(
            tournamentId: 'tournament-1',
            guestTeamId: 'guest-team-1',
            actorId: 'guest-owner-1',
            mode: TournamentRegistrationMode.quick,
            now: now.add(const Duration(minutes: 10)),
          ),
          throwsA(
            isA<Exception>().having(
              (error) => error.toString(),
              'message',
              contains('الوضع السريع'),
            ),
          ),
        );
      },
    );

    test('verified mode for guest teams requires contact info', () async {
      expect(
        () => service.registerGuestTeam(
          tournamentId: 'tournament-1',
          guestTeamId: 'guest-team-1',
          actorId: 'guest-owner-1',
          mode: TournamentRegistrationMode.verified,
          now: now.add(const Duration(minutes: 10)),
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('الوضع الموثق'),
          ),
        ),
      );
    });

    test(
      'quick mode lets the organizer auto-approve guest registrations',
      () async {
        final result = await service.registerGuestTeam(
          tournamentId: 'tournament-1',
          guestTeamId: 'guest-team-1',
          actorId: 'organizer-1',
          mode: TournamentRegistrationMode.quick,
          now: now.add(const Duration(minutes: 10)),
        );

        final registration = await registrationRepository.getRegistration(
          result.registration.id,
        );
        final guestTeam = await guestTeamRepository.getGuestTeam(
          'guest-team-1',
        );

        expect(result.outcome, TournamentRegistrationOutcome.approved);
        expect(registration?.status, TournamentRegistrationStatus.approved);
        expect(registration?.verifiedBy, 'organizer-1');
        expect(guestTeam?.tournamentIds, contains('tournament-1'));
      },
    );

    test(
      'capacity policy blocks new registrations when tournament is full',
      () async {
        final fullTournamentId = 'tournament-full';
        await tournamentRepository.createTournament(
          Tournament(
            id: fullTournamentId,
            organizerId: 'organizer-1',
            name: 'Full Cup',
            format: TournamentFormat.groupsThenKnockout,
            teamSize: TournamentTeamSize.fiveVsFive,
            maxTeams: 1,
            status: TournamentStatus.registration,
            createdAt: now,
          ),
        );
        await guestTeamRepository.createGuestTeam(
          GuestTeam(
            id: 'guest-team-2',
            name: 'Guest Lions',
            normalizedName: 'guest lions',
            creatorId: 'guest-owner-2',
            contactName: 'Captain Guest',
            contactPhone: '01000000000',
            claimStatus: GuestClaimStatus.guest,
            createdAt: now,
            updatedAt: now,
          ),
        );

        await service.registerTeam(
          tournamentId: fullTournamentId,
          teamId: 'team-1',
          actorId: 'owner-1',
          now: now.add(const Duration(minutes: 5)),
        );

        expect(
          () => service.registerGuestTeam(
            tournamentId: fullTournamentId,
            guestTeamId: 'guest-team-2',
            actorId: 'guest-owner-2',
            mode: TournamentRegistrationMode.verified,
            now: now.add(const Duration(minutes: 10)),
          ),
          throwsA(
            isA<Exception>().having(
              (error) => error.toString(),
              'message',
              contains('اكتملت سعة التسجيل'),
            ),
          ),
        );
      },
    );

    test(
      'capacity policy prefers canonical activeParticipantCount before legacy arrays',
      () async {
        final canonicalFullTournamentId = 'tournament-canonical-full';
        await tournamentRepository.createTournament(
          Tournament(
            id: canonicalFullTournamentId,
            organizerId: 'organizer-1',
            name: 'Canonical Full Cup',
            format: TournamentFormat.groupsThenKnockout,
            teamSize: TournamentTeamSize.fiveVsFive,
            maxTeams: 1,
            status: TournamentStatus.registration,
            createdAt: now,
          ),
        );
        await teamRepository.createTeam(
          Team(
            id: 'team-2',
            name: 'Red Wolves',
            ownerId: 'owner-2',
            playerIds: const ['owner-2'],
            createdAt: now,
          ),
        );

        await participantService.addManualParticipant(
          tournamentId: canonicalFullTournamentId,
          sourceType: TournamentParticipantSourceType.registeredTeam,
          sourceEntityId: 'team-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 5)),
        );

        final tournament = await tournamentRepository.getTournament(
          canonicalFullTournamentId,
        );
        expect(tournament?.activeParticipantCount, 1);
        expect(tournament?.registeredTeamIds, isEmpty);

        expect(
          () => service.registerTeam(
            tournamentId: canonicalFullTournamentId,
            teamId: 'team-2',
            actorId: 'owner-2',
            now: now.add(const Duration(minutes: 10)),
          ),
          throwsA(
            isA<Exception>().having(
              (error) => error.toString(),
              'message',
              contains('اكتملت سعة التسجيل'),
            ),
          ),
        );
      },
    );

    test(
      'registration deadline closes new approvals and registrations',
      () async {
        final deadlineTournamentId = 'tournament-deadline';
        final deadline = now.add(const Duration(minutes: 15));
        await tournamentRepository.createTournament(
          Tournament(
            id: deadlineTournamentId,
            organizerId: 'organizer-1',
            name: 'Deadline Cup',
            format: TournamentFormat.groupsThenKnockout,
            teamSize: TournamentTeamSize.fiveVsFive,
            maxTeams: 8,
            status: TournamentStatus.registration,
            registrationDeadline: deadline,
            createdAt: now,
          ),
        );
        await guestTeamRepository.createGuestTeam(
          GuestTeam(
            id: 'guest-team-3',
            name: 'Guest Deadline',
            normalizedName: 'guest deadline',
            creatorId: 'guest-owner-3',
            contactName: 'Deadline Captain',
            contactPhone: '01111111111',
            claimStatus: GuestClaimStatus.guest,
            createdAt: now,
            updatedAt: now,
          ),
        );

        final pending = await service.registerGuestTeam(
          tournamentId: deadlineTournamentId,
          guestTeamId: 'guest-team-3',
          actorId: 'guest-owner-3',
          mode: TournamentRegistrationMode.hybrid,
          now: now.add(const Duration(minutes: 5)),
        );

        expect(
          () => service.approveRegistration(
            registrationId: pending.registration.id,
            actorId: 'organizer-1',
            now: now.add(const Duration(minutes: 20)),
          ),
          throwsA(
            isA<Exception>().having(
              (error) => error.toString(),
              'message',
              contains('إغلاق نافذة التسجيل'),
            ),
          ),
        );

        expect(
          () => service.registerTeam(
            tournamentId: deadlineTournamentId,
            teamId: 'team-1',
            actorId: 'owner-1',
            now: now.add(const Duration(minutes: 20)),
          ),
          throwsA(
            isA<Exception>().having(
              (error) => error.toString(),
              'message',
              contains('التسجيل في هذه الدورة مغلق'),
            ),
          ),
        );
      },
    );
  });
}
