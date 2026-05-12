import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/constants/firebase_paths.dart';
import 'package:el7reef/core/enums/fantasy_league_phase.dart';
import 'package:el7reef/core/enums/tournament_enums.dart';
import 'package:el7reef/features/fantasy/services/fantasy_lifecycle_service.dart';
import 'package:el7reef/data/repositories/fantasy_lifecycle_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_repository_impl.dart';
import 'package:el7reef/domain/entities/fantasy_league_lifecycle.dart';
import 'package:el7reef/domain/entities/tournament.dart';

void main() {
  group('FantasyLifecycleService', () {
    late FakeFirebaseFirestore firestore;
    late FantasyLifecycleService service;
    late FantasyLifecycleRepositoryImpl lifecycleRepository;
    late TournamentRepositoryImpl tournamentRepository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      lifecycleRepository = FantasyLifecycleRepositoryImpl(firestore: firestore);
      tournamentRepository = TournamentRepositoryImpl(db: firestore);
      service = FantasyLifecycleService(
        lifecycleRepository: lifecycleRepository,
        tournamentRepository: tournamentRepository,
      );
    });

    test('returns global fallback when no lifecycle document exists', () async {
      final lifecycle = await service.resolveLifecycle(
        'global',
        now: DateTime(2026, 4, 14, 12),
      );

      expect(lifecycle.leagueId, 'global');
      expect(lifecycle.currentGameweek, 1);
      expect(lifecycle.phase, FantasyLeaguePhase.draft);
      expect(lifecycle.isLocked, isFalse);
      expect(lifecycle.isGlobal, isTrue);
    });

    test('returns stored lifecycle and auto-locks after deadline', () async {
      await lifecycleRepository.saveLeagueLifecycle(
        FantasyLeagueLifecycle(
          leagueId: 'league-1',
          currentGameweek: 4,
          phase: FantasyLeaguePhase.live,
          deadlineAt: DateTime(2026, 4, 14, 10),
          isLocked: false,
          updatedAt: DateTime(2026, 4, 14, 9),
        ),
      );

      final lifecycle = await service.resolveLifecycle(
        'league-1',
        now: DateTime(2026, 4, 14, 12),
      );

      expect(lifecycle.currentGameweek, 4);
      expect(lifecycle.phase, FantasyLeaguePhase.live);
      expect(lifecycle.isLocked, isTrue);
    });

    test('falls back to tournament status when no fantasy lifecycle exists',
        () async {
      await tournamentRepository.createTournament(
        Tournament(
          id: 'tour-1',
          organizerId: 'org-1',
          name: 'League One',
          format: TournamentFormat.groupsOnly,
          teamSize: TournamentTeamSize.fiveVsFive,
          maxTeams: 8,
          status: TournamentStatus.transferWindow,
          createdAt: DateTime(2026, 4, 1),
        ),
      );

      final lifecycle = await service.resolveLifecycle(
        'tour-1',
        now: DateTime(2026, 4, 14, 12),
      );

      expect(lifecycle.leagueId, 'tour-1');
      expect(lifecycle.phase, FantasyLeaguePhase.transferWindow);
      expect(lifecycle.currentGameweek, 3);
      expect(lifecycle.isLocked, isFalse);
    });
  });

  group('FantasyLifecycleRepositoryImpl', () {
    test('stores and reloads a lifecycle document from fantasyLeagues',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repository = FantasyLifecycleRepositoryImpl(firestore: firestore);
      final lifecycle = FantasyLeagueLifecycle(
        leagueId: 'league-2',
        currentGameweek: 2,
        phase: FantasyLeaguePhase.locked,
        isLocked: true,
        updatedAt: DateTime(2026, 4, 14, 8),
      );

      await repository.saveLeagueLifecycle(lifecycle);
      final stored = await repository.getLeagueLifecycle('league-2');
      final rawDoc = await firestore
          .collection(FirebasePaths.fantasyLeagues)
          .doc('league-2')
          .get();

      expect(stored, isNotNull);
      expect(stored!.currentGameweek, 2);
      expect(stored.phase, FantasyLeaguePhase.locked);
      expect(stored.isLocked, isTrue);
      expect(rawDoc.exists, isTrue);
    });
  });
}
