import 'package:get/get.dart';

import '../../../core/enums/fantasy_league_phase.dart';
import '../../../core/enums/tournament_enums.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/repositories/fantasy_lifecycle_repository_impl.dart';
import '../../../data/repositories/tournament_repository_impl.dart';
import '../../../domain/entities/fantasy_league_lifecycle.dart';
import '../../../domain/entities/tournament.dart';
import '../../../domain/repositories/fantasy_lifecycle_repository.dart';
import '../../../domain/repositories/tournament_repository.dart';

class FantasyLifecycleService extends GetxService {
  final FantasyLifecycleRepository _lifecycleRepository;
  final TournamentRepository _tournamentRepository;

  FantasyLifecycleService({
    FantasyLifecycleRepository? lifecycleRepository,
    TournamentRepository? tournamentRepository,
  })  : _lifecycleRepository =
            lifecycleRepository ?? FantasyLifecycleRepositoryImpl(),
        _tournamentRepository =
            tournamentRepository ?? TournamentRepositoryImpl();

  Future<FantasyLeagueLifecycle> resolveLifecycle(
    String leagueId, {
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();

    try {
      final stored = await _lifecycleRepository.getLeagueLifecycle(leagueId);
      if (stored != null) {
        return _normalizeLifecycle(stored, effectiveNow);
      }

      if (leagueId == 'global') {
        return _buildGlobalFallback(effectiveNow);
      }

      final tournament = await _tournamentRepository.getTournament(leagueId);
      if (tournament != null) {
        return _buildTournamentFallback(tournament, effectiveNow);
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'FantasyLifecycleService.resolveLifecycle',
        error,
        stackTrace,
      );
    }

    return _buildUnknownLeagueFallback(leagueId, effectiveNow);
  }

  Future<void> saveLifecycle(FantasyLeagueLifecycle lifecycle) async {
    final normalized = _normalizeLifecycle(
      lifecycle.copyWith(updatedAt: lifecycle.updatedAt),
      lifecycle.updatedAt,
    );
    await _lifecycleRepository.saveLeagueLifecycle(normalized);
  }

  FantasyLeagueLifecycle _normalizeLifecycle(
    FantasyLeagueLifecycle lifecycle,
    DateTime now,
  ) {
    final deadlinePassed =
        lifecycle.deadlineAt != null && !lifecycle.deadlineAt!.isAfter(now);
    final phaseLocksActions = lifecycle.phase == FantasyLeaguePhase.locked ||
        lifecycle.phase == FantasyLeaguePhase.settled ||
        lifecycle.phase == FantasyLeaguePhase.completed ||
        lifecycle.phase == FantasyLeaguePhase.cancelled;

    final effectiveLocked = lifecycle.isLocked ||
        phaseLocksActions ||
        (deadlinePassed && lifecycle.phase != FantasyLeaguePhase.transferWindow);

    return lifecycle.copyWith(
      isGlobal: lifecycle.isGlobal || lifecycle.leagueId == 'global',
      isLocked: effectiveLocked,
      updatedAt: lifecycle.updatedAt,
    );
  }

  FantasyLeagueLifecycle _buildGlobalFallback(DateTime now) {
    return FantasyLeagueLifecycle(
      leagueId: 'global',
      currentGameweek: 1,
      phase: FantasyLeaguePhase.draft,
      isLocked: false,
      isGlobal: true,
      updatedAt: now,
    );
  }

  FantasyLeagueLifecycle _buildUnknownLeagueFallback(
    String leagueId,
    DateTime now,
  ) {
    return FantasyLeagueLifecycle(
      leagueId: leagueId,
      currentGameweek: 1,
      phase: FantasyLeaguePhase.draft,
      isLocked: false,
      updatedAt: now,
    );
  }

  FantasyLeagueLifecycle _buildTournamentFallback(
    Tournament tournament,
    DateTime now,
  ) {
    final mappedPhase = switch (tournament.status) {
      TournamentStatus.upcoming => FantasyLeaguePhase.upcoming,
      TournamentStatus.registration => FantasyLeaguePhase.draft,
      TournamentStatus.groupStage => FantasyLeaguePhase.live,
      TournamentStatus.transferWindow => FantasyLeaguePhase.transferWindow,
      TournamentStatus.knockoutStage => FantasyLeaguePhase.live,
      TournamentStatus.completed => FantasyLeaguePhase.completed,
      TournamentStatus.cancelled => FantasyLeaguePhase.cancelled,
    };

    final gameweek = switch (tournament.status) {
      TournamentStatus.upcoming => 1,
      TournamentStatus.registration => 1,
      TournamentStatus.groupStage => 2,
      TournamentStatus.transferWindow => 3,
      TournamentStatus.knockoutStage => 4,
      TournamentStatus.completed => 5,
      TournamentStatus.cancelled => 1,
    };

    final deadlineAt = tournament.startDate ?? tournament.registrationDeadline;

    return _normalizeLifecycle(
      FantasyLeagueLifecycle(
        leagueId: tournament.id,
        currentGameweek: gameweek,
        phase: mappedPhase,
        deadlineAt: deadlineAt,
        isLocked: mappedPhase == FantasyLeaguePhase.completed ||
            mappedPhase == FantasyLeaguePhase.cancelled,
        isGlobal: false,
        updatedAt: now,
      ),
      now,
    );
  }
}
