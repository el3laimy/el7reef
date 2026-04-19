import 'package:get/get.dart';

import '../../../core/services/tournament_fixture_service.dart';
import '../../../core/services/tournament_lifecycle_service.dart';
import '../../../core/services/tournament_ops_migration_service.dart';
import '../../../core/services/tournament_participant_service.dart';
import '../../../data/repositories/guest_team_repository_impl.dart';
import '../../../data/repositories/group_standing_snapshot_repository_impl.dart';
import '../../../data/repositories/knockout_bracket_repository_impl.dart';
import '../../../data/repositories/knockout_tie_repository_impl.dart';
import '../../../data/repositories/match_repository_impl.dart';
import '../../../data/repositories/team_repository_impl.dart';
import '../../../data/repositories/tournament_group_repository_impl.dart';
import '../../../data/repositories/tournament_repository_impl.dart';
import '../controllers/tournament_operations_controller.dart';

class TournamentOperationsBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<TournamentRepositoryImpl>()) {
      Get.lazyPut<TournamentRepositoryImpl>(() => TournamentRepositoryImpl());
    }
    if (!Get.isRegistered<TournamentGroupRepositoryImpl>()) {
      Get.lazyPut<TournamentGroupRepositoryImpl>(
        () => TournamentGroupRepositoryImpl(),
      );
    }
    if (!Get.isRegistered<GroupStandingSnapshotRepositoryImpl>()) {
      Get.lazyPut<GroupStandingSnapshotRepositoryImpl>(
        () => GroupStandingSnapshotRepositoryImpl(),
      );
    }
    if (!Get.isRegistered<MatchRepositoryImpl>()) {
      Get.lazyPut<MatchRepositoryImpl>(() => MatchRepositoryImpl());
    }
    if (!Get.isRegistered<TeamRepositoryImpl>()) {
      Get.lazyPut<TeamRepositoryImpl>(() => TeamRepositoryImpl());
    }
    if (!Get.isRegistered<GuestTeamRepositoryImpl>()) {
      Get.lazyPut<GuestTeamRepositoryImpl>(() => GuestTeamRepositoryImpl());
    }
    if (!Get.isRegistered<KnockoutBracketRepositoryImpl>()) {
      Get.lazyPut<KnockoutBracketRepositoryImpl>(
        () => KnockoutBracketRepositoryImpl(),
      );
    }
    if (!Get.isRegistered<KnockoutTieRepositoryImpl>()) {
      Get.lazyPut<KnockoutTieRepositoryImpl>(() => KnockoutTieRepositoryImpl());
    }
    if (!Get.isRegistered<TournamentParticipantService>()) {
      Get.lazyPut<TournamentParticipantService>(
        () => TournamentParticipantService(),
      );
    }
    if (!Get.isRegistered<TournamentOpsMigrationService>()) {
      Get.lazyPut<TournamentOpsMigrationService>(
        () => TournamentOpsMigrationService(),
      );
    }
    if (!Get.isRegistered<TournamentLifecycleService>()) {
      Get.lazyPut<TournamentLifecycleService>(
        () => TournamentLifecycleService(),
      );
    }
    if (!Get.isRegistered<TournamentFixtureService>()) {
      Get.lazyPut<TournamentFixtureService>(() => TournamentFixtureService());
    }

    Get.lazyPut<TournamentOperationsController>(
      () => TournamentOperationsController(
        tournamentRepository: Get.find<TournamentRepositoryImpl>(),
        groupRepository: Get.find<TournamentGroupRepositoryImpl>(),
        matchRepository: Get.find<MatchRepositoryImpl>(),
        teamRepository: Get.find<TeamRepositoryImpl>(),
        guestTeamRepository: Get.find<GuestTeamRepositoryImpl>(),
        standingRepository: Get.find<GroupStandingSnapshotRepositoryImpl>(),
        bracketRepository: Get.find<KnockoutBracketRepositoryImpl>(),
        tieRepository: Get.find<KnockoutTieRepositoryImpl>(),
        participantService: Get.find<TournamentParticipantService>(),
        migrationService: Get.find<TournamentOpsMigrationService>(),
        lifecycleService: Get.find<TournamentLifecycleService>(),
        fixtureService: Get.find<TournamentFixtureService>(),
      ),
    );
  }
}
