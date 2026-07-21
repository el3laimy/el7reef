import 'package:get/get.dart';

import '../../../core/permissions/tournament_viewer_context.dart';
import '../../../data/repositories/tournament_repository_impl.dart';
import '../../../domain/repositories/tournament_repository.dart';

class TournamentOrganizerAccessService {
  final TournamentRepository _repository;

  TournamentOrganizerAccessService({TournamentRepository? repository})
    : _repository = repository ?? TournamentRepositoryImpl();

  factory TournamentOrganizerAccessService.fromDependencies() {
    if (Get.isRegistered<TournamentOrganizerAccessService>()) {
      return Get.find<TournamentOrganizerAccessService>();
    }
    final repository = Get.isRegistered<TournamentRepositoryImpl>()
        ? Get.find<TournamentRepositoryImpl>()
        : TournamentRepositoryImpl();
    return TournamentOrganizerAccessService(repository: repository);
  }

  Future<bool> canAccess({
    required String? tournamentId,
    required String? actorId,
  }) async {
    if (tournamentId == null ||
        tournamentId.trim().isEmpty ||
        actorId == null ||
        actorId.trim().isEmpty) {
      return false;
    }
    final tournament = await _repository.getTournament(tournamentId);
    if (tournament == null) return false;
    return TournamentViewerContext.fromTournament(
      tournament: tournament,
      userId: actorId,
    ).canViewAdminDashboard;
  }
}
