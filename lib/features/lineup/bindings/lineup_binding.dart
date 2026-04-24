import 'package:get/get.dart';

import '../../../core/auth/auth_service_session.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/services/matchday_service.dart';
import '../../../core/services/team_roster_service.dart';
import '../../../data/repositories/guest_player_repository_impl.dart';
import '../../../data/repositories/match_attendance_repository_impl.dart';
import '../../../data/repositories/match_check_in_repository_impl.dart';
import '../../../data/repositories/match_lineup_snapshot_repository_impl.dart';
import '../../../data/repositories/match_repository_impl.dart';
import '../../../data/repositories/player_repository_impl.dart';
import '../../../data/repositories/team_membership_repository_impl.dart';
import '../../../data/repositories/team_repository_impl.dart';
import '../../../data/repositories/tournament_repository_impl.dart';
import '../../../services/auth_service.dart';
import '../controllers/match_result_lineup_controller.dart';
import '../controllers/team_lineup_editor_controller.dart';

class TeamLineupEditorBinding extends Bindings {
  @override
  void dependencies() {
    _putSharedLineupDependencies();
    Get.lazyPut<TeamLineupEditorController>(
      () => TeamLineupEditorController(
        authSession: _authSession(),
        matchRepository: Get.find<MatchRepositoryImpl>(),
        teamRepository: Get.find<TeamRepositoryImpl>(),
        tournamentRepository: Get.find<TournamentRepositoryImpl>(),
        membershipRepository: Get.find<TeamMembershipRepositoryImpl>(),
        playerRepository: Get.find<PlayerRepositoryImpl>(),
        guestPlayerRepository: Get.find<GuestPlayerRepositoryImpl>(),
        snapshotRepository: Get.find<MatchLineupSnapshotRepositoryImpl>(),
        matchdayService: Get.find<MatchdayService>(),
        teamRosterService: Get.find<TeamRosterService>(),
      ),
    );
  }
}

class MatchResultLineupBinding extends Bindings {
  @override
  void dependencies() {
    _putSharedLineupDependencies();
    Get.lazyPut<MatchResultLineupController>(
      () => MatchResultLineupController(
        matchRepository: Get.find<MatchRepositoryImpl>(),
        teamRepository: Get.find<TeamRepositoryImpl>(),
        snapshotRepository: Get.find<MatchLineupSnapshotRepositoryImpl>(),
      ),
    );
  }
}

void _putSharedLineupDependencies() {
  if (!Get.isRegistered<MatchRepositoryImpl>()) {
    Get.lazyPut<MatchRepositoryImpl>(() => MatchRepositoryImpl());
  }
  if (!Get.isRegistered<TeamRepositoryImpl>()) {
    Get.lazyPut<TeamRepositoryImpl>(() => TeamRepositoryImpl());
  }
  if (!Get.isRegistered<TournamentRepositoryImpl>()) {
    Get.lazyPut<TournamentRepositoryImpl>(() => TournamentRepositoryImpl());
  }
  if (!Get.isRegistered<TeamMembershipRepositoryImpl>()) {
    Get.lazyPut<TeamMembershipRepositoryImpl>(
      () => TeamMembershipRepositoryImpl(),
    );
  }
  if (!Get.isRegistered<PlayerRepositoryImpl>()) {
    Get.lazyPut<PlayerRepositoryImpl>(() => PlayerRepositoryImpl());
  }
  if (!Get.isRegistered<GuestPlayerRepositoryImpl>()) {
    Get.lazyPut<GuestPlayerRepositoryImpl>(() => GuestPlayerRepositoryImpl());
  }
  if (!Get.isRegistered<MatchLineupSnapshotRepositoryImpl>()) {
    Get.lazyPut<MatchLineupSnapshotRepositoryImpl>(
      () => MatchLineupSnapshotRepositoryImpl(),
    );
  }
  if (!Get.isRegistered<MatchCheckInRepositoryImpl>()) {
    Get.lazyPut<MatchCheckInRepositoryImpl>(() => MatchCheckInRepositoryImpl());
  }
  if (!Get.isRegistered<MatchAttendanceRepositoryImpl>()) {
    Get.lazyPut<MatchAttendanceRepositoryImpl>(
      () => MatchAttendanceRepositoryImpl(),
    );
  }
  if (!Get.isRegistered<MatchdayService>()) {
    Get.lazyPut<MatchdayService>(() => MatchdayService());
  }
  if (!Get.isRegistered<TeamRosterService>()) {
    Get.lazyPut<TeamRosterService>(
      () => TeamRosterService(
        teamRepository: Get.find<TeamRepositoryImpl>(),
        membershipRepository: Get.find<TeamMembershipRepositoryImpl>(),
        guestPlayerRepository: Get.find<GuestPlayerRepositoryImpl>(),
      ),
    );
  }
}

AuthSession _authSession() {
  if (Get.isRegistered<AuthSession>()) {
    return Get.find<AuthSession>();
  }
  if (Get.isRegistered<AuthService>()) {
    return AuthServiceSession(Get.find<AuthService>());
  }
  return const _AnonymousAuthSession();
}

class _AnonymousAuthSession implements AuthSession {
  const _AnonymousAuthSession();

  @override
  get currentPlayer => null;

  @override
  String? get currentUserId => null;
}
